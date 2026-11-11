import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/constants/text_style_weight.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/presentation/widgets/auth_page.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';

/// Verify email (SCREENS §2.3) — web `/auth/verify-email`: "Check your
/// inbox" (or verifying / link expired), resend with an email field and
/// "Back to login".
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
  late final _email = TextEditingController(text: widget.email ?? '');
  bool _busy = false;
  bool _verifying = false;
  bool _failed = false;
  bool _resent = false;

  @override
  void initState() {
    super.initState();
    final token = widget.token;
    if (token != null && token.isNotEmpty) {
      _verifying = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _verify(token));
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _verify(String token) async {
    final ok = await _run(
      () => ref.read(authNotifierProvider.notifier).verifyEmail(token),
      // On success the router redirects away from the auth pages.
    );
    if (mounted) {
      setState(() {
        _verifying = false;
        _failed = !ok;
      });
    }
  }

  Future<void> _resend() async {
    final email = _email.text.trim();
    if (email.isEmpty) return;
    final ok = await _run(
      () => ref.read(authNotifierProvider.notifier).resendVerification(email),
    );
    if (ok && mounted) setState(() => _resent = true);
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (_busy) return false;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(localizedError(l10n, e))),
      );
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final backToLogin = AuthTextLink(
      label: l10n.authBackToSignIn,
      onPressed: () => context.go(AppRoutes.login),
    );
    if (_verifying) {
      return AuthCenteredPage(
        children: [
          const Center(
            child: SizedBox(
              width: 52,
              height: 52,
              child: CircularProgressIndicator(
                strokeWidth: 5,
                color: AppColors.tertiary,
              ),
            ),
          ),
          AppSpacing.vGapLg,
          AuthPageTitle(l10n.authVerifying, center: true),
        ],
      );
    }
    return AuthCenteredPage(
      children: [
        if (_failed)
          AuthStatusBlock(
            icon: Icons.error_outline_rounded,
            color: AppColors.error,
            title: l10n.authVerifyExpiredTitle,
            body: l10n.authVerifyExpiredBody,
          )
        else
          AuthStatusBlock(
            icon: Icons.mark_email_unread_outlined,
            title: l10n.authCheckInbox,
            body: widget.email == null
                ? l10n.authVerifySentBody
                : l10n.authVerifySentTo(widget.email!),
          ),
        AppSpacing.vGapLg,
        if (_resent)
          Text(
            l10n.authVerificationResent,
            key: const Key('verify-resent'),
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium
                .weight(FontWeight.w600)
                .copyWith(color: AppColors.tertiary),
          )
        else ...[
          SettingsField(
            fieldKey: const Key('verify-email'),
            hint: l10n.authVerifyResendHint,
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _resend(),
          ),
          AppSpacing.vGapSm,
          AppButton(
            key: const Key('verify-resend'),
            label: l10n.authResendEmail,
            variant:
                _failed ? AppButtonVariant.primary : AppButtonVariant.secondary,
            isLoading: _busy,
            onPressed: _busy ? null : _resend,
          ),
        ],
        AppSpacing.vGapSm,
        backToLogin,
      ],
    );
  }
}
