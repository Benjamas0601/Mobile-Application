import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/coupon_model.dart';

/// Reads discount codes for the checkout.
///
/// Coupons are administered by an admin, so this repository only performs the
/// by-code lookup the checkout needs; `firestore.rules` already limits writes
/// to admins.
/// ค้นหาคูปองตามรหัสที่ผู้ซื้อกรอกตอนชำระเงิน
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
}