import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles the Material [ThemeData] from the design tokens.
///
/// Two themes are provided: light (default) and dark. Dark is not cosmetic —
/// product photos are shot on white, so the dark theme uses a deep indigo
/// rather than pure black to avoid harsh contrast against those images.
/// ประกอบ ThemeData จากสี ระยะห่าง และรูปแบบตัวอักษรของแอป
class AppTheme {
  AppTheme._();

  static const String fontFamilyFallbackNote =
      'Thai text uses the platform Thai font. See AppTextStyles.';

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: isDark
          ? AppColors.darkSurfaceMuted
          : AppColors.primaryLight,
      onPrimaryContainer: isDark ? AppColors.darkInk : AppColors.primaryDark,
      secondary: AppColors.accent,
      onSecondary: isDark ? AppColors.primaryDark : AppColors.ink,
      secondaryContainer: AppColors.accentLight,
      onSecondaryContainer: AppColors.accentDark,
      tertiary: AppColors.clay,
      onTertiary: AppColors.onPrimary,
      tertiaryContainer: AppColors.clayLight,
      onTertiaryContainer: AppColors.clayDark,
      error: AppColors.danger,
      onError: AppColors.onPrimary,
      errorContainer: AppColors.dangerLight,
      onErrorContainer: AppColors.clayDark,
      surface: isDark ? AppColors.darkSurface : AppColors.surface,
      onSurface: isDark ? AppColors.darkInk : AppColors.ink,
      surfaceContainerHighest: isDark
          ? AppColors.darkSurfaceMuted
          : AppColors.surfaceMuted,
      onSurfaceVariant: isDark ? AppColors.darkInkMuted : AppColors.inkMuted,
      outline: isDark ? AppColors.darkBorder : AppColors.border,
      outlineVariant: isDark ? AppColors.darkBorder : AppColors.border,
    );

    final TextTheme text = _textTheme(scheme);

    // The chunky button is the design's signature control: a solid fill with a
    // hard 4-5px "shadow" edge that collapses when pressed. It is expressed as
    // one reusable widget (AppChunkyButton) rather than a theme style, because
    // the shadow has to animate with the press state.
    final OutlineInputBorder inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.chunky),
      borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.background,
      textTheme: text,
      fontFamily: kAppFontFamily.isEmpty ? null : kAppFontFamily,

      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? AppColors.darkBackground
            : AppColors.background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleSpacing: AppSpacing.gutter,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.chunky),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: text.labelLarge,
          side: BorderSide(color: scheme.primary, width: 1.5),
          foregroundColor: scheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.chunky),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minTapTarget),
          textStyle: text.labelLarge,
          foregroundColor: scheme.primary,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
        ),
        labelStyle: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
        hintStyle: text.bodyMedium?.copyWith(color: AppColors.inkSubtle),
        // Errors are announced by screen readers, so keep them visible and
        // never rely on colour alone.
        errorStyle: text.bodySmall?.copyWith(color: AppColors.danger),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? AppColors.darkSurfaceMuted
            : AppColors.surface,
        selectedColor: AppColors.primary,
        side: BorderSide(color: scheme.outlineVariant, width: 1.5),
        labelStyle: text.labelMedium!,
        secondaryLabelStyle: text.labelMedium!.copyWith(
          color: AppColors.onPrimary,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.chunky)),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: AppSizes.bottomNavHeight,
        backgroundColor: scheme.surface,
        indicatorColor: isDark
            ? AppColors.darkSurfaceMuted
            : AppColors.primaryLight,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? text.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                )
              : text.labelSmall,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheetRadius),
        showDragHandle: true,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryDark,
        contentTextStyle: text.bodyMedium?.copyWith(color: AppColors.onPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chunky),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),

      // Respect the OS "reduce motion" accessibility switch.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: const <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    // Re-colour the ink tokens when the dark theme is active so text keeps
    // its hierarchy instead of turning into flat black-on-black.
    final bool isLight = scheme.brightness == Brightness.light;
    final Color ink = scheme.onSurface;
    final Color muted = isLight ? AppColors.inkMuted : AppColors.darkInkMuted;

    return TextTheme(
      displayLarge: AppTextStyles.displayLarge.copyWith(color: ink),
      displayMedium: AppTextStyles.displayMedium.copyWith(color: ink),
      headlineLarge: AppTextStyles.headlineLarge.copyWith(color: ink),
      headlineMedium: AppTextStyles.headlineMedium.copyWith(color: ink),
      headlineSmall: AppTextStyles.headlineSmall.copyWith(color: ink),
      titleLarge: AppTextStyles.headlineSmall.copyWith(color: ink),
      titleMedium: AppTextStyles.labelLarge.copyWith(color: ink),
      titleSmall: AppTextStyles.labelMedium.copyWith(color: ink),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(color: ink),
      bodyMedium: AppTextStyles.bodyMedium.copyWith(color: ink),
      bodySmall: AppTextStyles.bodySmall.copyWith(color: muted),
      labelLarge: AppTextStyles.labelLarge.copyWith(color: ink),
      labelMedium: AppTextStyles.labelMedium.copyWith(color: muted),
      labelSmall: AppTextStyles.labelSmall.copyWith(color: muted),
    );
  }

  static bool isLight(ColorScheme scheme) =>
      scheme.brightness == Brightness.light;
}
