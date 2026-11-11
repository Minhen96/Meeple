import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_text_field.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';

/// Genre filter values sent to the API (web `categories`).
const libraryGenres = ['Strategy', 'Party', 'Family', '2 Player', 'Abstract'];

/// Complexity presets (web `complexityLevels`): (min, max).
const libraryComplexityLevels = [(1.0, 2.0), (2.1, 3.5), (3.6, 5.0)];

/// Sort options of the web sort select (`null` = default order).
const librarySortOptions = <String?>[
  null,
  'recommended',
  'rank,asc',
  'usersRated,desc',
  'yearPublished,desc',
  'playTime,asc',
];

String librarySortLabel(AppLocalizations l10n, String? sort) => switch (sort) {
      'recommended' => l10n.librarySortRecommended,
      'rank,asc' => l10n.librarySortRank,
      'usersRated,desc' => l10n.librarySortPopularity,
      'yearPublished,desc' => l10n.librarySortNewest,
      'playTime,asc' => l10n.librarySortShortest,
      _ => l10n.librarySortLabel,
    };

String libraryGenreLabel(AppLocalizations l10n, String genre) =>
    switch (genre) {
      'Strategy' => l10n.libraryGenreStrategy,
      'Party' => l10n.libraryGenreParty,
      'Family' => l10n.libraryGenreFamily,
      '2 Player' => l10n.libraryGenreTwoPlayer,
      _ => l10n.libraryGenreAbstract,
    };

Future<T?> _showLibrarySheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      builder: (_) => child,
    );

/// "Discovery Filters" sheet (web phone filter modal). Resolves to the
/// edited query when applied or reset, `null` when dismissed.
Future<GameBrowseQuery?> showLibraryFilterSheet(
  BuildContext context,
  GameBrowseQuery current,
) =>
    _showLibrarySheet<GameBrowseQuery>(
      context,
      LibraryFilterSheet(initial: current),
    );

/// Sort picker sheet. Resolves to `(sort,)` when an option is picked.
Future<(String?,)?> showLibrarySortSheet(
  BuildContext context,
  String? current,
) =>
    _showLibrarySheet<(String?,)>(context, _SortSheet(current: current));

class LibraryFilterSheet extends StatefulWidget {
  const LibraryFilterSheet({super.key, required this.initial});

  final GameBrowseQuery initial;

  @override
  State<LibraryFilterSheet> createState() => _LibraryFilterSheetState();
}

class _LibraryFilterSheetState extends State<LibraryFilterSheet> {
  late GameBrowseQuery _q = widget.initial;
  late final _minPlayers = _ctrl(widget.initial.minPlayers);
  late final _maxPlayers = _ctrl(widget.initial.maxPlayers);
  late final _minTime = _ctrl(widget.initial.minPlaytime);
  late final _maxTime = _ctrl(widget.initial.maxPlaytime);
  late final _minRating = _ctrl(widget.initial.minRating);

  static TextEditingController _ctrl(num? v) =>
      TextEditingController(text: v == null ? '' : '$v');

