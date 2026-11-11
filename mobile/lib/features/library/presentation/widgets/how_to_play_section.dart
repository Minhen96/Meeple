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
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';

/// Section order of the AI-extracted guide (HowToPlayExtractionService).
const howToPlaySectionOrder = [
  'overview',
  'objective',
  'components',
  'setup',
  'resources',
  'cardSystem',
  'board',
  'roles',
  'actions',
  'gameStructure',
  'rules',
  'variants',
  'scoring',
  'winCondition',
  'endCondition',
  'tips',
  'faq',
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

/// How to Play tab (web `HowToPlayTab`): the AI rule extraction header,
/// then the generated guide, its generating progress, or a "Generate" card.
class HowToPlaySection extends ConsumerWidget {
  const HowToPlaySection({super.key, required this.game});

  final Game game;

  /// (emoji, tile colour, title) of a guide section.
  static (String, Color, String) sectionStyle(
          AppLocalizations l10n, String key) =>
      switch (key) {
        'overview' => (
            '📖',
            AppColors.primary.withValues(alpha: 0.1),
            l10n.htpOverview
          ),
        'objective' => (
            '🎯',
            AppColors.primary.withValues(alpha: 0.1),
            l10n.htpObjective
          ),
        'components' => (
            '📦',
            AppColors.surfaceContainerHigh,
            l10n.htpSectionComponents
          ),
        'setup' => (
            '⚙️',
            AppColors.secondary.withValues(alpha: 0.1),
            l10n.htpSetup
          ),
        'resources' => ('💰', const Color(0x1AFBBF24), l10n.htpResources),
        'cardSystem' => (
            '🃏',
            AppColors.tertiary.withValues(alpha: 0.1),
            l10n.htpSectionCards
          ),
        'board' => (
            '🗺️',
            AppColors.surfaceContainerHigh,
            l10n.htpSectionBoard
          ),
        'roles' => (
            '👤',
            AppColors.secondary.withValues(alpha: 0.1),
            l10n.htpSectionRoles
          ),
        'actions' => (
            '⚡',
            AppColors.primary.withValues(alpha: 0.1),
            l10n.htpActions
          ),
        'gameStructure' => (
            '🔄',
            AppColors.tertiary.withValues(alpha: 0.1),
            l10n.htpSectionFlow
          ),
        'rules' => ('📜', AppColors.surfaceContainerHigh, l10n.htpRules),
        'variants' => (
            '🎲',
            AppColors.surfaceContainerHigh,
            l10n.htpSectionVariants
          ),
        'scoring' => ('🔢', const Color(0x1AFBBF24), l10n.htpScoring),
        'winCondition' => ('🏆', const Color(0x1AFBBF24), l10n.htpSectionWin),
        'endCondition' => ('🏁', AppColors.surfaceContainerHigh, l10n.htpEnd),
        'tips' => (
            '💡',
            AppColors.tertiary.withValues(alpha: 0.1),
            l10n.htpSectionTips
          ),
        'faq' => ('❓', AppColors.secondary.withValues(alpha: 0.1), l10n.htpFaq),
        _ => ('•', AppColors.surfaceContainerHigh, key),
      };

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(howToPlayNotifierProvider(game.id).notifier).generate();
    } catch (e) {
      if (context.mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final guide = ref.watch(howToPlayNotifierProvider(game.id));
    return Column(
      key: const Key('how-to-play-tab'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        const _Header(),
        const SizedBox(height: AppSpacing.xxl),
        guide.when(
          loading: () => const _GuideSkeleton(),
          error: (_, __) => _StateCard(
            tone: AppColors.surfaceContainerLow,
            iconTone: AppColors.primary.withValues(alpha: 0.1),
            icon: Icons.cloud_off_rounded,
            iconColor: AppColors.primary.withValues(alpha: 0.6),
            title: l10n.htpUnavailable,
          ),
          data: (g) => switch (g.status) {
            'generating' => _StateCard(
                tone: AppColors.tertiary.withValues(alpha: 0.1),
                iconTone: AppColors.tertiary.withValues(alpha: 0.1),
                icon: Icons.autorenew_rounded,
                iconColor: AppColors.tertiary,
                title: l10n.htpGeneratingTitle,
                body: l10n.htpGeneratingBody,
                footer: _Progress(progress: g.progress),
              ),
            'ready' => _Guide(guide: g),
            _ => _StateCard(
                tone: AppColors.surfaceContainerLow,
                iconTone: AppColors.primary.withValues(alpha: 0.1),
                icon: Icons.auto_awesome_rounded,
                iconColor: AppColors.primary.withValues(alpha: 0.6),
                title: g.status == 'failed'
                    ? l10n.htpFailedTitle
                    : l10n.htpGenerateTitle,
                body: g.status == 'failed'
                    ? (g.errorMessage ?? l10n.htpFailed)
                    : l10n.htpGenerateBody,
                footer: Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  child: InkWell(
                    key: const Key('htp-generate'),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    onTap: () => _generate(context, ref),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                            color: AppColors.onPrimary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            g.status == 'failed'
                                ? l10n.commonRetry
                                : l10n.htpGenerateShort,
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          },
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.06),
            AppColors.background,
            AppColors.secondary.withValues(alpha: 0.03),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      l10n.htpEyebrow.toUpperCase(),
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.htpTitle, style: AppTypography.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text(
                    l10n.htpSubtitle,
                    style: AppTypography.bodySmall.copyWith(height: 1.6),
                  ),
                ),
              ],
            ),
          ),
          Transform.rotate(
            angle: 0.2,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: 40,
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `rounded-3xl p-8` centred card with an icon tile, title, body, footer.
class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.tone,
    required this.iconTone,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.body,
    this.footer,
  });

  final Color tone;
  final Color iconTone;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: tone,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: iconTone,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: Icon(icon, size: 36, color: iconColor),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium,
            ),
            if (body != null) ...[
              const SizedBox(height: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(height: 1.6),
                ),
              ),
            ],
            if (footer != null) ...[
              const SizedBox(height: AppSpacing.lg),
              footer!,
            ],
          ],
        ),
      );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.progress});

  final int? progress;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ClipRRect(
              borderRadius: AppSpacing.borderRadiusFull,
              child: LinearProgressIndicator(
                value: progress == null ? null : progress! / 100,
                minHeight: 6,
                color: AppColors.tertiary,
                backgroundColor: AppColors.tertiary.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.htpGenerating(progress ?? 0),
              style: AppTypography.labelSmall.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.tertiary,
              ),
            ),
          ],
        ),
      );
}

