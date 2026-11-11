import 'package:flutter/material.dart';

/// Design system color tokens for Meeple.
/// All values sourced from docs/DESIGN.md — never use raw hex in templates.
abstract final class AppColors {
  // ── Primary ──────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF895100);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFFF9F1C);
  static const Color onPrimaryContainer = Color(0xFF683C00);
  static const Color primaryFixed = Color(0xFFFFDCBC);
  static const Color onPrimaryFixed = Color(0xFF2C1700);
  static const Color primaryFixedDim = Color(0xFFFFB86B);
  static const Color onPrimaryFixedVariant = Color(0xFF683D00);

  // ── Secondary ─────────────────────────────────────────────────────────────
  static const Color secondary = Color(0xFF835401);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFFDBD68);
  static const Color onSecondaryContainer = Color(0xFF764B00);
  static const Color secondaryFixed = Color(0xFFFFDDB5);
  static const Color onSecondaryFixed = Color(0xFF2A1800);
  static const Color secondaryFixedDim = Color(0xFFFABB65);

  // ── Tertiary ─────────────────────────────────────────────────────────────
  static const Color tertiary = Color(0xFF006A62);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF36C9BB);
  static const Color onTertiaryContainer = Color(0xFF005049);
  static const Color tertiaryFixed = Color(0xFF70F8E8);
  static const Color onTertiaryFixed = Color(0xFF00201D);
  static const Color tertiaryFixedDim = Color(0xFF4FDBCC);

  // ── Error ────────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // ── Surface / Background ─────────────────────────────────────────────────
  static const Color background = Color(0xFFF8F9FA);
  static const Color onBackground = Color(0xFF191C1D);
  static const Color surface = Color(0xFFF8F9FA);
  static const Color onSurface = Color(0xFF191C1D);
  static const Color onSurfaceVariant = Color(0xFF544434);

  static const Color surfaceDim = Color(0xFFD9DADB);

  /// Warm paper backdrop behind the auth screens (web `auth-backdrop`).
  static const Color authBackdrop = Color(0xFFEBE8E2);

  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF3F4F5);
  static const Color surfaceContainer = Color(0xFFEDEEEF);
  static const Color surfaceContainerHigh = Color(0xFFE7E8E9);
  static const Color surfaceContainerHighest = Color(0xFFE1E3E4);

  // ── Inverse ──────────────────────────────────────────────────────────────
  static const Color inverseSurface = Color(0xFF2E3132);
  static const Color inverseOnSurface = Color(0xFFF0F1F2);
  static const Color inversePrimary = Color(0xFFFFB86B);

  // ── Outline ──────────────────────────────────────────────────────────────
  static const Color outline = Color(0xFF877462);
  static const Color outlineVariant = Color(0xFFDAC2AE);

  // ── Shadow / Scrim ───────────────────────────────────────────────────────
  static const Color shadow = Color(0xFF000000);
  static const Color scrim = Color(0xFF000000);

  // ── Gradients ─────────────────────────────────────────────────────────────
  /// Primary brand gradient: rich amber → bright orange.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primary, primaryContainer],
  );

  /// Diagonal variant (`bg-gradient-to-br`) — the bottom-nav create button.
  static const LinearGradient primaryGradientDiagonal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryContainer],
  );

  /// Vertical variant for hero sections.
  static const LinearGradient primaryGradientVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primary, primaryContainer],
  );

  // ── Glass ────────────────────────────────────────────────────────────────
  /// 80% opacity white — used for glass surfaces.
  static const Color glassBackground = Color(0xCCF8F9FA);

  /// Glass border — rgba(255,255,255,0.10)
  static const Color glassBorder = Color(0x1AFFFFFF);

  /// Filled form input: surface-container-highest at 60% (web
  /// `bg-surface-container-highest/60`).
  static const Color inputFill = Color(0x99E1E3E4);

  // ── Utility ──────────────────────────────────────────────────────────────
  static const Color transparent = Color(0x00000000);

  /// Overlay for dimming screens (e.g. dialogs, bottom sheets).
  static const Color scrimOverlay = Color(0x66000000);

  /// Success green (semantic, not in base palette).
  static const Color success = Color(0xFF006A62);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color successContainer = Color(0xFF9EF2E8);
  static const Color onSuccessContainer = Color(0xFF00201E);

  // Private constructor — this class is not meant to be instantiated.
  const AppColors._();
}
