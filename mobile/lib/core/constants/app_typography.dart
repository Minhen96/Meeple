import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';

/// Typography scale for Meeple — mirrors the web app's Tailwind scale
/// (`frontend/tailwind.config.js`) so both clients render the same text.
///
/// Two font families:
/// - **Plus Jakarta Sans** — headlines, body, titles (`font-headline`,
///   `font-body`)
/// - **Manrope** — labels and metadata (`font-label`)
///
/// Tailwind → token map (size / line height / weight / tracking):
///
/// | Web class                                   | Token            |
/// |---------------------------------------------|------------------|
/// | `text-3xl font-extrabold tracking-tight`    | [headlineLarge]  |
/// | `text-2xl font-extrabold`                   | [headlineMedium] |
/// | `text-xl font-extrabold` (page header)      | [headlineSmall]  |
/// | `text-lg font-bold` (section heading)       | [titleLarge]     |
/// | `text-base font-bold` (card title)          | [titleMedium]    |
/// | `text-sm font-bold` (names, list titles)    | [titleSmall]     |
/// | `text-base` / `text-sm` / `text-xs`         | body L / M / S   |
/// | `font-label text-sm font-bold`              | [labelLarge]     |
/// | `font-label text-xs font-bold`              | [labelMedium]    |
/// | `font-label text-[10px]` (timestamps)       | [labelSmall]     |
/// | `text-xs font-bold uppercase tracking-widest` | [overline]     |
/// | `text-[10px] font-black uppercase tracking-[.2em]` | [eyebrow] |
///
/// Body text uses normal tracking (0) like the web — never add letter
/// spacing to running text. Uppercase micro labels ([overline], [eyebrow])
/// must be upper-cased by the caller (`text.toUpperCase()`).
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
    FontStyle? fontStyle,
  }) =>
      useGoogleFonts
          ? GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: fontWeight,
              letterSpacing: letterSpacing,
              height: height,
              color: color,
              fontStyle: fontStyle,
            )
          : TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: fontSize,
              fontWeight: fontWeight,
              letterSpacing: letterSpacing,
              height: height,
              color: color,
              fontStyle: fontStyle,
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
  /// `text-6xl font-black tracking-tighter` — auth hero wordmark.
  static TextStyle get displayLarge => _jakarta(
        fontSize: 60,
        fontWeight: FontWeight.w900,
        letterSpacing: -3,
        height: 1,
        color: AppColors.onBackground,
      );

  /// `text-4xl font-black tracking-tight`.
  static TextStyle get displayMedium => _jakarta(
        fontSize: 36,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.9,
        height: 1.11,
        color: AppColors.onBackground,
      );

  /// `text-3xl font-black tracking-tight` — auth hero title.
  static TextStyle get displaySmall => _jakarta(
        fontSize: 30,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.75,
        height: 1.2,
        color: AppColors.onBackground,
      );

  // ── Headline ──────────────────────────────────────────────────────────────
  /// `text-3xl font-extrabold tracking-tight` — page greeting / hero title.
  static TextStyle get headlineLarge => _jakarta(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.75,
        height: 1.2,
        color: AppColors.onBackground,
      );

  /// `text-2xl font-extrabold tracking-tight` — screen titles.
  static TextStyle get headlineMedium => _jakarta(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        height: 1.33,
        color: AppColors.onBackground,
      );

  /// `text-xl font-extrabold` — sub-page header title ([PageHeader]).
  static TextStyle get headlineSmall => _jakarta(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
        height: 1.4,
        color: AppColors.onBackground,
      );

  // ── Title ─────────────────────────────────────────────────────────────────
  /// `text-lg font-bold` — section headings ("Upcoming Events").
  static TextStyle get titleLarge => _jakarta(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.56,
        color: AppColors.onBackground,
      );

  /// `text-base font-bold` — card titles.
  static TextStyle get titleMedium => _jakarta(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.5,
        color: AppColors.onBackground,
      );

  /// `text-sm font-bold` — author names, list-row titles.
  static TextStyle get titleSmall => _jakarta(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.43,
        color: AppColors.onBackground,
      );

  // ── Body ──────────────────────────────────────────────────────────────────
  /// `text-base`.
  static TextStyle get bodyLarge => _jakarta(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.5,
        color: AppColors.onBackground,
      );

  /// `text-sm` — default running text.
  static TextStyle get bodyMedium => _jakarta(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.43,
        color: AppColors.onBackground,
      );

  /// `text-xs text-on-surface-variant` — secondary metadata.
  static TextStyle get bodySmall => _jakarta(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.33,
        color: AppColors.onSurfaceVariant,
      );

  // ── Label (Manrope) ───────────────────────────────────────────────────────
  /// `font-label text-sm font-bold` — tab / chip / pill labels.
  static TextStyle get labelLarge => _manrope(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.43,
        color: AppColors.onBackground,
      );

  /// `font-label text-xs font-bold` — chips, badges, counts.
  static TextStyle get labelMedium => _manrope(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.33,
        color: AppColors.onSurfaceVariant,
      );

  /// `font-label text-[10px]` — timestamps and fine print.
  static TextStyle get labelSmall => _manrope(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.5,
        color: AppColors.onSurfaceVariant,
      );

  // ── Uppercase micro labels ────────────────────────────────────────────────
  /// `font-label text-xs font-bold uppercase tracking-widest` — section
  /// labels ("THIS WEEK", "ACCOUNT") and link actions ("VIEW CALENDAR").
  /// Upper-case the text yourself.
  static TextStyle get overline => _manrope(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        height: 1.33,
        color: AppColors.onSurfaceVariant,
      );

  /// `text-[10px] font-black uppercase tracking-[.2em]` — form field labels
  /// and eyebrows above titles. Upper-case the text yourself.
  static TextStyle get eyebrow => _manrope(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
        height: 1.5,
        color: AppColors.onSurfaceVariant,
      );

  // ── Buttons ───────────────────────────────────────────────────────────────
  /// `font-headline font-bold` button text; [fontSize] follows the button
  /// size (sm 14, md 16, lg 18).
  static TextStyle button({double fontSize = 16, Color? color}) => _jakarta(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.4,
        color: color ?? AppColors.onPrimary,
      );

  // ── Brand ─────────────────────────────────────────────────────────────────
  /// Auth hero wordmark — `text-6xl font-black italic tracking-tighter`.
  static TextStyle get brandLarge => _jakarta(
        fontSize: 60,
        fontWeight: FontWeight.w900,
        letterSpacing: -3,
        height: 1,
        color: AppColors.primary,
        fontStyle: FontStyle.italic,
      );

  /// Top-bar wordmark — `text-xl font-black tracking-tighter text-primary`.
  static TextStyle get brandSmall => _jakarta(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: -1,
        height: 1.4,
        color: AppColors.primary,
      );

  // Private constructor — static-only class.
  const AppTypography._();
}
