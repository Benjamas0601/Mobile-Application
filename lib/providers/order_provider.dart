import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_enums.dart';
import '../models/order_model.dart';
import '../repositories/order_repository.dart';
import 'cart_provider.dart';

/// Injected once and overridden in tests with a fake, so screens can be driven
/// without a live Firestore.
final Provider<OrderRepository> orderRepositoryProvider =
    Provider<OrderRepository>((Ref ref) => OrderRepository());

/// The signed-in buyer's orders, newest first.
///
/// Deliberately `autoDispose`: the list is only interesting while the user is
/// looking at it, and dropping the listener lets Firestore release the query.
final StreamProvider<List<OrderModel>> myOrdersProvider =
    StreamProvider<List<OrderModel>>((Ref ref) {
      final OrderRepository repository = ref.watch(orderRepositoryProvider);
      return repository.watchMyOrders();
    });

/// One order, kept live so a status change from the seller shows up without a
/// pull-to-refresh.
final orderProvider = StreamProvider.autoDispose.family<OrderModel?, String>((
  Ref ref,
  String orderId,
) {
  final OrderRepository repository = ref.watch(orderRepositoryProvider);
  return repository.watchOrder(orderId);
});

/// The orders of one store — the seller's inbox.
///
/// Keyed by store id rather than merged across the seller's stores, because the
/// rule that makes the read possible is satisfied by a
/// `where('storeId', ...)` constraint; a filter-less `in` query over several
/// stores would need a different rule. The list screen therefore watches one
/// store at a time and re-keys when the seller picks another.
final storeOrdersProvider =
    StreamProvider.autoDispose.family<List<OrderModel>, String>((
      Ref ref,
      String storeId,
    ) {
      final OrderRepository repository = ref.watch(orderRepositoryProvider);
      return repository.watchStoreOrders(storeId);
    });

/// Turns the local cart into the snapshot written onto the order.
///
/// Kept here rather than in the repository so the repository never learns about
/// [CartLine]: the cart is a local concept, the order is a stored one.
List<OrderItem> snapshotFromCart(List<CartLine> lines) => <OrderItem>[
  for (final CartLine l in lines)
    OrderItem(
      productId: l.productId,
      name: l.name,
      price: l.price,
      quantity: l.quantity,
      imageUrl: l.imageUrl,
    ),
];

/// Writes the order, then empties the cart.
///
/// The cart is only cleared after Firestore confirms the write: a failed
/// checkout that empties the basket loses the customer's selection, which is
/// far worse than leaving it in place to retry.
class PlaceOrderController extends Notifier<bool> {
  @override
  bool build() => false;

  OrderRepository get _repository => ref.read(orderRepositoryProvider);

  /// Returns the new order id, or null when the write failed.
  Future<String?> place({
    required List<CartLine> lines,
    required String storeId,
    required String storeName,
    required String buyerName,
    required String shippingAddress,
    required PaymentMethod method,
    String? note,
  }) async {
    // The screen-facing guard, so an invalid draft produces a clean message
    // instead of an exception. The repository re-checks the same invariants
    // because `createOrder` is also reachable from other callers.
    if (state) return null;
    if (lines.isEmpty || storeId.isEmpty || shippingAddress.trim().isEmpty) {
      return null;
    }
    state = true;
    try {
      final String id = await _repository.createOrder(
        items: snapshotFromCart(lines),
        storeId: storeId,
        storeName: storeName,
        buyerName: buyerName,
        shippingAddress: shippingAddress,
        method: method,
        note: note,
      );
      ref.read(cartProvider.notifier).clear();
      ref.read(checkoutDraftProvider.notifier).clear();
      ref.invalidate(myOrdersProvider);
      return id;
    } finally {
      state = false;
    }
  }
}

final NotifierProvider<PlaceOrderController, bool> placeOrderProvider =
    NotifierProvider<PlaceOrderController, bool>(PlaceOrderController.new);

/// What the buyer agreed to on the address step, carried to the payment step.
///
/// Kept in a provider rather than passed as route arguments: a URL cannot hold
/// a typed address, and a deep link to `/checkout/payment` would otherwise have
/// nothing to show. Holding it here also means the payment screen never has to
/// be told *where* its data came from.
class CheckoutDraft {
  const CheckoutDraft({required this.storeId, required this.shippingAddress});

  final String storeId;
  final String shippingAddress;

  bool get isComplete => storeId.isNotEmpty && shippingAddress.trim().isNotEmpty;
}

class CheckoutDraftController extends Notifier<CheckoutDraft?> {
  @override
  CheckoutDraft? build() => null;

  void start({required String storeId, required String shippingAddress}) {
    state = CheckoutDraft(storeId: storeId, shippingAddress: shippingAddress);
  }

  /// Called once the order is written, so a stale draft cannot produce a second
  /// order if the buyer navigates back to the payment screen.
  void clear() => state = null;
}

final NotifierProvider<CheckoutDraftController, CheckoutDraft?>
checkoutDraftProvider =
    NotifierProvider<CheckoutDraftController, CheckoutDraft?>(
      CheckoutDraftController.new,
    );

/// Advances an order one step, for the demo seller control and the seller
/// console.
///
/// The state machine is checked in the repository as well as here, so a
/// double-tap or a stale screen cannot skip a stage.
class AdvanceOrderStatusController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> advance(
    String orderId,
    OrderStatus next, {
    String? trackingNumber,
  }) async {
    if (state) return;
    state = true;
    try {
      await ref
          .read(orderRepositoryProvider)
          .advanceStatus(orderId, next, trackingNumber: trackingNumber);
    } finally {
      state = false;
    }
  }
}

final NotifierProvider<AdvanceOrderStatusController, bool>
advanceOrderStatusProvider =
    NotifierProvider<AdvanceOrderStatusController, bool>(
      AdvanceOrderStatusController.new,
    );
