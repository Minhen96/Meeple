import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/constants/text_style_weight.dart';
import 'package:meeple_hearth/features/auth/data/google_auth_client.dart';
import 'package:meeple_hearth/features/auth/presentation/widgets/auth_layout.dart';
import 'package:meeple_hearth/l10n/l10n.dart';

/// The simple auth pages of the web (`/auth` layout on phones: forgot /
/// reset password, verify email, reactivate): plain page background, a
/// column at most 384px wide, vertically centred (`min-h-screen flex
/// items-center px-4 py-12`), scrolling when the keyboard is up.
class AuthCenteredPage extends StatelessWidget {
  const AuthCenteredPage({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  static const _padding = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.xxxl,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            padding: _padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (viewport.maxHeight - _padding.vertical)
                    .clamp(0, double.infinity),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 384),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: crossAxisAlignment,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Web `text-2xl font-extrabold font-headline` auth page title.
class AuthPageTitle extends StatelessWidget {
  const AuthPageTitle(this.text, {super.key, this.center = false});

  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: AppTypography.headlineMedium,
      );
}

/// Centred status block (web): a 60px Material icon, title and a small
/// muted line — "Check your inbox", "Password updated!", "Invalid link".
class AuthStatusBlock extends StatelessWidget {
  const AuthStatusBlock({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.color = AppColors.tertiary,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 60, color: color),
        AppSpacing.vGapLg,
        AuthPageTitle(title, center: true),
        if (body != null) ...[
          AppSpacing.vGapLg,
          Text(
            body!,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// Web "← Back" text link at the top of the forgot-password page.
class AuthBackLink extends StatelessWidget {
  const AuthBackLink({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: InkWell(
        key: const Key('auth-back'),
        borderRadius: AppSpacing.borderRadiusFull,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: AppColors.onSurfaceVariant,
              ),
              AppSpacing.hGapXs,
              Text(
                context.l10n.commonBack,
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centred small text link ("Back to login", "Request a new link").
class AuthTextLink extends StatelessWidget {
  const AuthTextLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
  });

  final String label;
  final VoidCallback onPressed;

  /// Primary semibold (default) or muted on-surface-variant.
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor:
              primary ? AppColors.primary : AppColors.onSurfaceVariant,
          textStyle: primary
              ? AppTypography.bodyMedium.weight(FontWeight.w600)
              : AppTypography.bodyMedium,
          shape: const StadiumBorder(),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Inline error banner of the auth forms (web `text-sm text-error
/// bg-error-container rounded-xl px-4 py-3`).
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        child: Text(
          message,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
        ),
      );
}

/// "OR" divider + white "Continue with Google" pill; hidden when no Google
/// client id was provided at build time.
class AuthGoogleButton extends ConsumerWidget {
  const AuthGoogleButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  final VoidCallback onPressed;
  final bool isLoading;

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
            key: const Key('register-google'),
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
                    style: AppTypography.titleSmall.weight(FontWeight.w600),
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
