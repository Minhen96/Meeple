import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';

/// Shown after registration (and when sign-in reports `EMAIL_NOT_VERIFIED`).
///
/// Registration starts no session: the user opens the emailed link, which
/// lands here with `?token=` and signs them in, or verifies elsewhere and
/// then signs in with their password.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.email, this.token});

  /// Address the link was sent to, when known (needed to resend).
  final String? email;

  /// Verification token from the email link.
  final String? token;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final token = widget.token;
    if (token != null && token.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verify(token));
    }
  }

  Future<void> _verify(String token) => _run(
        () => ref.read(authNotifierProvider.notifier).verifyEmail(token),
        // On success the router redirects away from the auth pages.
      );

  Future<void> _resend(String email) => _run(
        () => ref.read(authNotifierProvider.notifier).resendVerification(email),
        successMessage: context.l10n.authVerificationResent,
      );

  Future<void> _run(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await action();
      if (successMessage != null) {
        messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            localizedError(l10n, e),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final knownEmail = widget.email;
    final email = knownEmail ?? context.l10n.authYourEmail;

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
                  onPressed: () => context.go(AppRoutes.login),
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
              Text(context.l10n.authCheckInbox, style: AppTypography.headlineSmall),
              AppSpacing.vGapMd,
              Text(
                context.l10n.authVerifySentTo(email),
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.vGapXs,
              Text(
                context.l10n.authVerifyBody,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // Verified via the link in another app/browser — sign in now.
              AppButton(
                label: context.l10n.authIveVerified,
                onPressed: _busy ? null : () => context.go(AppRoutes.login),
              ),
              if (knownEmail != null) ...[
                AppSpacing.vGapMd,
                AppOutlinedButton(
                  label: context.l10n.authResendEmail,
                  onPressed: _busy ? null : () => _resend(knownEmail),
                ),
              ],
              AppSpacing.vGapXl,
            ],
          ),
        ),
      ),
    );
  }
}
