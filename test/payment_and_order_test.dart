import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:cross_file/cross_file.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:thai_promptpay/thai_promptpay.dart';
import 'package:thai_otop_marketplace/core/constants/app_enums.dart';
import 'package:thai_otop_marketplace/core/constants/app_strings.dart';
import 'package:thai_otop_marketplace/core/constants/payment_strings.dart';
import 'package:thai_otop_marketplace/core/routes/app_router.dart';
import 'package:thai_otop_marketplace/core/services/image/image_storage_service.dart';
import 'package:thai_otop_marketplace/features/cart/screens/payment_screen.dart';
import 'package:thai_otop_marketplace/features/orders/screens/order_detail_screen.dart';
import 'package:thai_otop_marketplace/features/orders/screens/order_tracking_screen.dart';
import 'package:thai_otop_marketplace/models/coupon_model.dart';
import 'package:thai_otop_marketplace/models/order_model.dart';
import 'package:thai_otop_marketplace/models/product_model.dart';
import 'package:thai_otop_marketplace/models/store_model.dart';
import 'package:thai_otop_marketplace/models/user_model.dart';
import 'package:thai_otop_marketplace/providers/auth_provider.dart';
import 'package:thai_otop_marketplace/providers/cart_provider.dart';
import 'package:thai_otop_marketplace/providers/catalog_provider.dart';
import 'package:thai_otop_marketplace/providers/coupon_provider.dart';
import 'package:thai_otop_marketplace/providers/image_storage_provider.dart';
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
  promptPayId: '0812345678',
  bankName: 'ธนาคารตัวอย่าง',
  bankAccountName: 'ร้านชิงไทร',
  bankAccountNumber: '1234567890',
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

/// Records what a screen asked the repository to do, without a Firestore.
class _FakeOrderRepository implements OrderRepository {
  _FakeOrderRepository({this.trackedOrderStatus = OrderStatus.shipped});

  final OrderStatus trackedOrderStatus;
  final List<String> created = <String>[];
  final List<String> advanced = <String>[];
  final List<String> storeQueries = <String>[];
  Object? failWith;
  CouponModel? lastCoupon;

  @override
  Future<String> createOrder({
    required List<OrderItem> items,
    required String storeId,
    required String storeName,
    required String buyerName,
    required String shippingAddress,
    required PaymentMethod method,
    String? slipUrl,
    String? note,
    CouponModel? coupon,
  }) async {
    if (failWith != null) throw failWith!;
    created.add('$storeId|$shippingAddress|${method.value}');
    submittedSlips.add(slipUrl ?? '');
    lastCoupon = coupon;
    return 'new-order-id';
  }

  final List<String> submittedSlips = <String>[];

  @override
  Future<void> advanceStatus(
    String orderId,
    OrderStatus next, {
    String? trackingNumber,
  }) async {
    // Only the tracking number is appended, and only when the seller supplies
    // one — so a status change that carries no number still records the bare
    // step and the assertion below stays readable.
    advanced.add(
      trackingNumber == null
          ? '$orderId:${next.value}'
          : '$orderId:${next.value}|$trackingNumber',
    );
  }

  @override
  Stream<List<OrderModel>> watchMyOrders() =>
      Stream<List<OrderModel>>.value(<OrderModel>[_order()]);

  @override
  Stream<List<OrderModel>> watchStoreOrders(String storeId) {
    storeQueries.add(storeId);
    return Stream<List<OrderModel>>.value(<OrderModel>[_order()]);
  }

  @override
  Stream<OrderModel?> watchOrder(String orderId) =>
      Stream<OrderModel?>.value(_order(status: trackedOrderStatus));
}

/// An order that was cancelled, for the terminal-state case.
class _CancelledOrderRepository extends _FakeOrderRepository {
  @override
  Stream<OrderModel?> watchOrder(String orderId) =>
      Stream<OrderModel?>.value(_order(status: OrderStatus.cancelled));
}

class _FakePaymentSlipPicker implements PaymentSlipPicker {
  @override
  Future<XFile?> pickImage() async => XFile.fromData(
    Uint8List.fromList(<int>[1, 2, 3]),
    path: 'transfer-slip.jpg',
    name: 'transfer-slip.jpg',
  );
}

class _FakePaymentSlipStorage implements ImageStorageService {
  @override
  Future<UploadedImage> uploadImage({
    required XFile file,
    required String folder,
  }) async => const UploadedImage(
    url: 'https://images.example.test/transfer-slip.jpg',
    publicId: 'payment-slip-test',
  );

  @override
  Future<void> deleteImage(String publicId) async {}

  @override
  String buildUrl({
    required String publicId,
    int? width,
    int? height,
    String gravity = 'auto',
  }) => 'https://images.example.test/$publicId';
}

