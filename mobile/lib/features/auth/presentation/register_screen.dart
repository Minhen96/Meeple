import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
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
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _displayNameFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _isLoading = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameFocus.dispose();
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
            username: _usernameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            displayName: _displayNameController.text.trim(),
          );
      if (!mounted) return;
      context.go(AppRoutes.verifyEmail);
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
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  AppSpacing.vGapMd,
                  Text('Create account', style: AppTypography.headlineMedium),
                  AppSpacing.vGapXs,
                  Text(
                    'Join the Meeple community',
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
                            label: 'Display name',
                            hint: 'How others see you',
                            controller: _displayNameController,
                            focusNode: _displayNameFocus,
                            prefixIcon: Icons.badge_outlined,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Display name is required';
                              }
                              if (v.trim().length < 2) {
                                return 'Must be at least 2 characters';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) =>
                                FocusScope.of(context).requestFocus(_usernameFocus),
                          ),
                          AppSpacing.vGapMd,
                          AuthTextField(
                            label: 'Username',
                            hint: 'board_game_pro',
                            controller: _usernameController,
                            focusNode: _usernameFocus,
                            prefixIcon: Icons.alternate_email_rounded,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newUsername],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Username is required';
                              }
                              if (v.trim().length < 3) {
                                return 'Must be at least 3 characters';
                              }
                              if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
                                return 'Only letters, numbers, and underscores';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) =>
                                FocusScope.of(context).requestFocus(_emailFocus),
                          ),
                          AppSpacing.vGapMd,
                          AuthTextField(
                            label: 'Email',
                            hint: 'you@example.com',
                            controller: _emailController,
                            focusNode: _emailFocus,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.mail_outline_rounded,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Email is required';
                              }
                              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                                  .hasMatch(v)) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) =>
                                FocusScope.of(context).requestFocus(_passwordFocus),
                          ),
                          AppSpacing.vGapMd,
                          AuthTextField(
                            label: 'Password',
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            isPassword: true,
                            prefixIcon: Icons.lock_outline_rounded,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Password is required';
                              }
                              if (v.length < 8) {
                                return 'Must be at least 8 characters';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => FocusScope.of(context)
                                .requestFocus(_confirmPasswordFocus),
                          ),
                          AppSpacing.vGapMd,
                          AuthTextField(
                            label: 'Confirm password',
                            controller: _confirmPasswordController,
                            focusNode: _confirmPasswordFocus,
                            isPassword: true,
                            prefixIcon: Icons.lock_outline_rounded,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (v) {
                              if (v != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          AppSpacing.vGapLg,
                          AppButton(
                            label: 'Create Account',
                            onPressed: _isLoading ? null : _submit,
                            isLoading: _isLoading,
                          ),
                          AppSpacing.vGapMd,
                          Text(
                            'By creating an account you agree to our Terms of Service and Privacy Policy.',
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
                        'Already have an account? ',
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
                          'Sign in',
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
