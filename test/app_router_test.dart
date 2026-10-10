import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_otop_marketplace/core/constants/app_strings.dart';
import 'package:thai_otop_marketplace/core/routes/app_router.dart';
import 'package:thai_otop_marketplace/features/auth/screens/login_screen.dart';
import 'package:thai_otop_marketplace/features/auth/screens/register_screen.dart';

import 'package:thai_otop_marketplace/core/constants/app_enums.dart';
import 'package:thai_otop_marketplace/models/user_model.dart';

void main() {
  // ตรวจสิทธิ์ route, redirect ตาม role และการกลับไปยังปลายทางเดิม
  group('authRedirect', () {
    test('a guest may browse the whole catalogue', () {
      // Browse-first: opening the app must never bounce a guest to login.
      expect(authRedirect(signedIn: false, location: AppRoutes.home), isNull);
      expect(authRedirect(signedIn: false, location: AppRoutes.cart), isNull);
      expect(authRedirect(signedIn: false, location: AppRoutes.stores), isNull);
      expect(
        authRedirect(signedIn: false, location: AppRoutes.productDetail('p1')),
        isNull,
      );
    });

    test('a guest reaches checkout, where the gate itself offers a choice', () {
      // Guarding /checkout here would hide the three-button gate and race the
      // auth stream when signing in.
      expect(
        authRedirect(signedIn: false, location: AppRoutes.checkout),
        isNull,
      );
    });

    test(
      'a guest is sent to login for account-only routes, with destination',
      () {
        for (final String location in <String>[
          AppRoutes.orders,
          AppRoutes.ordersHistory,
          AppRoutes.profile,
          AppRoutes.orderDetail('o1'),
          AppRoutes.orderTracking('o1'),
        ]) {
          expect(
            authRedirect(signedIn: false, location: location),
            '${AppRoutes.login}?redirect=$location',
          );
        }
      },
    );

    test('a guest is sent to login for every seller route', () {
      // The seller console is guarded by prefix, so a new `/seller/...` screen
      // is covered without anyone remembering to add it to a list.
      for (final String location in <String>[
        AppRoutes.sellerRoot,
        AppRoutes.sellerProducts,
        AppRoutes.sellerOrders,
        AppRoutes.sellerStoreProfile,
        AppRoutes.sellerProductNew('s1'),
        AppRoutes.sellerProductEdit('p1'),
      ]) {
        expect(
          authRedirect(signedIn: false, location: location),
          '${AppRoutes.login}?redirect=$location',
          reason: '$location must send a signed-out visitor to login',
        );
        expect(
          authRedirect(signedIn: true, location: location),
          isNull,
          reason: 'a signed-in user must reach $location',
        );
      }
    });

    test('chat routes are account-bound, like orders', () {
      // `/chat` และทุก `/chat/<thread>` ต้องมีเจ้าของจริง — ข้อความระบุชื่อผู้ส่ง
      // คนที่ยังไม่ล็อกอินจึงเข้าถล่องข้อความไม่ได้
      for (final String location in <String>[
        AppRoutes.chat,
        AppRoutes.chatThread('t1'),
      ]) {
        expect(
          authRedirect(signedIn: false, location: location),
          '${AppRoutes.login}?redirect=$location',
          reason: '$location must send a signed-out visitor to login',
        );
        expect(
          authRedirect(signedIn: true, location: location),
          isNull,
          reason: 'a signed-in user must reach $location',
        );
      }
    });

    test('the login screen itself is never redirected', () {
      expect(authRedirect(signedIn: false, location: AppRoutes.login), isNull);
      expect(
        authRedirect(signedIn: false, location: AppRoutes.register),
        isNull,
      );
    });

    test('a signed-in customer reaches everything', () {
      const customer = UserModel(
        uid: 'c1',
        displayName: 'Customer',
        email: 'customer@test.com',
        roles: <UserRole>[UserRole.customer],
      );
      for (final String location in <String>[
        AppRoutes.home,
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.cart,
        AppRoutes.checkout,
        AppRoutes.orders,
        AppRoutes.orderDetail('o1'),
        AppRoutes.orderTracking('o1'),
        AppRoutes.chat,
        AppRoutes.chatThread('t1'),
        AppRoutes.profile,
      ]) {
        expect(
          authRedirect(signedIn: true, location: location, user: customer),
          isNull,
        );
      }
    });

    test(
      'a signed-in seller is redirected to /seller on home, login, register',
      () {
        const seller = UserModel(
          uid: 's1',
          displayName: 'Seller',
          email: 'seller@test.com',
          roles: <UserRole>[UserRole.seller],
        );
        expect(
          authRedirect(signedIn: true, location: AppRoutes.home, user: seller),
          AppRoutes.sellerRoot,
        );
        expect(
          authRedirect(signedIn: true, location: AppRoutes.login, user: seller),
          AppRoutes.sellerRoot,
        );
        expect(
          authRedirect(
            signedIn: true,
            location: AppRoutes.register,
            user: seller,
          ),
          AppRoutes.sellerRoot,
        );
        expect(
          authRedirect(
            signedIn: true,
            location: AppRoutes.sellerRoot,
            user: seller,
          ),
          isNull,
        );
        expect(
          authRedirect(
            signedIn: true,
            location: AppRoutes.sellerProducts,
            user: seller,
          ),
          isNull,
        );
      },
    );

    test('an admin is redirected to the admin console', () {
      const admin = UserModel(
        uid: 'a1',
        displayName: 'Admin',
        email: 'admin@test.com',
        roles: <UserRole>[UserRole.admin],
      );

      for (final String location in <String>[
        AppRoutes.home,
        AppRoutes.login,
        AppRoutes.register,
      ]) {
        expect(
          authRedirect(signedIn: true, location: location, user: admin),
          AppRoutes.adminRoot,
        );
      }
      expect(
        authRedirect(
          signedIn: true,
          location: AppRoutes.adminRoot,
          user: admin,
        ),
        isNull,
      );
    });

    test('only admins can open the admin console', () {
      expect(
        authRedirect(signedIn: false, location: AppRoutes.adminRoot),
        '${AppRoutes.login}?redirect=${AppRoutes.adminRoot}',
      );
      expect(
        authRedirect(signedIn: true, location: AppRoutes.adminRoot),
        AppRoutes.home,
      );
    });

    test('a signed-in customer is sent home from the seller console', () {
      const customer = UserModel(
        uid: 'c1',
        displayName: 'Customer',
        email: 'customer@test.com',
        roles: <UserRole>[UserRole.customer],
      );
      for (final String location in <String>[
        AppRoutes.sellerRoot,
        AppRoutes.sellerProducts,
        AppRoutes.sellerOrders,
        AppRoutes.sellerStoreProfile,
        AppRoutes.sellerProductNew('s1'),
        AppRoutes.sellerProductEdit('p1'),
      ]) {
        expect(
          authRedirect(signedIn: true, location: location, user: customer),
          AppRoutes.home,
          reason: '$location must not strand a non-seller',
        );
      }
      // แอดมินยังเข้าส่วนผู้ขายได้เหมือนเดิม
      const admin = UserModel(
        uid: 'a1',
        displayName: 'Admin',
        email: 'admin@test.com',
        roles: <UserRole>[UserRole.admin],
      );
      expect(
        authRedirect(
          signedIn: true,
          location: AppRoutes.sellerRoot,
          user: admin,
        ),
        isNull,
      );
    });

    test('an unknown path is not guarded', () {
      expect(authRedirect(signedIn: false, location: '/nope'), isNull);
    });
  });

  group('auth screens', () {
    // The hero spins forever, so `pumpAndSettle` would never return. A single
    // pump is enough: the form validation is synchronous.
    Future<void> pumpAuth(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(ProviderScope(child: MaterialApp(home: child)));
      await tester.pump();
    }

    testWidgets('login rejects an empty submit', (WidgetTester tester) async {
      await pumpAuth(tester, const LoginScreen());

      await tester.tap(find.widgetWithText(FilledButton, AppStrings.login));
      await tester.pump();

      expect(find.text(AppStrings.errRequired), findsNWidgets(2));
    });

    testWidgets('login rejects a malformed email', (WidgetTester tester) async {
      await pumpAuth(tester, const LoginScreen());

      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.email),
        'not-an-email',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.password),
        'secret123',
      );
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.login));
      await tester.pump();

      expect(find.text(AppStrings.errEmailFormat), findsOneWidget);
    });

    testWidgets('register blocks a mismatched confirmation', (
      WidgetTester tester,
    ) async {
      await pumpAuth(tester, const RegisterScreen());

      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.displayName),
        'Test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.email),
        'new@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.password),
        'secret123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.confirmPassword),
        'different',
      );
      await submitRegister(tester);
      await tester.pump();

      expect(find.text(AppStrings.errPasswordMismatch), findsOneWidget);
    });

    testWidgets('register rejects a short password', (
      WidgetTester tester,
    ) async {
      await pumpAuth(tester, const RegisterScreen());

      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.displayName),
        'Test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.email),
        'new@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.password),
        'abc',
      );
      await submitRegister(tester);
      await tester.pump();

      expect(find.text(AppStrings.errPasswordShort), findsOneWidget);
    });

    testWidgets('register rejects a malformed mobile number', (
      WidgetTester tester,
    ) async {
      await pumpAuth(tester, const RegisterScreen());

      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.displayName),
        'Test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.phone),
        '12345',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.password),
        'secret123',
      );
      await submitRegister(tester);
      await tester.pump();

      expect(find.text(AppStrings.errPhoneFormat), findsOneWidget);
    });

    testWidgets('register accepts a valid form', (WidgetTester tester) async {
      await pumpAuth(tester, const RegisterScreen());

      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.displayName),
        'Test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.email),
        'new@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.phone),
        '0812345678',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'จังหวัด'),
        'เชียงใหม่',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.password),
        'secret123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.confirmPassword),
        'secret123',
      );
      await submitRegister(tester);
      await tester.pump();

      // Validation passed, so the form submitted: no validator messages.
      expect(find.text(AppStrings.errRequired), findsNothing);
      expect(find.text(AppStrings.errPasswordMismatch), findsNothing);
      expect(find.text(AppStrings.errPasswordShort), findsNothing);
    });

    testWidgets('registration type reveals store fields', (
      WidgetTester tester,
    ) async {
      await pumpAuth(tester, const RegisterScreen());

      expect(find.text('Affiliate'), findsNothing);

      await tester.tap(find.text('ร้านค้า'));
      await tester.pump();
      expect(find.text('ชื่อร้าน'), findsOneWidget);
      expect(find.text('ชุมชน / กลุ่มผู้ผลิต'), findsOneWidget);
      expect(find.text('เรื่องราวและรายละเอียดร้าน'), findsOneWidget);
    });
  });
}

/// The register form is taller than the 800x600 test surface, so the submit
/// button sits below the fold. Scroll it into view or the tap silently misses
/// and the validators never run.
Future<void> submitRegister(WidgetTester tester) async {
  final Finder button = find.widgetWithText(FilledButton, AppStrings.register);
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
}
