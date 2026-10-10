import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:thai_otop_marketplace/core/constants/app_enums.dart';
import 'package:thai_otop_marketplace/features/admin/providers/admin_provider.dart';
import 'package:thai_otop_marketplace/features/admin/screens/admin_home_screen.dart';
import 'package:thai_otop_marketplace/models/store_model.dart';
import 'package:thai_otop_marketplace/models/user_model.dart';
import 'package:thai_otop_marketplace/providers/auth_provider.dart';

// ข้อมูลผู้ดูแลระบบสำหรับจำลองการเข้าสู่หน้าจัดการ
const UserModel _admin = UserModel(
  uid: 'a1',
  displayName: 'ผู้ดูแลระบบ',
  email: 'admin@example.com',
  roles: <UserRole>[UserRole.admin],
);

// ผู้ใช้ทั่วไปใช้ตรวจสอบการปิดกั้นสิทธิ์เข้าถึง
const UserModel _customer = UserModel(
  uid: 'u1',
  displayName: 'สมชาย ใจดี',
  email: 'customer@example.com',
  roles: <UserRole>[UserRole.customer],
);

// ร้านค้าตัวอย่างที่ใช้ทดสอบการแสดงรายการ
const StoreModel _store = StoreModel(
  id: 's1',
  ownerUid: 'owner-1',
  name: 'ร้านชิงไทร',
  province: 'เชียงใหม่',
  region: 'north',
  community: 'บ้านมะคำ',
  description: 'ร้านขายของฝาก',
);

/// ประกอบ ProviderContainer ด้วยข้อมูลจำลอง — ไม่แตะ Firestore
ProviderContainer _container({
  UserModel user = _admin,
  List<StoreModel> stores = const <StoreModel>[_store],
  List<UserModel> users = const <UserModel>[_admin, _customer],
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      authUserProvider.overrideWith(
        (Ref ref) => Stream<UserModel?>.value(user),
      ),
      adminStoresProvider.overrideWith(
        (Ref ref) => Stream<List<StoreModel>>.value(stores),
      ),
      adminUsersProvider.overrideWith(
        (Ref ref) => Stream<List<UserModel>>.value(users),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  // แสดงหน้าจอภายใต้ Provider ที่เตรียมข้อมูลจำลองไว้
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AdminHomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // คุมว่าหน้าผู้ดูแลระบบต้องมี "จัดการร้านค้า" และ "จัดการผู้ใช้" และไม่โล่ง
  testWidgets('shows exactly the two management tabs with their rows', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _container());

    // มี 2 แท็บพอดี — กันบั๊ก DefaultTabController length ไม่ตรงกับจำนวน tabs
    expect(find.text('ร้านค้า'), findsOneWidget);
    expect(find.text('ผู้ใช้'), findsOneWidget);

    // แท็บร้านค้าแสดงรายการ ไม่ปล่อยโล่ง
    expect(find.text('ร้านชิงไทร'), findsOneWidget);

    // สลับไปแท็บผู้ใช้แล้วเห็นรายการผู้ใช้
    await tester.tap(find.text('ผู้ใช้'));
    await tester.pumpAndSettle();
    expect(find.text('สมชาย ใจดี'), findsOneWidget);
  });

  testWidgets('a non-admin sees the permission gate, not the lists', (
    WidgetTester tester,
  ) async {
    // ยืนยันว่าผู้ใช้ทั่วไปเห็นข้อความแจ้งสิทธิ์และไม่เห็นข้อมูลร้านค้า
    await _pump(tester, _container(user: _customer));

    expect(find.text('ไม่มีสิทธิ์เข้าถึง'), findsOneWidget);
    expect(find.text('ร้านชิงไทร'), findsNothing);
  });

  testWidgets('empty stores fall back to the empty state', (
    WidgetTester tester,
  ) async {
    // เมื่อไม่มีร้านค้า ระบบควรแสดงสถานะว่างแทนรายการ
    await _pump(tester, _container(stores: const <StoreModel>[]));

    expect(find.text('ยังไม่มีร้านค้า'), findsOneWidget);
  });
}
