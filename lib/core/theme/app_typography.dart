import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale for the app.
///
/// NOTE ON THE FONT
/// The app is Thai-first, so the text styles below deliberately do **not**
/// pin a single `fontFamily`. Pinning a family that only contains Latin
/// glyphs makes Thai text fall back inconsistently across Android, iOS,
/// Chrome and Windows. Leaving `fontFamily` null lets each platform use its
/// own Thai-capable system font (Noto Sans Thai on Android/Chrome,
/// Thonburi on iOS, Leelawadee UI on Windows), which is always legible.
///
/// TODO(week5): bundle "Noto Sans Thai" (SIL Open Font License) into
/// assets/fonts/ and set [kAppFontFamily] so typography is pixel-identical on
/// every device. Drop the .ttf files in, then flip the switch below — no
/// other file needs to change.
const String kAppFontFamily = '';

class AppTextStyles {
  AppTextStyles._();

  static const String _thai = 'Noto Sans Thai';

  /// Family list handed to [TextStyle.fontFamilyFallback].
  /// Order matters: Latin first (cleaner shapes), Thai as the fallback.
  static const List<String> _fallback = <String>[
    'Roboto',
    _thai,
    'Leelawadee UI',
    'Thonburi',
  ];

  static TextStyle _s({
    required double size,
    required FontWeight weight,
    required Color color,
    double? height,
    double? spacing,
  }) {
    return TextStyle(
      fontFamily: kAppFontFamily.isEmpty ? null : kAppFontFamily,
      fontFamilyFallback: kAppFontFamily.isEmpty ? _fallback : const <String>[],
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: spacing,
    );
  }

  // --- Display / hero ------------------------------------------------------
  static final TextStyle displayLarge = _s(
    size: 34,
    weight: FontWeight.w800,
    color: AppColors.ink,
    height: 1.2,
    spacing: -0.4,
  );
  static final TextStyle displayMedium = _s(
    size: 28,
    weight: FontWeight.w800,
    color: AppColors.ink,
    height: 1.25,
    spacing: -0.3,
  );

  // --- Headings ------------------------------------------------------------
  static final TextStyle headlineLarge = _s(
    size: 24,
    weight: FontWeight.w700,
    color: AppColors.ink,
    height: 1.3,
    spacing: -0.2,
  );
  static final TextStyle headlineMedium = _s(
    size: 20,
    weight: FontWeight.w700,
    color: AppColors.ink,
    height: 1.35,
  );
  static final TextStyle headlineSmall = _s(
    size: 17,
    weight: FontWeight.w700,
    color: AppColors.ink,
    height: 1.4,
  );

  // --- Body ----------------------------------------------------------------
  static final TextStyle bodyLarge = _s(
    size: 16,
    weight: FontWeight.w400,
    color: AppColors.ink,
    height: 1.5,
  );
  static final TextStyle bodyMedium = _s(
    size: 14,
    weight: FontWeight.w400,
    color: AppColors.ink,
    height: 1.5,
  );
  static final TextStyle bodySmall = _s(
    size: 13,
    weight: FontWeight.w400,
    color: AppColors.inkMuted,
    height: 1.45,
  );

  // --- Labels / buttons -----------------------------------------------------
  static final TextStyle labelLarge = _s(
    size: 15,
    weight: FontWeight.w600,
    color: AppColors.ink,
    height: 1.2,
  );
  static final TextStyle labelMedium = _s(
    size: 13,
    weight: FontWeight.w600,
    color: AppColors.inkMuted,
    height: 1.2,
  );
  static final TextStyle labelSmall = _s(
    size: 11,
    weight: FontWeight.w600,
    color: AppColors.inkSubtle,
    height: 1.2,
  );

  // --- Price / rating ------------------------------------------------------
  /// Prices are always bold and tabular-looking so a list of products scans
  /// quickly and numbers line up.
  static final TextStyle priceLarge = _s(
    size: 22,
    weight: FontWeight.w800,
    color: AppColors.ink,
    height: 1.1,
  );
  static final TextStyle priceMedium = _s(
    size: 16,
    weight: FontWeight.w700,
    color: AppColors.ink,
    height: 1.1,
  );
  static final TextStyle priceStrike = _s(
    size: 13,
    weight: FontWeight.w400,
    color: AppColors.inkSubtle,
    height: 1.1,
  ).copyWith(decoration: TextDecoration.lineThrough);

  // --- Section label -------------------------------------------------------
  /// Small uppercase-ish eyebrow used above section titles.
  static final TextStyle overline = _s(
    size: 12,
    weight: FontWeight.w700,
    color: AppColors.primary,
    height: 1.2,
    spacing: 0.6,
  );
}
