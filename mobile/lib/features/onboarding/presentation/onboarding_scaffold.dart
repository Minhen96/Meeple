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

/// Layout of steps 2–5: step dots and Skip in the top bar.
class OnboardingScaffold extends ConsumerWidget {
  const OnboardingScaffold({
    super.key,
    required this.route,
    required this.title,
    required this.subtitle,
    required this.child,
    this.bottom,
  });

  final String route;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? bottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final step = onboardingSteps.indexOf(route);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < onboardingSteps.length; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == step ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i <= step
                      ? AppColors.primary
                      : AppColors.surfaceContainerHigh,
                  borderRadius: AppSpacing.borderRadiusFull,
                ),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          TextButton(
            key: const Key('onboarding-skip'),
            onPressed: () => goToNextOnboardingStep(context, ref, route),
            child: Text(l10n.commonSkip),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.headlineMedium),
                  AppSpacing.vGapSm,
                  Text(
                    subtitle,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: child),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}
