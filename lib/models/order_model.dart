import '../core/constants/app_enums.dart';
import 'firestore_codec.dart';

/// A single purchased line, snapshotted onto the order.
///
/// This is a copy, not a reference: the price, name and image are captured at
/// purchase time so the order history still reads correctly after the seller
/// renames the product, changes the price, or the product is deleted. That is
/// also why it lives embedded in the order document rather than being joined
/// from `products` at read time.
class OrderItem {
  const OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
    this.variantId,
    this.variantLabel,
  });

  final String productId;
  final String name;
  final double price;
  final int quantity;
  final String? imageUrl;
  final String? variantId;

  /// Human-readable variant ("แดง / M"), flattened at purchase time.
  final String? variantLabel;

  double get lineTotal => price * quantity;

  factory OrderItem.fromFirestore(Map<String, dynamic> data) {
    final FirestoreReader r = FirestoreReader(data);
    return OrderItem(
      productId: r.string('productId'),
      name: r.string('name', fallback: 'สินค้า'),
      price: r.decimal('price'),
      quantity: r.integer('quantity', fallback: 1),
      imageUrl: r.stringOrNull('imageUrl'),
      variantId: r.stringOrNull('variantId'),
      variantLabel: r.stringOrNull('variantLabel'),
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
    'productId': productId,
    'name': name,
    'price': price,
    'quantity': quantity,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (variantId != null) 'variantId': variantId,
    if (variantLabel != null) 'variantLabel': variantLabel,
  };
}

/// Where an order is in the delivery lifecycle.
///
/// Mirrors the `OrderStatus` enum, including `allowedNext`, so the UI can show
/// a timeline and a seller can only ever move an order to a legal next step —
/// the same rule the Firestore Security Rules enforce server-side.
class OrderModel {
  const OrderModel({
    required this.id,
    required this.buyerUid,
    required this.storeId,
    required this.items,
    required this.subtotal,
    required this.shippingFee,
    required this.total,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    this.storeName = '',
    this.buyerName = '',
    this.shippingAddress = '',
    this.note,
    this.trackingNumber,
    this.shippedAt,
    required this.createdAt,
  });

  final String id;
  final String buyerUid;

  /// One order belongs to one store: `firestore.rules` resolves the seller with
  /// `orderDoc.storeId`, so a multi-store cart could not be represented.
  final String storeId;

  final String storeName;
  final String buyerName;
  final String shippingAddress;
  final String? note;
  final String? trackingNumber;
  final DateTime? shippedAt;
  final List<OrderItem> items;
  final double subtotal;
  final double shippingFee;
  final double total;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final DateTime createdAt;

  int get itemCount =>
      items.fold(0, (int sum, OrderItem i) => sum + i.quantity);

  /// The statuses the order has already passed, for the timeline UI.
  ///
  /// `cancelled` is a dead end rather than a step, so it is never pre-filled;
  /// the timeline switches to a single cancelled state instead.
  List<OrderStatus> get timeline => switch (status) {
    OrderStatus.pendingPayment => const <OrderStatus>[OrderStatus.pendingPayment],
    OrderStatus.paid => const <OrderStatus>[
      OrderStatus.pendingPayment,
      OrderStatus.paid,
    ],
    OrderStatus.awaitingShipment => const <OrderStatus>[
      OrderStatus.pendingPayment,
      OrderStatus.paid,
      OrderStatus.awaitingShipment,
    ],
    OrderStatus.shipped => const <OrderStatus>[
      OrderStatus.pendingPayment,
      OrderStatus.paid,
      OrderStatus.awaitingShipment,
      OrderStatus.shipped,
    ],
    OrderStatus.completed => const <OrderStatus>[
      OrderStatus.pendingPayment,
      OrderStatus.paid,
      OrderStatus.awaitingShipment,
      OrderStatus.shipped,
      OrderStatus.completed,
    ],
    OrderStatus.cancelled => const <OrderStatus>[OrderStatus.cancelled],
  };

  /// The step a seller/admin would move to next, or null when finished.
  OrderStatus? get nextStatus {
    final List<OrderStatus> options = status.allowedNext;
    if (options.isEmpty) return null;
    // `paid` also offers `cancelled`; the demo advances along the happy path
    // so the first non-cancelled option is the sensible one.
    for (final OrderStatus s in options) {
      if (s != OrderStatus.cancelled) return s;
    }
    return options.first;
  }

  bool get isFinished => status.allowedNext.isEmpty;
  bool get isCancelled => status == OrderStatus.cancelled;

  factory OrderModel.fromFirestore(String id, Map<String, dynamic> data) {
    final FirestoreReader r = FirestoreReader(data);
    final String address = r.nested(
      'shippingAddress',
      (FirestoreReader a) => a.string('full'),
    ) ?? r.string('shippingAddress');

    return OrderModel(
      id: id,
      buyerUid: r.string('buyerUid'),
      storeId: r.string('storeId'),
      storeName: r.string('storeName'),
      buyerName: r.string('buyerName'),
      shippingAddress: address,
      note: r.stringOrNull('note'),
      trackingNumber: r.stringOrNull('trackingNumber'),
      shippedAt: r.dateTime('shippedAt'),
      items: r
          .mapList('items')
          .map(OrderItem.fromFirestore)
          .toList(growable: false),
      subtotal: r.decimal('subtotal'),
      shippingFee: r.decimal('shippingFee'),
      total: r.decimal('total'),
      status: OrderStatus.fromValue(r.string('status')),
      paymentMethod: PaymentMethod.fromValue(r.string('paymentMethod')),
      paymentStatus: PaymentStatus.fromValue(r.string('paymentStatus')),
      createdAt: r.dateTimeOr('createdAt', DateTime.fromMillisecondsSinceEpoch(0)),
    );
  }
}
