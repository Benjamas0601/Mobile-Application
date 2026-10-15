import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_enums.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/store_model.dart';
import '../repositories/catalog_repository.dart';

/// หมวดหมู่ที่ซ่อนไม่ให้แสดงบนแถวหมวดหมู่ของหน้าแรก (7 ต.ค. 2569)
///
/// เอกสาร `categories/{id}` ยังอยู่จริงใน Firestore และสินค้าในหมวดนั้นยัง
/// ปรากฏใน "ทั้งหมด" — มีแค่จุดนี้ที่ไม่แสดงเท่านั้น ข้อมูลไม่ถูกแตะ
const Set<String> kHomeHiddenCategoryIds = <String>{'handicraft', 'food'};

final Provider<CatalogRepository> catalogRepositoryProvider =
    Provider<CatalogRepository>((Ref ref) => CatalogRepository());

/// Active categories, ordered by `sortOrder`, streamed live from Firestore —
/// an admin adding/hiding a category appears on the home tab without a
/// refresh (`.snapshots()` lifecycle, same as the coupon tab).
final StreamProvider<List<CategoryModel>> categoriesProvider =
    StreamProvider<List<CategoryModel>>((Ref ref) {
      return ref.watch(catalogRepositoryProvider).watchCategories();
    });

/// The current browse filter.
class ProductFilter {
  const ProductFilter({this.categoryId, this.region, this.search});

  final String? categoryId;
  final ThaiRegion? region;
  final String? search;
}

/// Riverpod 3 removed `StateProvider`, so filter state lives in a [Notifier].
class ProductFilterNotifier extends Notifier<ProductFilter> {
  @override
  ProductFilter build() => const ProductFilter();

  /// Tapping the selected category clears it — a toggle, not a radio.
  void toggleCategory(String? categoryId) {
    // `null` is the "ทั้งหมด" chip: always clear the category (keeping the
    // region/search) so tapping it after picking one returns to "everything".
    if (categoryId == null) {
      if (state.categoryId == null) return;
      state = ProductFilter(region: state.region, search: state.search);
      return;
    }
    state = ProductFilter(
      categoryId: state.categoryId == categoryId ? null : categoryId,
      region: state.region,
      search: state.search,
    );
  }

  /// Same toggle for the region chips, so tapping "ทุกภาค" style chips clear.
  void toggleRegion(ThaiRegion region) {
    state = ProductFilter(
      categoryId: state.categoryId,
      region: state.region == region ? null : region,
      search: state.search,
    );
  }

  /// Free-text search. An empty string clears the term so the chip state and
  /// the repository query both fall back to "everything".
  void setSearch(String term) {
    final String trimmed = term.trim();
    state = ProductFilter(
      categoryId: state.categoryId,
      region: state.region,
      search: trimmed.isEmpty ? null : trimmed,
    );
  }

  void clear() => state = const ProductFilter();
}

final productFilterProvider =
    NotifierProvider<ProductFilterNotifier, ProductFilter>(
      ProductFilterNotifier.new,
    );

/// The product list for the current filter, streamed live. `autoDispose` so
/// leaving the catalogue frees the subscription instead of holding a live
/// listener.
final StreamProvider<List<ProductModel>> productsProvider =
    StreamProvider.autoDispose<List<ProductModel>>((Ref ref) {
      final ProductFilter filter = ref.watch(productFilterProvider);
      return ref
          .watch(catalogRepositoryProvider)
          .watchProducts(
            categoryId: filter.categoryId,
            region: filter.region,
            search: filter.search,
          );
    });

final productProvider = StreamProvider.autoDispose
    .family<ProductModel?, String>(
      (Ref ref, String productId) =>
          ref.watch(catalogRepositoryProvider).watchProduct(productId),
    );

final productVariantsProvider = StreamProvider.autoDispose
    .family<List<ProductVariantModel>, String>(
      (Ref ref, String productId) =>
          ref.watch(catalogRepositoryProvider).watchVariants(productId),
    );

final storeProvider = StreamProvider.autoDispose.family<StoreModel?, String>(
  (Ref ref, String storeId) =>
      ref.watch(catalogRepositoryProvider).watchStore(storeId),
);

final storesProvider = StreamProvider<List<StoreModel>>(
  (Ref ref) => ref.watch(catalogRepositoryProvider).watchStores(),
);