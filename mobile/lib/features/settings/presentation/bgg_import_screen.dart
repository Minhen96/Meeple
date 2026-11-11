import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/constants/text_style_weight.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/library/domain/user_game_model.dart';
import 'package:meeple_hearth/features/library/providers/library_provider.dart';
import 'package:meeple_hearth/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';

/// BGG import form + live progress — the web `BggImportPanel` (shared by
/// Settings and onboarding).
class BggImportPanel extends ConsumerStatefulWidget {
  const BggImportPanel({super.key, this.onDone, this.doneLabel});

  /// Action shown once the import finished ("Continue" in onboarding,
  /// "View my library" in Settings). Without it: "Import again".
  final VoidCallback? onDone;
  final String? doneLabel;

  @override
  ConsumerState<BggImportPanel> createState() => _BggImportPanelState();
}

class _BggImportPanelState extends ConsumerState<BggImportPanel> {
  late final _username = TextEditingController(
    text: ref.read(authNotifierProvider).valueOrNull?.bggUsername ?? '',
  );

  /// "Import again" hides the finished result.
  bool _again = false;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  String? _errorText(AppLocalizations l10n, BggImportStatus s) =>
      switch (s.errorCode) {
        'BGG_USER_NOT_FOUND' => l10n.errorBggUserNotFound,
        'BGG_API_UNAVAILABLE' => l10n.errorBggUnavailable,
        null => s.isFailed ? l10n.bggImportFailed : null,
        _ => l10n.bggImportFailed,
      };

  void _start() {
    final name = _username.text.trim();
    if (name.isEmpty) return;
    setState(() => _again = false);
    ref.read(bggImportProvider.notifier).start(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final import = ref.watch(bggImportProvider);
    final status = import.valueOrNull ?? const BggImportStatus();
    final running = status.isRunning;
    final error = import.hasError
        ? localizedError(l10n, import.error!)
        : _errorText(l10n, status);
    if (status.isDone && !_again) return _done(l10n, status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          Container(
            key: const Key('bgg-error'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            ),
            child: Text(
              error,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.onErrorContainer),
            ),
          ),
          AppSpacing.vGapLg,
        ],
        SettingsField(
          fieldKey: const Key('bgg-username'),
          label: l10n.bggUsername,
          hint: l10n.bggUsername,
          controller: _username,
          enabled: !running,
          maxLength: 50,
          autofillHints: const [AutofillHints.username],
          onChanged: (_) => setState(() {}),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, AppSpacing.sm, 4, 0),
          child: Text(
            l10n.bggPrivacyNote,
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
        if (running) ...[
          AppSpacing.vGapLg,
          Text(
            status.total > 0
                ? l10n.bggImportProgress(status.processed, status.total)
                : l10n.bggImportStarting,
            style: AppTypography.titleSmall,
          ),
          AppSpacing.vGapSm,
          ClipRRect(
            borderRadius: AppSpacing.borderRadiusFull,
            child: LinearProgressIndicator(
              minHeight: 8,
              backgroundColor: AppColors.surfaceContainerHigh,
              value: status.total > 0 ? status.processed / status.total : null,
            ),
          ),
        ],
        AppSpacing.vGapLg,
        AppButton(
          key: const Key('bgg-import'),
          label: l10n.bggImportStart,
          isLoading: running,
          onPressed: running || _username.text.trim().isEmpty ? null : _start,
        ),
      ],
    );
  }

  Widget _done(AppLocalizations l10n, BggImportStatus status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 32,
              color: AppColors.tertiary,
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Text(
                status.imported > 0
                    ? l10n.bggImportSuccess(status.imported)
                    : l10n.bggImportSuccessNone,
                key: const Key('bgg-done'),
                style: AppTypography.titleLarge.weight(FontWeight.w800),
              ),
            ),
          ],
        ),
        if (status.skipped > 0) ...[
          const SizedBox(height: 20),
          Text(
            l10n.bggImportSkipped(status.skipped),
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
        if (status.preview.isNotEmpty) ...[
          const SizedBox(height: 20),
          SizedBox(
            height: 136,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: status.preview.length,
              separatorBuilder: (_, __) => AppSpacing.hGapMd,
              itemBuilder: (_, i) => _PreviewGame(game: status.preview[i]),
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (widget.onDone != null)
          AppButton(
            key: const Key('bgg-done-action'),
            label: widget.doneLabel ?? l10n.commonContinue,
            onPressed: widget.onDone,
          )
        else
          AppButton(
            key: const Key('bgg-again'),
            label: l10n.bggImportAgain,
            variant: AppButtonVariant.secondary,
            onPressed: () => setState(() => _again = true),
          ),
      ],
    );
  }
}

class _PreviewGame extends StatelessWidget {
  const _PreviewGame({required this.game});

  final BggPreviewGame game;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 80,
      height: 96,
      color: AppColors.surfaceContainerHigh,
      child: const Icon(
        Icons.casino_outlined,
        color: AppColors.onSurfaceVariant,
      ),
    );
    return GestureDetector(
      onTap: () => context.push(AppRoutes.gameDetail(game.gameId)),
      child: SizedBox(
        width: 80,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.tile / 2),
              child: game.thumbnailUrl == null
                  ? placeholder
                  : CachedNetworkImage(
                      imageUrl: game.thumbnailUrl!,
                      width: 80,
                      height: 96,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => placeholder,
                    ),
            ),
            AppSpacing.vGapXs,
            Text(
              game.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall.weight(FontWeight.w700).copyWith(
                  fontSize: 11, color: AppColors.onSurface, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings › BGG Import (web `/settings/bgg`).
class BggImportScreen extends StatelessWidget {
  const BggImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: MeepleAppBar(
        title: l10n.bggSettingsTitle,
        showBackButton: true,
        compactTitle: true,
        fallbackRoute: AppRoutes.settings,
      ),
      body: ListView(
        padding: settingsPagePadding,
        children: [
          SettingsNote(l10n.bggImportBody),
          AppSpacing.vGapXl,
          BggImportPanel(
            doneLabel: l10n.bggViewLibrary,
            onDone: () => context.go(AppRoutes.library),
          ),
        ],
      ),
    );
  }
}
