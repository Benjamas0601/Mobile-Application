import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:thai_otop_marketplace/core/constants/app_enums.dart';
import 'package:thai_otop_marketplace/core/constants/app_strings.dart';
import 'package:thai_otop_marketplace/core/constants/payment_strings.dart';
import 'package:thai_otop_marketplace/core/routes/app_router.dart';
import 'package:thai_otop_marketplace/features/cart/screens/payment_screen.dart';
import 'package:thai_otop_marketplace/features/orders/screens/order_detail_screen.dart';
import 'package:thai_otop_marketplace/models/order_model.dart';
import 'package:thai_otop_marketplace/models/product_model.dart';
import 'package:thai_otop_marketplace/models/store_model.dart';
import 'package:thai_otop_marketplace/models/user_model.dart';
import 'package:thai_otop_marketplace/providers/auth_provider.dart';
import 'package:thai_otop_marketplace/providers/cart_provider.dart';
import 'package:thai_otop_marketplace/providers/catalog_provider.dart';
import 'package:thai_otop_marketplace/providers/order_provider.dart';
import 'package:thai_otop_marketplace/repositories/order_repository.dart';

const ProductModel _product = ProductModel(
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

const UserModel _customer = UserModel(
  uid: 'u1',
  displayName: 'สมชาย ใจดี',
  email: 'customer@example.com',
);

const UserModel _seller = UserModel(
  uid: 's1',
  displayName: 'ผู้ขาย',
  email: 'seller.north@example.com',
  roles: <UserRole>[UserRole.seller],
);

const StoreModel _store = StoreModel(
  id: 's1',
  ownerUid: 'o1',
  name: 'ร้านชิงไทร',
  province: 'เชียงใหม่',
  region: 'north',
  community: 'บ้านมะคำ',
  description: '',
  coverImageUrl: '',
);

OrderModel _order({OrderStatus status = OrderStatus.shipped}) => OrderModel(
  id: 'o1',
  buyerUid: 'u1',
  storeId: 's1',
  storeName: 'ร้านชิงไทร',
  items: const <OrderItem>[
    OrderItem(productId: 'p1', name: 'กาแฟดอยอารามี', price: 480, quantity: 1),
  ],
  subtotal: 480,
  shippingFee: 50,
  total: 530,
  status: status,
  paymentMethod: PaymentMethod.promptPay,
  paymentStatus: PaymentStatus.verified,
  shippingAddress: 'เชียงใหม่ 50100',
  createdAt: DateTime(2026, 9, 28),
);

/// Stands in for the order detail route so the test can assert the write
/// happened without dragging Firestore in.
class _OrderDetailStub extends StatelessWidget {
  const _OrderDetailStub();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('รายละเอียดคำสั่งซื้อ')));
}

/// Records what a screen asked the repository to do, without a Firestore.
class _FakeOrderRepository implements OrderRepository {
  final List<String> created = <String>[];
  final List<String> advanced = <String>[];
  Object? failWith;

  @override
  Future<String> createOrder({
    required List<OrderItem> items,
    required String storeId,
    required String storeName,
    required String buyerName,
    required String shippingAddress,
    required PaymentMethod method,
    String? note,
  }) async {
    if (failWith != null) throw failWith!;
    created.add('$storeId|$shippingAddress|${method.value}');
    return 'new-order-id';
  }

  @override
  Future<void> advanceStatus(String orderId, OrderStatus next) async {
    advanced.add('$orderId:${next.value}');
  }

  @override
  Stream<List<OrderModel>> watchMyOrders() =>
      Stream<List<OrderModel>>.value(<OrderModel>[_order()]);

  @override
  Stream<OrderModel?> watchOrder(String orderId) =>
      Stream<OrderModel?>.value(_order());
}

/// An order that was cancelled, for the terminal-state case.
class _CancelledOrderRepository extends _FakeOrderRepository {
  @override
  Stream<OrderModel?> watchOrder(String orderId) =>
      Stream<OrderModel?>.value(_order(status: OrderStatus.cancelled));
}

ProviderContainer _container(_FakeOrderRepository repo, {UserModel? user}) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      authUserProvider.overrideWith(
        (Ref ref) => Stream<UserModel?>.value(user ?? _customer),
      ),
      orderRepositoryProvider.overrideWithValue(repo),
      storeProvider.overrideWith((Ref ref, String id) async => _store),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Pumps [child] inside the router the payment screen navigates with.
Future<void> _pumpPayment(WidgetTester tester, ProviderContainer container) async {
  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.payment,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.payment,
        builder: (BuildContext context, GoRouterState state) =>
            const PaymentScreen(),
      ),
      GoRoute(
        path: AppRoutes.orderDetail(':orderId'),
        builder: (BuildContext context, GoRouterState state) =>
            const _OrderDetailStub(),
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

/// Pumps a single screen outside a router (the detail screen navigates only
/// on an order-not-found action).
Future<void> _pumpHome(WidgetTester tester, ProviderContainer container, Widget child) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: MaterialApp(home: child)),
  );
  await tester.pumpAndSettle();
}

