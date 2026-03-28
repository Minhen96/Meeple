import 'package:flutter/material.dart';

/// Spacing and border-radius constants for Meeple & Hearth.
///
/// All padding, gap, and radius values MUST use these tokens — never raw numbers.
abstract final class AppSpacing {
  // ── Spacing ───────────────────────────────────────────────────────────────
  /// 4px — micro gap, icon padding
  static const double xs = 4;

  /// 8px — tight padding, small gaps
  static const double sm = 8;

  /// 12px — medium-tight padding
  static const double md = 12;

  /// 16px — standard horizontal page padding
  static const double lg = 16;

  /// 24px — card internal padding, section gaps
  static const double xl = 24;

  /// 32px — large section gaps, hero padding
  static const double xxl = 32;

  /// 48px — screen-level vertical breathing room
  static const double xxxl = 48;

  // ── EdgeInsets shortcuts ──────────────────────────────────────────────────
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: lg,
  );

  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(
    horizontal: lg,
  );

  static const EdgeInsets cardPadding = EdgeInsets.all(xl);

  static const EdgeInsets chipPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: xs + 2,
  );

  // ── Border Radii ──────────────────────────────────────────────────────────
  /// 4px — subtle rounding for small elements
  static const double radiusXs = 4;

  /// 8px — small cards, chips
  static const double radiusSm = 8;

  /// 12px — medium inputs, tags
  static const double radiusMd = 12;

  /// 16px — standard card radius
  static const double radiusLg = 16;

  /// 24px — large surfaces
  static const double radiusXl = 24;

  /// 32px — large containers
  static const double radiusXxl = 32;

  /// 48px — pill / stadium shapes
  static const double radiusPill = 48;

  /// 9999px — fully circular (avatars, FAB)
  static const double radiusFull = 9999;

  // ── BorderRadius objects ───────────────────────────────────────────────────
  static const BorderRadius borderRadiusXs = BorderRadius.all(
    Radius.circular(radiusXs),
  );
  static const BorderRadius borderRadiusSm = BorderRadius.all(
    Radius.circular(radiusSm),
  );
  static const BorderRadius borderRadiusMd = BorderRadius.all(
    Radius.circular(radiusMd),
  );
  static const BorderRadius borderRadiusLg = BorderRadius.all(
    Radius.circular(radiusLg),
  );
  static const BorderRadius borderRadiusXl = BorderRadius.all(
    Radius.circular(radiusXl),
  );
  static const BorderRadius borderRadiusXxl = BorderRadius.all(
    Radius.circular(radiusXxl),
  );
  static const BorderRadius borderRadiusPill = BorderRadius.all(
    Radius.circular(radiusPill),
  );
  static const BorderRadius borderRadiusFull = BorderRadius.all(
    Radius.circular(radiusFull),
  );

  // ── SizedBox helpers ──────────────────────────────────────────────────────
  static const SizedBox gapXs = SizedBox(width: xs, height: xs);
  static const SizedBox gapSm = SizedBox(width: sm, height: sm);
  static const SizedBox gapMd = SizedBox(width: md, height: md);
  static const SizedBox gapLg = SizedBox(width: lg, height: lg);
  static const SizedBox gapXl = SizedBox(width: xl, height: xl);
  static const SizedBox gapXxl = SizedBox(width: xxl, height: xxl);

  static const SizedBox hGapXs = SizedBox(width: xs);
  static const SizedBox hGapSm = SizedBox(width: sm);
  static const SizedBox hGapMd = SizedBox(width: md);
  static const SizedBox hGapLg = SizedBox(width: lg);
  static const SizedBox hGapXl = SizedBox(width: xl);

  static const SizedBox vGapXs = SizedBox(height: xs);
  static const SizedBox vGapSm = SizedBox(height: sm);
  static const SizedBox vGapMd = SizedBox(height: md);
  static const SizedBox vGapLg = SizedBox(height: lg);
  static const SizedBox vGapXl = SizedBox(height: xl);
  static const SizedBox vGapXxl = SizedBox(height: xxl);
  static const SizedBox vGapXxxl = SizedBox(height: xxxl);

  // Private constructor.
  const AppSpacing._();
}
