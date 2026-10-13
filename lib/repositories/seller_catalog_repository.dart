import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/product_draft.dart';
import '../models/product_model.dart';
import '../models/store_model.dart';
import '../models/store_profile_draft.dart';

//ไฟล์นี้เป็นตัวจัดการสินค้าและร้านของผู้ขาย โดยให้ Firestore Rules ตรวจสิทธิ์ซ้ำ
/// Reads and writes the seller's own catalogue.
///
/// The customer-facing [CatalogRepository] is deliberately read-only; a seller
/// editing their products needs the write half, which lives here so the rule
/// "browsing is read-only" stays true by construction.
///
/// Every write is shaped by `firestore.rules`:
///
///  * product/variant create & delete require the caller to own the product's
///    store ([sellsInStore] / [ownsProductStore] in the rules);
///  * a product update may not change `storeId` or `createdAt`.
///
/// `stockTotal` on the product is always recomputed from the variant rows in
/// the draft, so it can never drift out of sync with what the buyer picks.
/// จัดการสินค้าและร้านของผู้ขาย โดยให้ Firestore Rules ตรวจสิทธิ์ซ้ำ
class SellerCatalogRepository {
  SellerCatalogRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const String _stores = 'stores';
  static const String _products = 'products';
  static const String _variants = 'product_variants';

  /// A fresh, unused product id.
  ///
  /// The form asks for one up-front so uploaded images can live under
  /// `stores/{storeId}/products/{id}` before the product doc itself exists.
  String allocateProductId() => _firestore.collection(_products).doc().id;

