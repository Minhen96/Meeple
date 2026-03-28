import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';

/// A frosted-glass surface used for nav bars, modals, and sticky headers.
///
/// Design spec (docs/DESIGN.md §7):
/// - background: rgba(248, 249, 250, 0.80)
/// - backdrop-filter: blur(24px)
/// - optional white/10 border on glass surfaces only
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = AppSpacing.borderRadiusXl,
    this.padding,
    this.showBorder = true,
    this.blurSigma = 24.0,
    this.opacity = 0.80,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool showBorder;
  final double blurSigma;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: opacity),
            borderRadius: borderRadius,
            border: showBorder
                ? Border.all(color: AppColors.glassBorder, width: 1)
                : null,
          ),
          child: padding != null
              ? Padding(padding: padding!, child: child)
              : child,
        ),
      ),
    );
  }
}
