import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:thai_otop_marketplace/core/config/cloudinary_config.dart';
import 'package:thai_otop_marketplace/core/constants/app_enums.dart';
import 'package:thai_otop_marketplace/core/constants/app_strings.dart';
import 'package:thai_otop_marketplace/core/utils/formatters.dart';
import 'package:thai_otop_marketplace/features/seller/screens/seller_home_screen.dart';
import 'package:thai_otop_marketplace/features/seller/screens/seller_order_list_screen.dart';
import 'package:thai_otop_marketplace/features/seller/screens/seller_store_edit_screen.dart';
import 'package:thai_otop_marketplace/models/order_model.dart';
import 'package:thai_otop_marketplace/models/product_draft.dart';
import 'package:thai_otop_marketplace/models/product_model.dart';
import 'package:thai_otop_marketplace/models/store_model.dart';
import 'package:thai_otop_marketplace/models/store_profile_draft.dart';
import 'package:thai_otop_marketplace/models/user_model.dart';
import 'package:thai_otop_marketplace/providers/auth_provider.dart';
import 'package:thai_otop_marketplace/providers/image_storage_provider.dart';
import 'package:thai_otop_marketplace/providers/order_provider.dart';
import 'package:thai_otop_marketplace/providers/seller_catalog_provider.dart';
import 'package:thai_otop_marketplace/repositories/order_repository.dart';
import 'package:thai_otop_marketplace/repositories/seller_catalog_repository.dart';

const UserModel _seller = UserModel(
  uid: 's1',
  displayName: 'ผู้ขาย',
  email: 'seller.north@example.com',
  roles: <UserRole>[UserRole.seller],
);

const UserModel _customer = UserModel(
  uid: 'u1',
  displayName: 'สมชาย ใจดี',
  email: 'customer@example.com',
);

const StoreModel _store = StoreModel(
  id: 's1',
  ownerUid: 's1',
  name: 'ร้านชิงไทร',
  province: 'เชียงใหม่',
  region: 'north',
  community: 'บ้านมะคำ',
  description: 'ร้านขายของฝากจากลำพูน',
  coverImageUrl: '',
);

OrderModel _order({
  String id = 'o1',
  OrderStatus status = OrderStatus.paid,
  String buyerName = 'สมชาย ใจดี',
  int minutesAgo = 30,
}) {
  return OrderModel(
    id: id,
    buyerUid: 'u1',
    buyerName: buyerName,
    storeId: _store.id,
    storeName: _store.name,
    status: status,
    paymentMethod: PaymentMethod.cashOnDelivery,
    paymentStatus: PaymentStatus.unpaid,
    shippingAddress: 'เชียงใหม่',
    items: const <OrderItem>[
      OrderItem(productId: 'p1', name: 'ผ้าไหม', price: 1290, quantity: 2),
    ],
    subtotal: 2580,
    shippingFee: 50,
    total: 2630,
    createdAt: DateTime(2026, 1, 2, 9, minutesAgo),
  );
}

/// The seller side of the order repository, with no Firestore.
class _FakeOrderRepository implements OrderRepository {
  _FakeOrderRepository({this.orders = const <OrderModel>[]});

  final List<OrderModel> orders;
  final List<String> advanced = <String>[];
  final List<String?> trackingNumbers = <String?>[];
  Object? failWith;

  @override
  Stream<List<OrderModel>> watchMyOrders() =>
      Stream<List<OrderModel>>.value(orders);

  @override
  Stream<List<OrderModel>> watchStoreOrders(String storeId) =>
      Stream<List<OrderModel>>.value(
        orders.where((OrderModel o) => o.storeId == storeId).toList(),
      );

  @override
  Stream<OrderModel?> watchOrder(String orderId) => Stream<OrderModel?>.value(
    orders.where((OrderModel o) => o.id == orderId).firstOrNull,
  );

  @override
  Future<void> advanceStatus(
    String orderId,
    OrderStatus next, {
    String? trackingNumber,
  }) async {
    if (failWith != null) throw failWith!;
    advanced.add('$orderId:${next.value}');
    trackingNumbers.add(trackingNumber);
  }

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
  }) async => 'new-order-id';
}

