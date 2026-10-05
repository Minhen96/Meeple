import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/onboarding/presentation/onboarding_scaffold.dart';
import 'package:meeple_hearth/features/settings/presentation/bgg_import_screen.dart';
import 'package:meeple_hearth/l10n/l10n.dart';

/// Onboarding step 3 (SCREENS §3.4): live BGG collection import.
class OnboardingBggScreen extends ConsumerWidget {
  const OnboardingBggScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return OnboardingScaffold(
      route: AppRoutes.onboardingBgg,
      title: l10n.onboardingBggTitle,
      subtitle: l10n.onboardingBggBody,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          BggImportPanel(
            onDone: () =>
                goToNextOnboardingStep(context, ref, AppRoutes.onboardingBgg),
          ),
        ],
      ),
    );
  }
}
