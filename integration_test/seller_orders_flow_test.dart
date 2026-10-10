import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:thai_otop_marketplace/app.dart';
import 'package:thai_otop_marketplace/core/config/firebase_bootstrap.dart';
import 'package:thai_otop_marketplace/core/constants/app_strings.dart';

/// หลักฐาน End-to-end จริงบนโปรเจกต์ Firebase (thaiotop-587f1) สำหรับกล่อง
/// ข้อความของผู้ขายและโปรไฟล์ร้าน:
///   1. เลื่อน seeded `o-demo-3` (awaiting_shipment) ไปเป็น shipped พร้อมพิมพ์
///      เลขพัสดุที่กฎอนุญาตให้ผู้ขายกรอกเอง
///   2. แก้คำอธิบายร้านแล้วกลับเข้าหน้าใหม่เพื่อพิสูจน์ว่าข้อมูลเขียนลง Firestore
///      จริง ไม่ใช่แค่บนหน้าจอ
///
/// การเลื่อนสถานะออเดอร์เป็นการแก้ข้อมูล demo ใน seed อย่างตั้งใจ — ฉะนั้น
/// ก่อนรันควร `node tool/seed_firestore.js thaiotop-587f1` เสมอ (ทั้งรันเทสต์
/// เดี่ยวและรัน suite integration_test ทั้งหมด) เพื่อให้ o-demo-3 กลับมาเป็น
/// awaiting_shipment ตามเดิม
///
/// รัน: flutter test integration_test -d emulator-5554
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
    debugPrint('pumpUntil timeout. Visible text:\n${visible.join('\n')}');
    throw StateError(
      'Timed out waiting for $finder (${reason ?? 'no reason'})',
    );
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
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    final DateTime end = DateTime.now().add(const Duration(seconds: 20));
    while (finder.evaluate().isEmpty && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(finder, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 150));
  }

  // ย้อนกลับผ่านปุ่ม BackButton ของ AppBar (tooltip เป็นภาษาไทยจึงไม่มีอะไร
    // ตรงกับ "Back") — คอยจนปุ่มโผล่ แล้วค่อยถอยมาที่ระบบ back ของ Android
    // เฉพาะเมื่อปุ่มไม่เคยถูก render เลย
  Future<void> goBack(WidgetTester tester) async {
    final DateTime end = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(end)) {
      final Finder back = find.byType(BackButton);
      if (back.evaluate().isNotEmpty) {
        await tester.tap(back.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 300));
        return;
      }
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
  }

  // ลากจน [finder] อยู่ในจอ โดยรอให้มี vertical Scrollable ก่อน — ไม่กี่เฟรม
  // ที่ Scrollable ว่างอาจเกิดสลับตอนเปลี่ยน route ได้ เลยวนรอแทนการเก็บ
  // `.last` ขณะที่ยังไม่มี; `dragUntilVisible` จะลากซ้ำไปเรื่อย ๆ จนลูกที่อยู่
  // นอกจอ (lazy build) โผล่ขึ้นมาเอง
  Future<void> scrollToVisible(WidgetTester tester, Finder finder) async {
    final DateTime end = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(end)) {
      final Finder scrollable = find
          .byWidgetPredicate(
            (Widget w) =>
                w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first;
      if (scrollable.evaluate().isNotEmpty) {
        await tester.dragUntilVisible(
          finder,
          scrollable,
          const Offset(0, -200),
        );
        await tester.pump(const Duration(milliseconds: 200));
        return;
      }
      await tester.pump(const Duration(milliseconds: 200));
    }
    await pumpUntil(tester, finder, reason: 'scrollToVisible ยังไม่เจอเป้า');
  }

  // หาช่องกรอกโดยดูข้อความที่โหลดอยู่ใน controller (ทนต่อการเลื่อน layout
  // ระหว่างฟอร์ม) — ไม่พึ่ง index ที่ตำแหน่งอาจคลาดเคลื่อน
  Finder fieldWith(String value) => find.byWidgetPredicate(
    (Widget w) => w is EditableText && w.controller.value.text == value,
  );

  testWidgets('seller advances an order with tracking and edits the store', (
    WidgetTester tester,
  ) async {
    final String suffix =
        'E2E${DateTime.now().millisecondsSinceEpoch}';
    final String newDescription =
        'เกี่ยวกับร้าน แก้โดยเทสต์ $suffix';

    final FirebaseStartupResult startup = await FirebaseBootstrap.start();
    await tester.pumpWidget(
      ProviderScope(
        child: ThaiOtopApp(
          startup: Future<FirebaseStartupResult>.value(startup),
        ),
      ),
    );

    // --- เข้าสู่ระบบด้วยผู้ขาย seed (เจ้าของ store-singthai) -------------
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

    // --- กล่องข้อความ: เลื่อน o-demo-3 (awaiting_shipment) ไปเป็น shipped -
    await pumpUntil(tester, find.text(AppStrings.navSellerDashboard));
    await tapAndSettle(tester, find.text(AppStrings.navSellerOrders));

    // มีการ์ดเดียวที่เดินสถานะเป็น shipped: o-demo-3 คือออเดอร์ awaiting_shipment
    // เพียงรายเดียวของ store-singthai ใน seed. กรองสถานะนี้ก่อน เพื่อให้หา row
    // เจอโดยไม่ต้องเลื่อนผ่านออเดอร์ E2E เก่า
    await tapAndSettle(tester, find.text('รอจัดส่ง'));
    await pumpUntil(
      tester,
      find.text('${AppStrings.orderIdPrefix} o-demo-3'),
      reason: 'ยังไม่เจอออเดอร์ awaiting_shipment จาก seed',
    );
    final Finder shipButton = find.widgetWithText(
      FilledButton,
      FmtLike.advanceTo('จัดส่งแล้ว'),
    );
    await pumpUntil(
      tester,
      shipButton,
      reason: 'ยังไม่เจอปุ่มเลื่อนสถานะเป็น จัดส่งแล้ว',
    );
    await tapAndSettle(tester, shipButton);

    // หน้าต่างกรอกเลขพัสดุ แล้วกดยืนยัน
    await pumpUntil(tester, find.text(AppStrings.sellerShipTrackingTitle));
    await tester.enterText(
      find.byType(TextField).last,
      'POST-$suffix',
    );
    await dismissKeyboard(tester);
    await tapAndSettle(
      tester,
      find.text(AppStrings.sellerShipConfirm),
    );
    await pumpUntil(
      tester,
      find.textContaining('จัดส่งแล้ว'),
      reason: 'ยังไม่เจอ snackbar ยืนยันการเปลี่ยนสถานะ',
    );

    // ออเดอร์เพิ่งหลุดออกจาก filter "รอจัดส่ง" (กลายเป็น จัดส่งแล้ว) — สลับไป
    // filter "จัดส่งแล้ว" ให้การ์ดโหลดใหม่ แล้วยืนยันว่าเลขพัสดุถูกเขียนจริง
    await tapAndSettle(tester, find.text('จัดส่งแล้ว'));
    await pumpUntil(
      tester,
      find.text('${AppStrings.trackingNumberPrefix} POST-$suffix'),
      reason: 'ยังไม่เจอเลขพัสดุที่บันทึกบนการ์ด',
    );

// --- โปรไฟล์ร้าน: แก้คำอธิบาย บันทึก แล้วกลับเข้าดูอีกครั้ง ----------
    await goBack(tester);
    await pumpUntil(tester, find.text(AppStrings.navSellerDashboard));
    await tapAndSettle(tester, find.text(AppStrings.navSellerStore));
    await pumpUntil(
      tester,
      fieldWith('ชิงไทย ผ้าไหมและของดีล้านนา'),
      reason: 'ฟอร์มร้านยังไม่โหลดชื่อจาก seed',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      newDescription,
    );
    await dismissKeyboard(tester);
    // กดที่ตัวปุ่ม FilledButton (ไม่ใช่ตัวอักษร) เพราะลูก row ที่เพิ่งถูก build
    // อาจอยู่พ้นขอบจอ/ใต้ fold พอดี แล้วปุ่มก็จะโดน tap พลาดเงียบ ๆ
    await scrollToVisible(tester, find.text(AppStrings.save));
    await tester.ensureVisible(find.text(AppStrings.save));
    await tester.pump(const Duration(milliseconds: 300));
    final Finder saveButton = find.ancestor(
      of: find.text(AppStrings.save),
      matching: find.byType(FilledButton),
    );
    await tester.tap(saveButton, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 150));
    // กรณีสำเร็จ: snackbar แล้ว pop กลับแดชบอร์ด — pop เกิดเฉพาะเมื่อ
    // เขียน Firestore สำเร็จ (โค้ดเรียก context.pop() หลัง ok==true เท่านั้น)
    // จึงใช้หน้า popped เองเป็นหลักฐานการบันทึกแทน snackbar ที่หายไว
    await pumpUntil(
      tester,
      find.text(AppStrings.navSellerDashboard),
      reason: 'หน้ายังไม่ pop หลังบันทึก (บันทึกไม่สำเร็จ?)',
    );

    // กลับเข้าไปดูอีกครั้ง: ต้องเห็นคำอธิบายใหม่ที่อ่านกลับมาจาก Firestore
    await tapAndSettle(tester, find.text(AppStrings.navSellerStore));
    await pumpUntil(
      tester,
      fieldWith(newDescription),
      reason: 'คำอธิบายใหม่ยังไม่โหลดกลับจาก Firestore',
    );
  });
}

/// สร้าง label ให้ตรงกับ `Fmt.fill(AppStrings.advanceToStatus, status: …)`
/// โดยไม่ต้อง import formatter — เป้าที่กดคือ label ที่ถูก render เท่านั้น
class FmtLike {
  static String advanceTo(String status) => 'เปลี่ยนเป็น "$status"';
}