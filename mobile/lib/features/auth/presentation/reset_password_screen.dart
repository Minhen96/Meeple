import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/data/auth_repository.dart';
import 'package:meeple_hearth/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';

/// Handles the deep-link from password-reset email.
///
/// Receives [token] from query parameters: `/auth/reset-password?token=xxx`
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
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _isLoading = false;
  bool _success = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _passwordFocus.dispose();
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
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Password'),
        backgroundColor: AppColors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.pagePadding,
          child: _success ? _SuccessView() : _FormView(
            formKey: _formKey,
            passwordController: _passwordController,
            confirmController: _confirmController,
            passwordFocus: _passwordFocus,
            confirmFocus: _confirmFocus,
            isLoading: _isLoading,
            onSubmit: _submit,
            hasToken: widget.token.isNotEmpty,
          ),
        ),
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  const _FormView({
    required this.formKey,
    required this.passwordController,
    required this.confirmController,
    required this.passwordFocus,
    required this.confirmFocus,
    required this.isLoading,
    required this.onSubmit,
    required this.hasToken,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final FocusNode passwordFocus;
  final FocusNode confirmFocus;
  final bool isLoading;
  final VoidCallback onSubmit;
  final bool hasToken;

  @override
  Widget build(BuildContext context) {
    if (!hasToken) {
      return Center(
        child: Text(
          'Invalid or expired reset link.',
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSpacing.vGapLg,
        Text('Set a new password', style: AppTypography.headlineSmall),
        AppSpacing.vGapSm,
        Text(
          'Your new password must be at least 8 characters.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        AppSpacing.vGapXxl,
        Form(
          key: formKey,
          child: Column(
            children: [
              AuthTextField(
                label: 'New password',
                controller: passwordController,
                focusNode: passwordFocus,
                isPassword: true,
                prefixIcon: Icons.lock_outline_rounded,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 8) return 'Must be at least 8 characters';
                  return null;
                },
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(confirmFocus),
              ),
              AppSpacing.vGapMd,
              AuthTextField(
                label: 'Confirm new password',
                controller: confirmController,
                focusNode: confirmFocus,
                isPassword: true,
                prefixIcon: Icons.lock_outline_rounded,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) {
                  if (v != passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => onSubmit(),
              ),
            ],
          ),
        ),
        AppSpacing.vGapXl,
        AppButton(
          label: 'Reset Password',
          onPressed: isLoading ? null : onSubmit,
          isLoading: isLoading,
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
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
            Icons.check_circle_outline_rounded,
            color: AppColors.onPrimary,
            size: 48,
          ),
        ),
        AppSpacing.vGapXl,
        Text(
          'Password updated!',
          style: AppTypography.headlineSmall,
          textAlign: TextAlign.center,
        ),
        AppSpacing.vGapMd,
        Text(
          'Your password has been reset. Sign in with your new password.',
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        AppButton(
          label: 'Sign In',
          onPressed: () => context.go(AppRoutes.login),
        ),
        AppSpacing.vGapXl,
      ],
    );
  }
}
