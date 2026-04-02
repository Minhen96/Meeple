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
  // ── Display ───────────────────────────────────────────────────────────────
  static TextStyle get displayLarge => GoogleFonts.plusJakartaSans(
        fontSize: 57,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.12,
        color: AppColors.onBackground,
      );

  static TextStyle get displayMedium => GoogleFonts.plusJakartaSans(
        fontSize: 45,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
        height: 1.16,
        color: AppColors.onBackground,
      );

  static TextStyle get displaySmall => GoogleFonts.plusJakartaSans(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.22,
        color: AppColors.onBackground,
      );

  // ── Headline ──────────────────────────────────────────────────────────────
  static TextStyle get headlineLarge => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
        height: 1.25,
        color: AppColors.onBackground,
      );

  static TextStyle get headlineMedium => GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.29,
        color: AppColors.onBackground,
      );

  static TextStyle get headlineSmall => GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.33,
        color: AppColors.onBackground,
      );

  // ── Title ─────────────────────────────────────────────────────────────────
  static TextStyle get titleLarge => GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.27,
        color: AppColors.onBackground,
      );

  static TextStyle get titleMedium => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
        height: 1.5,
        color: AppColors.onBackground,
      );

  static TextStyle get titleSmall => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.43,
        color: AppColors.onBackground,
      );

  // ── Body ──────────────────────────────────────────────────────────────────
  static TextStyle get bodyLarge => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        height: 1.5,
        color: AppColors.onBackground,
      );

  static TextStyle get bodyMedium => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        height: 1.43,
        color: AppColors.onBackground,
      );

  static TextStyle get bodySmall => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.33,
        color: AppColors.onSurfaceVariant,
      );

  // ── Label (Manrope) ───────────────────────────────────────────────────────
  static TextStyle get labelLarge => GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.43,
        color: AppColors.onBackground,
      );

  /// Uppercase, widest tracking — for metadata, categories, tags.
  static TextStyle get labelMedium => GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        height: 1.33,
        color: AppColors.onSurfaceVariant,
      ).copyWith(
        // Force uppercase rendering expectation — apply TextCapitalization
        // in widgets using this style.
      );

  static TextStyle get labelSmall => GoogleFonts.manrope(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        height: 1.6,
        color: AppColors.onSurfaceVariant,
      );

  // ── Convenience helpers ───────────────────────────────────────────────────
  /// Brand wordmark — large extrabold Plus Jakarta Sans.
  static TextStyle get brandLarge => GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: AppColors.primary,
      );

  static TextStyle get brandSmall => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
        color: AppColors.primary,
      );

  // Private constructor — static-only class.
  const AppTypography._();
}
