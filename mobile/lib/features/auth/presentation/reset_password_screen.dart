import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/data/auth_repository.dart';
import 'package:meeple_hearth/features/auth/presentation/widgets/auth_page.dart';
import 'package:meeple_hearth/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';

/// Reset password from the email link (SCREENS §2.5) — web
/// `/auth/reset-password`: "Set new password", two fields, "Update
/// Password" and "Back to login"; invalid-link and done states.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _confirmFocus = FocusNode();
  bool _isLoading = false;
  bool _success = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            token: widget.token,
            newPassword: _passwordController.text,
          );
      if (!mounted) return;
      setState(() => _success = true);
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
    if (widget.token.isEmpty) {
      return AuthCenteredPage(
        children: [
          AuthStatusBlock(
            icon: Icons.error_outline_rounded,
            color: AppColors.error,
            title: l10n.authResetInvalidTitle,
            body: l10n.authResetLinkExpired,
          ),
          AppSpacing.vGapMd,
          AuthTextLink(
            label: l10n.authRequestNewLink,
            onPressed: () => context.go(AppRoutes.forgotPassword),
          ),
        ],
      );
    }
    if (_success) {
      return AuthCenteredPage(
        children: [
          AuthStatusBlock(
            icon: Icons.check_circle_outline_rounded,
            title: l10n.authPasswordUpdated,
            body: l10n.authPasswordUpdatedBody,
          ),
          AppSpacing.vGapXl,
          AppButton(
            label: l10n.authSignIn,
            onPressed: () => context.go(AppRoutes.login),
          ),
        ],
      );
    }
    return AuthCenteredPage(
      children: [
        AuthPageTitle(l10n.authSetNewPassword),
        AppSpacing.vGapXl,
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsField(
                fieldKey: const Key('reset-password'),
                hint: l10n.authNewPassword,
                controller: _passwordController,
                isPassword: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) {
                  if (v == null || v.isEmpty) return l10n.authPasswordRequired;
                  if (v.length < 8) return l10n.authPasswordMin;
                  return null;
                },
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_confirmFocus),
              ),
              AppSpacing.vGapLg,
              SettingsField(
                fieldKey: const Key('reset-confirm'),
                hint: l10n.authConfirmPassword,
                controller: _confirmController,
                focusNode: _confirmFocus,
                isPassword: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) => v != _passwordController.text
                    ? l10n.authPasswordsMismatch
                    : null,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        AppSpacing.vGapLg,
        AppButton(
          key: const Key('reset-submit'),
          label: l10n.authUpdatePassword,
          onPressed: _isLoading ? null : _submit,
          isLoading: _isLoading,
        ),
        AppSpacing.vGapSm,
        AuthTextLink(
          label: l10n.authBackToSignIn,
          primary: false,
          onPressed: () => context.go(AppRoutes.login),
        ),
      ],
    );
  }
}
