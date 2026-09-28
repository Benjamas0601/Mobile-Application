import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_model.dart';

/// One line in the cart.
///
/// The product is flattened into the line on purpose: the cart must survive a
/// catalogue refresh and must be readable while signed out, so it cannot depend
/// on a live Firestore document.
class CartLine {
  const CartLine({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
    this.stock = 0,
  });

  final String productId;
  final String name;
  final double price;
  final int quantity;
  final String? imageUrl;

  /// Stock at the time of adding, used as an upper bound on quantity.
  final int stock;

  double get lineTotal => price * quantity;

  CartLine copyWith({int? quantity}) => CartLine(
    productId: productId,
    name: name,
    price: price,
    quantity: quantity ?? this.quantity,
    imageUrl: imageUrl,
    stock: stock,
  );
}

/// Local cart that works for guests and signed-in users alike.
///
/// Deliberately in-memory: nothing here is tied to an account, so a guest can
/// fill a cart and only be asked to sign in at checkout. Persisting to
/// `users/{uid}/cart_items` is a later step and belongs behind this interface.
class CartNotifier extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => const <CartLine>[];

  /// Adds [quantity] units, or tops the line up to [quantity] if it already
  /// exists. Quantity is clamped to the stock the product had.
  void add(ProductModel product, {int quantity = 1}) {
    if (product.stockTotal <= 0) return;

    final int cap = product.stockTotal;
    final int existing = state
        .where((CartLine l) => l.productId == product.id)
        .fold(0, (int sum, CartLine l) => sum + l.quantity);

    if (existing >= cap) return;

    final int wanted = existing + quantity;
    final int next = wanted > cap ? cap : wanted;

    final bool present = state.any((CartLine l) => l.productId == product.id);
    if (present) {
      state = [
        for (final CartLine l in state)
          if (l.productId == product.id) l.copyWith(quantity: next) else l,
      ];
      return;
    }

    state = <CartLine>[
      ...state,
      CartLine(
        productId: product.id,
        name: product.name,
        price: product.price,
        quantity: next > cap ? cap : next,
        imageUrl: product.imageUrls.isEmpty ? null : product.imageUrls.first,
        stock: cap,
      ),
    ];
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

/// Flat fee, matching the seed data's shipping model.
const double kShippingFee = 50;

const double kFreeShippingOver = 1000;

double getShippingFee(double subtotal) =>
    (subtotal <= 0 || subtotal >= kFreeShippingOver) ? 0 : kShippingFee;

double getCartTotal(double subtotal) => subtotal + getShippingFee(subtotal);

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
