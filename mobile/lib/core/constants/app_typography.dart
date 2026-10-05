import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';

/// Typography scale for Meeple.
///
/// Two font families:
/// - **Plus Jakarta Sans** — headlines, body, titles
/// - **Manrope** — labels (uppercase tracking for metadata)
///
/// Usage: `AppTypography.headlineLarge`
abstract final class AppTypography {
  /// Fonts are fetched/bundled through google_fonts at runtime. Widget tests
  /// switch this off (see test/flutter_test_config.dart) so no font loading
  /// is attempted; the family names stay the same.
  static bool useGoogleFonts = true;

  static TextStyle _jakarta({
    required double fontSize,
    required FontWeight fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
  }) =>
      useGoogleFonts
          ? GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: fontWeight,
              letterSpacing: letterSpacing,
              height: height,
              color: color,
            )
          : TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: fontSize,
              fontWeight: fontWeight,
              letterSpacing: letterSpacing,
              height: height,
              color: color,
            );

  static TextStyle _manrope({
    required double fontSize,
    required FontWeight fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
  }) =>
      useGoogleFonts
          ? GoogleFonts.manrope(
              fontSize: fontSize,
              fontWeight: fontWeight,
              letterSpacing: letterSpacing,
              height: height,
              color: color,
            )
          : TextStyle(
              fontFamily: 'Manrope',
              fontSize: fontSize,
              fontWeight: fontWeight,
              letterSpacing: letterSpacing,
              height: height,
              color: color,
            );
  // ── Display ───────────────────────────────────────────────────────────────
  static TextStyle get displayLarge => _jakarta(
        fontSize: 57,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.12,
        color: AppColors.onBackground,
      );

  static TextStyle get displayMedium => _jakarta(
        fontSize: 45,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
        height: 1.16,
        color: AppColors.onBackground,
      );

  static TextStyle get displaySmall => _jakarta(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.22,
        color: AppColors.onBackground,
      );

  // ── Headline ──────────────────────────────────────────────────────────────
  static TextStyle get headlineLarge => _jakarta(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
        height: 1.25,
        color: AppColors.onBackground,
      );

  static TextStyle get headlineMedium => _jakarta(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.29,
        color: AppColors.onBackground,
      );

  static TextStyle get headlineSmall => _jakarta(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.33,
        color: AppColors.onBackground,
      );

  // ── Title ─────────────────────────────────────────────────────────────────
  static TextStyle get titleLarge => _jakarta(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.27,
        color: AppColors.onBackground,
      );

  static TextStyle get titleMedium => _jakarta(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
        height: 1.5,
        color: AppColors.onBackground,
      );

  static TextStyle get titleSmall => _jakarta(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.43,
        color: AppColors.onBackground,
      );

  // ── Body ──────────────────────────────────────────────────────────────────
  static TextStyle get bodyLarge => _jakarta(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        height: 1.5,
        color: AppColors.onBackground,
      );

  static TextStyle get bodyMedium => _jakarta(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        height: 1.43,
        color: AppColors.onBackground,
      );

  static TextStyle get bodySmall => _jakarta(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.33,
        color: AppColors.onSurfaceVariant,
      );

  // ── Label (Manrope) ───────────────────────────────────────────────────────
  static TextStyle get labelLarge => _manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.43,
        color: AppColors.onBackground,
      );

  /// Uppercase, widest tracking — for metadata, categories, tags.
  static TextStyle get labelMedium => _manrope(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        height: 1.33,
        color: AppColors.onSurfaceVariant,
      ).copyWith(
        // Force uppercase rendering expectation — apply TextCapitalization
        // in widgets using this style.
      );

  static TextStyle get labelSmall => _manrope(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        height: 1.6,
        color: AppColors.onSurfaceVariant,
      );

  // ── Convenience helpers ───────────────────────────────────────────────────
  /// Brand wordmark — large extrabold Plus Jakarta Sans.
  static TextStyle get brandLarge => _jakarta(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: AppColors.primary,
      );

  static TextStyle get brandSmall => _jakarta(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
        color: AppColors.primary,
      );

  // Private constructor — static-only class.
  const AppTypography._();
}