/// The seller catalogue, with no Firestore.
///
/// Only the reads and the store write matter here; the product methods exist
/// because the interface requires them, and the hub never calls them.
class _FakeSellerCatalogRepository implements SellerCatalogRepository {
  _FakeSellerCatalogRepository({this.stores = const <StoreModel>[_store]});

  final List<StoreModel> stores;
  final List<({String storeId, String name})> storeProfileWrites =
      <({String storeId, String name})>[];
  Object? failWith;

  @override
  Future<StoreModel?> getMyStore() async =>
      stores.isEmpty ? null : stores.first;

  @override
  Future<List<StoreModel>> listMyStores() async => stores;

  @override
  Future<void> updateStoreProfile({
    required StoreModel store,
    required StoreProfileDraft draft,
  }) async {
    if (failWith != null) throw failWith!;
    storeProfileWrites.add((storeId: store.id, name: draft.name));
  }

  @override
  String allocateProductId() => 'p1';

  @override
  Future<List<ProductModel>> listMyProducts(String storeId) async =>
      const <ProductModel>[];

  @override
  Future<List<ProductVariantModel>> listVariants(String productId) async =>
      const <ProductVariantModel>[];

  @override
  Future<String> createProduct({
    required String productId,
    required StoreModel store,
    required ProductDraft draft,
  }) async => productId;

  @override
  Future<void> updateProduct({
    required ProductModel existing,
    required ProductDraft draft,
  }) async {}

  @override
  Future<void> deleteProduct(String productId) async {}
}

