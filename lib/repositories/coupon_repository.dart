import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/coupon_model.dart';

/// Reads and administers discount codes.
///
/// The buyer-facing lookup lives here alongside the admin CRUD surface the
/// จัดการคูปอง screen uses; `firestore.rules` limits writes to admins, so the
/// repository never has to double-check the caller's role.
/// ค้นหาและจัดการคูปองในระบบ
class CouponRepository {
  CouponRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _coupons = 'coupons';

  /// The active-looking coupon whose code matches [code], or null.
  ///
  /// Codes are compared case-insensitively; `active` is checked by the caller
  /// through [CouponModel.isUsableFor] so the checkout can explain *why* a
  /// code that exists still cannot be used.
  Future<CouponModel?> findByCode(String code) async {
    final String normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;

    final QuerySnapshot<Map<String, dynamic>> result = await _firestore
        .collection(_coupons)
        .where('code', isEqualTo: normalized)
        .limit(1)
        .get();
    if (result.docs.isEmpty) return null;
    final DocumentSnapshot<Map<String, dynamic>> doc = result.docs.first;
    return CouponModel.fromFirestore(doc.id, doc.data() ?? const {});
  }

  /// Live list of every coupon for the admin screen, newest first.
  Stream<List<CouponModel>> watchAll() {
    return _firestore
        .collection(_coupons)
        .orderBy('code')
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    CouponModel.fromFirestore(doc.id, doc.data()),
              )
              .toList(),
        );
  }

  /// Creates a coupon with a server-generated id.
  Future<void> create(Map<String, dynamic> data) async {
    await _firestore.collection(_coupons).add(data);
  }

  /// Replaces every coupon field from the editor, keeping the id stable.
  Future<void> update(String id, Map<String, dynamic> data) async {
    await _firestore.collection(_coupons).doc(id).set(data);
  }

  /// Flips the discount on/off without losing the coupon's history.
  Future<void> setActive(String id, bool active) async {
    await _firestore.collection(_coupons).doc(id).update(<String, dynamic>{
      'active': active,
    });
  }

  /// Deletes the coupon for good.
  Future<void> delete(String id) async {
    await _firestore.collection(_coupons).doc(id).delete();
  }
}