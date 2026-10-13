import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_enums.dart';
import '../core/utils/shipping.dart' as shipping;
import '../models/order_model.dart';
import 'notification_repository.dart';

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
/// สร้างและติดตามออเดอร์ โดยเก็บ snapshot เพื่อรักษาราคาตอนซื้อ
class OrderRepository {
  OrderRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const String _orders = 'orders';
  static const String _payments = 'payments';
  static const String _products = 'products';

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
    String? slipUrl,
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
    final String? submittedSlip = slipUrl?.trim();
    if (method.requiresSlip &&
        (submittedSlip == null || submittedSlip.isEmpty)) {
      throw const OrderWriteException(
        'กรุณาแนบหลักฐานการโอนก่อนยืนยันคำสั่งซื้อ',
      );
    }

    final double subtotal = items.fold(
      0.0,
      (double sum, OrderItem i) => sum + i.lineTotal,
    );
    final double shippingFee = shippingFeeFor(subtotal);

    final PaymentStatus paymentStatus = method == PaymentMethod.cashOnDelivery
        ? PaymentStatus.unpaid
        : PaymentStatus.submitted;

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
      batch.set(_firestore.collection(_payments).doc(), <String, dynamic>{
        'orderId': ref.id,
        'buyerUid': _uid,
        'method': method.value,
        'amount': subtotal + shippingFee,
        'status': paymentStatus.value,
        'slipUrl': submittedSlip,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    // แจ้งเจ้าของร้านแบบ best-effort — แจ้งเตือนพลาดก็ต้องไม่ทำให้ออเดอร์พัง
    await _notifyStoreOwner(ref.id, storeId, storeName, subtotal + shippingFee);
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

  /// The orders of one store, newest first — the seller's inbox.
  ///
  /// The `where('storeId', ...)` clause is not an optimisation, it is what
  /// makes the read possible at all: `firestore.rules` evaluates a `list`
  /// against the query's *potential* result set, not the real documents, so a
  /// rule clause can only be satisfied when a query constraint proves it. The
  /// `orders.allow list` seller branch is exactly `sellsInStore(storeId)`,
  /// which is what this filter supplies. A seller with several stores calls
  /// this once per store, or drops the filter and uses an `in` query.
  ///
  /// Sorted in Dart instead of `orderBy` for the same reason as the seller's
  /// product list: `storeId == x` + `createdAt` ordering would need a
  /// composite index, and a store's recent orders are few enough to cap.
  Stream<List<OrderModel>> watchStoreOrders(String storeId) {
    return _ordersCol
        .where('storeId', isEqualTo: storeId)
        .limit(200)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
          final List<OrderModel> orders = snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    OrderModel.fromFirestore(d.id, d.data()),
              )
              .toList();
          orders.sort((OrderModel a, OrderModel b) {
            // `OrderModel.createdAt` is non-nullable (it falls back to the
            // epoch), so a missing timestamp sorts last instead of throwing.
            final int byTime = b.createdAt.compareTo(a.createdAt);
            return byTime != 0 ? byTime : a.id.compareTo(b.id);
          });
          return orders;
        });
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
  /// Runs as a transaction so the order status and the product stock it touches
  /// change together: the seller confirming an order (`pendingPayment` -> `paid`)
  /// deducts each item's quantity, and cancelling that same confirmed order puts
  /// the units back. A half-applied step would either oversell or lose stock, so
  /// both writes share one transaction.
  ///
  /// The guard is duplicated in `firestore.rules`; this copy exists so the
  /// caller gets a sentence it can show, instead of a raw permission error.
  ///
  /// [trackingNumber] is written only alongside `shipped`: an OTOP seller often
  /// delivers by hand and has no courier number, so it stays optional — but
  /// when the seller does have one, the buyer needs it in the order history.
  Future<void> advanceStatus(
    String orderId,
    OrderStatus next, {
    String? trackingNumber,
  }) async {
    final DocumentReference<Map<String, dynamic>> orderRef = _ordersCol.doc(
      orderId,
    );
    final String? tracking = trackingNumber?.trim();

    OrderStatus? movedFrom;
    await _firestore.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(orderRef);
      final Map<String, dynamic>? data = snap.data();
      if (data == null) {
        throw const OrderWriteException('ไม่พบคำสั่งซื้อนี้');
      }

      final OrderStatus current = OrderStatus.fromValue(
        data['status'] as String?,
      );
      if (!current.allowedNext.contains(next)) {
        throw OrderWriteException(
          'เปลี่ยนสถานะจาก "${current.label}" ไป "${next.label}" ไม่ได้',
        );
      }

      // `shippedAt` is written alongside the status so the timeline has a real
      // date; the rules explicitly allow both fields to change together.
      final Map<String, dynamic> update = <String, dynamic>{
        'status': next.value,
        if (next == OrderStatus.shipped) ...<String, dynamic>{
          'shippedAt': FieldValue.serverTimestamp(),
          if (tracking != null && tracking.isNotEmpty)
            'trackingNumber': tracking,
        },
      };

      // Deduct stock the moment the seller confirms (paid), and restore it if
      // that confirmed order is later cancelled. `stockDeductedAt` makes both
      // one-shot: it is only set on a real deduction, so a plain cancel of an
      // unpaid order never invents stock that was never taken.
      final bool deducting =
          next == OrderStatus.paid && current == OrderStatus.pendingPayment;
      final bool restoring =
          next == OrderStatus.cancelled && data['stockDeductedAt'] != null;

      if (deducting || restoring) {
        await _applyStockDelta(
          tx,
          data['items'],
          deduct: deducting,
        );
        if (deducting) {
          update['stockDeductedAt'] = FieldValue.serverTimestamp();
        }
      }

      tx.update(orderRef, update);
      movedFrom = current;
    });

    // Paying moves the payment record too, so the seller sees the money state
    // without opening a second collection. Kept outside the transaction because
    // it looks the payment up by query, which a transaction cannot run.
    if (next == OrderStatus.paid &&
        movedFrom == OrderStatus.pendingPayment) {
      await _markPaymentVerified(orderId);
    }
    // ผู้ซื้อควรได้เห็นสถานะที่สำคัญ — best-effort เช่นกัน
    await _notifyOrderParty(orderId, next, tracking);
  }

  /// แจ้งเจ้าของร้านว่ามีออเดอร์ใหม่เข้ามา (ผู้ส่งคือผู้ซื้อ ซึ่งเป็นคู่ค้า
  /// ตาม rules — `orderCounterpartyAllows` ใน firestore.rules)
  Future<void> _notifyStoreOwner(
    String orderId,
    String storeId,
    String storeName,
    double total,
  ) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> store = await _firestore
          .collection('stores')
          .doc(storeId)
          .get();
      final String ownerUid = (store.data()?['ownerUid'] as String?) ?? '';
      // ข้ามถ้าไม่มีเจ้าของ หรือสั่งจากร้านตัวเอง
      if (ownerUid.isEmpty || ownerUid == _uid) return;
      await _notifications().create(
        userId: ownerUid,
        type: NotificationType.orderStatus,
        title: 'มีคำสั่งซื้อใหม่',
        body: '$storeName · ออเดอร์ #$orderId · '
            '${total.toStringAsFixed(0)} บาท',
        orderId: orderId,
      );
    } catch (_) {
      // best-effort: อย่าให้การแจ้งเตือนทำให้การสั่งซื้อล้มเหลว
    }
  }

  /// แจ้งผู้ซื้อเมื่อสถานะออเดอร์เปลี่ยนไปจุดที่เขาควรรู้ (ผู้ส่งคือผู้ขาย)
  Future<void> _notifyOrderParty(
    String orderId,
    OrderStatus next,
    String? tracking,
  ) async {
    // เปลี่ยนผ่านภายใน (awaitingShipment) ไม่ต้องรบกวนผู้ซื้อ
    if (next != OrderStatus.paid &&
        next != OrderStatus.shipped &&
        next != OrderStatus.completed &&
        next != OrderStatus.cancelled) {
      return;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> order = await _firestore
          .collection(_orders)
          .doc(orderId)
          .get();
      final String buyerUid = (order.data()?['buyerUid'] as String?) ?? '';
      if (buyerUid.isEmpty || buyerUid == _uid) return;
      final String base = 'ออเดอร์ #$orderId';
      final String? trimmedTracking = tracking?.trim();
      await _notifications().create(
        userId: buyerUid,
        type: NotificationType.orderStatus,
        title: 'สถานะออเดอร์: ${next.label}',
        body: next == OrderStatus.shipped &&
                trimmedTracking != null &&
                trimmedTracking.isNotEmpty
            ? '$base · เลขพัสดุ $trimmedTracking'
            : base,
        orderId: orderId,
      );
    } catch (_) {
      // best-effort
    }
  }

  /// สร้าง NotificationRepository ที่ชี้ไปที่ firestore/auth ชุดเดียวกับคลาสนี้
  /// เพื่อให้ hook การแจ้งเตือนไม่ต้องเดา instance
  NotificationRepository _notifications() =>
      NotificationRepository(firestore: _firestore, auth: _auth);

  /// Applies [deduct] to every product on the order inside [tx].
  ///
  /// Stock is clamped at zero so a race between two buyers can never drive a
  /// product negative, and `soldCount` moves in the same direction. A product
  /// the seller has since deleted is skipped rather than failing the whole step.
  Future<void> _applyStockDelta(
    Transaction tx,
    Object? rawItems, {
    required bool deduct,
  }) async {
    if (rawItems is! List) return;
    for (final Object? raw in rawItems) {
      if (raw is! Map) continue;
      final String productId = (raw['productId'] as String?) ?? '';
      if (productId.isEmpty) continue;
      final int quantity = _asInt(raw['quantity'], 1);
      if (quantity <= 0) continue;

      final DocumentReference<Map<String, dynamic>> ref = _firestore
          .collection(_products)
          .doc(productId);
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
      if (!snap.exists) continue;

      final Map<String, dynamic> product = snap.data() ?? const {};
      final int stock = _asInt(product['stockTotal'], 0);
      final int sold = _asInt(product['soldCount'], 0);
      final int nextStock = deduct
          ? (stock - quantity < 0 ? 0 : stock - quantity)
          : stock + quantity;
      final int nextSold = deduct
          ? sold + quantity
          : (sold - quantity < 0 ? 0 : sold - quantity);

      tx.update(ref, <String, dynamic>{
        'stockTotal': nextStock,
        'soldCount': nextSold,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static int _asInt(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
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
