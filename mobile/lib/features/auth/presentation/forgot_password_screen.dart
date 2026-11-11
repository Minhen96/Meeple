import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/data/auth_repository.dart';
import 'package:meeple_hearth/features/auth/presentation/widgets/auth_page.dart';
import 'package:meeple_hearth/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';

/// Forgot password (SCREENS §2.4) — web `/auth/forgot-password`: "← Back",
/// title, one email field and "Send Reset Link"; afterwards the neutral
/// "if registered…" note and "Back to login".
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _toLogin() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.login);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .forgotPassword(email: _emailController.text.trim());
      if (!mounted) return;
      setState(() => _emailSent = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizedError(context.l10n, e))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AuthCenteredPage(
      children: [
        AuthBackLink(onPressed: _toLogin),
        AppSpacing.vGapXl,
        if (_emailSent) ...[
          Text(
            l10n.authResetSentTo(_emailController.text.trim()),
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          AppSpacing.vGapLg,
          AppButton(
            key: const Key('forgot-back-to-login'),
            label: l10n.authBackToSignIn,
            variant: AppButtonVariant.secondary,
            onPressed: _toLogin,
          ),
        ] else ...[
          AuthPageTitle(l10n.authForgotTitle),
          AppSpacing.vGapXl,
          Form(
            key: _formKey,
            child: SettingsField(
              fieldKey: const Key('forgot-email'),
              hint: l10n.authEmailAddress,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return l10n.authEmailRequired;
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v)) {
                  return l10n.authInvalidEmail;
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
          AppSpacing.vGapLg,
          AppButton(
            label: l10n.authSendResetLink,
            onPressed: _isLoading ? null : _submit,
            isLoading: _isLoading,
          ),
        ],
      ],
    );
  }
}
