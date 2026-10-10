import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:thai_otop_marketplace/core/constants/app_enums.dart';
import 'package:thai_otop_marketplace/core/constants/app_strings.dart';
import 'package:thai_otop_marketplace/core/routes/app_router.dart';
import 'package:thai_otop_marketplace/features/profile/screens/profile_screen.dart';
import 'package:thai_otop_marketplace/models/user_model.dart';
import 'package:thai_otop_marketplace/providers/auth_provider.dart';
import 'package:thai_otop_marketplace/repositories/auth_repository.dart';

const UserModel _customer = UserModel(
  uid: 'c1',
  displayName: 'ณัฐวุฒิ ศรีสุข',
  email: 'customer@example.com',
  phone: '0812345678',
  province: 'เชียงใหม่',
  roles: <UserRole>[UserRole.customer],
);

/// Fake ที่ไม่แตะ Firebase จริง เอาไว้จับสิ่งที่หน้าจอส่งให้ repository
/// (ขอบเขตกรองเฉพาะเมธอดที่หน้าจอโปรไฟล์เรียก เท่ากับเทสต์ต้องระบุเจตนา)
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.failMessage});

  /// ถ้าตั้งค่าไว้ updateProfile จะโยน AuthFailure ข้อความนี้ (จำลองกฎ/เน็ตพัง)
  final String? failMessage;

  /// ค่าที่หน้าจอส่งให้ updateProfile ครั้งล่าสุด (null = ยังไม่เคยกดบันทึก)
  ({String displayName, String phone})? lastSaved;

  @override
  Future<UserModel> updateProfile({
    required String displayName,
    required String phone,
  }) async {
    final String? fail = failMessage;
    if (fail != null) throw AuthFailure(fail);
    // เลียนแบบสัญญาของ repository จริง: ตัดช่องว่างหัวท้ายแล้วค่อยบันทึก
    final String name = displayName.trim();
    final String tel = phone.trim();
    lastSaved = (displayName: name, phone: tel);
    return UserModel(
      uid: _customer.uid,
      displayName: name,
      email: _customer.email,
      phone: tel,
      province: _customer.province,
      roles: _customer.roles,
    );
  }

  @override
  Stream<User?> authStateChanges() => Stream<User?>.empty();

  @override
  User? get currentAuthUser => null;

  @override
  Future<UserModel?> loadUser(String uid) async => _customer;

  @override
  Future<UserModel?> loadCurrentUser() async => _customer;

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    required String displayName,
    required String phone,
    required String province,
    required UserRole accountType,
    String storeName = '',
    String community = '',
    String storeDescription = '',
    String region = '',
  }) =>
      throw UnimplementedError();

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  late _FakeAuthRepository repo;
  late ProviderContainer container;
  late GoRouter router;

  /// เปิด แอปโดยมี route home + /profile พร้อมเทสต์ fake — แล้วพาไปหน้าโปรไฟล์
  Widget harness() => UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );

  void setup({String? failMessage, UserModel? user}) {
    repo = _FakeAuthRepository(failMessage: failMessage);
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        authUserProvider.overrideWith(
          (Ref ref) => Stream<UserModel?>.value(user ?? _customer),
        ),
      ],
    );
    router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.home,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('home'))),
        ),
        GoRoute(
          path: AppRoutes.profile,
          builder: (BuildContext context, GoRouterState state) =>
              const ProfileScreen(),
        ),
      ],
    );
  }

  Future<void> openProfile(WidgetTester tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    // push (ไม่ใช่ go) เพื่อให้มี home ในสแตกให้ context.pop() กลับไปได้
    router.push(AppRoutes.profile);
    await tester.pumpAndSettle();
  }

  tearDown(() {
    container.dispose();
    router.dispose();
  });

  group('profile screen', () {
    testWidgets('pre-fills current values and locks the email', (
      WidgetTester tester,
    ) async {
      setup();
      await openProfile(tester);

      // ชื่อ/เบอร์โหลดจากโปรไฟล์เข้ามาในช่อง
      expect(
        find.widgetWithText(TextFormField, _customer.displayName),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, _customer.phone),
        findsOneWidget,
      );
      // ไม่มีช่องจังหวัด — ข้อมูลนี้ไม่จำเป็นต้องแก้เอง
      expect(find.byType(TextFormField), findsNWidgets(3));
      // อีเมลแสดงแบบอ่านอย่างเดียว + มีป้ายบอกว่าทำไมแก้ไม่ได้
      expect(find.text(_customer.email), findsOneWidget);
      expect(find.text(AppStrings.emailLockedHint), findsOneWidget);
      // ป้ายบทบาทของบัญชีแสดงในส่วนหัว
      expect(find.text(UserRole.customer.label), findsOneWidget);
    });

    testWidgets('blocks empty name / malformed phone without writing', (
      WidgetTester tester,
    ) async {
      setup();
      await openProfile(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.displayName),
        '',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.phone),
        '1234',
      );
      await tester.tap(find.text(AppStrings.saveProfile));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.errRequired), findsOneWidget);
      expect(find.text(AppStrings.errPhoneFormat), findsOneWidget);
      // ไม่เคยไปถึง repository — แอปตรวจก่อนเขียน
      expect(repo.lastSaved, isNull);
    });

    testWidgets('saves trimmed values, shows success, and returns home', (
      WidgetTester tester,
    ) async {
      setup();
      await openProfile(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.displayName),
        '  ใหม่ ชื่อ  ',
      );
      await tester.tap(find.text(AppStrings.saveProfile));
      await tester.pumpAndSettle();

      // ค่าที่เขียนถูก trim ฝั่ง repository ก่อน Firestore
      expect(
        repo.lastSaved?.displayName,
        'ใหม่ ชื่อ',
        reason: 'repository ตัดช่องว่างหัวท้ายแล้วค่อยส่งออก',
      );
      expect(repo.lastSaved?.phone, _customer.phone);
      expect(find.text(AppStrings.profileSaved), findsOneWidget);
      // ป็อปกลับหน้าหลัก — ไม่ค้างอยู่บนฟอร์ม
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('surfaces a repository failure as a Thai message', (
      WidgetTester tester,
    ) async {
      setup(failMessage: 'กฎการอัปเดตไม่อนุญาต');
      await openProfile(tester);

      await tester.tap(find.text(AppStrings.saveProfile));
      await tester.pumpAndSettle();

      expect(find.text('กฎการอัปเดตไม่อนุญาต'), findsOneWidget);
      expect(find.text(AppStrings.profileSaved), findsNothing);
    });

    testWidgets('shows a loading gate while the profile is not resolved', (
      WidgetTester tester,
    ) async {
      setup(user: null);
      await tester.pumpWidget(harness());
      await tester.pump();
      router.go(AppRoutes.profile);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // ยังไม่แสดงฟอร์มแก้ไขตอนข้อมูลยังไม่มา
      expect(find.text(AppStrings.saveProfile), findsNothing);
      // อย่า pumpAndSettle — สปินเนอร์หมุนตลอดเวลาไม่ settle ได้
    });
  });
}