import 'package:flutter/painting.dart';

/// Shadows used by the web design (soft, low-opacity — never harsh).
abstract final class AppShadows {
  /// Feed card: `0 8px 24px rgba(0,0,0,.04)`.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// Glass top bar: `0 12px 32px rgba(0,0,0,.06)`.
  static const List<BoxShadow> bar = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 32, offset: Offset(0, 12)),
  ];

  /// Bottom nav: `0 -8px 24px rgba(0,0,0,.04)`.
  static const List<BoxShadow> nav = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 24, offset: Offset(0, -8)),
  ];

  /// Primary glow: `0 8px 24px rgba(137,81,0,.35)` (create button).
  static const List<BoxShadow> primaryGlow = [
    BoxShadow(color: Color(0x59895100), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// Tailwind `shadow-sm`.
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
  ];
}
