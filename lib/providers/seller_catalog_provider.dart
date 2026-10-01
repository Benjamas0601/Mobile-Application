import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_enums.dart' hide AsyncValue;
import '../models/order_model.dart';
import '../models/product_draft.dart';
import '../models/product_model.dart';
import '../models/store_model.dart';
import '../models/store_profile_draft.dart';
import '../repositories/seller_catalog_repository.dart';
import 'auth_provider.dart';
import 'order_provider.dart';

/// Injected once and overridden in tests with a fake, so the seller screens
/// can be driven without a live Firestore.
/// จุดฉีด repository ฝั่งผู้ขาย; tests override จุดนี้เพื่อไม่ต่อ Firestore จริง
final Provider<SellerCatalogRepository> sellerCatalogRepositoryProvider =
    Provider<SellerCatalogRepository>((Ref ref) => SellerCatalogRepository());

/// The signed-in seller's single store (1 Seller = 1 Store).
final FutureProvider<StoreModel?> myStoreProvider =
    FutureProvider<StoreModel?>((Ref ref) {
      final String? uid = ref.watch(authUserProvider).asData?.value?.uid;
      if (uid == null) return Future.value(null);
      return ref.watch(sellerCatalogRepositoryProvider).getMyStore();
    });

/// Backward compatibility: returns the seller's single store in a list.
final FutureProvider<List<StoreModel>> myStoresProvider =
    FutureProvider<List<StoreModel>>((Ref ref) async {
      final StoreModel? store = await ref.watch(myStoreProvider.future);
      return store == null ? const <StoreModel>[] : <StoreModel>[store];
    });

/// Metrics summary for the Seller Dashboard.
class SellerDashboardMetrics {
  const SellerDashboardMetrics({
    required this.totalRevenue,
    required this.pendingOrdersCount,
    required this.awaitingShipmentCount,
    required this.totalProducts,
    required this.lowStockCount,
  });

  final double totalRevenue;
  final int pendingOrdersCount;
  final int awaitingShipmentCount;
  final int totalProducts;
  final int lowStockCount;

  static const SellerDashboardMetrics zero = SellerDashboardMetrics(
    totalRevenue: 0,
    pendingOrdersCount: 0,
    awaitingShipmentCount: 0,
    totalProducts: 0,
    lowStockCount: 0,
  );
}

/// Computes live KPIs and metrics for one store's dashboard.
final sellerDashboardMetricsProvider =
    Provider.autoDispose.family<AsyncValue<SellerDashboardMetrics>, String>((
      Ref ref,
      String storeId,
    ) {
      final AsyncValue<List<OrderModel>> ordersAsync = ref.watch(
        storeOrdersProvider(storeId),
      );
      final AsyncValue<List<ProductModel>> productsAsync = ref.watch(
        myProductsProvider(storeId),
      );

      if (ordersAsync.isLoading || productsAsync.isLoading) {
        return const AsyncValue.loading();
      }

      if (ordersAsync.hasError) {
        return AsyncValue.error(ordersAsync.error!, ordersAsync.stackTrace!);
      }
      if (productsAsync.hasError) {
        return AsyncValue.error(productsAsync.error!, productsAsync.stackTrace!);
      }

      final List<OrderModel> orders = ordersAsync.value ?? const <OrderModel>[];
      final List<ProductModel> products =
          productsAsync.value ?? const <ProductModel>[];

      double revenue = 0.0;
      int pending = 0;
      int awaitingShipment = 0;

      for (final OrderModel o in orders) {
        if (!o.isCancelled &&
            o.status != OrderStatus.pendingPayment) {
          revenue += o.total;
        }
        if (o.status == OrderStatus.paid ||
            o.status == OrderStatus.pendingPayment) {
          pending++;
        }
        if (o.status == OrderStatus.awaitingShipment) {
          awaitingShipment++;
        }
      }

      int lowStock = 0;
      for (final ProductModel p in products) {
        if (p.stockTotal <= 5) {
          lowStock++;
        }
      }

      return AsyncValue.data(
        SellerDashboardMetrics(
          totalRevenue: revenue,
          pendingOrdersCount: pending,
          awaitingShipmentCount: awaitingShipment,
          totalProducts: products.length,
          lowStockCount: lowStock,
        ),
      );
    });

/// Every product of one store, drafts included, newest first.
final myProductsProvider = FutureProvider.autoDispose
    .family<List<ProductModel>, String>(
      (Ref ref, String storeId) => ref
          .watch(sellerCatalogRepositoryProvider)
          .listMyProducts(storeId),
    );

/// Saves a product: creates when [existing] is null, otherwise updates it.
///
/// Returns the product id on success, or null when the controller was already
/// busy or the draft failed validation. The busy guard mirrors the order
/// controller: a seller mashing Save must not double-write the catalogue.
class SaveProductController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<String?> save({
    required String productId,
    required StoreModel store,
    required ProductDraft draft,
    ProductModel? existing,
  }) async {
    if (state) return null;
    if (!draft.isValid || productId.isEmpty) return null;
    state = true;
    try {
      final SellerCatalogRepository repository = ref.read(
        sellerCatalogRepositoryProvider,
      );
      if (existing == null) {
        await repository.createProduct(
          productId: productId,
          store: store,
          draft: draft,
        );
      } else {
        await repository.updateProduct(existing: existing, draft: draft);
      }
      ref.invalidate(myProductsProvider);
      return productId;
    } finally {
      state = false;
    }
  }
}

final NotifierProvider<SaveProductController, bool> saveProductProvider =
    NotifierProvider<SaveProductController, bool>(SaveProductController.new);

  /// Deletes a product (with its variants).
class DeleteProductController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<String?> delete(ProductModel product) async {
    if (state) return null;
    state = true;
    try {
      await ref.read(sellerCatalogRepositoryProvider).deleteProduct(product.id);
      ref.invalidate(myProductsProvider);
      return product.id;
    } finally {
      state = false;
    }
  }
}

final NotifierProvider<DeleteProductController, bool> deleteProductProvider =
    NotifierProvider<DeleteProductController, bool>(
      DeleteProductController.new,
    );

/// Saves the store profile.
///
/// Returns true on success, false when the draft failed validation or the
/// write threw. The screen shows a sentence either way; it never has to render
/// a raw Firestore error, which is the same contract [SaveProductController]
/// offers.
class SaveStoreProfileController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<bool> save({
    required StoreModel store,
    required StoreProfileDraft draft,
  }) async {
    if (state || !draft.isValid) return false;
    state = true;
    try {
      await ref
          .read(sellerCatalogRepositoryProvider)
          .updateStoreProfile(store: store, draft: draft);
      // The store's name, images and region appear on the customer-facing
      // screens, so the shared store list has to re-read.
      ref.invalidate(myStoresProvider);
      return true;
    } on Object {
      return false;
    } finally {
      state = false;
    }
  }
}

final NotifierProvider<SaveStoreProfileController, bool>
saveStoreProfileProvider =
    NotifierProvider<SaveStoreProfileController, bool>(
      SaveStoreProfileController.new,
    );