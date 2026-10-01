import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:thai_otop_marketplace/app.dart';
import 'package:thai_otop_marketplace/core/config/firebase_bootstrap.dart';
import 'package:thai_otop_marketplace/core/constants/app_strings.dart';
import 'package:thai_otop_marketplace/core/utils/formatters.dart';
import 'package:thai_otop_marketplace/widgets/design_system.dart';

/// End-to-end affiliate-console proof against the real Firebase project
/// (thaiotop-587f1): sign in as the seeded demo affiliate, verify the KPI grid
/// matches the seeded links/commissions, create one link, then delete it again.
///
/// The created link is removed at the end, so the run is repeatable and the
/// seeded numbers stay put.
///
/// Run: flutter test integration_test -d emulator-5554
void main() {
  // ทดสอบหน้า Affiliate บน Firestore จริง: ล็อกอิน → ดู KPI → สร้าง/ลบลิงก์
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// The seeded fixture `tool/seed_firestore.js` writes. Hard-coded rather than
  /// recomputed so the test fails loudly if the seed changes underneath it.
  const int seededLinks = 4;
  const int seededClicks = 292; // 148 + 96 + 41 + 7
  const int seededOrders = 3; // cancelled row excluded
  const double seededSales = 4520; // 2230 + 1450 + 840
  const double seededApproved = 184; // 111.5 + 72.5
  const double seededPending = 42;

  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 60),
    String? reason,
  }) async {
    final DateTime end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 250));
      if (finder.evaluate().isNotEmpty) return;
    }
    final List<String> visible = tester
        .widgetList<Text>(find.byType(Text))
        .map((Text t) => t.data ?? '')
        .where((String s) => s.isNotEmpty)
        .toList();
    debugPrint('pumpUntil timeout. Visible text:\n${visible.join('\n')}');
    throw StateError(
      'Timed out waiting for $finder (${reason ?? 'no reason'})',
    );
  }

  /// The dashboard's own scroller.
  ///
  /// A `ListView` builds its `Scrollable` as an *ancestor*, so a
  /// descendant-of-ListView lookup finds nothing and `scrollUntilVisible`
  /// throws "Bad state: No element".
  /// Drags the dashboard list until [finder] is built, in whichever direction it
  /// happens to lie.
  ///
  /// `scrollUntilVisible` is not usable here: it only ever drags one way, so a
  /// target already *above* the viewport — which is the case after scrolling down
  /// to the commission table — is never reached. Dragging the ListView directly
  /// also sidesteps the `Scrollable`-not-under-ListView tree shape.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    const Offset down = Offset(0, 400);
    const Offset up = Offset(0, -400);

    Finder dashboardList() => find.byType(ListView).first;

    // Rewind to the top first, so the sweep below is deterministic whichever
    // direction the previous step left the page in.
    for (int i = 0; i < 12 && finder.evaluate().isEmpty; i++) {
      if (dashboardList().evaluate().isEmpty) break;
      await tester.drag(dashboardList(), down);
      await tester.pumpAndSettle();
    }
    for (int i = 0; i < 12 && finder.evaluate().isEmpty; i++) {
      if (dashboardList().evaluate().isEmpty) break;
      await tester.drag(dashboardList(), up);
      await tester.pumpAndSettle();
    }

    if (finder.evaluate().isEmpty) {
      throw StateError(
        'Could not scroll to $finder. Visible text:\n'
        '${tester.widgetList<Text>(find.byType(Text)).map((Text t) => t.data ?? '').where((String s) => s.isNotEmpty).join('\n')}',
      );
    }
  }

  testWidgets('affiliate signs in, sees real KPIs, creates and deletes a link', (
    WidgetTester tester,
  ) async {
    final FirebaseStartupResult startup = await FirebaseBootstrap.start();
    await tester.pumpWidget(
      ProviderScope(
        child: ThaiOtopApp(
          startup: Future<FirebaseStartupResult>.value(startup),
        ),
      ),
    );

    // --- Sign in as the seeded demo affiliate. ---------------------------
    await pumpUntil(tester, find.text(AppStrings.appName));
    await pumpUntil(tester, find.text(AppStrings.login));
    await tester.tap(find.text(AppStrings.login));
    await pumpUntil(tester, find.byType(TextFormField));
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'affiliate@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'OtopDemo123');
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.login));

    // An affiliate-only account is redirected to /affiliate, so the dashboard
    // is the landing screen — there is no home hop to perform first.
    await pumpUntil(
      tester,
      find.text(AppStrings.navAffiliateDashboard),
      reason: 'an affiliate lands on their own dashboard',
    );

    // --- The KPI grid matches the seeded rows. ----------------------------
    await pumpUntil(
      tester,
      find.text('ยอดขายที่ลิงก์ของคุณทำให้เกิด ${Fmt.price(seededSales)}'),
      reason: 'the sales line is computed from the affiliate_commissions rows',
    );
    expect(
      find.text('ยอดขายที่ลิงก์ของคุณทำให้เกิด ${Fmt.price(seededSales)}'),
      findsOneWidget,
    );
    // Clicks come from summing the link counters, and the caption restates the
    // order count so a mismatched pair is visible on screen.
    expect(find.text(Fmt.compactCount(seededClicks)), findsWidgets);
    expect(
      find.textContaining('$seededOrders จากคลิก $seededClicks'),
      findsOneWidget,
    );
    expect(find.text(Fmt.price(seededApproved)), findsWidgets);
    expect(
      find.text(
        'อนุมัติ ${Fmt.price(seededApproved)} · รอ ${Fmt.price(seededPending)}',
      ),
      findsOneWidget,
    );

    // --- The seeded links are listed, best-performing first. -------------
    await scrollTo(tester, find.text('ลิงก์ของฉัน · $seededLinks ลิงก์'));
    expect(find.text('ลิงก์ของฉัน · $seededLinks ลิงก์'), findsOneWidget);

    // The highest-click link leads the list; its counter is on the tile.
    await scrollTo(tester, find.text('148'));
    expect(find.text('148'), findsOneWidget);

    // --- Commissions render with their Thai status labels. ----------------
    await scrollTo(tester, find.text('รอตรวจสอบ'));
    expect(find.text('รอตรวจสอบ'), findsOneWidget);

    // --- Create one link, the write the rules allow an affiliate. ---------
    await scrollTo(tester, find.text('สร้างลิงก์'));
    await tester.tap(find.text('สร้างลิงก์'));
    await pumpUntil(tester, find.text('เลือกสินค้าที่จะโปรโมต'));
    await pumpUntil(tester, find.byType(ListTile));

    // Remember which product was picked: the list is sorted by clicks, so a
    // fresh zero-click link cannot be found by position afterwards.
    final String pickedProduct =
        (tester.widget<ListTile>(find.byType(ListTile).first).title! as Text)
            .data!;
    await tester.tap(find.byType(ListTile).first);
    await pumpUntil(tester, find.text('สร้างลิงก์เรียบร้อยแล้ว'));

    // The new link raises the count by one — proof the create passed the rules.
    await scrollTo(tester, find.text('ลิงก์ของฉัน · ${seededLinks + 1} ลิงก์'));
    expect(find.text('ลิงก์ของฉัน · ${seededLinks + 1} ลิงก์'), findsOneWidget);
    await scrollTo(tester, find.text(pickedProduct));
    expect(find.text(pickedProduct), findsWidgets);

    // --- Delete it again so the seeded fixture stays untouched. ----------
    // `AppCard`, not `Card`: the link tile is built from the design-system
    // container, which is not a Material `Card`. `ensureVisible` first, because
    // the row can be built just off the fold and a tap there hits nothing.
    final Finder deleteButton = find.descendant(
      of: find.ancestor(
        of: find.text(pickedProduct),
        matching: find.byType(AppCard),
      ),
      matching: find.byTooltip('ลบลิงก์'),
    );
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await pumpUntil(tester, find.text('ลบลิงก์นี้?'));
    await tester.tap(find.widgetWithText(FilledButton, 'ลบ'));
    await pumpUntil(tester, find.text('ลิงก์ของฉัน · $seededLinks ลิงก์'));
    expect(find.text(pickedProduct), findsNothing);
  });
}
