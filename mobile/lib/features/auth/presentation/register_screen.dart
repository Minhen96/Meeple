import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).register(
            username: _usernameController.text.trim().toLowerCase(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (!mounted) return;
      // No session yet: the user verifies their email, then signs in.
      context.go(AppRoutes.verifyEmail, extra: _emailController.text.trim());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizedError(context.l10n, e),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _AuthBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: AppSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSpacing.vGapXl,
                  // Back button row
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  AppSpacing.vGapMd,
                  Text(context.l10n.authCreateAccountTitle, style: AppTypography.headlineMedium),
                  AppSpacing.vGapXs,
                  Text(
                    context.l10n.authJoin,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: AppSpacing.borderRadiusXl,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AuthTextField(
                            label: context.l10n.profileUsername,
                            hint: 'board_game_pro',
                            controller: _usernameController,
                            focusNode: _usernameFocus,
                            prefixIcon: Icons.alternate_email_rounded,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newUsername],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return context.l10n.authUsernameRequired;
                              }
                              final name = v.trim().toLowerCase();
                              if (name.length < 3 || name.length > 20) {
                                return context.l10n.authUsernameLength;
                              }
                              if (!RegExp(r'^[a-z0-9][a-z0-9_]*$')
                                  .hasMatch(name)) {
                                return 'Letters, numbers and underscores; '
                                    'cannot start with an underscore';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => FocusScope.of(context)
                                .requestFocus(_emailFocus),
                          ),
                          AppSpacing.vGapMd,
                          AuthTextField(
                            label: context.l10n.authEmail,
                            hint: 'you@example.com',
                            controller: _emailController,
                            focusNode: _emailFocus,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.mail_outline_rounded,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return context.l10n.authEmailRequired;
                              }
                              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                                  .hasMatch(v)) {
                                return context.l10n.authInvalidEmail;
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => FocusScope.of(context)
                                .requestFocus(_passwordFocus),
                          ),
                          AppSpacing.vGapMd,
                          AuthTextField(
                            label: context.l10n.authPassword,
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            isPassword: true,
                            prefixIcon: Icons.lock_outline_rounded,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return context.l10n.authPasswordRequired;
                              }
                              if (v.length < 8 || v.length > 128) {
                                return context.l10n.authPasswordLength;
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => FocusScope.of(context)
                                .requestFocus(_confirmPasswordFocus),
                          ),
                          AppSpacing.vGapMd,
                          AuthTextField(
                            label: context.l10n.authConfirmPassword,
                            controller: _confirmPasswordController,
                            focusNode: _confirmPasswordFocus,
                            isPassword: true,
                            prefixIcon: Icons.lock_outline_rounded,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (v) {
                              if (v != _passwordController.text) {
                                return context.l10n.authPasswordsMismatch;
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          AppSpacing.vGapLg,
                          AppButton(
                            label: context.l10n.authCreateAccount,
                            onPressed: _isLoading ? null : _submit,
                            isLoading: _isLoading,
                          ),
                          AppSpacing.vGapMd,
                          Text(
                            context.l10n.authTermsNote,
                            style: AppTypography.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  AppSpacing.vGapXl,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        context.l10n.authHaveAccount,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.pop(),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          context.l10n.authSignInLink,
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.vGapXl,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background,
              AppColors.primaryContainer.withValues(alpha: 0.3),
              AppColors.background,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}
