import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles the Material [ThemeData] from the design tokens.
///
/// Two themes are provided: light (default) and dark. Dark is not cosmetic —
/// product photos are shot on white, so the dark theme uses a warm charcoal
/// rather than pure black to avoid harsh contrast against those images.
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
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.accent,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.accentLight,
      onSecondaryContainer: AppColors.ink,
      tertiary: AppColors.clay,
      onTertiary: AppColors.onPrimary,
      tertiaryContainer: AppColors.clayLight,
      onTertiaryContainer: AppColors.clay,
      error: AppColors.danger,
      onError: AppColors.onPrimary,
      errorContainer: AppColors.dangerLight,
      onErrorContainer: AppColors.danger,
      surface: isDark ? AppColors.surfaceMuted : AppColors.surface,
      onSurface: isDark ? AppColors.background : AppColors.ink,
      surfaceContainerHighest: isDark
          ? AppColors.border
          : AppColors.surfaceMuted,
      onSurfaceVariant: AppColors.inkMuted,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.border,
    );

    final TextTheme text = _textTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? AppColors.surfaceMuted
          : AppColors.background,
      textTheme: text,
      fontFamily: kAppFontFamily.isEmpty ? null : kAppFontFamily,

      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.surfaceMuted : AppColors.background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
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
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: text.labelLarge,
          side: BorderSide(color: scheme.outline),
          foregroundColor: scheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minTapTarget),
          textStyle: text.labelLarge,
          foregroundColor: AppColors.primary,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surface : AppColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
        labelStyle: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
        hintStyle: text.bodyMedium?.copyWith(color: AppColors.inkSubtle),
        // Errors are announced by screen readers, so keep them visible and
        // never rely on colour alone.
        errorStyle: text.bodySmall?.copyWith(color: AppColors.danger),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceMuted,
        selectedColor: AppColors.primaryLight,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: text.labelMedium!,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillRadius),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: AppSizes.bottomNavHeight,
        backgroundColor: scheme.surface,
        indicatorColor: AppColors.primaryLight,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? text.labelSmall?.copyWith(
                  color: AppColors.primary,
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

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: AppColors.background,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),

      // Respect the OS "reduce motion" accessibility switch.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    // Re-colour the ink tokens when the dark theme is active so text keeps
    // its hierarchy instead of turning into flat black-on-black.
    final Color ink = scheme.onSurface;
    final Color muted = isLight(scheme)
        ? AppColors.inkMuted
        : AppColors.inkSubtle;

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
