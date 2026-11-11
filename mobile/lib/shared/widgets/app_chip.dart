import 'package:flutter/material.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';

/// Variants of the chip component — web `Chip.svelte` plus status tones.
enum AppChipVariant {
  /// primary-fixed / on-primary-fixed.
  primary,

  /// secondary-container / on-secondary-container ("Open", date badges).
  secondary,

  /// tertiary-container / on-tertiary-container.
  tertiary,

  /// surface-container-highest / on-surface-variant (web `surface`).
  neutral,

  /// error-container / on-error-container.
  error,

  /// Solid primary with white text — the selected state of filter pills.
  solid,
}

/// A compact rounded-full label: status badges, tags, categories
/// (web `px-3 py-1 rounded-full text-xs font-bold font-label`).
///
/// Follows the No-Line Rule — no border, depth through background tonal
/// shift. Pass [uppercase] for the tracked micro-badge look
/// (e.g. "THURSDAY · 11:36 AM").
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.variant = AppChipVariant.neutral,
    this.onTap,
    this.isSelected = false,
    this.icon,
    this.uppercase = false,
    this.dense = false,
  });

  final String label;
  final AppChipVariant variant;
  final VoidCallback? onTap;

  /// Renders as [AppChipVariant.solid] when true.
  final bool isSelected;
  final IconData? icon;
  final bool uppercase;

  /// 10px text and `px-2 py-0.5` with a 4px radius (event date badge).
  final bool dense;

  AppChipVariant get _effective => isSelected ? AppChipVariant.solid : variant;

  Color get _backgroundColor => switch (_effective) {
        AppChipVariant.primary => AppColors.primaryFixed,
        AppChipVariant.secondary => AppColors.secondaryContainer,
        AppChipVariant.tertiary => AppColors.tertiaryContainer,
        AppChipVariant.neutral => AppColors.surfaceContainerHighest,
        AppChipVariant.error => AppColors.errorContainer,
        AppChipVariant.solid => AppColors.primary,
      };

  Color get _textColor => switch (_effective) {
        AppChipVariant.primary => AppColors.onPrimaryFixed,
        AppChipVariant.secondary => AppColors.onSecondaryContainer,
        AppChipVariant.tertiary => AppColors.onTertiaryContainer,
        AppChipVariant.neutral => AppColors.onSurfaceVariant,
        AppChipVariant.error => AppColors.onErrorContainer,
        AppChipVariant.solid => AppColors.onPrimary,
      };

  @override
  Widget build(BuildContext context) {
    final base = dense ? AppTypography.labelSmall : AppTypography.labelMedium;
    final style = base.copyWith(
      color: _textColor,
      fontWeight: FontWeight.w700,
      letterSpacing: uppercase ? (dense ? -0.2 : 0.6) : 0,
    );
    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: dense
          ? const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2)
          : const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius:
            dense ? AppSpacing.borderRadiusXs : AppSpacing.borderRadiusFull,
      ),
      // One Text (icon as a WidgetSpan) so a long label ellipsizes when the
      // chip is width-constrained instead of overflowing.
      child: Text.rich(
        TextSpan(
          children: [
            if (icon != null) ...[
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Icon(icon, size: dense ? 12 : 14, color: _textColor),
                ),
              ),
            ],
            TextSpan(text: uppercase ? label.toUpperCase() : label),
          ],
        ),
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, child: chip);
  }
}

/// Selectable filter pill — web events tabs / library filters
/// (`px-4 py-2 rounded-full text-sm font-label font-bold`; active
/// `bg-primary text-on-primary`, inactive `bg-surface-container-high`).
class AppFilterPill extends StatelessWidget {
  const AppFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onPrimary : AppColors.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primary : AppColors.surfaceContainerHigh,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  AppSpacing.hGapXs,
                ],
                Text(label, style: AppTypography.labelLarge.copyWith(color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One option of an [AppSegmentedControl].
class AppSegment<T> {
  const AppSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Pill-shaped segmented control — web list/calendar toggle: a
/// surface-container-low track (`p-1 rounded-full`) whose selected segment
/// is filled primary (`px-4 py-1.5 text-sm font-label font-bold`).
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<AppSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in segments)
            Padding(
              padding: EdgeInsets.only(
                left: identical(s, segments.first) ? 0 : AppSpacing.xs,
              ),
              child: _Segment(
                segment: s,
                selected: s.value == selected,
                onTap: () => onChanged(s.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final AppSegment<T> segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onPrimary : AppColors.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primary : AppColors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (segment.icon != null) ...[
                  Icon(segment.icon, size: 18, color: fg),
                  AppSpacing.hGapXs,
                ],
                Text(
                  segment.label,
                  style: AppTypography.labelLarge.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
