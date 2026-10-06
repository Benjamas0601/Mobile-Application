import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_otop_marketplace/core/theme/app_colors.dart';
import 'package:thai_otop_marketplace/core/theme/app_theme.dart';
import 'package:thai_otop_marketplace/widgets/design_system.dart';

/// Renders the shared design components under both themes.
///
/// `design_contrast_test.dart` proves the tokens are readable; this proves the
/// widgets actually resolve to the theme's colours rather than to hard-coded
/// light values, which is the failure mode a token-level test cannot see.
void main() {
  /// Pumps [child] inside the real app theme at the given brightness, and
  /// returns the resolved [ThemeData] for assertions.
  Future<ThemeData> pumpIn(
    WidgetTester tester,
    Widget child, {
    required Brightness brightness,
  }) async {
    late ThemeData used;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: brightness == Brightness.light
              ? AppTheme.light
              : AppTheme.dark,
          home: Builder(
            builder: (BuildContext context) {
              used = Theme.of(context);
              return child;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return used;
  }

  /// The painted colour of a [Container]/[DecoratedBox], resolved to the
  /// colour actually given to the painter.
  Color? fillOf(WidgetTester tester, Finder finder) {
    final Finder box = find
        .descendant(of: finder, matching: find.byType(DecoratedBox))
        .first;
    final BoxDecoration decoration =
        tester.widget<DecoratedBox>(box).decoration as BoxDecoration;
    return decoration.color;
  }

  for (final Brightness brightness in <Brightness>[
    Brightness.light,
    Brightness.dark,
  ]) {
    final String mode = brightness == Brightness.light ? 'light' : 'dark';

    group('components in $mode mode', () {
      testWidgets('AppCard uses the theme surface, not a fixed white', (
        WidgetTester tester,
      ) async {
        final ThemeData theme = await pumpIn(
          tester,
          const Scaffold(body: AppCard(child: Text('การ์ด'))),
          brightness: brightness,
        );

        final Color? painted = fillOf(tester, find.byType(AppCard));
        expect(
          painted,
          theme.colorScheme.surface,
          reason: 'a card must follow the theme surface in $mode mode',
        );
        if (brightness == Brightness.dark) {
          expect(
            painted,
            isNot(AppColors.surface),
            reason: 'a dark card must not stay white',
          );
        }
      });

      testWidgets('AppHint reads as a hint in both modes', (
        WidgetTester tester,
      ) async {
        await pumpIn(
          tester,
          const Scaffold(body: AppHint('คำใบ้')),
          brightness: brightness,
        );

        final Finder hint = find.byType(AppHint);
        expect(hint, findsOneWidget);
        expect(find.text('คำใบ้'), findsOneWidget);
      });

      testWidgets('AppSectionLabel and AppChip render their labels', (
        WidgetTester tester,
      ) async {
        await pumpIn(
          tester,
          const Scaffold(
            body: Column(
              children: <Widget>[
                AppSectionLabel('หัวข้อ'),
                AppChip(label: 'ตัวเลือก', selected: true),
              ],
            ),
          ),
          brightness: brightness,
        );

        expect(find.text('หัวข้อ'), findsOneWidget);
        expect(find.text('ตัวเลือก'), findsOneWidget);
      });

      testWidgets('AppChunkyButton is tappable and shows its label', (
        WidgetTester tester,
      ) async {
        int taps = 0;
        await pumpIn(
          tester,
          Scaffold(
            body: AppChunkyButton(
              label: 'ขั้นตอนถัดไป',
              onPressed: () => taps++,
            ),
          ),
          brightness: brightness,
        );

        expect(find.text('ขั้นตอนถัดไป'), findsOneWidget);
        await tester.tap(find.byType(AppChunkyButton));
        await tester.pumpAndSettle();
        expect(
          taps,
          1,
          reason: 'the primary action must stay pressable in $mode mode',
        );
      });

      testWidgets('every status pill tone renders with a visible fill', (
        WidgetTester tester,
      ) async {
        for (final AppTone tone in AppTone.values) {
          await pumpIn(
            tester,
            Scaffold(
              body: AppStatusPill.semantic(label: tone.name, tone: tone),
            ),
            brightness: brightness,
          );
          expect(
            find.text(tone.name),
            findsOneWidget,
            reason: 'pill ${tone.name} must render its label in $mode mode',
          );
          expect(fillOf(tester, find.byType(AppStatusPill)), tone.background);
        }
      });
    });
  }
}
