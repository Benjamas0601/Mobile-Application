import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/shipping.dart' as shipping;
import '../models/product_model.dart';

/// One line in the cart.
///
/// The product is flattened into the line on purpose: the cart must survive a
/// catalogue refresh and must be readable while signed out, so it cannot depend
/// on a live Firestore document.
class CartLine {
  const CartLine({
    required this.productId,
    required this.storeId,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
    this.stock = 0,
  });

  final String productId;

  /// Which store this line came from.
  ///
  /// An order document holds a single `storeId` because `firestore.rules`
  /// resolves the seller with it, so the cart refuses to mix stores — see
  /// [CartNotifier.add].
  final String storeId;

  final String name;
  final double price;
  final int quantity;
  final String? imageUrl;

  /// Stock at the time of adding, used as an upper bound on quantity.
  final int stock;

  double get lineTotal => price * quantity;

  CartLine copyWith({int? quantity}) => CartLine(
    productId: productId,
    storeId: storeId,
    name: name,
    price: price,
    quantity: quantity ?? this.quantity,
    imageUrl: imageUrl,
    stock: stock,
  );
}

/// Outcome of an add attempt, so the UI can explain a refusal instead of
/// silently doing nothing.
enum CartAddResult {
  /// Added, or the existing line was topped up.
  added,

  /// The product has no stock left.
  outOfStock,

  /// The cart already holds something from another store.
  differentStore,

  /// The line is already at the maximum the store has in stock.
  atStockLimit,
}

/// Local cart that works for guests and signed-in users alike.
///
/// Deliberately in-memory: nothing here is tied to an account, so a guest can
/// fill a cart and only be asked to sign in at checkout. Persisting to
/// `users/{uid}/cart_items` is a later step and belongs behind this interface.
class CartNotifier extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => const <CartLine>[];

  /// The store the whole cart belongs to, or null while it is empty.
  String? get storeId => state.isEmpty ? null : state.first.storeId;

  /// Adds [quantity] units, or tops the line up to [quantity] if it already
  /// exists. Quantity is clamped to the stock the product had.
  ///
  /// Refuses a product from a second store: one order maps to one store, so a
  /// mixed cart could not be checked out. The caller is expected to offer a
  /// way out — clear the cart and start again — rather than fail silently.
  CartAddResult add(ProductModel product, {int quantity = 1}) {
    if (product.stockTotal <= 0) return CartAddResult.outOfStock;

    final String? owner = storeId;
    if (owner != null && owner != product.storeId) {
      return CartAddResult.differentStore;
    }

    final int cap = product.stockTotal;
    final int existing = state
        .where((CartLine l) => l.productId == product.id)
        .fold(0, (int sum, CartLine l) => sum + l.quantity);

    if (existing >= cap) return CartAddResult.atStockLimit;

    final int wanted = existing + quantity;
    final int next = wanted > cap ? cap : wanted;

    final bool present = state.any((CartLine l) => l.productId == product.id);
    if (present) {
      state = [
        for (final CartLine l in state)
          if (l.productId == product.id) l.copyWith(quantity: next) else l,
      ];
      return CartAddResult.added;
    }

    state = <CartLine>[
      ...state,
      CartLine(
        productId: product.id,
        storeId: product.storeId,
        name: product.name,
        price: product.price,
        quantity: next > cap ? cap : next,
        imageUrl: product.imageUrls.isEmpty ? null : product.imageUrls.first,
        stock: cap,
      ),
    ];
    return CartAddResult.added;
  }

  void setQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      remove(productId);
      return;
    }
    state = [
      for (final CartLine l in state)
        if (l.productId == productId)
          // Never let the stepper push past what the store has.
          l.copyWith(
            quantity: l.stock > 0 && quantity > l.stock ? l.stock : quantity,
          )
        else
          l,
    ];
  }

  void remove(String productId) {
    state = state.where((CartLine l) => l.productId != productId).toList();
  }

  void clear() => state = const <CartLine>[];

  int get itemCount => state.fold(0, (int sum, CartLine l) => sum + l.quantity);

  double get subtotal =>
      state.fold(0.0, (double sum, CartLine l) => sum + l.lineTotal);
}

/// Flat fee, matching the seed data's shipping model. Re-exported from
/// `core/utils/shipping.dart` so existing call sites keep compiling while the
/// constants have a single definition shared with the order repository.
const double kShippingFee = shipping.kShippingFee;

const double kFreeShippingOver = shipping.kFreeShippingOver;

double getShippingFee(double subtotal) => shipping.shippingFeeFor(subtotal);

double getCartTotal(double subtotal) => shipping.totalFor(subtotal);

/// Not auto-disposed: a cart that empties when the tab is popped would be a
/// bug, not a feature.
final NotifierProvider<CartNotifier, List<CartLine>> cartProvider =
    NotifierProvider<CartNotifier, List<CartLine>>(CartNotifier.new);

/// Badge count for the app bar.
final Provider<int> cartCountProvider = Provider<int>(
  (Ref ref) =>
      ref.watch(cartProvider).fold(0, (int s, CartLine l) => s + l.quantity),
);

final Provider<double> cartSubtotalProvider = Provider<double>(
  (Ref ref) => ref
      .watch(cartProvider)
      .fold(0.0, (double s, CartLine l) => s + l.lineTotal),
);
