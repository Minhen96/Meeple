import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/constants/text_style_weight.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/onboarding/presentation/onboarding_scaffold.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';

/// Onboarding step 1 (SCREENS §3.2) — web `/onboarding/welcome`: tilted
/// logo tile, primary "Meeple" wordmark, tagline, three feature cards and
/// "Get Started".
class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final features = [
      (
        Icons.inventory_2_outlined,
        l10n.welcomeLibraryTitle,
        l10n.welcomeLibrary
      ),
      (Icons.event_outlined, l10n.welcomeEventsTitle, l10n.welcomeEvents),
      (
        Icons.group_add_outlined,
        l10n.welcomeMatchingTitle,
        l10n.welcomeMatching
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: onboardingGutter,
            vertical: AppSpacing.xxxl,
          ),
          children: [
            const Center(child: MeepleLogo(size: 80, angle: -6)),
            AppSpacing.vGapLg,
            Text(
              l10n.appName,
              textAlign: TextAlign.center,
              style: AppTypography.displaySmall
                  .weight(FontWeight.w800)
                  .copyWith(color: AppColors.primary, fontSize: 36),
            ),
            AppSpacing.vGapMd,
            Text(
              l10n.welcomeTagline,
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            AppSpacing.vGapXxl,
            for (final (icon, title, body) in features) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(icon, size: 24, color: AppColors.primary),
                    ),
                    AppSpacing.hGapLg,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTypography.bodyLarge
                                .weight(FontWeight.w600)
                                .copyWith(color: AppColors.onSurface),
                          ),
                          Text(
                            body,
                            style: AppTypography.bodyMedium
                                .copyWith(color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.vGapLg,
            ],
            AppSpacing.vGapLg,
            AppButton(
              key: const Key('welcome-start'),
              label: l10n.welcomeStart,
              onPressed: () => context.go(AppRoutes.onboardingProfile),
            ),
          ],
        ),
      ),
    );
  }
}
