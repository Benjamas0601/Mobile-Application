import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_enums.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/store_model.dart';

//ไฟล์นี้เป็นตัวจัดการข้อมูลแคตตาล็อกสาธารณะ (categories, stores, products, variants) โดยใช้ Firebase Firestore เป็น backend
/// Read-only access to the public catalogue: categories, stores, products and
/// variants.
///
/// Every method here is readable while signed out — `firestore.rules` sets
/// `allow read: if true` on all four collections so browsing works before
/// anyone creates an account.
/// อ่านข้อมูลแคตตาล็อกสาธารณะ; การเขียนสินค้าแยกไปฝั่งผู้ขาย
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

  /// Real-time categories: re-emits whenever a document in the collection
  /// changes, so an admin's edit shows up on the home tab without a refresh.
  /// The `active` filter is applied in Dart for the same reason as
  /// [listCategories] (missing-field-safe, no composite index).
  Stream<List<CategoryModel>> watchCategories() {
    return _db
        .collection(_categories)
        .orderBy('sortOrder')
        .limit(_maxLimit)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    CategoryModel.fromFirestore(d.id, d.data()),
              )
              .where((CategoryModel c) => c.active)
              .toList(growable: false),
        );
  }

  /// Real-time product list for the home grid and category pages — same
  /// filtering (visible only, name search) as [listProducts], applied to every
  /// snapshot so new/edited products appear live.
  Stream<List<ProductModel>> watchProducts({
    String? categoryId,
    ThaiRegion? region,
    String? search,
    int limit = 30,
  }) {
    Query<Map<String, dynamic>> query = _db.collection(_products);

    if (categoryId != null) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    if (region != null) {
      query = query.where('region', isEqualTo: region.value);
    }

    final Query<Map<String, dynamic>> ordered = query
        .orderBy('createdAt', descending: true)
        .limit(limit.clamp(1, _maxLimit));

    return ordered.snapshots().map(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        List<ProductModel> products = snapshot.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                  ProductModel.fromFirestore(d.id, d.data()),
            )
            .toList();

        products = products.where((ProductModel p) => p.isVisible).toList();

        final String term = (search ?? '').trim().toLowerCase();
        if (term.isNotEmpty) {
          products = products
              .where((ProductModel p) => p.name.toLowerCase().contains(term))
              .toList();
        }

        return products;
      },
    );
  }

  /// Live products for a fixed set of ids, in the order given.
  ///
  /// Used by the ถูกใจ screen: the favourite ids arrive in "newest first"
  /// order and the grid should keep it, so results are re-sorted to match the
  /// input instead of Firestore's (arbitrary) `whereIn` order. Firestore caps
  /// `whereIn` at 30 values per query, which is far beyond any realistic
  /// wishlist; anything past that would need chunking.
  Stream<List<ProductModel>> watchProductsByIds(List<String> ids) {
    final List<String> wanted = ids.take(30).toList(growable: false);
    if (wanted.isEmpty) {
      return Stream<List<ProductModel>>.value(const <ProductModel>[]);
    }

    return _db
        .collection(_products)
        .where(FieldPath.documentId, whereIn: wanted)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final Map<String, ProductModel> byId = <String, ProductModel>{
            for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                in snapshot.docs)
              doc.id: ProductModel.fromFirestore(doc.id, doc.data()),
          };

          return wanted
              .where(byId.containsKey)
              .map((String id) => byId[id]!)
              .where((ProductModel p) => p.isVisible)
              .toList(growable: false);
        });
  }

  /// Real-time single product.
  Stream<ProductModel?> watchProduct(String productId) {
    return _db
        .collection(_products)
        .doc(productId)
        .snapshots()
        .map(
          (DocumentSnapshot<Map<String, dynamic>> doc) => doc.exists
              ? ProductModel.fromFirestore(doc.id, doc.data()!)
              : null,
        );
  }

  /// Real-time variants for one product.
  Stream<List<ProductVariantModel>> watchVariants(String productId) {
    return _db
        .collection(_variants)
        .where('productId', isEqualTo: productId)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    ProductVariantModel.fromFirestore(d.id, d.data()),
              )
              .toList(growable: false),
        );
  }

  Future<StoreModel?> getStore(String storeId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _db
        .collection(_stores)
        .doc(storeId)
        .get();
    if (!doc.exists) return null;
    return StoreModel.fromFirestore(doc.id, doc.data()!);
  }

  /// Real-time single store.
  Stream<StoreModel?> watchStore(String storeId) {
    return _db
        .collection(_stores)
        .doc(storeId)
        .snapshots()
        .map(
          (DocumentSnapshot<Map<String, dynamic>> doc) => doc.exists
              ? StoreModel.fromFirestore(doc.id, doc.data()!)
              : null,
        );
  }

  /// Real-time store list.
  Stream<List<StoreModel>> watchStores({int limit = 30}) {
    return _db
        .collection(_stores)
        .limit(limit)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    StoreModel.fromFirestore(d.id, d.data()),
              )
              .toList(growable: false),
        );
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
