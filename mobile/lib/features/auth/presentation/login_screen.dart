import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:meeple_hearth/features/auth/data/google_auth_client.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.redirect});

  /// Deep-link URL to push after successful login.
  final String? redirect;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final l10n = context.l10n;
    try {
      await ref.read(authNotifierProvider.notifier).login(
            emailOrUsername: _emailController.text.trim(),
            password: _passwordController.text,
          );
      // The router redirect (incl. `?redirect=`) takes over from here.
    } on EmailNotVerifiedException {
      if (!mounted) return;
      showToast(context, l10n.authVerifyFirst);
      final identifier = _emailController.text.trim();
      await context.push(
        AppRoutes.verifyEmail,
        extra: identifier.contains('@') ? identifier : null,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'ACCOUNT_DELETED') {
        await context.push(
          AppRoutes.reactivate,
          extra: _emailController.text.trim(),
        );
      } else {
        showErrorToast(context, e);
      }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _google() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
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
                  AppSpacing.vGapXxxl,
                  _BrandHeader(subtitle: context.l10n.authSignInSubtitle),
                  const SizedBox(height: 48),
                  _FormCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AuthTextField(
                            label: context.l10n.authEmailOrUsername,
                            hint: context.l10n.authEmailHint,
                            controller: _emailController,
                            focusNode: _emailFocus,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.person_outline_rounded,
                            autofillHints: const [
                              AutofillHints.email,
                              AutofillHints.username,
                            ],
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? context.l10n.authEmailOrUsernameRequired
                                : null,
                            onFieldSubmitted: (_) => FocusScope.of(context)
                                .requestFocus(_passwordFocus),
                          ),
                          AppSpacing.vGapMd,
                          AuthTextField(
                            label: context.l10n.authPassword,
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            isPassword: true,
                            textInputAction: TextInputAction.done,
                            prefixIcon: Icons.lock_outline_rounded,
                            autofillHints: const [AutofillHints.password],
                            validator: (v) => (v == null || v.isEmpty)
                                ? context.l10n.authPasswordRequired
                                : null,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          AppSpacing.vGapSm,
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () =>
                                  context.push(AppRoutes.forgotPassword),
                              child: Text(
                                context.l10n.authForgotPassword,
                                style: AppTypography.labelMedium.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          AppSpacing.vGapLg,
                          AppButton(
                            label: context.l10n.authSignIn,
                            onPressed: _isLoading ? null : _submit,
                            isLoading: _isLoading,
                          ),
                        ],
                      ),
                    ),
                  ),
                  AppSpacing.vGapXl,
                  const _OrDivider(),
                  AppSpacing.vGapXl,
                  _GoogleSignInButton(isLoading: _isLoading, onPressed: _google),
                  AppSpacing.vGapXxxl,
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        context.l10n.authNoAccount,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.register),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          context.l10n.authSignUp,
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

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

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

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: AppSpacing.borderRadiusXl,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.games_rounded,
            color: AppColors.onPrimary,
            size: 36,
          ),
        ),
        AppSpacing.vGapLg,
        Text(context.l10n.appName, style: AppTypography.brandLarge),
        AppSpacing.vGapXs,
        Text(
          subtitle,
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: AppSpacing.borderRadiusXl,
      ),
      child: child,
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            context.l10n.authOr,
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.outlineVariant)),
      ],
    );
  }
}

class _GoogleSignInButton extends ConsumerWidget {
  const _GoogleSignInButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hidden when no Google client id was provided at build time.
    if (!ref.watch(googleAuthClientProvider).isAvailable) {
      return const SizedBox.shrink();
    }
    return OutlinedButton.icon(
      key: const Key('google-sign-in'),
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        shape: const StadiumBorder(),
        foregroundColor: AppColors.onSurface,
      ),
      icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
      label: Text(
        context.l10n.authContinueWithGoogle,
        style: AppTypography.labelLarge,
      ),
    );
  }
}
