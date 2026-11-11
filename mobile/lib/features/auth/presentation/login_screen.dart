import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/presentation/widgets/auth_layout.dart';
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
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'ACCOUNT_DELETED') {
        await context.push(AppRoutes.reactivate);
      } else {
        showErrorToast(context, e);
      }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Web login on phones: hero on top (flex-1), the form at the bottom.
    return AuthScaffold(
      fill: true,
      children: [
        Expanded(
          child: AuthHero(title: l10n.authHeroTitle, body: l10n.authHeroBody),
        ),
        AppSpacing.vGapXxl,
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  label: l10n.authEmailOrUsername,
                  controller: _emailController,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.email,
                    AutofillHints.username,
                  ],
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.authEmailOrUsernameRequired
                      : null,
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_passwordFocus),
                ),
                const SizedBox(height: 20),
                AuthTextField(
                  label: l10n.authPassword,
                  hint: l10n.authPasswordHint,
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: (v) => (v == null || v.isEmpty)
                      ? l10n.authPasswordRequired
                      : null,
                  onFieldSubmitted: (_) => _submit(),
                  labelAction: AppLinkButton(
                    key: const Key('forgot-password'),
                    label: l10n.authForgotPassword,
                    small: true,
                    onPressed: () => context.push(AppRoutes.forgotPassword),
                  ),
                ),
                const SizedBox(height: 44),
                AppButton(
                  label: l10n.authSignIn,
                  onPressed: _isLoading ? null : _submit,
                  isLoading: _isLoading,
                  size: AppButtonSize.lg,
                ),
                const SizedBox(height: 44),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l10n.authNewPlayer,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    InkWell(
                      key: const Key('login-register'),
                      onTap: () => context.push(AppRoutes.register),
                      borderRadius: AppSpacing.borderRadiusSm,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        child: Text(
                          l10n.authSignUp,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                _GoogleSignIn(isLoading: _isLoading, onPressed: _google),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "OR" divider + Google button; hidden when no Google client id was
/// provided at build time.
class _GoogleSignIn extends ConsumerWidget {
  const _GoogleSignIn({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(googleAuthClientProvider).isAvailable) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthOrDivider(),
        Material(
          color: AppColors.surfaceContainerLowest,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('google-sign-in'),
            onTap: isLoading ? null : onPressed,
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.g_mobiledata_rounded,
                    size: 28,
                    color: AppColors.onSurface,
                  ),
                  AppSpacing.hGapXs,
                  Text(
                    context.l10n.authContinueWithGoogle,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
