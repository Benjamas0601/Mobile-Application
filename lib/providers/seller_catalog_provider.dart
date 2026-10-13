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


//ดึงข้อมูลร้านค้าของผู้ขายที่ล็อกอินอยู่ (1 ผู้ขาย = 1 ร้าน) แบบสตรีมสด
//ไฟล์นี้เป็นตัวจัดการ state ของร้านค้าผู้ขายและสินค้าของร้านนั้น ๆ โดยใช้ Riverpod เป็นตัวจัดการ state
//ข้อมูลร้านค้าผู้ขายและสินค้าของร้านนั้น ๆ จะถูกดึงจาก Firestore ผ่าน SellerCatalogRepository
//ส่งไปยังหน้าจอที่ต้องการแสดงข้อมูลร้านค้าผู้ขายและสินค้าของร้านนั้น ๆ

/// Injected once and overridden in tests with a fake, so the seller screens
/// can be driven without a live Firestore.
/// จุดฉีด repository ฝั่งผู้ขาย; tests override จุดนี้เพื่อไม่ต่อ Firestore จริง
final Provider<SellerCatalogRepository> sellerCatalogRepositoryProvider =
    Provider<SellerCatalogRepository>((Ref ref) => SellerCatalogRepository());

/// The signed-in seller's single store (1 Seller = 1 Store), streamed live
/// so a profile edit made on another device shows up here without a manual
/// refresh.
final StreamProvider<StoreModel?> myStoreProvider = StreamProvider<StoreModel?>(
  (Ref ref) {
    final String? uid = ref.watch(authUserProvider).asData?.value?.uid; //ดึง uid ของผู้ใช้ที่ล็อกอินอยู่จาก authUserProvider
    if (uid == null) return Stream<StoreModel?>.value(null);
    return ref.watch(sellerCatalogRepositoryProvider).watchMyStore();
  },
);

/// Backward compatibility: returns the seller's single store in a list,
/// re-emitting whenever [myStoreProvider] (and thus Firestore) updates.
final StreamProvider<List<StoreModel>> myStoresProvider =
    StreamProvider<List<StoreModel>>((Ref ref) {
      return ref
          .watch(sellerCatalogRepositoryProvider)
          .watchMyStore()
          .map(
            (StoreModel? store) => store == null
                ? const <StoreModel>[]
                : <StoreModel>[store],
          );
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
final sellerDashboardMetricsProvider = Provider.autoDispose
    .family<AsyncValue<SellerDashboardMetrics>, String>((
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
        return AsyncValue.error(
          productsAsync.error!,
          productsAsync.stackTrace!,
        );
      }

      final List<OrderModel> orders = ordersAsync.value ?? const <OrderModel>[];
      final List<ProductModel> products =
          productsAsync.value ?? const <ProductModel>[];

      double revenue = 0.0;
      int pending = 0;
      int awaitingShipment = 0;

      for (final OrderModel o in orders) {
        if (!o.isCancelled && o.status != OrderStatus.pendingPayment) {
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

/// Every product of one store, drafts included, newest first — streamed live
/// so edits made elsewhere (or by the seller's own form, without relying on
/// the post-save `invalidate`) appear on the dashboard and lists immediately.
final myProductsProvider =
    StreamProvider.autoDispose.family<List<ProductModel>, String>((
      Ref ref,
      String storeId,
    ) {
      return ref.watch(sellerCatalogRepositoryProvider).watchMyProducts(storeId);
    });

/// A product variant that has almost run out, paired with its product.
///
/// The dashboard warns per *variant*, not per product: "the indigo one is
/// nearly gone" is a different fact from "the shop is nearly gone", and the
/// HTML design lists the colour in the warning line for exactly that reason.
/// Products whose variants carry no colour/size fall back to a null label so
/// the row still reads as the product name alone.
class LowStockVariant {
  const LowStockVariant({
    required this.product,
    required this.stock,
    this.variantName,
  });

  final ProductModel product;
  final int stock;
  final String? variantName;

  /// `ผ้าทอมือ (สีคราม)` — the product name plus the variant, so the seller
  /// can tell two rows apart at a glance.
  String get displayName =>
      variantName == null ? product.name : '${product.name} ($variantName)';
}

/// Everything that needs restocking, worst first — re-emitted live as the
/// seller's product list changes (edits, deletes, draft status flips), so the
/// dashboard warning tracks Firestore without a manual pull-to-refresh.
///
/// A product counts as low when its own `stockTotal` is low OR any of its
/// variants is. `stockTotal` is recomputed from the variants on every save, so
/// the two agree for a freshly written product; the per-variant check is what
/// catches a multi-colour product where one colour sold out and the rest did
/// not — the case the dashboard exists to surface.
final lowStockVariantsProvider = StreamProvider.autoDispose
    .family<List<LowStockVariant>, String>((Ref ref, String storeId) {
      final SellerCatalogRepository repository = ref.watch(
        sellerCatalogRepositoryProvider,
      );
      // Watches the same collection query as [myProductsProvider] (seller
      // repo `watchMyProducts`), then recomputes per emission so the warning
      // stays live without subscribing to the product provider separately.
      return repository.watchMyProducts(storeId).asyncMap(
        (List<ProductModel> products) async {
          final List<LowStockVariant> low = <LowStockVariant>[];
          for (final ProductModel product in products) {
            // A draft is the seller's own work in progress; warning about it is
            // noise, and a product with no variants falls back to stockTotal.
            if (product.status == ProductStatus.draft) continue;

            final List<ProductVariantModel> variants = await repository
                .listVariants(product.id);

            if (variants.isEmpty) {
              if (product.stockTotal <= lowStockThreshold) {
                low.add(
                  LowStockVariant(product: product, stock: product.stockTotal),
                );
              }
              continue;
            }

            for (final ProductVariantModel variant in variants) {
              if (variant.stock > lowStockThreshold) continue;
              low.add(
                LowStockVariant(
                  product: product,
                  stock: variant.stock,
                  variantName: variant.name.trim().isEmpty
                      ? null
                      : variant.name.trim(),
                ),
              );
            }
          }

          low.sort(
            (LowStockVariant a, LowStockVariant b) => a.stock.compareTo(b.stock),
          );
          return low;
        },
      );
    });

/// At or below this many units a variant is flagged as running out.
///
/// Three matches the HTML copy ("เหลือไม่ถึง 3 ชิ้น") and is small enough to be
/// worth restocking before a link dies, large enough not to nag on every unit
/// sale.
const int lowStockThreshold = 3;

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
      // ชื่อร้าน/รูป/ภาคปรากฏบนหน้าลูกค้า ต้องรีเฟรชรายการร้านใหม่ และหน้าแก้
      // โปรไฟล์เองก็ดู myStoreProvider (โดด) ซึ่งเป็น dependency ของ
      // myStoresProvider อีกชั้น — ถ้าไม่ invalidate เผื่อทั้งคู่ กลับเข้าหน้า
      // แก้ซ้ำจะเห็นข้อมูลเก่าค้างจาก cache
      ref.invalidate(myStoreProvider);
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
saveStoreProfileProvider = NotifierProvider<SaveStoreProfileController, bool>(
  SaveStoreProfileController.new,
);
