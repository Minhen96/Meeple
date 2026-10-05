import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/push/push_providers.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';

/// In-app pre-permission prompt shown before the OS notification dialog
/// (MOBILE_FLUTTER §8): "Allow" triggers the system request, "Not now"
/// never asks again automatically.
class PushPermissionScreen extends ConsumerStatefulWidget {
  const PushPermissionScreen({super.key});

  @override
  ConsumerState<PushPermissionScreen> createState() =>
      _PushPermissionScreenState();
}

class _PushPermissionScreenState extends ConsumerState<PushPermissionScreen> {
  bool _busy = false;

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _allow() async {
    setState(() => _busy = true);
    await ref.read(pushServiceProvider).requestPermission();
    if (mounted) _close();
  }

  Future<void> _notNow() async {
    await ref.read(pushServiceProvider).dismissPrePrompt();
    if (mounted) _close();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: const BoxDecoration(
                  color: AppColors.primaryFixed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  size: 56,
                  color: AppColors.primary,
                ),
              ),
              AppSpacing.vGapXl,
              Text(
                l10n.pushPromptTitle,
                style: AppTypography.headlineMedium,
                textAlign: TextAlign.center,
              ),
              AppSpacing.vGapMd,
              Text(
                l10n.pushPromptBody,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppButton(
                key: const Key('push-allow'),
                label: l10n.pushPromptAllow,
                isLoading: _busy,
                onPressed: _allow,
              ),
              AppSpacing.vGapSm,
              TextButton(
                key: const Key('push-not-now'),
                onPressed: _busy ? null : _notNow,
                child: Text(l10n.pushPromptNotNow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