  String get _uid {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw const ProductWriteException('ยังไม่ได้เข้าสู่ระบบ');
    }
    return user.uid;
  }

  /// The signed-in seller's store (1 Seller = 1 Store).
  Future<StoreModel?> getMyStore() async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection(_stores)
        .where('ownerUid', isEqualTo: _uid)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return StoreModel.fromFirestore(snap.docs.first.id, snap.docs.first.data());
  }

  /// Backward compatibility: returns the seller's single store in a list.
  Future<List<StoreModel>> listMyStores() async {
    final StoreModel? store = await getMyStore();
    return store == null ? const <StoreModel>[] : <StoreModel>[store];
  }

  /// Every product of one store, including drafts the customer never sees.
  ///
  /// Sorted in Dart instead of `orderBy` on the server: `storeId == x` plus a
  /// `createdAt` ordering would need a composite index just for a seller's
  /// own management list, and a seller sells a manageable number of items.
  Future<List<ProductModel>> listMyProducts(String storeId) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection(_products)
        .where('storeId', isEqualTo: storeId)
        .limit(200)
        .get();

    final List<ProductModel> products = snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              ProductModel.fromFirestore(d.id, d.data()),
        )
        .toList();
    products.sort((ProductModel a, ProductModel b) {
      final DateTime? aTime = a.createdAt;
      final DateTime? bTime = b.createdAt;
      final int byTime = (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
        aTime?.millisecondsSinceEpoch ?? 0,
      );
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return products;
  }

  Future<List<ProductVariantModel>> listVariants(String productId) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
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

  /// Real-time version of [getMyStore]: re-emits when the seller's store
  /// document changes (name, logo, region), so screens that render the profile
  /// update themselves instead of showing a cached copy.
  Stream<StoreModel?> watchMyStore() {
    return _firestore
        .collection(_stores)
        .where('ownerUid', isEqualTo: _uid)
        .limit(1)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
              .isEmpty
              ? null
              : StoreModel.fromFirestore(
                  snapshot.docs.first.id,
                  snapshot.docs.first.data(),
                ),
        );
  }

  /// Real-time version of [listMyProducts] — same sort, same "drafts
  /// included" contract, but re-emits as the seller edits products so the
  /// dashboard and list screens track Firestore without manual refreshes.
  Stream<List<ProductModel>> watchMyProducts(String storeId) {
    return _firestore
        .collection(_products)
        .where('storeId', isEqualTo: storeId)
        .limit(200)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<ProductModel> products = snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    ProductModel.fromFirestore(d.id, d.data()),
              )
              .toList();
          products.sort((ProductModel a, ProductModel b) {
            final DateTime? aTime = a.createdAt;
            final DateTime? bTime = b.createdAt;
            final int byTime = (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
              aTime?.millisecondsSinceEpoch ?? 0,
            );
            return byTime != 0 ? byTime : a.id.compareTo(b.id);
          });
          return products;
        });
  }

  /// Creates a product (status may still be `draft`) and its variant rows.
  ///
  /// The write is deliberately TWO steps even though a single batch would be
  /// atomic: the rules gate a variant create on `exists(products/{id})`, and
  /// Firestore evaluates a batch against the state *before* the batch — so a
  /// batch that contains both the product and its variants fails every check
  /// with `PERMISSION_DENIED` even when the seller owns the store.
  ///
  /// The product goes first (with `sellsInStore` — a rule that reads the
  /// store, not the product), then the variants in their own batch.
  Future<String> createProduct({
    required String productId,
    required StoreModel store,
    required ProductDraft draft,
  }) async {
    if (!draft.isValid || productId.isEmpty) {
      throw const ProductWriteException('ข้อมูลสินค้ายังไม่ครบถ้วน');
    }

    await _firestore
        .collection(_products)
        .doc(productId)
        .set(_productData(store: store, draft: draft, isCreate: true));

    if (draft.variants.isNotEmpty) {
      final WriteBatch batch = _firestore.batch();
      for (final VariantDraft variant in draft.variants) {
        batch.set(
          _firestore.collection(_variants).doc(),
          variant.toFirestore(productId: productId),
        );
      }
      await batch.commit();
    }
    return productId;
  }

  /// Replaces the editable fields on an existing product and rewrites its
  /// variants from the draft.
  ///
  /// Unlike create, one batch can hold all of it: the product already exists
  /// before the batch, so the variant rule's `exists(products/{id})` lookup
  /// (`ownsProductStore`) sees it.
  ///
  /// Variants are rebuilt wholesale (delete then re-create) rather than
  /// diffed, because a variant id is never referenced by an order snapshot —
  /// orders embed the product name/price, not the variant id — so there is no
  /// foreign key to preserve.
  Future<void> updateProduct({
    required ProductModel existing,
    required ProductDraft draft,
  }) async {
    if (!draft.isValid) {
      throw const ProductWriteException('ข้อมูลสินค้ายังไม่ครบถ้วน');
    }

    final WriteBatch batch = _firestore.batch();

    // `storeId` and `createdAt` are deliberately absent: the rules refuse an
    // update that touches them.
    batch.update(
      _firestore.collection(_products).doc(existing.id),
      _productData(draft: draft, isCreate: false),
    );

    // The draft's variant rows carry any kept image URLs, so the delete/re-
    // create loop below loses nothing the seller can see.
    final List<ProductVariantModel> old = await listVariants(existing.id);
    for (final ProductVariantModel variant in old) {
      batch.delete(_firestore.collection(_variants).doc(variant.id));
    }
    for (final VariantDraft variant in draft.variants) {
      batch.set(
        _firestore.collection(_variants).doc(),
        variant.toFirestore(productId: existing.id),
      );
    }
    await batch.commit();
  }

  /// Deletes a product and its variants. Order snapshots keep their own copy
  /// of the items, so history stays intact after a deletion.
  Future<void> deleteProduct(String productId) async {
    final WriteBatch batch = _firestore.batch();
    final List<ProductVariantModel> variants = await listVariants(productId);
    for (final ProductVariantModel variant in variants) {
      batch.delete(_firestore.collection(_variants).doc(variant.id));
    }
    batch.delete(_firestore.collection(_products).doc(productId));
    await batch.commit();
  }

  /// Updates the store's own profile fields.
  ///
  /// A plain `update`, not a `set`: writing the whole document would need every
  /// non-editable field again, and one the form does not know about would be
  /// silently wiped. `ownerUid`/`createdAt` are simply not in [draft], and the
  /// rules reject an update that mentions them anyway.
  ///
  /// `logoUrl` is written even when empty, because the form lets the seller
  /// clear it and silently keeping the old one would look like the save failed.
  /// `StoreModel.fromFirestore` reads an empty string back as `null`, so "no
  /// logo" stays a null and not a URL pointing at nothing.
  Future<void> updateStoreProfile({
    required StoreModel store,
    required StoreProfileDraft draft,
  }) async {
    if (!draft.isValid) {
      throw const ProductWriteException('กรุณากรอกชื่อร้าน');
    }

    await _firestore.collection(_stores).doc(store.id).update(<String, dynamic>{
      'name': draft.name.trim(),
      'description': draft.description.trim(),
      'province': draft.province.trim(),
      'region': draft.region.trim(),
      'community': draft.community.trim(),
      'coverImageUrl': draft.coverImageUrl.trim(),
      'logoUrl': draft.logoUrl?.trim() ?? '',
      'promptPayId': draft.promptPayId.trim(),
      'bankName': draft.bankName.trim(),
      'bankAccountName': draft.bankAccountName.trim(),
      'bankAccountNumber': draft.bankAccountNumber.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Map<String, dynamic> _productData({
    StoreModel? store,
    required ProductDraft draft,
    required bool isCreate,
  }) {
    final Map<String, dynamic> data = <String, dynamic>{
      'name': draft.name.trim(),
      'description': draft.description.trim(),
      'price': draft.price,
      'categoryId': draft.categoryId,
      'imageUrls': draft.imageUrls,
      'stockTotal': draft.stockTotal,
      'status': draft.status.value,
      'story': <String, dynamic>{
        'community': draft.story.community.trim(),
        'ingredients': draft.story.ingredients.trim(),
        'productionMethod': draft.story.productionMethod.trim(),
        'uniqueness': draft.story.uniqueness.trim(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (isCreate) {
      // province/region are copied from the store so the product grid can
      // filter by region without a join back to the store.
      data.addAll(<String, dynamic>{
        'storeId': store!.id,
        'province': store.province,
        'region': store.region,
        'ratingAvg': 0.0,
        'ratingCount': 0,
        'soldCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return data;
  }
}

/// A failure worth showing the seller, as opposed to a crash or a raw
/// permission error.
class ProductWriteException implements Exception {
  const ProductWriteException(this.message);

  final String message;

  @override
  String toString() => message;
}