/// The ListView builds lazily, so the confirm button and the notice below it
/// live past the edge of the test viewport until scrolled into view.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300);
  await tester.pumpAndSettle();
}

void main() {
  // `Fmt` formats Buddhist-era Thai dates; the symbols are loaded once per
  // process, which the app's `main` does and the test binary must repeat.
  setUpAll(() async {
    await initializeDateFormatting('th');
  });

  group('the payment step offers every method', () {
    testWidgets('shows all three, with the total on the button', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = _container(_FakeOrderRepository())
        ..read(cartProvider.notifier).add(_product);
      container.read(checkoutDraftProvider.notifier).start(
        storeId: 's1',
        shippingAddress: 'เชียงใหม่ 50100',
      );

      await _pumpPayment(tester, container);

      expect(find.text(PaymentMethod.promptPay.label), findsOneWidget);
      expect(find.text(PaymentMethod.bankTransfer.label), findsOneWidget);
      expect(find.text(PaymentMethod.cashOnDelivery.label), findsOneWidget);
      expect(
        find.textContaining('฿530'),
        findsWidgets,
        reason: 'the buyer must see what they are about to pay',
      );
    });

    testWidgets('states plainly that no gateway is connected', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = _container(_FakeOrderRepository())
        ..read(cartProvider.notifier).add(_product);
      container.read(checkoutDraftProvider.notifier).start(
        storeId: 's1',
        shippingAddress: 'เชียงใหม่ 50100',
      );

      await _pumpPayment(tester, container);

      // Never let the UI imply a real transfer happened. Both statements sit
      // below the fold of the lazy list, so scroll to each in turn.
      await _scrollTo(tester, find.text(PaymentStrings.slipNotAvailableHint));
      expect(
        find.text(PaymentStrings.slipNotAvailableHint),
        findsOneWidget,
        reason: 'a build without Cloudinary must say so instead of faking it',
      );
      await _scrollTo(tester, find.text(AppStrings.mvpPaymentNotice));
      expect(find.text(AppStrings.mvpPaymentNotice), findsOneWidget);
    });

    testWidgets('cash on delivery hides the QR and instructions', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = _container(_FakeOrderRepository())
        ..read(cartProvider.notifier).add(_product);
      container.read(checkoutDraftProvider.notifier).start(
        storeId: 's1',
        shippingAddress: 'เชียงใหม่ 50100',
      );

      await _pumpPayment(tester, container);

      expect(
        find.text(PaymentStrings.promptPayQrPlaceholder),
        findsOneWidget,
      );

      await tester.tap(find.text(PaymentMethod.cashOnDelivery.label));
      await tester.pumpAndSettle();

      expect(find.text(PaymentStrings.promptPayQrPlaceholder), findsNothing);
      expect(find.text(PaymentStrings.codHint), findsOneWidget);
    });

    testWidgets('offers a way out when reached without a draft', (
      WidgetTester tester,
    ) async {
      // A deep link to /checkout/payment must not show an empty form.
      final ProviderContainer container = _container(_FakeOrderRepository());

      await _pumpPayment(tester, container);

      expect(find.text(AppStrings.noDraftTitle), findsOneWidget);
      expect(find.text(AppStrings.continueShopping), findsOneWidget);
    });
  });

  group('confirming an order', () {
    testWidgets('writes the order, then empties the cart', (
      WidgetTester tester,
    ) async {
      final _FakeOrderRepository repo = _FakeOrderRepository();
      final ProviderContainer container = _container(repo)
        ..read(cartProvider.notifier).add(_product);
      container.read(checkoutDraftProvider.notifier).start(
        storeId: 's1',
        shippingAddress: 'เชียงใหม่ 50100',
      );

      await _pumpPayment(tester, container);

      await _scrollTo(tester, find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(repo.created, <String>[
        's1|เชียงใหม่ 50100|promptpay',
      ]);
      expect(
        container.read(cartProvider),
        isEmpty,
        reason: 'the basket is consumed only after the write succeeds',
      );
      expect(container.read(checkoutDraftProvider), isNull);
    });

    testWidgets('keeps the cart and shows a sentence when the write fails', (
      WidgetTester tester,
    ) async {
      // Losing the basket on a failed checkout is worse than an error
      // message: the buyer would have to rebuild their selection by hand.
      final _FakeOrderRepository repo = _FakeOrderRepository()
        ..failWith = const OrderWriteException('เซิร์ฟเวอร์ไม่ตอบ');
      final ProviderContainer container = _container(repo)
        ..read(cartProvider.notifier).add(_product);
      container.read(checkoutDraftProvider.notifier).start(
        storeId: 's1',
        shippingAddress: 'เชียงใหม่ 50100',
      );

      await _pumpPayment(tester, container);

      await _scrollTo(tester, find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('เซิร์ฟเวอร์ไม่ตอบ'));
      expect(find.text('เซิร์ฟเวอร์ไม่ตอบ'), findsOneWidget);
      expect(container.read(cartProvider), hasLength(1));
      expect(container.read(checkoutDraftProvider), isNotNull);
    });

    test('refuses an empty basket before touching the repository', () async {
      final _FakeOrderRepository repo = _FakeOrderRepository();
      final ProviderContainer container = _container(repo);
      container.read(checkoutDraftProvider.notifier).start(
        storeId: 's1',
        shippingAddress: 'เชียงใหม่ 50100',
      );

      final String? id = await container.read(placeOrderProvider.notifier).place(
        lines: const <CartLine>[],
        storeId: 's1',
        storeName: 'ร้านชิงไทร',
        buyerName: 'สมชาย ใจดี',
        shippingAddress: 'เชียงใหม่ 50100',
        method: PaymentMethod.promptPay,
      );

      expect(id, isNull);
      expect(repo.created, isEmpty);
    });

    test('a blank address is rejected without an error banner case', () async {
      final _FakeOrderRepository repo = _FakeOrderRepository();
      final ProviderContainer container = _container(repo);

      final String? id = await container.read(placeOrderProvider.notifier).place(
        lines: const <CartLine>[
          CartLine(
            productId: 'p1',
            storeId: 's1',
            name: 'กาแฟดอยอารามี',
            price: 480,
            quantity: 1,
          ),
        ],
        storeId: 's1',
        storeName: 'ร้านชิงไทร',
        buyerName: 'สมชาย ใจดี',
        shippingAddress: '   ',
        method: PaymentMethod.promptPay,
      );

      expect(id, isNull);
      expect(repo.created, isEmpty);
    });
  });

  group('the order detail timeline', () {
    testWidgets('shows every stage up to the current one', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = _container(_FakeOrderRepository());

      await _pumpHome(
        tester,
        container,
        const OrderDetailScreen(orderId: 'o1'),
      );

      expect(find.text(OrderStatus.pendingPayment.label), findsOneWidget);
      expect(find.text(OrderStatus.paid.label), findsOneWidget);
      expect(find.text(OrderStatus.awaitingShipment.label), findsOneWidget);
      // The current step appears twice: in the header chip and in the timeline.
      expect(find.text(OrderStatus.shipped.label), findsWidgets);
      expect(
        find.text(OrderStatus.completed.label),
        findsNothing,
        reason: 'a future stage must not be claimed as reached',
      );
    });

    testWidgets('a cancelled order turns the track into one terminal state', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = _container(_CancelledOrderRepository());

      await _pumpHome(
        tester,
        container,
        const OrderDetailScreen(orderId: 'o1'),
      );

      expect(find.text(PaymentStrings.statusCancelledHint), findsOneWidget);
      expect(find.text(OrderStatus.shipped.label), findsNothing);
    });

    testWidgets('a plain customer is not offered the status control', (
      WidgetTester tester,
    ) async {
      // firestore.rules only lets a seller or admin write `status`, so showing
      // the control to a customer would only produce a permission error.
      final ProviderContainer container = _container(_FakeOrderRepository());

      await _pumpHome(
        tester,
        container,
        const OrderDetailScreen(orderId: 'o1'),
      );

      expect(find.text(AppStrings.demoSellerControl), findsNothing);
    });

    testWidgets('a seller is offered the next legal step', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = _container(
        _FakeOrderRepository(),
        user: _seller,
      );

      await _pumpHome(
        tester,
        container,
        const OrderDetailScreen(orderId: 'o1'),
      );

      // The control is the last card on the page, outside the lazy viewport.
      await _scrollTo(tester, find.text(AppStrings.demoSellerControl));
      expect(find.text(AppStrings.demoSellerControl), findsOneWidget);
      // The next legal step from `shipped` is `completed`.
      expect(
        find.textContaining(OrderStatus.completed.label),
        findsOneWidget,
      );
    });

    test('advancing writes exactly one legal step', () async {
      final _FakeOrderRepository repo = _FakeOrderRepository();
      final ProviderContainer container = _container(repo);

      await container.read(advanceOrderStatusProvider.notifier).advance(
        'o1',
        OrderStatus.completed,
      );

      expect(repo.advanced, <String>['o1:completed']);
    });

    testWidgets(
        'an order opened on its own (after checkout) still has a way back', (
      WidgetTester tester,
    ) async {
      // After placing an order the payment screen `context.go`s straight onto
      // the detail route, leaving nothing below it — so no back arrow. The
      // footer action must fall back to going to the order list instead.
      final ProviderContainer container = _container(_FakeOrderRepository());
      final GoRouter router = GoRouter(
        initialLocation: AppRoutes.orderDetail('o1'),
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.orders,
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Center(child: Text('orders-list'))),
          ),
          GoRoute(
            path: AppRoutes.orderDetail(':orderId'),
            builder: (BuildContext context, GoRouterState state) =>
                const OrderDetailScreen(orderId: 'o1'),
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

      await _scrollTo(tester, find.text(AppStrings.backToOrders));
      expect(find.text(AppStrings.backToOrders), findsOneWidget);

      await tester.tap(find.text(AppStrings.backToOrders));
      await tester.pumpAndSettle();
      expect(find.text('orders-list'), findsOneWidget);
    });
  });
}