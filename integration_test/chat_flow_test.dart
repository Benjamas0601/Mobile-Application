import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:thai_otop_marketplace/app.dart';
import 'package:thai_otop_marketplace/core/config/firebase_bootstrap.dart';
import 'package:thai_otop_marketplace/core/constants/app_strings.dart';

/// End-to-end smoke test for the chat feature — drives the real app on an
/// emulator against the real Firebase project (thaiotop-587f1).
///
/// The seeded demo customer opens the seeded room with store-singthai (2
/// messages from `tool/seed_firestore.js`), sends a new line, and sees it
/// bubble up; then the inbox preview is confirmed to carry the new text.
///
/// Requires the seed to have run first:
///   node tool/seed_firestore.js thaiotop-587f1
void main() {
  // ทดสอบแชทปลายทาง: เปิดห้องจากหน้าสินค้า ส่งข้อความ แล้วเห็นข้อความใหม่บนหน้าคุย
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

  Future<void> pumpUntilTrue(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final DateTime end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 250));
      if (condition()) return;
    }
    final List<String> visible = tester
        .widgetList<Text>(find.byType(Text))
        .map((Text t) => t.data ?? '')
        .where((String s) => s.isNotEmpty)
        .toList();
    debugPrint('pumpUntilTrue timeout. Visible text:\n${visible.join('\n')}');
    throw StateError('Timed out waiting for condition');
  }

  testWidgets('customer opens the seeded chat, sends, and the inbox updates', (
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

    // --- Boot, then sign in as the seeded demo customer. ----------------
    await pumpUntil(tester, find.text(AppStrings.appName));
    await pumpUntil(tester, find.text(AppStrings.login));
    await tester.tap(find.text(AppStrings.login));
    await pumpUntil(tester, find.byType(TextFormField));
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'customer@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'OtopDemo123');
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.login));
    await pumpUntil(tester, find.textContaining('สวัสดี'));

    // --- Open a product of store-singthai and tap "ส่งข้อความถึงร้าน". ---
    await tester.scrollUntilVisible(
      find.text('ผ้าไหมแดงลายไทย'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ผ้าไหมแดงลายไทย'));
    await tester.pump(const Duration(milliseconds: 500));
    await pumpUntil(tester, find.text(AppStrings.addToCart));

    await tester.scrollUntilVisible(
      find.text(AppStrings.chatWithSeller),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.chatWithSeller));

    // --- The seeded room opens with its two historical messages. --------
    await pumpUntil(tester, find.byType(TextField));
    await pumpUntil(tester, find.textContaining('เสื้อผ้าไหมแดงลายไทย'));
    await pumpUntil(tester, find.textContaining('จัดส่งได้วันไหนครับ'));

    // --- Send a new line; it must appear as a bubble. --------------------
    final String marker = 'สวัสดีครับ จาก E2E แชท';
    await tester.enterText(find.byType(TextField), marker);
    await tester.pump();
    await tester.tap(
      find.widgetWithIcon(FilledButton, Icons.send_rounded),
    );
    await pumpUntil(tester, find.text(marker));
    // คอมโพเซอร์อาจยังถือข้อความอยู่ชั่วขณะก่อน clear (บับเบิลมาจาก stream
    // ก่อนที่ batch commit จะคืนค่า) — รอจนเหลือ occurrence เดียว = บับเบิล
    await pumpUntilTrue(
      tester,
      () => find.text(marker).evaluate().length == 1,
    );
    expect(find.text(marker), findsOneWidget);

    // --- The buyer inbox (home → chat icon) previews the sent text. ------
    await tester.tap(find.byType(BackButton));
    await pumpUntil(tester, find.text(AppStrings.addToCart));
    await tester.tap(find.byType(BackButton));
    await pumpUntil(tester, find.text(AppStrings.appName));
    await tester.tap(find.byTooltip(AppStrings.chat));
    await pumpUntil(tester, find.textContaining('ชิงไทย ผ้าไหมและของดีล้านนา'));
    await pumpUntil(tester, find.textContaining(marker));
    expect(find.textContaining(marker), findsOneWidget);
  });
}