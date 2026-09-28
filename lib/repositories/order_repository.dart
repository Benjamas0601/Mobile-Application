import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_enums.dart';
import '../core/utils/shipping.dart' as shipping;
import '../models/order_model.dart';

/// Reads and writes the buyer's own orders.
///
/// Every write here is shaped by `firestore.rules`:
///
///  * create requires `status == 'pending_payment'`, a numeric non-negative
///    `total`, `buyerUid == auth.uid` and `createdAt == request.time` — hence
///    [FieldValue.serverTimestamp], which resolves to the server clock and is
///    the only value that satisfies that last clause;
///  * only the seller of the order's store, or an admin, may change `status`.
///    The client checks [OrderStatus.allowedNext] first so an illegal step is
///    reported as a clear message rather than a permission error.
class OrderRepository {
  OrderRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const String _orders = 'orders';
  static const String _payments = 'payments';

  CollectionReference<Map<String, dynamic>> get _ordersCol =>
      _firestore.collection(_orders);

  String get _uid {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw const OrderWriteException('ยังไม่ได้เข้าสู่ระบบ');
    }
    return user.uid;
  }

  /// Creates an order and the matching payment record.
  ///
  /// Takes already-snapshotted [items] rather than cart lines so this layer
  /// never has to know about the local cart; the mapping lives in the provider
  /// above. Totals are recomputed here instead of trusted from the caller,
  /// because `firestore.rules` cannot check them and a client-sent total is
  /// not evidence of what was actually owed.
  ///
  /// The items are written as an embedded array rather than into
  /// `orders/{id}/items`, because the rules make that subcollection
  /// write-once-from-the-server. A payment document is skipped for cash on
  /// delivery — there is nothing to transfer yet.
  Future<String> createOrder({
    required List<OrderItem> items,
    required String storeId,
    required String storeName,
    required String buyerName,
    required String shippingAddress,
    required PaymentMethod method,
    String? note,
  }) async {
    if (items.isEmpty) {
      throw const OrderWriteException('ตะกร้าว่างอยู่');
    }
    if (storeId.isEmpty) {
      throw const OrderWriteException('ไม่พบข้อมูลร้านค้า');
    }
    if (shippingAddress.trim().isEmpty) {
      throw const OrderWriteException('กรุณากรอกที่อยู่จัดส่ง');
    }

    final double subtotal = items.fold(
      0.0,
      (double sum, OrderItem i) => sum + i.lineTotal,
    );
    final double shippingFee = shippingFeeFor(subtotal);

    final PaymentStatus paymentStatus = method == PaymentMethod.cashOnDelivery
        ? PaymentStatus.unpaid
        : PaymentStatus.awaitingTransfer;

    final Map<String, dynamic> data = <String, dynamic>{
      'buyerUid': _uid,
      'buyerName': buyerName,
      'storeId': storeId,
      'storeName': storeName,
      'items': <Map<String, dynamic>>[
        for (final OrderItem i in items) i.toFirestore(),
      ],
      'subtotal': subtotal,
      'shippingFee': shippingFee,
      'total': subtotal + shippingFee,
      'status': OrderStatus.pendingPayment.value,
      'paymentMethod': method.value,
      'paymentStatus': paymentStatus.value,
      'shippingAddress': <String, dynamic>{'full': shippingAddress.trim()},
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    final DocumentReference<Map<String, dynamic>> ref = _ordersCol.doc();
    // Batched so a failure cannot leave an order with no payment record.
    final WriteBatch batch = _firestore.batch();
    batch.set(ref, data);

    if (method != PaymentMethod.cashOnDelivery) {
      batch.set(
        _firestore.collection(_payments).doc(),
        <String, dynamic>{
          'orderId': ref.id,
          'buyerUid': _uid,
          'method': method.value,
          'amount': subtotal + shippingFee,
          'status': paymentStatus.value,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    }

    await batch.commit();
    return ref.id;
  }

  /// The signed-in buyer's orders, newest first.
  ///
  /// Uses the `orders` composite index on `buyerUid + createdAt`, already
  /// declared in `firestore.indexes.json` and deployed.
  Stream<List<OrderModel>> watchMyOrders() {
    return _ordersCol
        .where('buyerUid', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    OrderModel.fromFirestore(d.id, d.data()),
              )
              .toList(growable: false),
        );
  }

  Stream<OrderModel?> watchOrder(String orderId) {
    return _ordersCol.doc(orderId).snapshots().map((snap) {
      final Map<String, dynamic>? data = snap.data();
      if (data == null) return null;
      return OrderModel.fromFirestore(snap.id, data);
    });
  }

  /// Moves an order to [next], refusing a step the state machine disallows.
  ///
  /// The guard is duplicated in `firestore.rules`; this copy exists so the
  /// caller gets a sentence it can show, instead of a raw permission error.
  Future<void> advanceStatus(String orderId, OrderStatus next) async {
    final DocumentSnapshot<Map<String, dynamic>> snap = await _ordersCol
        .doc(orderId)
        .get();
    final Map<String, dynamic>? data = snap.data();
    if (data == null) {
      throw const OrderWriteException('ไม่พบคำสั่งซื้อนี้');
    }

    final OrderStatus current = OrderStatus.fromValue(data['status'] as String?);
    if (!current.allowedNext.contains(next)) {
      throw OrderWriteException('เปลี่ยนสถานะจาก "${current.label}" ไป "${next.label}" ไม่ได้');
    }

    // `shippedAt` is written alongside the status so the timeline has a real
    // date; the rules explicitly allow both fields to change together.
    final Map<String, dynamic> update = <String, dynamic>{
      'status': next.value,
      if (next == OrderStatus.shipped) 'shippedAt': FieldValue.serverTimestamp(),
    };

    // Paying moves the payment record too, so the seller sees the money state
    // without opening a second collection.
    if (next == OrderStatus.paid &&
        OrderStatus.fromValue(data['status'] as String?) ==
            OrderStatus.pendingPayment) {
      await _markPaymentVerified(orderId);
    }

    await _ordersCol.doc(orderId).update(update);
  }

  Future<void> _markPaymentVerified(String orderId) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection(_payments)
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
      await doc.reference.update(<String, dynamic>{
        'status': PaymentStatus.verified.value,
        'verifiedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}

/// Flat fee, matching the seed data's shipping model.
double shippingFeeFor(double subtotal) => shipping.shippingFeeFor(subtotal);

/// A failure worth showing the buyer, as opposed to a crash.
class OrderWriteException implements Exception {
  const OrderWriteException(this.message);

  final String message;

  @override
  String toString() => message;
}
