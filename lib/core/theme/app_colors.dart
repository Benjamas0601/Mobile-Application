import 'package:flutter/material.dart';

/// Design tokens for the app.
///
/// Identity: "Modern Thai + Premium + Friendly + Trustworthy"
///
/// The palette is the one agreed in the HTML design set
/// (`Thai OTOP — ดีไซน์เพิ่ม.html`), ported 1:1 to Flutter:
///  - Indigo      = brand / primary actions / numbers
///  - Indigo deep = pressed state of a chunky button, dark surface
///  - Lac         = urgency, promotion, destructive, "sold out"
///  - Turmeric    = focus ring, current step, active accent
///  - Paper       = app background
///
/// Every screen therefore reads from the same tokens, and a change here
/// propagates app-wide instead of being re-decided per screen.
/// สีหลักของแบรนด์ตามชุดดีไซน์ ใช้ผ่าน token เพื่อปรับธีมได้จากจุดเดียว
class AppColors {
  AppColors._();

  // --- Brand ---------------------------------------------------------------
  /// Indigo — primary brand colour, chunky buttons, prices, headings.
  static const Color primary = Color(0xFF22337A);

  /// Indigo deep — the solid "shadow" under a chunky button, and the dark
  /// surface colour. Also the pressed/disabled edge of the button.
  static const Color primaryDark = Color(0xFF141F52);

  /// Indigo deep as a light tint, for selected chips and soft fills.
  static const Color primaryLight = Color(0xFFEEF1FB);

  /// A lighter indigo used for hairline borders on dark surfaces.
  static const Color primaryBorder = Color(0xFF5A67A8);

  /// Turmeric — focus ring, "you are here" step, high-value numbers.
  static const Color accent = Color(0xFFF0B429);

  /// Turmeric as a dark amber for text that must stay readable on paper.
  static const Color accentDark = Color(0xFF8A6A00);
  static const Color accentLight = Color(0xFFFFF3D6);

  /// Lac — urgency, promotion, out-of-stock, rejected commission.
  static const Color clay = Color(0xFFC8324A);
  static const Color clayDark = Color(0xFFA32338);
  static const Color clayLight = Color(0xFFFCE8EB);

  // --- Neutrals -------------------------------------------------------------
  /// Paper — the app background, a cool off-white.
  static const Color background = Color(0xFFEDEFF4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF6F8FF);
  static const Color border = Color(0xFFD5D9E6);
  static const Color borderStrong = Color(0xFFB8BED6);

  static const Color ink = Color(0xFF1A2140);
  static const Color inkMuted = Color(0xFF5C6484);
  static const Color inkSubtle = Color(0xFF9AA0BC);

  /// Body copy that sits one step below [ink] but is still readable.
  static const Color inkBody = Color(0xFF3A4263);
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Muted indigo for secondary text on an indigo fill.
  static const Color onPrimaryMuted = Color(0xFFC5CDF2);

  // --- Semantic ------------------------------------------------------------
  static const Color success = Color(0xFF1F6B57);
  static const Color successLight = Color(0xFFE3F1EA);
  static const Color warning = Color(0xFFB07A00);
  static const Color warningLight = Color(0xFFFFF3D6);
  static const Color danger = Color(0xFFC8324A);
  static const Color dangerLight = Color(0xFFFCE8EB);
  static const Color info = Color(0xFF3E6B8A);
  static const Color infoLight = Color(0xFFE3EFF6);

  /// Neutral chip fill, used for the "cancelled" status.
  static const Color neutralLight = Color(0xFFF0F1F6);

  /// Shown behind disabled buttons and inactive icons.
  static const Color disabled = Color(0xFFB8BED6);
  static const Color disabledDark = Color(0xFF98A0BF);

  // --- Province accents -----------------------------------------------------
  // Used to give each Thai region its own colour on the Explore map and
  // province cards, so browsing by region feels like a place, not a filter.
  // Values match the HTML design set exactly.
  static const Color regionNorth = Color(0xFF3E6B8A);
  static const Color regionNortheast = Color(0xFF8A6A3E);
  static const Color regionCentral = Color(0xFF7A4E8A);
  static const Color regionEast = Color(0xFF9A5A3E);
  static const Color regionWest = Color(0xFF466B5A);
  static const Color regionSouth = Color(0xFF8A3E5E);

  // --- Product placeholders -------------------------------------------------
  // Woven-fabric stand-ins for product photography. The design uses texture
  // instead of photos so the layout reads the same with or without assets.
  static const Color weaveGreen = Color(0xFF4E7A3E);
  static const Color weaveIndigo = Color(0xFF22337A);
  static const Color weaveLac = Color(0xFFC8324A);
  static const Color weavePlum = Color(0xFF8A3E5E);

  // --- Dark theme -----------------------------------------------------------
  /// Dark surfaces reuse the same hues rather than dropping to pure black, so
  /// product images (shot on white) do not glare against the background.
  static const Color darkBackground = Color(0xFF0E1430);
  static const Color darkSurface = Color(0xFF161E44);
  static const Color darkSurfaceMuted = Color(0xFF1E2753);
  static const Color darkBorder = Color(0xFF2E3870);
  static const Color darkInk = Color(0xFFEDEFF4);
  static const Color darkInkMuted = Color(0xFFA9B3E6);
  static const Color darkInkSubtle = Color(0xFF7B85BC);
  static const Color darkInkBody = Color(0xFFC6CCE8);

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
