import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';

/// Onboarding step 3 — optional BoardGameGeek collection import.
class OnboardingBggScreen extends StatefulWidget {
  const OnboardingBggScreen({super.key});

  @override
  State<OnboardingBggScreen> createState() => _OnboardingBggScreenState();
}

class _OnboardingBggScreenState extends State<OnboardingBggScreen> {
  final _usernameController = TextEditingController();
  bool _isImporting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    if (_usernameController.text.trim().isEmpty) return;
    setState(() => _isImporting = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isImporting = false);
    context.go(AppRoutes.onboardingFriends);
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
              _OnboardingProgress(step: 2, total: 4),
              AppSpacing.vGapXl,
              Text(
                'Import from BoardGameGeek',
                style: AppTypography.headlineMedium,
              ),
              AppSpacing.vGapSm,
              Text(
                'Already have a BGG account? Import your collection in one tap.',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              AppSpacing.vGapXxl,
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: AppSpacing.borderRadiusXl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthTextField(
                      label: 'BGG username',
                      hint: 'your_bgg_username',
                      controller: _usernameController,
                      prefixIcon: Icons.person_search_rounded,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _import(),
                    ),
                    AppSpacing.vGapLg,
                    AppButton(
                      label: 'Import Collection',
                      onPressed: _isImporting ? null : _import,
                      isLoading: _isImporting,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              AppTextButton(
                label: 'Skip — I\'ll add games manually',
                onPressed: () => context.go(AppRoutes.onboardingFriends),
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
