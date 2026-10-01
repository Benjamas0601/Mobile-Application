import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_otop_marketplace/core/theme/app_colors.dart';
import 'package:thai_otop_marketplace/core/theme/app_theme.dart';
import 'package:thai_otop_marketplace/widgets/design_system.dart';

/// Contrast and dark-mode checks for the HTML design pass.
///
/// The design work cannot be eyeballed in CI, so the parts of "it looks
/// right" that are actually decidable are asserted here instead: every
/// colour pair the shared components rely on has to clear WCAG AA on its
/// background, in both themes, and the theme has to actually switch rather
/// than silently reusing the light palette.
void main() {
  /// Relative luminance, per WCAG 2.x.
  double luminance(Color c) {
    double channel(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  double contrast(Color a, Color b) {
    final double la = luminance(a);
    final double lb = luminance(b);
    final double hi = math.max(la, lb);
    final double lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  // WCAG AA: 4.5 for body text, 3.0 for large text (18.66px bold or 24px).
  void expectReadable(String what, Color fg, Color bg, {bool large = false}) {
    final double ratio = contrast(fg, bg);
    final double min = large ? 3.0 : 4.5;
    expect(
      ratio,
      greaterThanOrEqualTo(min),
      reason:
          '$what contrast ${ratio.toStringAsFixed(2)} < $min '
          '(fg ${fg.toARGB32().toRadixString(16)} on bg '
          '${bg.toARGB32().toRadixString(16)})',
    );
  }

  group('theme switches', () {
    test('light and dark are genuinely different themes', () {
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(
        AppTheme.light.scaffoldBackgroundColor,
        isNot(AppTheme.dark.scaffoldBackgroundColor),
      );
      expect(
        AppTheme.light.colorScheme.onSurface,
        isNot(AppTheme.dark.colorScheme.onSurface),
      );
    });

    test('the dark background is actually dark, and the light one is not', () {
      expect(
        luminance(AppTheme.dark.scaffoldBackgroundColor),
        lessThan(0.05),
        reason: 'a dark theme must not render a near-white scaffold',
      );
      expect(
        luminance(AppTheme.light.scaffoldBackgroundColor),
        greaterThan(0.6),
      );
    });

    test('both themes keep the design\'s primary hue', () {
      // The HTML is built around indigo; a theme that drifts off-hue in dark
      // mode reads as a different product.
      expect(AppTheme.light.colorScheme.primary, AppColors.primary);
      expect(AppTheme.dark.colorScheme.primary, AppColors.primary);
    });
  });

  group('theme contrast in both modes', () {
    for (final (String label, ThemeData theme) in <(String, ThemeData)>[
      ('light', AppTheme.light),
      ('dark', AppTheme.dark),
    ]) {
      group(label, () {
        final Color bg = theme.scaffoldBackgroundColor;
        final Color surface = theme.colorScheme.surface;
        final ColorScheme scheme = theme.colorScheme;

        test('body text on the scaffold and on cards is readable', () {
          expectReadable('$label onSurface/scaffold', scheme.onSurface, bg);
          expectReadable('$label onSurface/card', scheme.onSurface, surface);
        });

        test('muted text stays readable on both backgrounds', () {
          expectReadable(
            '$label onSurfaceVariant/scaffold',
            scheme.onSurfaceVariant,
            bg,
          );
          expectReadable(
            '$label onSurfaceVariant/card',
            scheme.onSurfaceVariant,
            surface,
          );
        });

        test('text on primary and on accent is readable', () {
          expectReadable(
            '$label onPrimary/primary',
            scheme.onPrimary,
            scheme.primary,
          );
          // Turmeric is deliberately light, so it carries ink in both themes
          // rather than white — that pairing is the one the button uses.
          expectReadable(
            '$label onSecondary/accent',
            scheme.onSecondary,
            scheme.secondary,
          );
        });

        test('error state is readable', () {
          expectReadable('$label onError/error', scheme.onError, scheme.error);
        });

        test('every status pill tone is readable on its own fill', () {
          // AppStatusPill.semantic always paints its own background, so the
          // meaningful pair is foreground-on-fill, not foreground-on-scaffold.
          for (final AppTone tone in AppTone.values) {
            expectReadable(
              '$label pill ${tone.name}',
              tone.foreground,
              tone.background,
            );
          }
        });

        test('borders are visible against the surface', () {
          // A border that vanishes makes a card read as a floating blob.
          expect(
            contrast(theme.dividerColor, bg),
            greaterThan(1.2),
            reason: '$label dividers must be perceptible',
          );
        });
      });
    }
  });

  group('hard-coded colour audit', () {
    test('AppColors exposes a dark variant for every surface colour', () {
      // A light-only token set is how dark mode quietly ends up with white
      // cards on a dark scaffold, so the presence of the counterparts is
      // asserted directly.
      expect(AppColors.darkBackground, isNot(AppColors.background));
      expect(AppColors.darkSurface, isNot(AppColors.surface));
      expect(AppColors.darkSurfaceMuted, isNot(AppColors.surfaceMuted));
    });

    test('ink tokens are all dark, i.e. light-mode text', () {
      for (final (String name, Color c) in <(String, Color)>[
        ('ink', AppColors.ink),
        ('inkMuted', AppColors.inkMuted),
        ('inkBody', AppColors.inkBody),
      ]) {
        expect(
          luminance(c),
          lessThan(0.2),
          reason: '$name is a light-theme token',
        );
      }
    });
  });
}
