import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/utils/app_date_utils.dart';
import 'package:meeple_hearth/features/notifications/domain/notification_model.dart';
import 'package:meeple_hearth/features/notifications/presentation/notification_text.dart';
import 'package:meeple_hearth/features/notifications/providers/notifications_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';

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
        fallbackRoute: '/settings',
      ),
      body: prefs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(notificationPreferencesProvider),
        ),
        data: (list) => ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            const _QuietHoursCard(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.prefTypeHeader,
                      style: AppTypography.labelMedium,
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      l10n.prefInApp,
                      textAlign: TextAlign.center,
                      style: AppTypography.labelSmall,
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      l10n.prefPush,
                      textAlign: TextAlign.center,
                      style: AppTypography.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
            for (final p in list)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        notificationTypeLabel(l10n, p.type),
                        style: AppTypography.bodyMedium,
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
                              .read(notificationPreferencesProvider.notifier)
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
                              .read(notificationPreferencesProvider.notifier)
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

    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.borderRadiusXl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            key: const Key('quiet-hours'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.quietHoursTitle, style: AppTypography.titleMedium),
            subtitle: Text(l10n.quietHoursBody),
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('quiet-start'),
                  onPressed: settings.quietHoursEnabled
                      ? () => pick(isStart: true)
                      : null,
                  child: Text(l10n.quietHoursFrom(start.format(context))),
                ),
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: OutlinedButton(
                  key: const Key('quiet-end'),
                  onPressed: settings.quietHoursEnabled
                      ? () => pick(isStart: false)
                      : null,
                  child: Text(l10n.quietHoursTo(end.format(context))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
