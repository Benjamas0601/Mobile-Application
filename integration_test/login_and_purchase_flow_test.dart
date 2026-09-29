import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:thai_otop_marketplace/app.dart';
import 'package:thai_otop_marketplace/core/config/firebase_bootstrap.dart';
import 'package:thai_otop_marketplace/core/constants/app_enums.dart';
import 'package:thai_otop_marketplace/core/constants/app_strings.dart';
import 'package:thai_otop_marketplace/core/constants/payment_strings.dart';

/// End-to-end smoke test that drives the real app on an emulator against the
/// real Firebase project (thaiotop-587f1).
///
/// It signs in as the seeded demo customer, verifies the seeded order history
/// renders with the correct timelines, then performs one real purchase from
/// product → cart → checkout → payment and asserts the new order appears.
///
/// Run: flutter test integration_test -d emulator-5554
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 60),
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
    throw StateError('Timed out waiting for $finder');
  }

  testWidgets('customer login → seeded order history → real purchase', (
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

    // --- App boots to the home screen as a guest. ----------------------
    await pumpUntil(tester, find.text(AppStrings.appName));
    await pumpUntil(tester, find.text(AppStrings.login));

    // --- Sign in with the seeded demo customer. ------------------------
    await tester.tap(find.text(AppStrings.login));
    await pumpUntil(tester, find.byType(TextFormField));
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'customer@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'OtopDemo123');
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.login));
    await pumpUntil(tester, find.textContaining('สวัสดี'));

    // --- Seeded order history renders. ----------------------------------
    await tester.tap(find.byTooltip(AppStrings.navOrders));
    await pumpUntil(tester, find.textContaining(AppStrings.orderIdPrefix));

    // Cancelled order explains why it was cancelled.
    await tester.scrollUntilVisible(
      find.textContaining('o-demo-6'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('o-demo-6'));
    await pumpUntil(tester, find.text(PaymentStrings.statusCancelledHint));
    await pumpUntil(tester, find.text(OrderStatus.cancelled.label));
    await tester.tap(find.byType(BackButton));
    await pumpUntil(tester, find.textContaining(AppStrings.orderIdPrefix));

    // Fully-delivered order shows the whole timeline + the tracking number.
    await tester.scrollUntilVisible(
      find.textContaining('o-demo-1'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('o-demo-1'));
    await pumpUntil(tester, find.text(OrderStatus.completed.label));
    await pumpUntil(
      tester,
      find.textContaining(AppStrings.trackingNumberPrefix),
    );
    await tester.tap(find.byType(BackButton));
    await pumpUntil(tester, find.textContaining(AppStrings.orderIdPrefix));
    await tester.tap(find.byType(BackButton));

    // --- One real purchase. ---------------------------------------------
    await tester.scrollUntilVisible(
      find.text('ผ้าไหมแดงลายไทย'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ผ้าไหมแดงลายไทย'));
    await tester.pump(const Duration(milliseconds: 500));
    await pumpUntil(tester, find.text(AppStrings.addToCart));
    await tester.tap(find.text(AppStrings.addToCart));

    // Jump to the cart straight from the confirmation snackbar.
    await pumpUntil(tester, find.text(AppStrings.cart));
    await tester.tap(find.text(AppStrings.cart));
    await pumpUntil(tester, find.text(AppStrings.checkout));
    expect(find.text('ผ้าไหมแดงลายไทย'), findsOneWidget);

    await tester.tap(find.text(AppStrings.checkout));
    await pumpUntil(tester, find.text(AppStrings.goToPayment));
    await tester.enterText(
      find.byType(TextField),
      '99/1 ถนนสาทร กรุงเทพฯ 10120',
    );
    await tester.tap(find.text(AppStrings.goToPayment));

    // Payment screen shows the correct total before confirming.
    await pumpUntil(tester, find.textContaining('1,290'));
    await tester.tap(find.textContaining(AppStrings.confirm));

    // New order lands on its own detail page as pending payment.
    await pumpUntil(tester, find.text(AppStrings.orderDetailTitle));
    await pumpUntil(tester, find.text(OrderStatus.pendingPayment.label));
    await pumpUntil(tester, find.textContaining('99/1 ถนนสาทร'));

    // Remember its id, then use the footer action to reach the history.
    final String newOrderId = tester
        .widgetList<Text>(find.textContaining(AppStrings.orderIdPrefix))
        .first
        .data!
        .split(' ')
        .last;
    await tester.scrollUntilVisible(
      find.text(AppStrings.backToOrders),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.backToOrders));
    // Query snapshots can lag a fresh point-read, so wait for this run's
    // order specifically instead of any `เลขที่` from the stale cache.
    await pumpUntil(tester, find.textContaining(newOrderId));
  });
}
