import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_enums.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/store_model.dart';
import '../repositories/catalog_repository.dart';

final Provider<CatalogRepository> catalogRepositoryProvider =
    Provider<CatalogRepository>((Ref ref) => CatalogRepository());

/// Active categories, ordered by `sortOrder`.
final categoriesProvider = FutureProvider<List<CategoryModel>>(
  (Ref ref) => ref.watch(catalogRepositoryProvider).listCategories(),
);

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
    if (categoryId == null) return;
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

/// The product list for the current filter. `autoDispose` so leaving the
/// catalogue frees the subscription instead of holding a live listener.
final productsProvider = FutureProvider.autoDispose<List<ProductModel>>((
  Ref ref,
) {
  final ProductFilter filter = ref.watch(productFilterProvider);
  return ref
      .watch(catalogRepositoryProvider)
      .listProducts(
        categoryId: filter.categoryId,
        region: filter.region,
        search: filter.search,
      );
});

final productProvider = FutureProvider.autoDispose
    .family<ProductModel?, String>(
      (Ref ref, String productId) =>
          ref.watch(catalogRepositoryProvider).getProduct(productId),
    );

final productVariantsProvider = FutureProvider.autoDispose
    .family<List<ProductVariantModel>, String>(
      (Ref ref, String productId) =>
          ref.watch(catalogRepositoryProvider).listVariants(productId),
    );

final storeProvider = FutureProvider.autoDispose.family<StoreModel?, String>(
  (Ref ref, String storeId) =>
      ref.watch(catalogRepositoryProvider).getStore(storeId),
);

final storesProvider = FutureProvider<List<StoreModel>>(
  (Ref ref) => ref.watch(catalogRepositoryProvider).listStores(),
);
