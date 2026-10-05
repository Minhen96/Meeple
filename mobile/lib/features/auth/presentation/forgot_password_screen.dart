import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/features/auth/data/auth_repository.dart';
import 'package:meeple_hearth/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';

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
        SnackBar(
            content: Text(
          localizedError(context.l10n, e),
        )),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.l10n.authResetPasswordTitle),
        backgroundColor: AppColors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.pagePadding,
          child: _emailSent
              ? _SuccessView(email: _emailController.text.trim())
              : _FormView(
                  formKey: _formKey,
                  emailController: _emailController,
                  isLoading: _isLoading,
                  onSubmit: _submit,
                ),
        ),
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  const _FormView({
    required this.formKey,
    required this.emailController,
    required this.isLoading,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSpacing.vGapLg,
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: AppSpacing.borderRadiusXl,
          ),
          child: const Icon(
            Icons.lock_reset_rounded,
            color: AppColors.primary,
            size: 36,
          ),
        ),
        AppSpacing.vGapXl,
        Text(context.l10n.authForgotTitle, style: AppTypography.headlineSmall),
        AppSpacing.vGapSm,
        Text(
          context.l10n.authForgotBody,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        AppSpacing.vGapXxl,
        Form(
          key: formKey,
          child: AuthTextField(
            label: context.l10n.authEmail,
            hint: 'you@example.com',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline_rounded,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return context.l10n.authEmailRequired;
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v)) {
                return context.l10n.authInvalidEmail;
              }
              return null;
            },
            onFieldSubmitted: (_) => onSubmit(),
          ),
        ),
        AppSpacing.vGapXl,
        AppButton(
          label: context.l10n.authSendResetLink,
          onPressed: isLoading ? null : onSubmit,
          isLoading: isLoading,
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.email});

  final String email;

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
          context.l10n.authCheckInbox,
          style: AppTypography.headlineSmall,
          textAlign: TextAlign.center,
        ),
        AppSpacing.vGapMd,
        Text(
          context.l10n.authResetSentTo(email),
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        AppButton(
          label: context.l10n.authBackToSignIn,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppSpacing.vGapXl,
      ],
    );
  }
}
