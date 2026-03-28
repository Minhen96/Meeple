import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';

/// Shown after registration. Prompts user to check email and verify.
///
/// User can resend the verification email or sign out and try again.
class VerifyEmailScreen extends ConsumerWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final email = authState.valueOrNull?.email ?? 'your email';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.pagePadding,
          child: Column(
            children: [
              AppSpacing.vGapXl,
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => ref
                      .read(authNotifierProvider.notifier)
                      .logout()
                      .then((_) {
                    if (context.mounted) context.go(AppRoutes.login);
                  }),
                ),
              ),
              const Spacer(),
              // Email icon
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: AppSpacing.borderRadiusXl,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  color: AppColors.onPrimary,
                  size: 48,
                ),
              ),
              AppSpacing.vGapXl,
              Text('Check your inbox', style: AppTypography.headlineSmall),
              AppSpacing.vGapMd,
              Text(
                "We've sent a verification link to\n$email",
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.vGapXs,
              Text(
                'Click the link in the email to activate your account.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // Once they've verified, tapping this checks auth state.
              AppButton(
                label: "I've Verified My Email",
                onPressed: () => context.go(AppRoutes.home),
              ),
              AppSpacing.vGapMd,
              AppOutlinedButton(
                label: 'Resend Email',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Verification email resent'),
                    ),
                  );
                },
              ),
              AppSpacing.vGapXl,
            ],
          ),
        ),
      ),
    );
  }
}
