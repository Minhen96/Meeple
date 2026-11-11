import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/onboarding/providers/onboarding_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';

/// Ordered onboarding steps 2–5 (SCREENS §3.1).
const onboardingSteps = [
  AppRoutes.onboardingProfile,
  AppRoutes.onboardingBgg,
  AppRoutes.onboardingFriends,
  AppRoutes.onboardingAddGame,
];

/// Goes to the step after [current], or finishes onboarding after the last.
Future<void> goToNextOnboardingStep(
  BuildContext context,
  WidgetRef ref,
  String current,
) async {
  final i = onboardingSteps.indexOf(current);
  if (i >= 0 && i < onboardingSteps.length - 1) {
    context.go(onboardingSteps[i + 1]);
    return;
  }
  try {
    // The router leaves onboarding once `onboardingCompleted` is true.
    await ref.read(onboardingNotifierProvider.notifier).completeOnboarding();
    if (context.mounted) context.go(AppRoutes.home);
  } catch (e) {
    if (context.mounted) showErrorToast(context, e);
  }
}

/// Horizontal padding of the onboarding steps (web `px-6`).
const onboardingGutter = AppSpacing.xl;

/// Layout of steps 2–5 (web onboarding layout): step dots and "Skip" in a
/// slim top row, a 24px bold title (optional icon and subtitle) and the
/// step's content; [bottom] holds the primary action.
class OnboardingScaffold extends ConsumerWidget {
  const OnboardingScaffold({
    super.key,
    required this.route,
    required this.title,
    required this.child,
    this.subtitle,
    this.titleIcon,
    this.bottom,
  });

  final String route;
  final String title;
  final String? subtitle;

  /// Primary icon before the title (web BGG step `inventory_2`).
  final IconData? titleIcon;
  final Widget child;
  final Widget? bottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final step = onboardingSteps.indexOf(route);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                onboardingGutter,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  OnboardingStepDots(
                    total: onboardingSteps.length,
                    current: step,
                  ),
                  const Spacer(),
                  TextButton(
                    key: const Key('onboarding-skip'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.onSurfaceVariant,
                      textStyle: AppTypography.labelLarge,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () =>
                        goToNextOnboardingStep(context, ref, route),
                    child: Text(l10n.commonSkip),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                onboardingGutter,
                AppSpacing.sm,
                onboardingGutter,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (titleIcon != null) ...[
                        Icon(titleIcon, size: 28, color: AppColors.primary),
                        AppSpacing.hGapMd,
                      ],
                      Expanded(
                        child: Text(title, style: AppTypography.headlineMedium),
                      ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    AppSpacing.vGapSm,
                    Text(
                      subtitle!,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(child: child),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  onboardingGutter,
                  AppSpacing.md,
                  onboardingGutter,
                  AppSpacing.lg,
                ),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}

/// Web `StepDots`: the current step is a 24px primary pill, done steps are
/// primary/60 dots, later ones surface-container-highest.
class OnboardingStepDots extends StatelessWidget {
  const OnboardingStepDots({
    super.key,
    required this.total,
    required this.current,
  });

  final int total;

  /// Zero-based index of the current step.
  final int current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.onboardingProgress(current + 1, total),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) AppSpacing.hGapSm,
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: i == current ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == current
                    ? AppColors.primary
                    : i < current
                        ? AppColors.primary.withValues(alpha: 0.6)
                        : AppColors.surfaceContainerHighest,
                borderRadius: AppSpacing.borderRadiusFull,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
