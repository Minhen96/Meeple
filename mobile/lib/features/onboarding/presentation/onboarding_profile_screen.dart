import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';

/// Onboarding step 2 — set bio, location, avatar.
class OnboardingProfileScreen extends StatefulWidget {
  const OnboardingProfileScreen({super.key});

  @override
  State<OnboardingProfileScreen> createState() =>
      _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends State<OnboardingProfileScreen> {
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();

  @override
  void dispose() {
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OnboardingProgress(step: 1, total: 4),
              AppSpacing.vGapXl,
              Text('Your profile', style: AppTypography.headlineMedium),
              AppSpacing.vGapSm,
              Text(
                'Add a few details so others can get to know you.',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              AppSpacing.vGapXxl,
              // Avatar picker placeholder
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      child: const Icon(
                        Icons.person_rounded,
                        size: 48,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 16,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.vGapXxl,
              AuthTextField(
                label: 'Bio',
                hint: 'Tell us about your gaming style…',
                controller: _bioController,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                prefixIcon: Icons.edit_note_rounded,
              ),
              AppSpacing.vGapMd,
              AuthTextField(
                label: 'Location',
                hint: 'City, Country',
                controller: _locationController,
                prefixIcon: Icons.location_on_outlined,
                textInputAction: TextInputAction.done,
              ),
              const Spacer(),
              AppButton(
                label: 'Continue',
                onPressed: () => context.go(AppRoutes.onboardingBgg),
              ),
              AppSpacing.vGapMd,
              AppTextButton(
                label: 'Skip for now',
                onPressed: () => context.go(AppRoutes.onboardingBgg),
              ),
              AppSpacing.vGapXl,
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingProgress extends StatelessWidget {
  const _OnboardingProgress({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final isActive = i < step;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: AppSpacing.xs),
            height: 4,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary
                  : AppColors.surfaceContainerHigh,
              borderRadius: AppSpacing.borderRadiusSm,
            ),
          ),
        );
      }),
    );
  }
}
