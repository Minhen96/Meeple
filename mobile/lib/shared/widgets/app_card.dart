import 'package:flutter/material.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_shadows.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';

/// Surface tones for [AppCard] (No-Line Rule: depth by tone, never borders).
enum AppCardTone {
  /// `bg-surface-container-low` — the default content card / panel.
  low,

  /// `bg-surface-container-lowest` (white) with the soft feed shadow
  /// `0 8px 24px rgba(0,0,0,.04)` — feed post cards.
  elevated,

  /// `bg-surface-container-lowest` without shadow — tiles inside a
  /// [AppTileGroup].
  lowest,

  /// `bg-surface-container` — pressed / nested panels.
  container,
}

/// Rounded borderless card — the base surface of every web card.
///
/// ```dart
/// AppCard(child: ...)                                   // surface-container-low, 32px
/// AppCard(tone: AppCardTone.elevated, radius: AppRadius.card, child: ...) // feed card
/// AppCard(onTap: () => ..., child: ...)                 // tappable with ink
/// ```
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.tone = AppCardTone.low,
    this.radius = AppRadius.panel,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.onTap,
    this.width,
    this.clip = true,
  });

  final Widget child;
  final AppCardTone tone;
  final double radius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double? width;

  /// Clips children (images) to the rounded shape.
  final bool clip;

  Color get _color => switch (tone) {
        AppCardTone.low => AppColors.surfaceContainerLow,
        AppCardTone.elevated => AppColors.surfaceContainerLowest,
        AppCardTone.lowest => AppColors.surfaceContainerLowest,
        AppCardTone.container => AppColors.surfaceContainer,
      };

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) content = InkWell(onTap: onTap, child: content);
    Widget card = Material(
      color: _color,
      shape: shape,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: content,
    );
    if (tone == AppCardTone.elevated) {
      card = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: AppShadows.card,
        ),
        child: card,
      );
    }
    if (width != null) card = SizedBox(width: width, child: card);
    if (margin != null) card = Padding(padding: margin!, child: card);
    return card;
  }
}

/// Uppercase tracked section label — web `text-xs font-label font-bold
/// uppercase tracking-widest text-on-surface-variant` ("THIS WEEK",
/// "ACCOUNT"). Pass the text as written; it is upper-cased here.
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(4, 0, 4, AppSpacing.sm),
    this.color = AppColors.onSurfaceVariant,
  });

  final String text;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: AppTypography.overline.copyWith(color: color),
        ),
      ),
    );
  }
}

/// Grouped list of separate rounded tiles — the web settings menu:
/// a surface-container-low panel (`rounded-xl p-1 space-y-1`) holding
/// white [AppTile]s. Optional [label] renders a [SectionLabel] above.
class AppTileGroup extends StatelessWidget {
  const AppTileGroup({super.key, required this.children, this.label});

  final List<Widget> children;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) SectionLabel(label!),
        Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.panel),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) AppSpacing.vGapXs,
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One settings-style row (web SettingsMenu row): white rounded tile,
/// 20px leading icon, `text-sm` title, trailing chevron (or [trailing]).
class AppTile extends StatelessWidget {
  const AppTile({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
    this.showChevron = true,
  });

  final String title;
  final IconData? icon;
  final String? subtitle;

  /// Replaces the chevron (switch, detail text…).
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Error-coloured icon and title (Delete Account).
  final bool danger;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? AppColors.error : AppColors.onSurface;
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.panel),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 14,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: danger ? AppColors.error : AppColors.onSurfaceVariant,
                ),
                AppSpacing.hGapMd,
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyMedium.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null)
                      Text(subtitle!, style: AppTypography.bodySmall),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (showChevron && onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