ProviderContainer _container(
  _FakeSellerCatalogRepository catalog,
  _FakeOrderRepository orders, {
  UserModel user = _seller,
  bool? cloudinaryConfigured,
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      authUserProvider.overrideWith(
        (Ref ref) => Stream<UserModel?>.value(user),
      ),
      sellerCatalogRepositoryProvider.overrideWithValue(catalog),
      orderRepositoryProvider.overrideWithValue(orders),
      if (cloudinaryConfigured != null)
        cloudinaryConfiguredProvider.overrideWithValue(cloudinaryConfigured),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  Widget screen, {
  Size? surface,
}) async {
  if (surface != null) {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls the store form until its save button exists, then taps it.
///
/// The button is the last child of a `ListView`, and a `ListView` only builds
/// what is near the viewport — so on the default 800x600 test surface the
/// button is not in the tree at all, and `ensureVisible` has nothing to scroll
/// to. `scrollUntilVisible` is what a real user's scroll does.
Future<void> _tapSave(WidgetTester tester) async {
  final Finder button = find.widgetWithText(FilledButton, AppStrings.save);
  await tester.scrollUntilVisible(
    button,
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
  await tester.tap(button);
}

void main() {
  // ตรวจ role gate, กล่องออเดอร์ และการแก้โปรไฟล์ร้านใน Seller Hub
  setUpAll(() async {
    await initializeDateFormatting('th');
  });

  group('the seller hub', () {
    testWidgets('a customer is gated out', (WidgetTester tester) async {
      await _pump(
        tester,
        _container(
          _FakeSellerCatalogRepository(),
          _FakeOrderRepository(),
          user: _customer,
        ),
        const SellerHomeScreen(),
      );

      expect(find.text(AppStrings.errNotAuthorised), findsOneWidget);
    });

    testWidgets('offers products, orders and the store', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _container(_FakeSellerCatalogRepository(), _FakeOrderRepository()),
        const SellerHomeScreen(),
      );

      expect(find.text(AppStrings.navSellerProducts), findsOneWidget);
      expect(find.text(AppStrings.navSellerOrders), findsOneWidget);
      expect(find.text(AppStrings.navSellerStore), findsOneWidget);
    });

    testWidgets('shows the store it will edit', (WidgetTester tester) async {
      await _pump(
        tester,
        _container(_FakeSellerCatalogRepository(), _FakeOrderRepository()),
        const SellerHomeScreen(),
      );

      expect(find.text(_store.name), findsOneWidget);
    });

    testWidgets('a seller with no store is told why, not left guessing', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _container(
          _FakeSellerCatalogRepository(stores: const <StoreModel>[]),
          _FakeOrderRepository(),
        ),
        const SellerHomeScreen(),
      );

      expect(find.text(AppStrings.sellerNoStoreTitle), findsWidgets);
      expect(find.text(AppStrings.sellerNoStoreHint), findsWidgets);
    });
  });

  group('the seller order inbox', () {
    testWidgets('a customer is gated out', (WidgetTester tester) async {
      await _pump(
        tester,
        _container(
          _FakeSellerCatalogRepository(),
          _FakeOrderRepository(),
          user: _customer,
        ),
        const SellerOrderListScreen(),
      );

      expect(find.text(AppStrings.errNotAuthorised), findsOneWidget);
    });

    testWidgets('an empty inbox explains itself', (WidgetTester tester) async {
      await _pump(
        tester,
        _container(_FakeSellerCatalogRepository(), _FakeOrderRepository()),
        const SellerOrderListScreen(),
      );

      expect(find.text(AppStrings.sellerNoOrders), findsOneWidget);
    });

    testWidgets('lists the buyer, the total and the status', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _container(
          _FakeSellerCatalogRepository(),
          _FakeOrderRepository(orders: <OrderModel>[_order()]),
        ),
        const SellerOrderListScreen(),
      );

      expect(find.text('สมชาย ใจดี'), findsOneWidget);
      // Formatted through `Fmt.price` rather than typed out, so the test does
      // not pin a baht symbol or a separator that `formatters.dart` owns.
      expect(find.text(Fmt.price(2630)), findsOneWidget);
      // `OrderStatus.paid` and `PaymentStatus.verified` happen to share a
      // label, so this asserts presence rather than a count.
      expect(find.text(OrderStatus.paid.label), findsWidgets);
    });

    testWidgets('offers the next step the state machine allows', (
      WidgetTester tester,
    ) async {
      final _FakeOrderRepository repo = _FakeOrderRepository(
        orders: <OrderModel>[_order()],
      );
      await _pump(
        tester,
        _container(_FakeSellerCatalogRepository(), repo),
        const SellerOrderListScreen(),
      );

      // The label is a filled template ('เปลี่ยนเป็น "..."'), so match the
      // stable prefix instead of pinning the status name into the finder.
      final Finder button = find.ancestor(
        of: find.textContaining('เปลี่ยนเป็น'),
        matching: find.byType(FilledButton),
      );
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();

      // `paid` advances to `awaitingShipment`, and the write is the one the
      // repository already guards.
      expect(repo.advanced, <String>[
        'o1:${OrderStatus.awaitingShipment.value}',
      ]);
    });

    testWidgets('a cancelled order offers no step', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _container(
          _FakeSellerCatalogRepository(),
          _FakeOrderRepository(
            orders: <OrderModel>[_order(status: OrderStatus.cancelled)],
          ),
        ),
        const SellerOrderListScreen(),
      );

      expect(find.textContaining('เปลี่ยนเป็น'), findsNothing);
    });

    testWidgets('a completed order offers no step', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _container(
          _FakeSellerCatalogRepository(),
          _FakeOrderRepository(
            orders: <OrderModel>[_order(status: OrderStatus.completed)],
          ),
        ),
        const SellerOrderListScreen(),
      );

      expect(find.textContaining('เปลี่ยนเป็น'), findsNothing);
    });

    testWidgets('shipping asks for a tracking number and sends it', (
      WidgetTester tester,
    ) async {
      final _FakeOrderRepository repo = _FakeOrderRepository(
        orders: <OrderModel>[_order(status: OrderStatus.awaitingShipment)],
      );
      await _pump(
        tester,
        _container(_FakeSellerCatalogRepository(), repo),
        const SellerOrderListScreen(),
      );

      await tester.tap(
        find.ancestor(
          of: find.textContaining('เปลี่ยนเป็น'),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.sellerShipTrackingLabel),
        'TH123456789',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.sellerShipConfirm),
      );
      await tester.pumpAndSettle();

      expect(repo.advanced, <String>['o1:${OrderStatus.shipped.value}']);
      expect(repo.trackingNumbers, <String?>['TH123456789']);
    });

    testWidgets('leaving the tracking number blank still ships', (
      WidgetTester tester,
    ) async {
      final _FakeOrderRepository repo = _FakeOrderRepository(
        orders: <OrderModel>[_order(status: OrderStatus.awaitingShipment)],
      );
      await _pump(
        tester,
        _container(_FakeSellerCatalogRepository(), repo),
        const SellerOrderListScreen(),
      );

      await tester.tap(
        find.ancestor(
          of: find.textContaining('เปลี่ยนเป็น'),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();

      // A hand-delivered parcel has no courier number; the seller must still
      // be able to mark the order shipped.
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.sellerShipConfirm),
      );
      await tester.pumpAndSettle();

      expect(repo.advanced, <String>['o1:${OrderStatus.shipped.value}']);
      expect(repo.trackingNumbers, <String?>['']);
    });

    testWidgets('dismissing the tracking sheet changes nothing', (
      WidgetTester tester,
    ) async {
      final _FakeOrderRepository repo = _FakeOrderRepository(
        orders: <OrderModel>[_order(status: OrderStatus.awaitingShipment)],
      );
      await _pump(
        tester,
        _container(_FakeSellerCatalogRepository(), repo),
        const SellerOrderListScreen(),
      );

      await tester.tap(
        find.ancestor(
          of: find.textContaining('เปลี่ยนเป็น'),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, AppStrings.sellerShipCancel),
      );
      await tester.pumpAndSettle();

      expect(repo.advanced, isEmpty);
    });

    testWidgets('the status filter narrows the list', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _container(
          _FakeSellerCatalogRepository(),
          _FakeOrderRepository(
            orders: <OrderModel>[
              _order(id: 'o1', status: OrderStatus.paid),
              _order(id: 'o2', status: OrderStatus.shipped),
            ],
          ),
        ),
        const SellerOrderListScreen(),
      );

      // The row renders the id with its prefix, so search within the text.
      expect(find.textContaining('o1'), findsOneWidget);
      expect(find.textContaining('o2'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(FilterChip, OrderStatus.shipped.label),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('o1'), findsNothing);
      expect(find.textContaining('o2'), findsOneWidget);
    });
  });

  group('the store profile form', () {
    testWidgets('seeds the stored values into every field', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _container(_FakeSellerCatalogRepository(), _FakeOrderRepository()),
        const SellerStoreEditScreen(),
        // A tall surface so the whole form is laid out at once. The default
        // 800x600 leaves the save button outside a `ListView`'s build window,
        // which is a lazy-build artefact rather than a defect in the screen.
        surface: const Size(500, 2000),
      );

      expect(find.text(_store.name), findsOneWidget);
      expect(find.text(_store.description), findsOneWidget);
      expect(find.text(_store.province), findsOneWidget);
      expect(find.text(_store.community), findsOneWidget);
    });

    testWidgets('refuses to save an empty name', (WidgetTester tester) async {
      final _FakeSellerCatalogRepository repo = _FakeSellerCatalogRepository();
      await _pump(
        tester,
        _container(repo, _FakeOrderRepository()),
        const SellerStoreEditScreen(),
        surface: const Size(500, 2000),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.sellerStoreNameLabel),
        '  ',
      );
      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(repo.storeProfileWrites, isEmpty);
      expect(find.text(AppStrings.sellerStoreNameRequired), findsOneWidget);
    });

    testWidgets('upload explains itself when Cloudinary is not configured', (
      WidgetTester tester,
    ) async {
      // No `--dart-define` in a test run, so the provider is false. Tapping
      // upload must say why it cannot work instead of opening a picker that
      // would fail later with a permission error.
      await _pump(
        tester,
        _container(
          _FakeSellerCatalogRepository(),
          _FakeOrderRepository(),
          cloudinaryConfigured: false,
        ),
        const SellerStoreEditScreen(),
        surface: const Size(500, 2000),
      );

      await tester.tap(
        find.widgetWithText(OutlinedButton, AppStrings.uploadFromDevice).first,
      );
      await tester.pumpAndSettle();

      expect(find.text(CloudinaryConfig.notConfiguredMessage), findsOneWidget);
    });

    testWidgets('a failed write says so instead of pretending', (
      WidgetTester tester,
    ) async {
      final _FakeSellerCatalogRepository repo = _FakeSellerCatalogRepository()
        ..failWith = StateError('PERMISSION_DENIED');
      await _pump(
        tester,
        _container(repo, _FakeOrderRepository()),
        const SellerStoreEditScreen(),
        surface: const Size(500, 2000),
      );

      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.sellerStoreSaveFailed), findsOneWidget);
    });
  });
}
