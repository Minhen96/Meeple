import 'package:flutter/material.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';

/// Visual variants of [AppButton] — same names as the web `Button.svelte`.
enum AppButtonVariant {
  /// Gradient primary → primary-container with an amber glow (default CTA).
  primary,

  /// Filled surface-container-high, on-surface-variant text.
  secondary,

  /// Filled tertiary-container (teal).
  tertiary,

  /// Solid primary fill (web `bg-primary text-on-primary` pills).
  solid,

  /// Translucent white on images / glass.
  ghost,

  /// Error fill with a red glow (destructive confirm).
  danger,
}

/// Button sizes (web `sm` / `md` / `lg`): padding, text size and height.
enum AppButtonSize {
  /// `py-2 px-5 text-sm` — 36px tall.
  sm(36, 20, 14),

  /// `py-3 px-7 text-base` — 48px tall.
  md(48, 28, 16),

  /// `py-4 px-8 text-lg` — 60px tall.
  lg(60, 32, 18);

  const AppButtonSize(this.height, this.hPadding, this.fontSize);

  final double height;
  final double hPadding;
  final double fontSize;
}

/// Pill button with press-scale animation — the web `Button` component.
///
/// No outlines anywhere (No-Line Rule): secondary actions use the filled
/// [AppButtonVariant.secondary] instead of an outlined button.
///
/// ```dart
/// AppButton(label: l10n.authSignIn, onPressed: _submit, size: AppButtonSize.lg)
/// AppButton(label: l10n.commonCancel, onPressed: ..., variant: AppButtonVariant.secondary)
/// AppButton(label: 'Join', onPressed: ..., minWidth: 0) // hug content
/// ```
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.minWidth = double.infinity,
    this.height,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  /// `double.infinity` (default) stretches like `fullWidth`; 0 hugs content.
  final double minWidth;

  /// Overrides the [size] height.
  final double? height;
  final AppButtonVariant variant;
  final AppButtonSize size;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  (Gradient?, Color?, Color, List<BoxShadow>?) _style() =>
      switch (widget.variant) {
        AppButtonVariant.primary => (
            AppColors.primaryGradient,
            null,
            AppColors.onPrimary,
            [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.20),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        AppButtonVariant.secondary => (
            null,
            AppColors.surfaceContainerHigh,
            AppColors.onSurfaceVariant,
            null,
          ),
        AppButtonVariant.tertiary => (
            null,
            AppColors.tertiaryContainer,
            AppColors.onTertiaryContainer,
            null,
          ),
        AppButtonVariant.solid => (
            null,
            AppColors.primary,
            AppColors.onPrimary,
            null,
          ),
        AppButtonVariant.ghost => (
            null,
            AppColors.surfaceContainerLowest.withValues(alpha: 0.5),
            AppColors.onSurfaceVariant,
            null,
          ),
        AppButtonVariant.danger => (
            null,
            AppColors.error,
            AppColors.onError,
            [
              BoxShadow(
                color: AppColors.error.withValues(alpha: 0.20),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
      };

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final (gradient, fill, fg, shadow) = _style();
    final size = widget.size;

    return Semantics(
      button: true,
      enabled: !isDisabled,
      child: GestureDetector(
        onTapDown: isDisabled ? null : (_) => _controller.forward(),
        onTapUp: isDisabled ? null : (_) => _controller.reverse(),
        onTapCancel: isDisabled ? null : () => _controller.reverse(),
        onTap: isDisabled ? null : widget.onPressed,
        child: ScaleTransition(
          scale: _scale,
          child: Opacity(
            // Web: `disabled:opacity-50`; loading keeps full strength.
            opacity: widget.onPressed == null && !widget.isLoading ? 0.5 : 1,
            child: Container(
              height: widget.height ?? size.height,
              constraints: BoxConstraints(minWidth: widget.minWidth),
              padding: EdgeInsets.symmetric(horizontal: size.hPadding),
              decoration: BoxDecoration(
                gradient: gradient,
                color: fill,
                borderRadius: AppSpacing.borderRadiusFull,
                boxShadow: isDisabled ? null : shadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.isLoading) ...[
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg,
                      ),
                    ),
                    AppSpacing.hGapSm,
                  ] else if (widget.icon != null) ...[
                    Icon(widget.icon, color: fg, size: size.fontSize + 4),
                    AppSpacing.hGapSm,
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.button(
                        fontSize: size.fontSize,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary action — kept for existing call sites. Renders the filled
/// [AppButtonVariant.secondary] pill (the web has no outlined buttons).
class AppOutlinedButton extends StatelessWidget {
  const AppOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.minWidth = double.infinity,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      minWidth: minWidth,
      variant: AppButtonVariant.secondary,
    );
  }
}

/// Text link button — minimal, no background.
class AppTextButton extends StatelessWidget {
  const AppTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

/// Uppercase tracked text link (web `font-label text-xs font-bold uppercase
/// tracking-widest text-primary`), e.g. "VIEW CALENDAR", "FORGOT PASSWORD?".
class AppLinkButton extends StatelessWidget {
  const AppLinkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.small = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// 10px instead of 12px.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final style = small
        ? AppTypography.eyebrow.copyWith(letterSpacing: 1)
        : AppTypography.overline;
    return InkWell(
      onTap: onPressed,
      borderRadius: AppSpacing.borderRadiusSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Text(
          label.toUpperCase(),
          style: style.copyWith(color: AppColors.primary),
        ),
      ),
    );
  }
}
