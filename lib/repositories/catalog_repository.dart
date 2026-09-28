import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_enums.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/store_model.dart';

/// Read-only access to the public catalogue: categories, stores, products and
/// variants.
///
/// Every method here is readable while signed out — `firestore.rules` sets
/// `allow read: if true` on all four collections so browsing works before
/// anyone creates an account.
class CatalogRepository {
  CatalogRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String _categories = 'categories';
  static const String _stores = 'stores';
  static const String _products = 'products';
  static const String _variants = 'product_variants';

  static const int _maxLimit = 60;

  /// Active categories in the order the admin set, so the home tab never
  /// reshuffles between loads.
  ///
  /// The `active` flag is filtered here rather than in the query on purpose.
  /// A server-side `where('active', isEqualTo: true)` would need a composite
  /// index *and* would silently drop every category whose document predates
  /// the flag, because Firestore does not match missing fields. There are only
  /// a dozen categories, so reading them all and filtering in Dart is both
  /// cheaper to reason about and safe for partially-migrated data.
  Future<List<CategoryModel>> listCategories() async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _db
        .collection(_categories)
        .orderBy('sortOrder')
        .limit(_maxLimit)
        .get();

    return snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              CategoryModel.fromFirestore(d.id, d.data()),
        )
        .where((CategoryModel c) => c.active)
        .toList(growable: false);
  }

  /// Products for the home grid and category pages.
  ///
  /// [search] matches the product name only. Firestore cannot do a
  /// "contains" query, so a real search needs either a search index
  /// (Algolia/Typesense) or a normalised `searchTerms` array — noted as
  /// Week 5 work rather than faked here with a full-collection download.
  Future<List<ProductModel>> listProducts({
    String? categoryId,
    ThaiRegion? region,
    String? search,
    int limit = 30,
  }) async {
    Query<Map<String, dynamic>> query = _db.collection(_products);

    if (categoryId != null) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    if (region != null) {
      query = query.where('region', isEqualTo: region.value);
    }

    final QuerySnapshot<Map<String, dynamic>> snap = await query
        .orderBy('createdAt', descending: true)
        .limit(limit.clamp(1, _maxLimit))
        .get();

    List<ProductModel> products = snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              ProductModel.fromFirestore(d.id, d.data()),
        )
        .toList();

    // Drafts are hidden here rather than filtered in the query, so a seller
    // still sees their own drafts when the product page reads one by id.
    products = products.where((ProductModel p) => p.isVisible).toList();

    final String term = (search ?? '').trim().toLowerCase();
    if (term.isNotEmpty) {
      products = products
          .where((ProductModel p) => p.name.toLowerCase().contains(term))
          .toList();
    }

    return products;
  }

  Future<ProductModel?> getProduct(String productId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _db
        .collection(_products)
        .doc(productId)
        .get();
    if (!doc.exists) return null;
    return ProductModel.fromFirestore(doc.id, doc.data()!);
  }

  Future<List<StoreModel>> listStores({int limit = 30}) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _db
        .collection(_stores)
        .limit(limit)
        .get();
    return snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              StoreModel.fromFirestore(d.id, d.data()),
        )
        .toList(growable: false);
  }

  Future<StoreModel?> getStore(String storeId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _db
        .collection(_stores)
        .doc(storeId)
        .get();
    if (!doc.exists) return null;
    return StoreModel.fromFirestore(doc.id, doc.data()!);
  }

  /// Variants for one product. `stockTotal` on the product is the sum of
  /// these, but the list is what the buyer actually picks from.
  Future<List<ProductVariantModel>> listVariants(String productId) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _db
        .collection(_variants)
        .where('productId', isEqualTo: productId)
        .get();
    return snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              ProductVariantModel.fromFirestore(d.id, d.data()),
        )
        .toList(growable: false);
  }
}