  @override
  void dispose() {
    for (final c in [
      _minPlayers,
      _maxPlayers,
      _minTime,
      _maxTime,
      _minRating
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static int? _int(String s) {
    final v = int.tryParse(s.trim());
    return v == null || v <= 0 ? null : v;
  }

  GameBrowseQuery _result() {
    final rating = double.tryParse(_minRating.text.trim());
    return _q.copyWith(
      minPlayers: () => _int(_minPlayers.text),
      maxPlayers: () => _int(_maxPlayers.text),
      minPlaytime: () => _int(_minTime.text),
      maxPlaytime: () => _int(_maxTime.text),
      minRating: () => rating == null || rating <= 0 ? null : rating,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.xxl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.libraryFiltersTitle,
                  style:
                      AppTypography.headlineMedium.copyWith(letterSpacing: 0),
                ),
              ),
              CircleIconButton(
                icon: Icons.close_rounded,
                tooltip: l10n.commonClose,
                color: AppColors.surfaceContainerHigh,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Label(l10n.libraryFiltersGenre),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final g in libraryGenres)
                        _Choice(
                          key: ValueKey('genre-$g'),
                          label: libraryGenreLabel(l10n, g),
                          selected: _q.genre == g,
                          onTap: () => setState(
                            () => _q = _q.copyWith(
                              genre: () => _q.genre == g ? null : g,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _Label(l10n.libraryFiltersComplexity),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final (i, (min, max))
                          in libraryComplexityLevels.indexed)
                        _Choice(
                          key: ValueKey('complexity-$i'),
                          label: [
                            l10n.libraryComplexityLight,
                            l10n.libraryComplexityMedium,
                            l10n.libraryComplexityHeavy,
                          ][i],
                          selected: _q.minComplexity == min &&
                              _q.maxComplexity == max,
                          onTap: () => setState(() {
                            final on = _q.minComplexity == min &&
                                _q.maxComplexity == max;
                            _q = _q.copyWith(
                              minComplexity: () => on ? null : min,
                              maxComplexity: () => on ? null : max,
                            );
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _Label(
                    l10n.libraryFiltersPlayers,
                    trailing: l10n.libraryFiltersMinMax,
                  ),
                  _Pair(
                    left: _NumberField(
                      key: const Key('filter-min-players'),
                      controller: _minPlayers,
                      hint: l10n.libraryFiltersMin,
                    ),
                    right: _NumberField(
                      key: const Key('filter-max-players'),
                      controller: _maxPlayers,
                      hint: l10n.libraryFiltersMax,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _Label(l10n.libraryFiltersPlaytime),
                  _Pair(
                    left: _NumberField(
                      key: const Key('filter-min-time'),
                      controller: _minTime,
                      hint: l10n.libraryFiltersMin,
                    ),
                    right: _NumberField(
                      key: const Key('filter-max-time'),
                      controller: _maxTime,
                      hint: l10n.libraryFiltersMax,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _Label(l10n.libraryFiltersMinRating),
                  _NumberField(
                    key: const Key('filter-min-rating'),
                    controller: _minRating,
                    hint: '0.0',
                    decimal: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: _SheetButton(
                  key: const Key('filter-reset'),
                  label: l10n.libraryFiltersReset,
                  onTap: () => Navigator.of(context).pop(_q.withoutFilters()),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                flex: 2,
                child: _SheetButton(
                  key: const Key('filter-apply'),
                  label: l10n.libraryFiltersApply,
                  primary: true,
                  onTap: () => Navigator.of(context).pop(_result()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text.toUpperCase(),
                style: AppTypography.overline.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      );
}

class _Pair extends StatelessWidget {
  const _Pair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: left),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: right),
        ],
      );
}

/// `px-4 py-2 rounded-2xl text-sm font-bold` toggle.
class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? AppColors.primary : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                label,
                style: AppTypography.titleSmall.copyWith(
                  color: selected
                      ? AppColors.onPrimary
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.controller,
    required this.hint,
    this.decimal = false,
  });

  final TextEditingController controller;
  final String hint;
  final bool decimal;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
              RegExp(decimal ? r'[0-9.]' : '[0-9]')),
        ],
        style: AppTypography.bodyMedium,
        decoration: appFieldDecoration(
          hint: hint,
          fill: AppColors.surfaceContainerHigh,
          contentPadding: const EdgeInsets.all(AppSpacing.lg),
        ),
      );
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) => Material(
        color: primary ? AppColors.primary : AppColors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          onTap: onTap,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: primary
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  )
                : null,
            child: Text(
              label,
              style: AppTypography.titleSmall.copyWith(
                color:
                    primary ? AppColors.onPrimary : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.current});

  final String? current;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.sm,
              bottom: AppSpacing.lg,
            ),
            child: Text(
              l10n.librarySortLabel,
              style: AppTypography.headlineMedium.copyWith(letterSpacing: 0),
            ),
          ),
          for (final s in librarySortOptions.skip(1))
            Material(
              color: s == current
                  ? AppColors.surfaceContainerHigh
                  : AppColors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: InkWell(
                key: ValueKey('sort-$s'),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                // Picking the active option again returns to the default.
                onTap: () =>
                    Navigator.of(context).pop((s == current ? null : s,)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          librarySortLabel(l10n, s),
                          style: AppTypography.titleSmall.copyWith(
                            color: s == current
                                ? AppColors.primary
                                : AppColors.onSurface,
                          ),
                        ),
                      ),
                      if (s == current)
                        const Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
