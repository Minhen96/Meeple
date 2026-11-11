import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/constants/text_style_weight.dart';
import 'package:meeple_hearth/core/utils/app_date_utils.dart';
import 'package:meeple_hearth/features/notifications/domain/notification_model.dart';
import 'package:meeple_hearth/features/notifications/presentation/notification_text.dart';
import 'package:meeple_hearth/features/notifications/providers/notifications_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';

/// Parses "HH:mm" into a [TimeOfDay].
TimeOfDay? parseHhMm(String? value) {
  if (value == null) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h > 23 || m > 59) return null;
  return TimeOfDay(hour: h, minute: m);
}

/// Per-type In-App / Push toggles and Quiet Hours (SCREENS §11.3).
class NotificationPrefsScreen extends ConsumerWidget {
  const NotificationPrefsScreen({super.key});

  Future<void> _guard(BuildContext context, Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (context.mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final prefs = ref.watch(notificationPreferencesProvider);
    return Scaffold(
      appBar: MeepleAppBar(
        title: l10n.notificationPrefsTitle,
        showBackButton: true,
        compactTitle: true,
        fallbackRoute: '/settings',
      ),
      body: prefs.when(
        loading: () => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            for (var i = 0; i < 6; i++) ...[
              const SkeletonBox(height: 40),
              AppSpacing.vGapMd,
            ],
          ],
        ),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(notificationPreferencesProvider),
        ),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          children: [
            Text(
              l10n.notificationPrefsIntro,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            AppSpacing.vGapLg,
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.prefTypeHeader.toUpperCase(),
                          style: AppTypography.overline
                              .copyWith(letterSpacing: 0.6),
                        ),
                      ),
                      for (final label in [l10n.prefInApp, l10n.prefPush])
                        SizedBox(
                          width: 64,
                          child: Text(
                            label.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: AppTypography.overline
                                .copyWith(letterSpacing: 0.6),
                          ),
                        ),
                    ],
                  ),
                  for (final p in list)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              notificationTypeLabel(l10n, p.type),
                              style: AppTypography.bodyMedium
                                  .copyWith(color: AppColors.onSurface),
                            ),
                          ),
                          SizedBox(
                            width: 64,
                            child: Switch(
                              key: ValueKey('pref-inapp-${p.type}'),
                              value: p.inAppEnabled,
                              onChanged: (v) => _guard(
                                context,
                                () => ref
                                    .read(
                                      notificationPreferencesProvider.notifier,
                                    )
                                    .toggle(p.type, inApp: v),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 64,
                            child: Switch(
                              key: ValueKey('pref-push-${p.type}'),
                              value: p.pushEnabled,
                              onChanged: (v) => _guard(
                                context,
                                () => ref
                                    .read(
                                      notificationPreferencesProvider.notifier,
                                    )
                                    .toggle(p.type, push: v),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            AppSpacing.vGapXl,
            const _QuietHoursCard(),
          ],
        ),
      ),
    );
  }
}

class _QuietHoursCard extends ConsumerWidget {
  const _QuietHoursCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(quietHoursProvider).valueOrNull;
    if (settings == null) return const SizedBox.shrink();
    final start = parseHhMm(settings.quietHoursStart) ??
        const TimeOfDay(hour: 22, minute: 0);
    final end = parseHhMm(settings.quietHoursEnd) ??
        const TimeOfDay(hour: 8, minute: 0);

    Future<void> save(NotificationSettings next) async {
      try {
        await ref.read(quietHoursProvider.notifier).save(next);
      } catch (e) {
        if (context.mounted) showErrorToast(context, e);
      }
    }

    Future<void> pick({required bool isStart}) async {
      final picked = await showTimePicker(
        context: context,
        initialTime: isStart ? start : end,
      );
      if (picked == null) return;
      final value = AppDateUtils.formatHhMm(picked.hour, picked.minute);
      await save(
        isStart
            ? settings.copyWith(quietHoursStart: value)
            : settings.copyWith(quietHoursEnd: value),
      );
    }

    Widget timeField({
      required Key key,
      required String label,
      required TimeOfDay time,
      required bool isStart,
    }) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.labelMedium.weight(FontWeight.w500),
              ),
              AppSpacing.vGapXs,
              Opacity(
                opacity: settings.quietHoursEnabled ? 1 : 0.5,
                child: Material(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: key,
                    onTap: settings.quietHoursEnabled
                        ? () => pick(isStart: isStart)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              time.format(context),
                              style: AppTypography.bodyMedium
                                  .copyWith(color: AppColors.onSurface),
                            ),
                          ),
                          const Icon(
                            Icons.schedule_rounded,
                            size: 18,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.quietHoursTitle,
                      style: AppTypography.bodyLarge
                          .weight(FontWeight.w600)
                          .copyWith(color: AppColors.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.quietHoursBody,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Switch(
                key: const Key('quiet-hours'),
                value: settings.quietHoursEnabled,
                onChanged: (v) => save(
                  settings.copyWith(
                    quietHoursEnabled: v,
                    quietHoursStart: settings.quietHoursStart ??
                        AppDateUtils.formatHhMm(start.hour, start.minute),
                    quietHoursEnd: settings.quietHoursEnd ??
                        AppDateUtils.formatHhMm(end.hour, end.minute),
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.vGapLg,
          Row(
            children: [
              timeField(
                key: const Key('quiet-start'),
                label: l10n.quietHoursStartLabel,
                time: start,
                isStart: true,
              ),
              AppSpacing.hGapMd,
              timeField(
                key: const Key('quiet-end'),
                label: l10n.quietHoursEndLabel,
                time: end,
                isStart: false,
              ),
            ],
          ),
          if (settings.timezone != null) ...[
            AppSpacing.vGapMd,
            Text(
              l10n.quietHoursTimezone(settings.timezone!),
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
