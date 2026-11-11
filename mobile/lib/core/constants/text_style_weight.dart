import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';

/// Changing the weight of an [AppTypography] style.
///
/// google_fonts bakes the weight into the font family name
/// (`PlusJakartaSans_400`), so `style.copyWith(fontWeight: …)` keeps
/// drawing the original weight. Use `style.weight(FontWeight.w800)` instead:
/// it re-resolves the Google font file for the new weight.
extension TextStyleWeight on TextStyle {
  TextStyle weight(FontWeight weight) {
    final next = copyWith(fontWeight: weight);
    if (!AppTypography.useGoogleFonts) return next;
    final family = fontFamily ?? '';
    return family.startsWith('Manrope')
        ? GoogleFonts.manrope(textStyle: next)
        : GoogleFonts.plusJakartaSans(textStyle: next);
  }
}