class _Guide extends StatelessWidget {
  const _Guide({required this.guide});

  final HowToPlay guide;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = guide.data ?? const <String, dynamic>{};
    final keys = [
      ...howToPlaySectionOrder.where(data.containsKey),
    ].where((k) => flattenGuideValue(data[k]).isNotEmpty).toList();
    final rulebook = guide.sourceMode == 'rulebook';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (guide.sourceMode != null || guide.disclaimer != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (guide.sourceMode != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: rulebook
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : const Color(0x1AFBBF24),
                      borderRadius: AppSpacing.borderRadiusFull,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          rulebook
                              ? Icons.menu_book_rounded
                              : Icons.psychology_outlined,
                          size: 12,
                          color: rulebook
                              ? AppColors.primary
                              : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          (rulebook ? l10n.htpSourceRulebook : l10n.htpSourceAi)
                              .toUpperCase(),
                          style: AppTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: rulebook
                                ? AppColors.primary
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (guide.disclaimer != null)
                  Text(
                    guide.disclaimer!,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
        for (final key in keys) ...[
          _GuideSection(sectionKey: key, value: data[key]),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ],
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({required this.sectionKey, required this.value});

  final String sectionKey;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final (emoji, tone, title) =
        HowToPlaySection.sectionStyle(context.l10n, sectionKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 48, top: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in flattenGuideValue(value))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    line,
                    style: AppTypography.bodyMedium.copyWith(height: 1.6),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideSkeleton extends StatelessWidget {
  const _GuideSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
        child: Column(
          children: [
            for (var i = 0; i < 3; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SkeletonBox(
                          width: 40,
                          height: 40,
                          borderRadius: AppSpacing.borderRadiusMd,
                        ),
                        SizedBox(width: AppSpacing.md),
                        SkeletonBox(width: 128, height: 16),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: 52, top: AppSpacing.sm),
                      child: Column(
                        children: [
                          SkeletonBox(height: 12),
                          SizedBox(height: AppSpacing.sm),
                          SkeletonBox(height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}
