import 'package:flutter/material.dart';

/// Design tokens for the app.
///
/// Identity: "Modern Thai + Premium + Friendly + Trustworthy"
///
/// The palette is built from three ideas:
///  - Jade green  = trust, growth, freshness (primary brand colour)
///  - Thai gold   = premium, warmth, reward (price / rating / commission)
///  - Clay red    = urgency, promotion, OTOP handicraft (sale / coupon)
///
/// Everything else is a warm neutral so product photography stays the focus.
class AppColors {
  AppColors._();

  // --- Brand ---------------------------------------------------------------
  static const Color primary = Color(0xFF146356);
  static const Color primaryDark = Color(0xFF0B4439);
  static const Color primaryLight = Color(0xFFE3F0EC);

  static const Color accent = Color(0xFFE4A11B);
  static const Color accentLight = Color(0xFFFBF0D9);

  static const Color clay = Color(0xFFC1462F);
  static const Color clayLight = Color(0xFFFBE7E2);

  // --- Neutrals (warm, not cold grey) --------------------------------------
  static const Color background = Color(0xFFFAF7F2);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF3EFE8);
  static const Color border = Color(0xFFE6E0D6);
  static const Color borderStrong = Color(0xFFCFC7B8);

  static const Color ink = Color(0xFF1C1B1A);
  static const Color inkMuted = Color(0xFF6B6660);
  static const Color inkSubtle = Color(0xFF9A948C);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // --- Semantic ------------------------------------------------------------
  static const Color success = Color(0xFF2E7D52);
  static const Color successLight = Color(0xFFE4F2E9);
  static const Color warning = Color(0xFFB26A00);
  static const Color warningLight = Color(0xFFFCF0DC);
  static const Color danger = Color(0xFFB3261E);
  static const Color dangerLight = Color(0xFFFBE6E4);
  static const Color info = Color(0xFF1F5F8B);
  static const Color infoLight = Color(0xFFE3EFF6);

  /// Shown behind disabled buttons and inactive icons.
  static const Color disabled = Color(0xFFD6D0C6);

  // --- Province accents -----------------------------------------------------
  // Used to give each Thai region its own colour on the Explore map and
  // province cards, so browsing by region feels like a place, not a filter.
  static const Color regionNorth = Color(0xFF3E6B8A);
  static const Color regionNortheast = Color(0xFF8A6A3E);
  static const Color regionCentral = Color(0xFF7A4E8A);
  static const Color regionEast = Color(0xFF2E7D6F);
  static const Color regionWest = Color(0xFF4E7A3E);
  static const Color regionSouth = Color(0xFF8A3E5E);

  /// Build a [LinearGradient] from a list of hex ints (used for 3D hero art).
  static LinearGradient gradient(List<int> colors, {List<double>? stops}) {
    return LinearGradient(
      colors: colors.map((c) => Color(c)).toList(),
      stops: stops,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
