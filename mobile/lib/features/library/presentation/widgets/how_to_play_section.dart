import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/domain/user_game_model.dart';
import 'package:meeple_hearth/features/library/providers/library_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';

/// Section order of the AI-extracted guide (HowToPlayExtractionService).
const howToPlaySectionOrder = [
  'overview',
  'objective',
  'setup',
  'gameStructure',
  'winCondition',
  'endCondition',
  'scoring',
  'actions',
  'resources',
  'rules',
  'faq',
  'tips',
];

/// Flattens a JSON value of the guide into readable lines.
List<String> flattenGuideValue(Object? value) {
  if (value == null) return const [];
  if (value is String) return value.trim().isEmpty ? const [] : [value.trim()];
  if (value is num || value is bool) return ['$value'];
  if (value is List) {
    return [
      for (final item in value)
        if (item is Map)
          _mapLine(item)
        else
          ...flattenGuideValue(item).map((l) => '• $l'),
    ].where((l) => l.isNotEmpty).toList();
  }
  if (value is Map) {
    if (value['exists'] == false) return const [];
    return [
      for (final entry in value.entries)
        if (entry.key != 'exists') ...flattenGuideValue(entry.value),
    ];
  }
  return const [];
}

String _mapLine(Map<dynamic, dynamic> m) {
  final name = m['name'] ?? m['question'] ?? m['item'];
  final rest = m.entries
      .where((e) => e.key != 'name' && e.key != 'question' && e.key != 'item')
      .expand((e) => flattenGuideValue(e.value))
      .join(' — ');
  if (name == null) return '• $rest';
  return rest.isEmpty ? '• $name' : '• $name: $rest';
}

/// Expandable How-to-Play card (generated guide, generating progress, or a
/// "Generate" button).
class HowToPlaySection extends ConsumerWidget {
  const HowToPlaySection({super.key, required this.game});

  final Game game;

  String _title(AppLocalizations l10n, String key) => switch (key) {
        'overview' => l10n.htpOverview,
        'objective' => l10n.htpObjective,
        'setup' => l10n.htpSetup,
        'gameStructure' => l10n.htpTurns,
        'winCondition' => l10n.htpWinning,
        'endCondition' => l10n.htpEnd,
        'scoring' => l10n.htpScoring,
        'actions' => l10n.htpActions,
        'resources' => l10n.htpResources,
        'rules' => l10n.htpRules,
        'faq' => l10n.htpFaq,
        'tips' => l10n.htpTips,
        _ => key,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final guide = ref.watch(howToPlayNotifierProvider(game.id));
    Widget body = guide.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(l10n.htpUnavailable, style: AppTypography.bodySmall),
      ),
      data: (g) => _content(context, ref, l10n, g),
    );
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Material(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.borderRadiusXl,
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: const Key('how-to-play'),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: const Icon(Icons.menu_book_outlined, color: AppColors.tertiary),
          title: Text(l10n.htpTitle, style: AppTypography.titleMedium),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          children: [body],
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    HowToPlay g,
  ) {
    switch (g.status) {
      case 'generating':
        return Column(
          children: [
            LinearProgressIndicator(
              value: g.progress == null ? null : g.progress! / 100,
            ),
            AppSpacing.vGapSm,
            Text(l10n.htpGenerating(g.progress ?? 0), style: AppTypography.bodySmall),
          ],
        );
      case 'ready':
        final data = g.data ?? const <String, dynamic>{};
        final keys = [
          ...howToPlaySectionOrder.where(data.containsKey),
          ...data.keys.where((k) => !howToPlaySectionOrder.contains(k) &&
              const {'board', 'cardSystem', 'roles', 'variants', 'components'}
                  .contains(k)),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (g.disclaimer != null)
              Text(
                g.disclaimer!,
                style: AppTypography.bodySmall.copyWith(fontStyle: FontStyle.italic),
              ),
            for (final key in keys) ...[
              AppSpacing.vGapMd,
              Text(_title(l10n, key), style: AppTypography.titleSmall),
              for (final line in flattenGuideValue(data[key]))
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(line, style: AppTypography.bodyMedium),
                ),
            ],
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              g.status == 'failed'
                  ? (g.errorMessage ?? l10n.htpFailed)
                  : l10n.htpNotGenerated,
              style: AppTypography.bodyMedium,
            ),
            AppSpacing.vGapSm,
            FilledButton.tonalIcon(
              key: const Key('htp-generate'),
              onPressed: () async {
                try {
                  await ref
                      .read(howToPlayNotifierProvider(game.id).notifier)
                      .generate();
                } catch (e) {
                  if (context.mounted) showErrorToast(context, e);
                }
              },
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(l10n.htpGenerate),
            ),
          ],
        );
    }
  }
}
