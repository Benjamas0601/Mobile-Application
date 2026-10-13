import 'package:flutter/material.dart';

//ไฟล์นี้เป็นไฟล์ที่เก็บสีหลักของแบรนด์ตามชุดดีไซน์ ใช้ผ่าน token เพื่อปรับธีมได้จากจุดเดียวและเพื่อให้ทุกหน้าของแอปใช้สีเดียวกันและสามารถเปลี่ยนธีมได้ง่าย

/// Design tokens for the app.
///
/// Identity: "Modern Thai + Premium + Friendly + Trustworthy"
///
/// Palette: **jade / gold / clay on warm cream** (Thai OTOP revamp).
/// Ported into the existing token names so every screen inherits the new look
/// without being edited one by one. The new-style aliases ([jade], [gold],
/// [clay], ...) are also exposed for fresh code, mirroring the reference
/// design (`otop_flutter`):
///  - jade   = brand / primary actions / numbers
///  - jade dark = pressed surface, dark header band
///  - gold   = promo, "you are here" step, high-value numbers
///  - clay   = urgency, promotion, out-of-stock
///  - cream/page = warm app background
///
/// Every screen therefore reads from the same tokens, and a change here
/// propagates app-wide instead of being re-decided per screen.
/// สีหลักของแบรนด์ตามชุดดีไซน์ ใช้ผ่าน token เพื่อปรับธีมได้จากจุดเดียว
class AppColors {
  AppColors._();

  // --- Brand ---------------------------------------------------------------
  /// Jade — primary brand colour, chunky buttons, prices, headings.
  static const Color primary = Color(0xFF146356);
  static const Color jade = primary;

  /// Jade deep — the solid "shadow" under a chunky button, and the dark
  /// surface colour. Also the pressed/disabled edge of the button.
  static const Color primaryDark = Color(0xFF0E4D42);
  static const Color jadeDark = primaryDark;

  /// A lighter jade for hairlines and soft edges on dark jade surfaces.
  static const Color primaryBorder = Color(0xFF2A8A77);
  static const Color jadeLight = primaryBorder;

  /// Jade soft tint — selected chips, soft fills, notification unread.
  static const Color primaryLight = Color(0xFFE6F1ED);
  static const Color jadeTint = primaryLight;

  /// Gold — promo, "you are here" step, high-value numbers.
  static const Color accent = Color(0xFFE4A11B);
  static const Color gold = accent;

  /// Dark amber for text that must stay readable on gold tint / paper.
  static const Color accentDark = Color(0xFF6B4A00);
  static const Color warnText = accentDark;
  static const Color accentLight = Color(0xFFFFF4D6);
  static const Color goldTint = accentLight;

  /// Text that sits on a solid gold button.
  static const Color onGold = Color(0xFF2B1E00);

  /// Clay — urgency, promotion, out-of-stock, rejected commission.
  static const Color clay = Color(0xFFC1462F);
  static const Color clayDark = Color(0xFFA53A28);
  static const Color clayLight = Color(0xFFFBE9E4);

  // --- Neutrals ------------------------------------------------------------- //ส่วนของสีที่เป็นกลางพื้นหลังและตัวอักษร
  /// Page — the warm app background (cream).
  static const Color background = Color(0xFFF6F2E6);
  static const Color page = background;

  /// Cream accent used for soft warm fills.
  static const Color cream = Color(0xFFFBF6EA);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = cream;

  static const Color border = Color(0xFFE2DAC4);
  static const Color borderStrong = Color(0xFFD9D2BF);
  static const Color field = borderStrong;

  static const Color ink = Color(0xFF1C2B26);
  static const Color inkMuted = Color(0xFF4E5A54);
  static const Color inkSoft = inkMuted;
  static const Color inkSubtle = Color(0xFF6E7A74);
  static const Color hint = inkSubtle;

  /// Body copy that sits one step below [ink] but is still readable.  //ส่วนของตัวอักษรที่อยู่ด้านล่าง [ink] แต่ยังอ่านได้
  static const Color inkBody = Color(0xFF3F4F48);
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Muted jade for secondary text on a jade fill (e.g. header subtitles).
  static const Color onPrimaryMuted = Color(0xFFCFE5DE);

  // --- Semantic ------------------------------------------------------------ 
  static const Color success = Color(0xFF1F6B57);
  static const Color successLight = Color(0xFFE3F1EA);

  /// Amber for "waiting"/"pending". #6B4A00 on [warningLight] clears WCAG AA
  /// body-text contrast (4.5:1) while still reading as gold rather than brown.
  static const Color warning = Color(0xFF6B4A00);
  static const Color warningLight = Color(0xFFFFF4D6);
  static const Color danger = Color(0xFFC1462F);
  static const Color dangerLight = Color(0xFFFBE9E4);
  static const Color info = Color(0xFF3E6B8A);
  static const Color infoLight = Color(0xFFE3EFF6);

  /// Neutral chip fill, used for the "cancelled" status. //สีชิปที่เป็นกลาง ใช้สำหรับสถานะ "ยกเลิก"
  static const Color neutralLight = Color(0xFFF0EDE3);

  /// Shown behind disabled buttons and inactive icons. //แสดงด้านหลังปุ่มที่ถูกปิดใช้งานและไอคอนที่ไม่ใช้งาน
  static const Color disabled = Color(0xFFD9D2BF);
  static const Color disabledDark = Color(0xFFB9B299);

  // --- Province accents -----------------------------------------------------
  // Used to give each Thai region its own colour on Home's region chips and
  // the seller tints, so browsing by region feels like a place, not a filter.
  // Values match the HTML design set exactly.  //สีที่ใช้เพื่อให้แต่ละภูมิภาคของไทยมีสีของตัวเองบนชิปภูมิภาคของหน้าแรกและสีของผู้ขาย เพื่อให้การเรียกดูตามภูมิภาครู้สึกเหมือนเป็นสถานที่ ไม่ใช่ตัวกรอง ค่าตรงกับชุดการออกแบบ HTML อย่างแม่นยำ
  static const Color regionNorth = Color(0xFF3E6B8A);
  static const Color regionNortheast = Color(0xFF8A6A3E);
  static const Color regionCentral = Color(0xFF7A4E8A);
  static const Color regionEast = Color(0xFF9A5A3E);
  static const Color regionWest = Color(0xFF466B5A);
  static const Color regionSouth = Color(0xFF8A3E5E);

  // --- Product placeholders -------------------------------------------------
  // Woven-fabric stand-ins for product photography. The design uses texture
  // instead of photos so the layout reads the same with or without assets.
  static const Color weaveGreen = Color(0xFF2A8A77);
  static const Color weaveIndigo = Color(0xFF146356);
  static const Color weaveLac = Color(0xFFC1462F);
  static const Color weavePlum = Color(0xFF8A3E5E);

  // --- Dark theme -----------------------------------------------------------
  /// Dark surfaces reuse the same jade hues rather than dropping to pure
  /// black, so product images (shot on white) do not glare against the
  /// background.
  static const Color darkBackground = Color(0xFF0E2B25);
  static const Color darkSurface = Color(0xFF16332C);
  static const Color darkSurfaceMuted = Color(0xFF1F4238);
  static const Color darkBorder = Color(0xFF2B5146);
  static const Color darkInk = Color(0xFFEDF3F0);
  static const Color darkInkMuted = Color(0xFFA9C4BB);
  static const Color darkInkSubtle = Color(0xFF7B9A92);
  static const Color darkInkBody = Color(0xFFC6D8D2);

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