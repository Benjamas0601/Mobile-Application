import 'package:flutter_test/flutter_test.dart';
import 'package:thai_otop_marketplace/core/constants/app_enums.dart';
import 'package:thai_otop_marketplace/models/order_model.dart';

OrderModel _order({
  required String id,
  required OrderStatus status,
  String storeId = 's1',
  double total = 530,
}) => OrderModel(
  id: id,
  buyerUid: 'u1',
  storeId: storeId,
  items: <OrderItem>[
    const OrderItem(
      productId: 'p1',
      name: 'กาแฟดอยอารามี',
      price: 480,
      quantity: 1,
    ),
  ],
  subtotal: 480,
  shippingFee: 50,
  total: total,
  status: status,
  paymentMethod: PaymentMethod.promptPay,
  paymentStatus: PaymentStatus.awaitingTransfer,
  createdAt: DateTime(2026, 9, 28),
);

void main() {
  group('the state machine allows one step at a time', () {
    test('an unpaid order can be paid or cancelled, and nothing else', () {
      expect(OrderStatus.pendingPayment.allowedNext, <OrderStatus>[
        OrderStatus.paid,
        OrderStatus.cancelled,
      ]);
    });

    test('a paid order waits for the seller, then ships', () {
      expect(OrderStatus.paid.allowedNext, <OrderStatus>[
        OrderStatus.awaitingShipment,
        OrderStatus.cancelled,
      ]);
    });

    test('the happy path reaches completed in four moves', () {
      final List<OrderStatus> walked = <OrderStatus>[];
      OrderStatus current = OrderStatus.pendingPayment;

      while (current.allowedNext.isNotEmpty) {
        final OrderStatus next = current.allowedNext
            .firstWhere((OrderStatus s) => s != OrderStatus.cancelled);
        walked.add(next);
        current = next;
      }

      expect(walked, <OrderStatus>[
        OrderStatus.paid,
        OrderStatus.awaitingShipment,
        OrderStatus.shipped,
        OrderStatus.completed,
      ]);
      expect(current, OrderStatus.completed);
    });

    test('a terminal status offers no way back', () {
      expect(OrderStatus.completed.allowedNext, isEmpty);
      expect(OrderStatus.cancelled.allowedNext, isEmpty);
    });
  });

  group('reading a document written by the server', () {
    test('decodes totals, status and the embedded item snapshot', () {
      final OrderModel order = OrderModel.fromFirestore('abc123', {
        'buyerUid': 'u1',
        'storeId': 's1',
        'storeName': 'ร้านชิงไทร',
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'productId': 'p1',
            'name': 'กาแฟดอยอารามี',
            'price': 480,
            'quantity': 2,
          },
        ],
        'subtotal': 960,
        'shippingFee': 50,
        'total': 1010,
        'status': 'shipped',
        'paymentMethod': 'bank_transfer',
        'paymentStatus': 'verified',
        'shippingAddress': <String, dynamic>{'full': 'เชียงใหม่ 50100'},
        'createdAt': DateTime(2026, 9, 28),
      });

      expect(order.id, 'abc123');
      expect(order.storeName, 'ร้านชิงไทร');
      expect(order.status, OrderStatus.shipped);
      expect(order.paymentMethod, PaymentMethod.bankTransfer);
      expect(order.paymentStatus, PaymentStatus.verified);
      expect(order.shippingAddress, 'เชียงใหม่ 50100');
      expect(order.items, hasLength(1));
      expect(order.items.first.lineTotal, 960);
      expect(order.itemCount, 2);
    });

    test('a missing or unknown field falls back instead of throwing', () {
      // A document written by an older build must still render, so every field
      // is read through a reader with a default rather than cast.
      final OrderModel order = OrderModel.fromFirestore('old', <String, dynamic>{
        'status': 'a_status_from_the_future',
        'total': 100,
      });

      expect(order.status, isA<OrderStatus>());
      expect(order.items, isEmpty);
      expect(order.itemCount, 0);
      expect(order.shippingAddress, isEmpty);
    });

    test('accepts an address written as a plain string too', () {
      final OrderModel order = OrderModel.fromFirestore('flat', {
        'shippingAddress': 'ล้านนา กรุงเทพฯ',
        'total': 100,
      });
      expect(order.shippingAddress, 'ล้านนา กรุงเทพฯ');
    });
  });

  group('the timeline grows with the status', () {
    test('an unpaid order shows one step', () {
      expect(
        _order(id: 'o1', status: OrderStatus.pendingPayment).timeline,
        <OrderStatus>[OrderStatus.pendingPayment],
      );
    });

    test('a shipped order shows everything up to shipping', () {
      expect(
        _order(id: 'o2', status: OrderStatus.shipped).timeline,
        <OrderStatus>[
          OrderStatus.pendingPayment,
          OrderStatus.paid,
          OrderStatus.awaitingShipment,
          OrderStatus.shipped,
        ],
      );
    });

    test('a cancelled order collapses to a single terminal state', () {
      // Showing the full progress track for a cancelled order would claim the
      // buyer received something.
      expect(
        _order(id: 'o3', status: OrderStatus.cancelled).timeline,
        <OrderStatus>[OrderStatus.cancelled],
      );
    });
  });

  group('the next step offered to a seller', () {
    test('follows the happy path rather than cancellation', () {
      // `paid` also allows `cancelled`; the demo control should offer the
      // forward move.
      expect(
        _order(id: 'o1', status: OrderStatus.pendingPayment).nextStatus,
        OrderStatus.paid,
      );
      expect(
        _order(id: 'o2', status: OrderStatus.shipped).nextStatus,
        OrderStatus.completed,
      );
    });

    test('is null once the order is finished', () {
      expect(
        _order(id: 'o3', status: OrderStatus.completed).nextStatus,
        isNull,
      );
      expect(
        _order(id: 'o4', status: OrderStatus.cancelled).nextStatus,
        isNull,
      );
    });

    test('a finished order reports isFinished', () {
      expect(
        _order(id: 'o1', status: OrderStatus.completed).isFinished,
        isTrue,
      );
      expect(
        _order(id: 'o2', status: OrderStatus.shipped).isFinished,
        isFalse,
      );
    });
  });

  group('the item snapshot is self-contained', () {
    test('keeps the price even after the product is repriced', () {
      // The reason items are copied onto the order rather than joined from
      // `products` at read time.
      final OrderItem item = OrderItem.fromFirestore(<String, dynamic>{
        'productId': 'p1',
        'name': 'กาแฟ',
        'price': 480,
        'quantity': 2,
      });

      expect(item.price, 480);
      expect(item.lineTotal, 960);
      expect(item.toFirestore()['price'], 480);
    });
  });
}
