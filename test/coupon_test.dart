import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:thai_otop_marketplace/core/constants/app_enums.dart';
import 'package:thai_otop_marketplace/core/constants/app_strings.dart';
import 'package:thai_otop_marketplace/core/routes/app_router.dart';
import 'package:thai_otop_marketplace/features/cart/screens/checkout_screen.dart';
import 'package:thai_otop_marketplace/features/coupons/screens/coupon_list_screen.dart';
import 'package:thai_otop_marketplace/models/coupon_model.dart';
import 'package:thai_otop_marketplace/models/product_model.dart';
import 'package:thai_otop_marketplace/models/user_model.dart';
import 'package:thai_otop_marketplace/providers/auth_provider.dart';
import 'package:thai_otop_marketplace/providers/cart_provider.dart';
import 'package:thai_otop_marketplace/providers/coupon_provider.dart';
import 'package:thai_otop_marketplace/repositories/coupon_repository.dart';

const UserModel _customer = UserModel(
  uid: 'u1',
  displayName: 'สมชาย ใจดี',
  email: 'customer@example.com',
);

final ProductModel _product = ProductModel(
  id: 'p1',
  storeId: 's1',
  name: 'กาแฟดอยอารามี',
  description: '',
  price: 480,
  categoryId: 'c1',
  province: 'เชียงใหม่',
  region: 'north',
  imageUrls: <String>[],
  stockTotal: 20,
  status: ProductStatus.active,
  story: ProductStory(),
);

/// Builds a usable coupon with defaults that a test can override.
CouponModel _coupon({
  String code = 'SAVE10',
  CouponType type = CouponType.percentage,
  double value = 10,
  double minSpend = 0,
  double? maxDiscount,
  String? storeId,
  bool active = true,
  int usageLimit = 0,
  int usedCount = 0,
  DateTime? startsAt,
  DateTime? expiresAt,
}) => CouponModel(
  id: 'c1',
  code: code,
  type: type,
  value: value,
  minSpend: minSpend,
  maxDiscount: maxDiscount,
  storeId: storeId,
  startsAt: startsAt ?? DateTime(2020, 1, 1),
  expiresAt: expiresAt ?? DateTime(2100, 1, 1),
  usageLimit: usageLimit == 0 ? null : usageLimit,
  usedCount: usedCount,
  active: active,
);

/// A coupon repository that answers from an in-memory map.
class _FakeCouponRepository implements CouponRepository {
  _FakeCouponRepository(this.byCode);

  final Map<String, CouponModel> byCode;

  Object? throwWith;

  @override
  Future<CouponModel?> findByCode(String code) async {
    if (throwWith != null) throw throwWith!;
    final String key = code.trim().toUpperCase();
    return byCode[key];
  }

  @override
  Stream<List<CouponModel>> watchAll() async* {
    yield byCode.values.toList();
  }

  @override
  Future<void> create(Map<String, dynamic> data) async {}

  @override
  Future<void> update(String id, Map<String, dynamic> data) async {}

  @override
  Future<void> setActive(String id, bool active) async {}

  @override
  Future<void> delete(String id) async {}
}

