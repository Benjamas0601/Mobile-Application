import 'package:flutter/material.dart';

//ไฟล์นี้เป็นไฟล์ที่เก็บระยะห่างและมิติที่ใช้ซ้ำ เพื่อคุมจังหวะ layout ให้สม่ำเสมอ

/// Spacing, radius and elevation tokens.
///
/// Rule for this project: never write a raw number into a `padding` or
/// `margin`. Use a token from here so rhythm stays consistent and a design
/// change is a one-line edit.
/// ระยะห่างและมิติที่ใช้ซ้ำ เพื่อคุมจังหวะ layout ให้สม่ำเสมอ
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

  /// Horizontal inset used by the cards on the console screens, so a card
  /// sits slightly narrower than the section label above it — the rhythm the
  /// HTML design set established.
  static const double cardGutter = 22;
}

class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;

  /// Radius of every *control* — chunky buttons, chips, text fields.
  /// Deliberately less round than the cards, so a button never reads as a card.
  static const double chunky = 14;

  /// Product cards, sheets, chat bubbles.
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(20)); //เพื่อให้ card มีความโค้งมน
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
  static const BorderRadius pillRadius = BorderRadius.all( //เพื่อให้ปุ่มมีความโค้งมน
    Radius.circular(pill),
  );
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

  /// Height of the design's signature chunky button. Taller than the minimum
  /// tap target because it carries the hard drop-shadow edge underneath.
  static const double chunkyButtonHeight = 52; //เพื่อให้ปุ่มมีความสูงมากขึ้น

  /// Height of the square-ish "pill" chips used for filters and inline
  /// actions (e.g. "จัดการ" on an order card).
  static const double chipHeight = 48; //เพื่อให้ chip มีความสูงมากขึ้น

  /// Height of the inline stepper buttons that adjust variant stock.
  static const double stepperButton = 42; 

  /// Hard drop-shadow thickness under a chunky button.
  static const double chunkyShadow = 5;

  static const double productCardWidth = 172;
  static const double storeCardWidth = 200;
  static const double bottomNavHeight = 64;
  static const double appBarHeight = 56;

  /// Size of the rounded-square icon plate used on empty/error states.
  static const double stateIconPlate = 66;
  static const double avatarSmall = 32;
  static const double avatarMedium = 44;
  static const double avatarLarge = 88;
}
