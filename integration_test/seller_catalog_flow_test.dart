import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:thai_otop_marketplace/app.dart';
import 'package:thai_otop_marketplace/core/config/firebase_bootstrap.dart';
import 'package:thai_otop_marketplace/core/constants/app_strings.dart';

/// End-to-end seller-console proof against the real Firebase project
/// (thaiotop-587f1): create a product with a variant, edit its price, then
/// delete it — exactly the writes `firestore.rules` constrains to the owner.
///
/// The created product is removed at the end, so the run is repeatable.
///
/// Run: flutter test integration_test -d emulator-5554
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
    final List<String> fieldValues = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .map((EditableText e) => e.controller.value.text)
        .where((String s) => s.isNotEmpty)
        .toList();
    debugPrint('pumpUntil timeout. Visible text:\n${visible.join('\n')}');
    debugPrint('pumpUntil timeout. FIELD VALUES:\n${fieldValues.join('\n')}');
    throw StateError(
      'Timed out waiting for $finder (${reason ?? 'no reason'})',
    );
  }

  Future<void> pumpUntilGone(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final DateTime end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 250));
      if (finder.evaluate().isEmpty) return;
    }
    throw StateError('Still visible: $finder');
  }

  Future<bool> probeVisible(
    WidgetTester tester,
    Finder finder,
    int seconds,
  ) async {
    final DateTime end = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 250));
      if (finder.evaluate().isNotEmpty) return true;
    }
    return false;
  }

  Future<void> dismissKeyboard(WidgetTester tester) async {
    tester.binding.focusManager.primaryFocus?.unfocus();
    final DateTime end = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      final double bottom =
          MediaQuery.maybeOf(
            tester.element(find.byType(Scaffold).first),
          )?.viewInsets.bottom ??
          0;
      if (bottom == 0) return;
    }
    debugPrint(
      'dismissKeyboard: MediaQuery insets still up: '
      '${MediaQuery.maybeOf(tester.element(find.byType(Scaffold).first))?.viewInsets}',
    );
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(finder, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 150));
  }

  testWidgets('seller creates, edits and deletes a product', (
    WidgetTester tester,
  ) async {
    final String productName =
        'ผ้าไหมเทสต์ ${DateTime.now().millisecondsSinceEpoch}';

    final FirebaseStartupResult startup = await FirebaseBootstrap.start();
    await tester.pumpWidget(
      ProviderScope(
        child: ThaiOtopApp(
          startup: Future<FirebaseStartupResult>.value(startup),
        ),
      ),
    );

    // --- Sign in as the seeded seller. ----------------------------------
    await pumpUntil(tester, find.text(AppStrings.appName));
    await pumpUntil(tester, find.text(AppStrings.login));
    await tester.tap(find.text(AppStrings.login));
    await pumpUntil(tester, find.byType(TextFormField));
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'seller.north@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'OtopDemo123');
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.login));
    await pumpUntil(tester, find.textContaining('สวัสดี'));

    // --- Land on the seller console. -------------------------------------
    // Signing in as a seller redirects straight to /seller, so there is no
    // home-screen hop to do. The hub is store-scoped: its body only exists
    // once this seller's own store has resolved.
    await pumpUntil(tester, find.text(AppStrings.navSellerDashboard));
    await pumpUntil(tester, find.byType(CustomScrollView));
    // The quick actions sit below the KPI grid, so they may not be laid out
    // until the page scrolls.
    await tester.scrollUntilVisible(
      find.text(AppStrings.sellerAddProduct),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    // --- Create a product with one variant. -----------------------------
    await tester.tap(find.text(AppStrings.sellerAddProduct));
    await pumpUntil(tester, find.text(AppStrings.productNameLabel));

    await tester.enterText(find.byType(TextFormField).at(0), productName);
    await tester.enterText(find.byType(TextFormField).at(2), '1290');

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await pumpUntil(tester, find.byType(DropdownMenuItem<String>).last);
    await tester.tap(find.byType(DropdownMenuItem<String>).last);
    await tester.pumpAndSettle();

    // One variant with stock, so the sold-as-sum stockTotal has a real row.
    final Finder pageScroller = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text(AppStrings.addVariant),
      300,
      scrollable: pageScroller,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.addVariant));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (Widget w) =>
            w is TextField &&
            w.decoration?.labelText == AppStrings.variantStockHint,
      ),
      '3',
    );

    await dismissKeyboard(tester);
    await tapAndSettle(tester, find.text(AppStrings.sellerAddProduct));
    if (!(await probeVisible(tester, find.text(AppStrings.productSaved), 8))) {
      await tapAndSettle(tester, find.text(AppStrings.sellerAddProduct));
    }
    await pumpUntil(tester, find.text(AppStrings.productSaved));

    // Saving pops the form back to wherever it was opened from — here the hub,
    // not a product list — so the new row has to be reached deliberately.
    // Its presence is the proof that the create passed the security rules.
    await pumpUntilGone(tester, find.text(AppStrings.productSaved));
    // Back on the hub again, so the products shortcut has to be scrolled to
    // before it can be tapped.
    await tester.scrollUntilVisible(
      find.text(AppStrings.navSellerProducts),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tapAndSettle(tester, find.text(AppStrings.navSellerProducts));
    await pumpUntil(tester, find.text(productName));

    // --- Edit its price. --------------------------------------------------
    await tester.tap(find.text(productName));
    await pumpUntil(tester, find.text(AppStrings.productNameLabel));

    // The form is controller-driven, so match on the controller text rather
    // than on a field's position in the tree, which shifts with the layout.
    Finder fieldWith(String value) => find.byWidgetPredicate(
      (Widget w) => w is EditableText && w.controller.value.text == value,
    );
    await pumpUntil(
      tester,
      fieldWith(productName),
      reason: 'the saved name must arrive in the name field',
    );
    await pumpUntil(
      tester,
      fieldWith('1290'),
      reason: 'the saved price must arrive in the price field',
    );
    // In edit mode the save button reads "บันทึก <ชื่อร้าน>", so match on the
    // prefix and scope it to the button — a bare text match would also catch
    // the "บันทึกสินค้าแล้ว" snackbar.
    Finder saveButton() => find.descendant(
      of: find.byType(FilledButton),
      matching: find.textContaining(AppStrings.save),
    );

    await tester.enterText(fieldWith('1290'), '1990');
    await dismissKeyboard(tester);
    await tapAndSettle(tester, saveButton());
    if (!(await probeVisible(tester, find.text(AppStrings.productSaved), 8))) {
      await tapAndSettle(tester, saveButton());
    }
    await pumpUntil(tester, find.text(AppStrings.productSaved));
    await pumpUntil(tester, find.text(productName));
    await pumpUntilGone(tester, find.text(AppStrings.productSaved));
    // The updated price is on the row now.
    await pumpUntil(tester, find.textContaining('1,990'));
    expect(find.text(productName), findsOneWidget);

    // --- Delete it again so the seeded catalogue stays untouched. --------
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, productName),
        matching: find.byTooltip(AppStrings.delete),
      ),
    );
    await pumpUntil(tester, find.text(AppStrings.deleteProductConfirm));
    await tester.tap(find.text(AppStrings.delete));
    await pumpUntil(tester, find.text(AppStrings.productDeleted));
    await pumpUntilGone(tester, find.text(productName));
  });
}
