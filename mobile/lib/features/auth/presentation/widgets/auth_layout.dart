import 'package:flutter/material.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';

/// Background of every auth screen. On phones the web paints the plain page
/// background (its warm `auth-backdrop` only shows from md up).
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key});

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(child: ColoredBox(color: AppColors.background));
}

/// Shared frame of the auth screens (web `/auth` layout on phones): the
/// plain page background, a centred column at most 384px wide (`max-w-sm`)
/// with the web's `px-4 py-12` + `p-6` padding, scrolling when the keyboard
/// is up.
///
/// With [fill] the column is at least the viewport tall so a flexible
/// child (e.g. an [Expanded] hero) can push the form to the bottom, like the
/// web login.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.children,
    this.fill = false,
    this.appBar,
  });

  final List<Widget> children;
  final bool fill;
  final PreferredSizeWidget? appBar;

  static const _padding = EdgeInsets.fromLTRB(40, 48, 40, 24);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar,
      body: Stack(
        children: [
          const AuthBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, viewport) => SingleChildScrollView(
                padding: _padding,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 384,
                      minHeight: fill
                          ? (viewport.maxHeight - _padding.vertical)
                              .clamp(0, double.infinity)
                          : 0,
                    ),
                    child: fill
                        ? IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: children,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: children,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The auth hero (web login): the tilted logo tile and the italic
/// "Meeple" wordmark, then a black headline and a muted body line.
class AuthHero extends StatelessWidget {
  const AuthHero({super.key, this.title, this.body});

  final String? title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl + AppSpacing.sm),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const MeepleLogo(size: 64, angle: -6),
              AppSpacing.hGapLg,
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    context.l10n.appName,
                    style: AppTypography.brandLarge,
                  ),
                ),
              ),
            ],
          ),
          if (title != null) ...[
            const SizedBox(height: AppSpacing.lg + AppSpacing.sm),
            Text(
              title!,
              textAlign: TextAlign.center,
              style: AppTypography.displaySmall.copyWith(
                color: AppColors.onSurface.withValues(alpha: 0.9),
              ),
            ),
          ],
          if (body != null) ...[
            AppSpacing.vGapLg,
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 384),
              child: Text(
                body!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.625,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "— OR —" divider between the form and social sign-in (web
/// `quickConnect`: 8px black uppercase, .3em tracking, faint rules).
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final rule = Expanded(
      child: Container(
        height: 1,
        color: AppColors.outlineVariant.withValues(alpha: 0.2),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg + 4),
      child: Row(
        children: [
          rule,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              context.l10n.authOr.toUpperCase(),
              style: AppTypography.eyebrow.copyWith(
                fontSize: 8,
                letterSpacing: 2.4,
              ),
            ),
          ),
          rule,
        ],
      ),
    );
  }
}
