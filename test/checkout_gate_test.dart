import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:thai_otop_marketplace/core/constants/app_enums.dart';
import 'package:thai_otop_marketplace/core/constants/app_strings.dart';
import 'package:thai_otop_marketplace/core/routes/app_router.dart';
import 'package:thai_otop_marketplace/features/auth/screens/login_screen.dart';
import 'package:thai_otop_marketplace/features/cart/screens/checkout_screen.dart';
import 'package:thai_otop_marketplace/models/product_model.dart';
import 'package:thai_otop_marketplace/models/user_model.dart';
import 'package:thai_otop_marketplace/providers/auth_provider.dart';
import 'package:thai_otop_marketplace/providers/cart_provider.dart';

final ProductModel _product = ProductModel(
  id: 'p-herb',
  storeId: 's1',
  name: 'สมุนไพรแก้ปวดเมื่อย',
  description: '',
  price: 480,
  categoryId: 'c1',
  province: 'นครศรีธรรมราช',
  region: ThaiRegion.south.value,
  imageUrls: <String>[],
  stockTotal: 70,
  status: ProductStatus.active,
  story: ProductStory(),
);

/// Stands in for Home so the test can assert where the user lands without
/// dragging Firestore into a widget test.
class _FakeHome extends StatelessWidget {
  const _FakeHome();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('หน้าแรก')));
}

Widget _harness(ProviderContainer container, GoRouter router) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    );

void main() {
  // ยืนยันว่า guest เห็นทางเลือกสมัคร/ล็อกอินก่อนถูกกันออกจากการซื้อ
  group('checkout auth gate', () {
    late ProviderContainer container;
    late GoRouter router;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          // Signed out, and settled: no auth round-trip in a widget test.
          authUserProvider.overrideWith(
            (Ref ref) => Stream<UserModel?>.value(null),
          ),
        ],
      );
      container.read(cartProvider.notifier).add(_product);

      router = GoRouter(
        initialLocation: AppRoutes.checkout,
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.home,
            builder: (BuildContext context, GoRouterState state) =>
                const _FakeHome(),
          ),
          GoRoute(
            path: AppRoutes.login,
            builder: (BuildContext context, GoRouterState state) =>
                LoginScreen(redirect: state.uri.queryParameters['redirect']),
          ),
          GoRoute(
            path: AppRoutes.checkout,
            builder: (BuildContext context, GoRouterState state) =>
                const CheckoutScreen(),
          ),
        ],
      );
    });

    tearDown(() {
      router.dispose();
      container.dispose();
    });

    testWidgets('a guest sees the message and all three choices', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(container, router));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.loginToOrder), findsOneWidget);
      expect(find.text(AppStrings.loginToOrderHint), findsOneWidget);
      expect(find.text(AppStrings.login), findsOneWidget);
      expect(find.text(AppStrings.register), findsOneWidget);
      expect(find.text(AppStrings.backToCart), findsOneWidget);
    });

    testWidgets('the order form stays hidden while signed out', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(container, router));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.shippingAddress), findsNothing);
      expect(find.text(AppStrings.placeOrder), findsNothing);
    });

    testWidgets('"go back to shopping" lands on the catalogue', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(container, router));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.backToCart));
      await tester.pumpAndSettle();

      expect(find.text('หน้าแรก'), findsOneWidget);
    });

    testWidgets('"sign in" opens the login form for this checkout', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(container, router));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.login));
      await tester.pumpAndSettle();

      // The gate is gone and the login form took its place.
      expect(find.text(AppStrings.loginToOrder), findsNothing);
      expect(
        find.widgetWithText(FilledButton, AppStrings.login),
        findsOneWidget,
      );
    });

    testWidgets('"register" opens the register form for this checkout', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(container, router));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.register));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.loginToOrder), findsNothing);
    });
  });
}
