import 'package:flutter/material.dart';

/// Spacing, radius and elevation tokens.
///
/// Rule for this project: never write a raw number into a `padding` or
/// `margin`. Use a token from here so rhythm stays consistent and a design
/// change is a one-line edit.
class AppSpacing {
  AppSpacing._();

  /// 4px base ladder.
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;

  /// Standard screen gutter. Used by every scrollable page.
  static const double gutter = 20;
}

class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;

  /// Product cards, sheets, chat bubbles.
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius sheetRadius = BorderRadius.vertical(top: Radius.circular(xl));
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(pill));
}

class AppElevation {
  AppElevation._();

  static const double none = 0;
  static const double low = 2;
  static const double medium = 6;
  static const double high = 12;
}

/// Fixed layout sizes that would otherwise be magic numbers in widgets.
class AppSizes {
  AppSizes._();

  /// Minimum tap target — keeps the app usable for users with large
  /// touch targets / motor impairments (accessibility requirement).
  static const double minTapTarget = 48;

  static const double productCardWidth = 172;
  static const double storeCardWidth = 200;
  static const double bottomNavHeight = 64;
  static const double appBarHeight = 56;
  static const double avatarSmall = 32;
  static const double avatarMedium = 44;
  static const double avatarLarge = 88;
}