ProviderContainer _container(
  _FakeOrderRepository repo, {
  UserModel? user,
  bool? cloudinaryConfigured,
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      authUserProvider.overrideWith(
        (Ref ref) => Stream<UserModel?>.value(user ?? _customer),
      ),
      orderRepositoryProvider.overrideWithValue(repo),
      paymentSlipPickerProvider.overrideWithValue(_FakePaymentSlipPicker()),
      imageStorageServiceProvider.overrideWithValue(_FakePaymentSlipStorage()),
      storeProvider.overrideWith(
        (Ref ref, String id) => Stream<StoreModel?>.value(_store),
      ),
      if (cloudinaryConfigured != null)
        cloudinaryConfiguredProvider.overrideWithValue(cloudinaryConfigured),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Pumps [child] inside the router the payment screen navigates with.
Future<void> _pumpPayment(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.payment,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.payment,
        builder: (BuildContext context, GoRouterState state) =>
            const PaymentScreen(),
      ),
      GoRoute(
        path: '/order/:orderId/tracking',
        builder: (BuildContext context, GoRouterState state) =>
            OrderTrackingScreen(orderId: state.pathParameters['orderId'] ?? ''),
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
Future<void> _pumpHome(
  WidgetTester tester,
  ProviderContainer container,
  Widget child,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

/// The ListView builds lazily, so the confirm button and the notice below it
/// live past the edge of the test viewport until scrolled into view.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300);
  await tester.pumpAndSettle();
}

Future<void> _attachSlip(WidgetTester tester) async {
  final Finder uploadButton = find.text(AppStrings.uploadSlip);
  await _scrollTo(tester, uploadButton);
  await tester.tap(uploadButton);
  await tester.pumpAndSettle();
}

void main() {
  // ตรวจการชำระเงินและการสร้าง/ติดตามออเดอร์โดยใช้ repository ปลอม
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
      container
          .read(checkoutDraftProvider.notifier)
          .start(storeId: 's1', shippingAddress: 'เชียงใหม่ 50100');

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
      // A build with no Cloudinary config has to admit it on the slip tab
      // rather than pretend an upload will succeed.
      final ProviderContainer container = _container(
        _FakeOrderRepository(),
        cloudinaryConfigured: false,
      )..read(cartProvider.notifier).add(_product);
      container
          .read(checkoutDraftProvider.notifier)
          .start(storeId: 's1', shippingAddress: 'เชียงใหม่ 50100');

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

    testWidgets('offers the slip tab once Cloudinary is configured', (
      WidgetTester tester,
    ) async {
      // The mirror image of the case above: with credentials in place the app
      // must not keep showing the "not configured" apology, or sellers will
      // believe uploading is broken.
      final ProviderContainer container = _container(
        _FakeOrderRepository(),
        cloudinaryConfigured: true,
      )..read(cartProvider.notifier).add(_product);
      container
          .read(checkoutDraftProvider.notifier)
          .start(storeId: 's1', shippingAddress: 'เชียงใหม่ 50100');

      await _pumpPayment(tester, container);

      expect(
        find.text(PaymentStrings.slipNotAvailableHint),
        findsNothing,
        reason: 'the config is present, so the warning would be a lie',
      );
    });

    testWidgets('cash on delivery hides the QR and instructions', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = _container(_FakeOrderRepository())
        ..read(cartProvider.notifier).add(_product);
      container
          .read(checkoutDraftProvider.notifier)
          .start(storeId: 's1', shippingAddress: 'เชียงใหม่ 50100');

      await _pumpPayment(tester, container);

      expect(find.byType(QrImageView), findsOneWidget);
      final String qrData = buildPromptPayPayload('0812345678', 53000)!;
      final PromptPayPayload payload = decodePromptPay(qrData);
      expect(payload.target.value, '0812345678');
      expect(payload.amountSatang, 53000);

      await tester.tap(find.text(PaymentMethod.cashOnDelivery.label));
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsNothing);
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
      container
          .read(checkoutDraftProvider.notifier)
          .start(storeId: 's1', shippingAddress: 'เชียงใหม่ 50100');

      await _pumpPayment(tester, container);

      await _attachSlip(tester);
      await _scrollTo(tester, find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(repo.created, <String>['s1|เชียงใหม่ 50100|promptpay']);
      expect(repo.submittedSlips, <String>[
        'https://images.example.test/transfer-slip.jpg',
      ]);
      expect(find.text('ติดตามสถานะ'), findsOneWidget);
      expect(find.text('กำลังจัดส่ง'), findsOneWidget);
      expect(find.text('รายละเอียดคำสั่งซื้อ'), findsNothing);
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
      container
          .read(checkoutDraftProvider.notifier)
          .start(storeId: 's1', shippingAddress: 'เชียงใหม่ 50100');

      await _pumpPayment(tester, container);

      await _attachSlip(tester);
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
      container
          .read(checkoutDraftProvider.notifier)
          .start(storeId: 's1', shippingAddress: 'เชียงใหม่ 50100');

      final String? id = await container
          .read(placeOrderProvider.notifier)
          .place(
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

    testWidgets(
      'non-COD confirmation stays disabled until a slip is attached',
      (WidgetTester tester) async {
        final ProviderContainer container = _container(_FakeOrderRepository())
          ..read(cartProvider.notifier).add(_product);
        container
            .read(checkoutDraftProvider.notifier)
            .start(storeId: 's1', shippingAddress: 'เชียงใหม่ 50100');

        await _pumpPayment(tester, container);
        await _scrollTo(tester, find.byType(FilledButton));
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );

        await _attachSlip(tester);
        await _scrollTo(tester, find.byType(FilledButton));
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
      },
    );

    testWidgets('cash on delivery can be confirmed without a slip', (
      WidgetTester tester,
    ) async {
      final _FakeOrderRepository repo = _FakeOrderRepository();
      final ProviderContainer container = _container(repo)
        ..read(cartProvider.notifier).add(_product);
      container
          .read(checkoutDraftProvider.notifier)
          .start(storeId: 's1', shippingAddress: 'เชียงใหม่ 50100');

      await _pumpPayment(tester, container);
      await tester.tap(find.text(PaymentMethod.cashOnDelivery.label));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byType(FilledButton));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(repo.created, <String>['s1|เชียงใหม่ 50100|cash_on_delivery']);
      expect(repo.submittedSlips, <String>['']);
    });

    test('a blank address is rejected without an error banner case', () async {
      final _FakeOrderRepository repo = _FakeOrderRepository();
      final ProviderContainer container = _container(repo);

      final String? id = await container
          .read(placeOrderProvider.notifier)
          .place(
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

    testWidgets('an applied coupon is handed to the order write', (
      WidgetTester tester,
    ) async {
      final _FakeOrderRepository repo = _FakeOrderRepository();
      final ProviderContainer container = _container(repo)
        ..read(cartProvider.notifier).add(_product);
      container
          .read(checkoutDraftProvider.notifier)
          .start(storeId: 's1', shippingAddress: 'เชียงใหม่ 50100');
      container.read(appliedCouponProvider.notifier).apply(
        CouponModel(
          id: 'c1',
          code: 'SAVE10',
          type: CouponType.percentage,
          value: 10,
          startsAt: DateTime(2020, 1, 1),
          expiresAt: DateTime(2100, 1, 1),
        ),
      );

      await _pumpPayment(tester, container);
      await tester.tap(find.text(PaymentMethod.cashOnDelivery.label));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(repo.lastCoupon?.code, 'SAVE10');
    });
  });

  group('a seller only ever sees their own store orders', () {
    // The seller inbox reads through `watchStoreOrders(storeId)` rather than
    // `watchMyOrders()`, because a seller is not the buyer of those orders.
    // If the two ever get mixed up the seller would see an empty inbox, or
    // worse, someone else's orders.
    test('the store inbox is read with the store id in scope', () async {
      final _FakeOrderRepository repo = _FakeOrderRepository();
      final ProviderContainer container = _container(repo);

      final List<OrderModel> orders = await container
          .read(orderRepositoryProvider)
          .watchStoreOrders('s1')
          .first;

      expect(repo.storeQueries, <String>['s1']);
      expect(orders, hasLength(1));
    });

    test(
      'a tracking number is forwarded when the seller ships an order',
      () async {
        // Without the number reaching the repository, the buyer sees a "shipped"
        // status with nothing to follow.
        final _FakeOrderRepository repo = _FakeOrderRepository();
        final ProviderContainer container = _container(repo);

        await container
            .read(orderRepositoryProvider)
            .advanceStatus(
              'o-1',
              OrderStatus.shipped,
              trackingNumber: 'THD-123456',
            );

        expect(repo.advanced, <String>['o-1:shipped|THD-123456']);
      },
    );
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
      final ProviderContainer container = _container(
        _CancelledOrderRepository(),
      );

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
      expect(find.textContaining(OrderStatus.completed.label), findsOneWidget);
    });

    test('advancing writes exactly one legal step', () async {
      final _FakeOrderRepository repo = _FakeOrderRepository();
      final ProviderContainer container = _container(repo);

      await container
          .read(advanceOrderStatusProvider.notifier)
          .advance('o1', OrderStatus.completed);

      expect(repo.advanced, <String>['o1:completed']);
    });

    testWidgets(
      'an order opened on its own (after checkout) still has a way back',
      (WidgetTester tester) async {
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
      },
    );
  });

  group('post-purchase status tracking', () {
    testWidgets('shows waiting for shipment as the current status', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = _container(
        _FakeOrderRepository(trackedOrderStatus: OrderStatus.awaitingShipment),
      );

      await _pumpHome(
        tester,
        container,
        const OrderTrackingScreen(orderId: 'o1'),
      );

      expect(find.text('ติดตามสถานะ'), findsOneWidget);
      expect(find.text('รอจัดส่ง'), findsWidgets);
      expect(find.text('จัดส่งสำเร็จ'), findsNothing);
    });

    testWidgets('shows successful delivery as the terminal status', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = _container(
        _FakeOrderRepository(trackedOrderStatus: OrderStatus.completed),
      );

      await _pumpHome(
        tester,
        container,
        const OrderTrackingScreen(orderId: 'o1'),
      );

      expect(find.text('จัดส่งสำเร็จ'), findsWidgets);
      expect(find.text('รอจัดส่ง'), findsWidgets);
    });
  });
}