Future<void> _pumpCheckout(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.checkout,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.home,
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Center(child: Text('หน้าแรก'))),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        builder: (BuildContext context, GoRouterState state) =>
            const CheckoutScreen(),
      ),
      GoRoute(
        path: AppRoutes.payment,
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Center(child: Text('payment'))),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('coupon discount maths', () {
    test('percentage takes value% of the subtotal', () {
      expect(_coupon(value: 10).discountFor(subtotal: 500, storeId: 's1'), 50);
    });

    test('percentage is capped by maxDiscount', () {
      final CouponModel c = _coupon(value: 25, maxDiscount: 100);
      expect(c.discountFor(subtotal: 1000, storeId: 's1'), 100);
    });

    test('fixed coupon returns value, clamped to the subtotal', () {
      final CouponModel c = _coupon(type: CouponType.fixed, value: 50);
      expect(c.discountFor(subtotal: 800, storeId: 's1'), 50);
      expect(c.discountFor(subtotal: 30, storeId: 's1'), 30);
    });

    test('a basket below minSpend gets nothing', () {
      final CouponModel c = _coupon(minSpend: 600);
      expect(c.discountFor(subtotal: 500, storeId: 's1'), 0);
    });

    test('a coupon scoped to another store gets nothing', () {
      final CouponModel c = _coupon(storeId: 's2');
      expect(c.discountFor(subtotal: 1000, storeId: 's1'), 0);
    });

    test('inactive, expired, not started or exhausted coupons get nothing', () {
      expect(_coupon(active: false).discountFor(subtotal: 500, storeId: 's1'), 0);
      expect(
        _coupon(
          expiresAt: DateTime(2020, 1, 1),
        ).discountFor(subtotal: 500, storeId: 's1'),
        0,
      );
      expect(
        _coupon(
          startsAt: DateTime(2100, 1, 1),
        ).discountFor(subtotal: 500, storeId: 's1'),
        0,
      );
      expect(
        _coupon(usageLimit: 2, usedCount: 2).discountFor(
          subtotal: 500,
          storeId: 's1',
        ),
        0,
      );
    });

    test('discounts are whole baht even when the percentage is fractional', () {
      final CouponModel c = _coupon(value: 10);
      expect(c.discountFor(subtotal: 49, storeId: 's1'), 5);
    });

    test('validation explains a rejected code', () {
      expect(
        couponValidationError(_coupon(), storeId: 's1', subtotal: 500),
        isNull,
      );
      expect(
        couponValidationError(
          _coupon(minSpend: 600),
          storeId: 's1',
          subtotal: 500,
        ),
        'ยอดซื้อขั้นต่ำ 600',
      );
      expect(
        couponValidationError(
          _coupon(expiresAt: DateTime(2020, 1, 1)),
          storeId: 's1',
          subtotal: 500,
        ),
        AppStrings.couponExpired,
      );
    });
  });

  group('checkout coupon box', () {
    late ProviderContainer container;
    late _FakeCouponRepository repo;

    setUp(() {
      repo = _FakeCouponRepository(<String, CouponModel>{
        'SAVE10': _coupon(),
        'LOW': _coupon(code: 'LOW', minSpend: 600),
      });
      container = ProviderContainer(
        overrides: [
          authUserProvider.overrideWith(
            (Ref ref) => Stream<UserModel?>.value(_customer),
          ),
          couponRepositoryProvider.overrideWithValue(repo),
        ],
      );
      container.read(cartProvider.notifier).add(_product);
      addTearDown(container.dispose);
    });

    testWidgets('a valid code applies and rewrites the total', (
      WidgetTester tester,
    ) async {
      await _pumpCheckout(tester, container);

      final Finder couponField = find.byType(TextField).last;
      await tester.ensureVisible(couponField);
      await tester.enterText(couponField, 'save10');
      await tester.tap(find.text(AppStrings.couponApply));
      await tester.pumpAndSettle();

      // Subtotal ฿480 + shipping ฿50 − 10% (฿48) = ฿482.
      expect(find.text('ใช้คูปอง SAVE10 แล้ว'), findsOneWidget);
      // Shown in the coupon chip and again in the summary row.
      expect(find.text('-฿48'), findsWidgets);
      expect(find.text('฿482'), findsOneWidget);
    });

    testWidgets('an unknown code gets an honest error', (
      WidgetTester tester,
    ) async {
      await _pumpCheckout(tester, container);

      final Finder couponField = find.byType(TextField).last;
      await tester.ensureVisible(couponField);
      await tester.enterText(couponField, 'nope');
      await tester.tap(find.text(AppStrings.couponApply));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.couponNotFound), findsOneWidget);
      expect(find.text('ใช้คูปอง SAVE10 แล้ว'), findsNothing);
    });

    testWidgets('a code below its minSpend explains why it cannot apply', (
      WidgetTester tester,
    ) async {
      await _pumpCheckout(tester, container);

      final Finder couponField = find.byType(TextField).last;
      await tester.ensureVisible(couponField);
      await tester.enterText(couponField, 'LOW');
      await tester.tap(find.text(AppStrings.couponApply));
      await tester.pumpAndSettle();

      expect(find.text('ยอดซื้อขั้นต่ำ 600'), findsOneWidget);
    });

    testWidgets('the applied code can be removed', (WidgetTester tester) async {
      await _pumpCheckout(tester, container);

      final Finder couponField = find.byType(TextField).last;
      await tester.ensureVisible(couponField);
      await tester.enterText(couponField, 'SAVE10');
      await tester.tap(find.text(AppStrings.couponApply));
      await tester.pumpAndSettle();
      expect(find.text('฿482'), findsOneWidget);

      await tester.tap(find.byTooltip(AppStrings.couponRemove));
      await tester.pumpAndSettle();

      // Back to the un-discounted checkout.
      expect(find.text('ใช้คูปอง SAVE10 แล้ว'), findsNothing);
      expect(find.text('฿530'), findsOneWidget);
    });
  });

  group('buyer coupon list screen', () {
    testWidgets('shows only usable coupons from the live repository', (
      WidgetTester tester,
    ) async {
      final _FakeCouponRepository repo = _FakeCouponRepository(
        <String, CouponModel>{
          'SAVE10': _coupon(),
          'EXPIRED': _coupon(
            code: 'EXPIRED',
            expiresAt: DateTime(2020, 1, 1),
            startsAt: DateTime(2019, 1, 1),
          ),
          'OFF': _coupon(code: 'OFF', active: false),
          'LATER': _coupon(code: 'LATER', startsAt: DateTime(2100, 1, 1)),
          'USEDUP': _coupon(code: 'USEDUP', usageLimit: 2, usedCount: 2),
        },
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          couponRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CouponListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SAVE10'), findsOneWidget);
      expect(find.text('EXPIRED'), findsNothing);
      expect(find.text('OFF'), findsNothing);
      expect(find.text('LATER'), findsNothing);
      expect(find.text('USEDUP'), findsNothing);
    });

    testWidgets('shows an empty state when nothing is usable', (
      WidgetTester tester,
    ) async {
      final _FakeCouponRepository repo = _FakeCouponRepository(
        <String, CouponModel>{
          'OFF': _coupon(code: 'OFF', active: false),
        },
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          couponRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CouponListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SAVE10'), findsNothing);
      expect(find.text('ยังไม่มีคูปอง'), findsOneWidget);
    });
  });
}