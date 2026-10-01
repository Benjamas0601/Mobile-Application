import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:thai_otop_marketplace/app.dart';
import 'package:thai_otop_marketplace/core/config/firebase_bootstrap.dart';
import 'package:thai_otop_marketplace/core/constants/app_strings.dart';
import 'package:thai_otop_marketplace/widgets/design_system.dart';

/// End-to-end seller-console proof against the real Firebase project
/// (thaiotop-587f1): create a product with a variant, edit its price, then
/// delete it — exactly the writes `firestore.rules` constrains to the owner.
///
/// The created product is removed at the end, so the run is repeatable.
///
/// Run: flutter test integration_test -d emulator-5554
void main() {
  // ทดสอบ CRUD สินค้าบน emulator และลบข้อมูลที่สร้างท้ายการทดสอบ
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
    await pumpUntil(tester, find.byType(ListView));
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

    // The editor is a four-step wizard, so the create is driven the same way a
    // seller would: basics -> images -> variants -> story -> publish. Only the
    // basics step is validated by index; later steps are addressed by label.
    await tester.enterText(find.byType(TextFormField).at(0), productName);
    await tester.enterText(find.byType(TextFormField).at(1), '1290');

    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    // Tap the menu entry by its rendered label rather than by type: the
    // dropdown route is an overlay, and addressing the route's own item widget
    // can resolve to a node that is no longer hit-testable by the time the tap
    // is dispatched.
    await pumpUntil(tester, find.byType(DropdownMenuItem<String>).last);
    final String categoryLabel = tester
        .widget<Text>(
          find
              .descendant(
                of: find.byType(DropdownMenuItem<String>).last,
                matching: find.byType(Text),
              )
              .first,
        )
        .data!;
    await tester.tap(find.text(categoryLabel).last);
    await tester.pumpAndSettle();

    // --- Step 2: images. Publishing needs at least one, and there is no
    // camera in a test, so add one by URL.
    await tapAndSettle(tester, find.text('ขั้นตอนถัดไป'));
    final Finder imageChip = find.ancestor(
      of: find.text('เพิ่มรูป'),
      matching: find.byType(AppChip),
    );
    await tester.tap(imageChip);
    await pumpUntil(tester, find.text(AppStrings.addImageByUrl));
    await tapAndSettle(tester, find.text(AppStrings.addImageByUrl));
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.imageUrlHint),
      'https://res.cloudinary.com/demo/image/upload/sample.jpg',
    );
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(AppStrings.addImage),
      ),
    );

    // --- Step 3: one variant with stock, so the sold-as-sum stockTotal has a
    // real row. Stock is a stepper here, not a text field.
    await tapAndSettle(tester, find.text('ขั้นตอนถัดไป'));
    await tester.ensureVisible(find.text(AppStrings.addVariant));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.addVariant));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (Widget w) =>
            w is TextField &&
            w.decoration?.hintText == AppStrings.variantNameExample,
      ),
      'แพ็คขวด',
    );
    final Finder stockUp = find.byKey(const ValueKey<String>('stock-up-0'));
    for (int i = 0; i < 3; i++) {
      await tester.tap(stockUp);
      await tester.pumpAndSettle();
    }

    // --- Step 4: story, then publish.
    await tapAndSettle(tester, find.text('ขั้นตอนถัดไป'));
    await tapAndSettle(tester, find.text(AppStrings.save));
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
    // Edit the price while it is still mounted — only the visible step is built,
    // so walking forward first would unmount the basics fields.
    await tester.enterText(fieldWith('1290'), '1990');
    await dismissKeyboard(tester);

    // The editor opens on the basics step even in edit mode, so the save lives
    // on the last step: walk to the end, then save. The saved product already
    // has its image and variants, so the later gates pass without touching
    // them.
    for (int i = 0; i < 3; i++) {
      await tapAndSettle(tester, find.text('ขั้นตอนถัดไป'));
    }

    await tapAndSettle(tester, find.text(AppStrings.save));
    if (!(await probeVisible(tester, find.text(AppStrings.productSaved), 8))) {
      await tapAndSettle(tester, find.text(AppStrings.save));
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
