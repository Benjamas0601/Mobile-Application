import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/affiliate_commission_model.dart';
import '../models/affiliate_link_model.dart';
import '../models/product_model.dart';

/// Reads and writes the affiliate's own promotional links.
///
/// Scope mirrors the rule in `firestore.rules` — "link/commission เฉพาะของตัวเอง"
/// (`docs/05_architecture.md:178`). An affiliate may list, create and delete
/// their own links; commissions are written by the system after an order is
/// verified, so this repository only ever reads them.
class AffiliateRepository {
  AffiliateRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Random _random = Random();

  static const String _links = 'affiliate_links';
  static const String _commissions = 'affiliate_commissions';

  String get _uid {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw const AffiliateWriteException('ยังไม่ได้เข้าสู่ระบบ');
    }
    return user.uid;
  }

  /// Every link the signed-in affiliate owns, best-performing first.
  ///
  /// Sorted in Dart rather than by the server: `affiliateUid == x` plus a
  /// `clicks` ordering would need a composite index, and an affiliate
  /// realistically promotes a handful of products, not thousands.
  Future<List<AffiliateLinkModel>> listMyLinks() async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection(_links)
        .where('affiliateUid', isEqualTo: _uid)
        .limit(500)
        .get();

    final List<AffiliateLinkModel> links = snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              AffiliateLinkModel.fromFirestore(d.id, d.data()),
        )
        .toList();

    links.sort((AffiliateLinkModel a, AffiliateLinkModel b) {
      // Clicks first because that is what the affiliate is trying to move;
      // orders break a tie so the strongest converting link leads.
      final int byClicks = b.clicks.compareTo(a.clicks);
      if (byClicks != 0) return byClicks;
      final int byOrders = b.orders.compareTo(a.orders);
      if (byOrders != 0) return byOrders;
      return a.id.compareTo(b.id);
    });
    return links;
  }

  /// The affiliate's commission rows, newest first.
  Future<List<AffiliateCommissionModel>> listMyCommissions() async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection(_commissions)
        .where('affiliateUid', isEqualTo: _uid)
        .limit(500)
        .get();

    final List<AffiliateCommissionModel> commissions = snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              AffiliateCommissionModel.fromFirestore(d.id, d.data()),
        )
        .toList();

    commissions.sort((AffiliateCommissionModel a, AffiliateCommissionModel b) {
      final DateTime? aTime = a.createdAt;
      final DateTime? bTime = b.createdAt;
      final int byTime = (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
        aTime?.millisecondsSinceEpoch ?? 0,
      );
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return commissions;
  }

  /// Creates a promotional link for [product].
  ///
  /// `clicks` and `orders` start at zero and are incremented by the backend as
  /// traffic arrives — they are not editable by the affiliate, and the rules
  /// refuse any update that tries.
  ///
  /// Product name and cover image are copied onto the link so the affiliate's
  /// link list does not need a join, the same denormalisation the product grid
  /// uses for `province`/`region`.
  Future<AffiliateLinkModel> createLink(ProductModel product) async {
    final String uid = _uid;
    final String code = _generateCode(uid);

    final DocumentReference<Map<String, dynamic>> ref = _firestore
        .collection(_links)
        .doc();

    await ref.set(<String, dynamic>{
      'affiliateUid': uid,
      'productId': product.id,
      'productName': product.name,
      'productImageUrl': product.coverImageUrl ?? '',
      'storeId': product.storeId,
      'code': code,
      'clicks': 0,
      'orders': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return AffiliateLinkModel(
      id: ref.id,
      affiliateUid: uid,
      productId: product.id,
      code: code,
      clicks: 0,
      orders: 0,
      productName: product.name,
      productImageUrl: product.coverImageUrl ?? '',
    );
  }

  /// Removes one of the affiliate's own links.
  Future<void> deleteLink(String linkId) async {
    await _firestore.collection(_links).doc(linkId).delete();
  }

  /// A referral code that is readable aloud and short enough to type.
  ///
  /// The uid prefix keeps codes from different affiliates apart, so a code stays
  /// attributable even in the unlikely event that the random suffix collides.
  /// No uniqueness check runs here: `affiliate_links.code` is not indexed, and a
  /// duplicate would only make two links share a string that a redirect layer
  /// resolves by document id anyway.
  String _generateCode(String uid) {
    const String alphabet = 'abcdefghijkmnpqrstuvwxyz23456789';
    final String prefix = uid.replaceAll(RegExp('[^a-zA-Z0-9]'), '').toLowerCase();
    final String head = prefix.length >= 4 ? prefix.substring(0, 4) : prefix;
    final StringBuffer tail = StringBuffer();
    for (int i = 0; i < 4; i++) {
      tail.write(alphabet[_random.nextInt(alphabet.length)]);
    }
    return '$head-${tail.toString()}';
  }
}

/// A failure worth showing the affiliate, as opposed to a crash or a raw
/// permission error. Mirrors `ProductWriteException` in the seller repository.
class AffiliateWriteException implements Exception {
  const AffiliateWriteException(this.message);

  final String message;

  @override
  String toString() => message;
}
