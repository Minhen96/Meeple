import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/constants/text_style_weight.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/presentation/widgets/auth_page.dart';
import 'package:meeple_hearth/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';

/// Password strength of the web register form.
enum PasswordStrength {
  weak,
  good,
  strong;

  static PasswordStrength of(String password) {
    if (password.length < 8) return weak;
    if (password.length >= 12 && RegExp('[^a-zA-Z0-9]').hasMatch(password)) {
      return strong;
    }
    if (RegExp('[a-zA-Z]').hasMatch(password) &&
        RegExp('[0-9]').hasMatch(password)) {
      return good;
    }
    return weak;
  }
}

/// Create account (SCREENS §2.2) — the web `/auth/register` phone layout:
/// warm game-board backdrop, "Join the *table.*" hero with two perks, the
/// email / username / password / confirm form, "Already have an account?
/// Log in" and Google sign-in.
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
        SnackBar(content: Text(localizedError(context.l10n, e))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _google() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedError(context.l10n, e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toLogin() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.login);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.authBackdrop,
      body: Stack(
        children: [
          const Positioned.fill(child: RegisterBackdrop()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xxxl,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 512),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Hero(),
                      AppSpacing.vGapXxl,
                      _form(l10n),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _form(AppLocalizations l10n) {
    const gap = SizedBox(height: 14);
    final strength = PasswordStrength.of(_passwordController.text);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            label: l10n.authEmailAddress,
            hint: l10n.registerEmailHint,
            controller: _emailController,
            focusNode: _emailFocus,
            keyboardType: TextInputType.emailAddress,
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
            onFieldSubmitted: (_) =>
                FocusScope.of(context).requestFocus(_usernameFocus),
          ),
          gap,
          AuthTextField(
            label: l10n.profileUsername,
            hint: l10n.registerUsernameHint,
            controller: _usernameController,
            focusNode: _usernameFocus,
            autofillHints: const [AutofillHints.newUsername],
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return l10n.authUsernameRequired;
              }
              final name = v.trim().toLowerCase();
              if (name.length < 3 || name.length > 20) {
                return l10n.authUsernameLength;
              }
              if (!RegExp(r'^[a-z0-9][a-z0-9_]*$').hasMatch(name)) {
                return l10n.profileUsernameInvalid;
              }
              return null;
            },
            onFieldSubmitted: (_) =>
                FocusScope.of(context).requestFocus(_passwordFocus),
          ),
          gap,
          AuthTextField(
            label: l10n.authPassword,
            hint: l10n.registerPasswordHint,
            controller: _passwordController,
            focusNode: _passwordFocus,
            isPassword: true,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.authPasswordRequired;
              if (v.length < 8 || v.length > 128) {
                return l10n.authPasswordLength;
              }
              return null;
            },
            onFieldSubmitted: (_) =>
                FocusScope.of(context).requestFocus(_confirmPasswordFocus),
          ),
          if (_passwordController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, AppSpacing.sm, 2, 0),
              child: _StrengthBar(strength: strength),
            ),
          gap,
          AuthTextField(
            label: l10n.authConfirmPassword,
            hint: l10n.registerConfirmHint,
            controller: _confirmPasswordController,
            focusNode: _confirmPasswordFocus,
            isPassword: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            validator: (v) => v != _passwordController.text
                ? l10n.authPasswordsMismatch
                : null,
            onFieldSubmitted: (_) => _submit(),
          ),
          AppSpacing.vGapXxl,
          AppButton(
            key: const Key('register-submit'),
            label: l10n.authCreateAccount,
            size: AppButtonSize.lg,
            onPressed: _isLoading ? null : _submit,
            isLoading: _isLoading,
          ),
          AppSpacing.vGapLg,
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.authHaveAccount,
                style: AppTypography.bodyMedium
                    .weight(FontWeight.w500)
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              InkWell(
                key: const Key('register-login'),
                onTap: _toLogin,
                borderRadius: AppSpacing.borderRadiusSm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  child: Text(
                    l10n.authSignInLink,
                    style: AppTypography.bodyMedium
                        .weight(FontWeight.w900)
                        .copyWith(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
          AuthGoogleButton(onPressed: _google, isLoading: _isLoading),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final headline =
        AppTypography.displayLarge.weight(FontWeight.w900).copyWith(
              color: AppColors.onSurface,
              letterSpacing: -3,
              height: 1.1,
            );
    return Column(
      children: [
        Transform.rotate(
          angle: 12 * math.pi / 180,
          child: const MeepleLogo(size: 56, angle: 0),
        ),
        AppSpacing.vGapSm,
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            l10n.registerHeroLead,
            textAlign: TextAlign.center,
            style: headline,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            l10n.registerHeroAccent,
            textAlign: TextAlign.center,
            style: headline.copyWith(
              color: AppColors.primary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        AppSpacing.vGapXl,
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            children: [
              _Perk(
                icon: Icons.group_outlined,
                color: AppColors.primary,
                text: l10n.registerPerkCommunity,
              ),
              AppSpacing.vGapMd,
              _Perk(
                icon: Icons.inventory_2_outlined,
                color: AppColors.secondary,
                text: l10n.registerPerkCollection,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        AppSpacing.hGapMd,
        Flexible(
          child: Text(
            text,
            style: AppTypography.bodySmall
                .weight(FontWeight.w700)
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.strength});

  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final (color, fraction) = switch (strength) {
      PasswordStrength.weak => (AppColors.error, 1 / 3),
      PasswordStrength.good => (AppColors.secondaryContainer, 2 / 3),
      PasswordStrength.strong => (AppColors.tertiary, 1.0),
    };
    return ClipRRect(
      key: ValueKey('strength-${strength.name}'),
      borderRadius: AppSpacing.borderRadiusFull,
      child: Container(
        height: 4,
        color: AppColors.surfaceContainerHighest.withValues(alpha: 0.4),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: AppSpacing.borderRadiusFull,
            ),
          ),
        ),
      ),
    );
  }
}

/// The web register "game board" backdrop: the warm auth backdrop with a
/// secondary glow top-right, a tertiary glow bottom-left, a faint dot grid
/// and a wider line grid.
class RegisterBackdrop extends StatelessWidget {
  const RegisterBackdrop({super.key});

  @override
  Widget build(BuildContext context) => const CustomPaint(
        painter: _BoardPainter(),
        child: SizedBox.expand(),
      );
}

class _BoardPainter extends CustomPainter {
  const _BoardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = AppColors.authBackdrop);
    final radius = size.longestSide * 0.7;
    canvas
      ..drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.secondary.withValues(alpha: 0.14),
              AppColors.secondary.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(center: Offset(size.width, 0), radius: radius),
          ),
      )
      ..drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.tertiary.withValues(alpha: 0.14),
              AppColors.tertiary.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(center: Offset(0, size.height), radius: radius),
          ),
      );
    final dot = Paint()..color = AppColors.onSurface.withValues(alpha: 0.06);
    for (var x = 16.0; x < size.width; x += 32) {
      for (var y = 16.0; y < size.height; y += 32) {
        canvas.drawCircle(Offset(x, y), 1, dot);
      }
    }
    final line = Paint()
      ..color = AppColors.onSurface.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 128) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = 0.0; y < size.height; y += 128) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(_BoardPainter oldDelegate) => false;
}
