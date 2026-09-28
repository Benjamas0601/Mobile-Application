import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_otop_marketplace/core/constants/app_enums.dart';
import 'package:thai_otop_marketplace/models/product_model.dart';
import 'package:thai_otop_marketplace/providers/cart_provider.dart';

ProductModel _product({
  required String id,
  required String name,
  required double price,
  int stock = 10,
}) => ProductModel(
  id: id,
  storeId: 's1',
  name: name,
  description: '',
  price: price,
  categoryId: 'c1',
  province: 'เชียงใหม่',
  region: ThaiRegion.north.value,
  imageUrls: const <String>[],
  stockTotal: stock,
  status: ProductStatus.active,
  story: const ProductStory(),
);

CartNotifier _cart(ProviderContainer c) => c.read(cartProvider.notifier);

void main() {
  group('guest cart', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('adds a product as a guest, with no account involved', () {
      _cart(container).add(_product(id: 'p1', name: 'กาแฟ', price: 120));

      expect(container.read(cartProvider), hasLength(1));
      expect(container.read(cartCountProvider), 1);
      expect(container.read(cartSubtotalProvider), 120);
    });

    test('adding the same product twice tops up the quantity', () {
      final ProductModel p = _product(id: 'p1', name: 'กาแฟ', price: 120);
      _cart(container).add(p);
      _cart(container).add(p);

      expect(container.read(cartProvider), hasLength(1));
      expect(container.read(cartCountProvider), 2);
      expect(container.read(cartSubtotalProvider), 240);
    });

    test('quantity never exceeds stock', () {
      final ProductModel p = _product(
        id: 'p1',
        name: 'กาแฟ',
        price: 120,
        stock: 2,
      );
      _cart(container).add(p);
      _cart(container).add(p);
      _cart(container).add(p);

      expect(container.read(cartCountProvider), 2);
    });

    test('an out-of-stock product is refused', () {
      _cart(
        container,
      ).add(_product(id: 'p1', name: 'หมด', price: 100, stock: 0));

      expect(container.read(cartProvider), isEmpty);
    });

    test('the stepper cannot push past stock', () {
      _cart(
        container,
      ).add(_product(id: 'p1', name: 'กาแฟ', price: 120, stock: 3));
      _cart(container).setQuantity('p1', 99);

      expect(container.read(cartCountProvider), 3);
    });

    test('setting quantity to zero removes the line', () {
      _cart(container).add(_product(id: 'p1', name: 'กาแฟ', price: 120));
      _cart(container).setQuantity('p1', 0);

      expect(container.read(cartProvider), isEmpty);
    });

    test('remove and clear work', () {
      _cart(container).add(_product(id: 'p1', name: 'กาแฟ', price: 120));
      _cart(container).add(_product(id: 'p2', name: 'ชา', price: 90));

      _cart(container).remove('p1');
      expect(container.read(cartCountProvider), 1);

      _cart(container).clear();
      expect(container.read(cartProvider), isEmpty);
    });

    test(
      'a guest cart survives navigation, because it is not auto-disposed',
      () {
        _cart(container).add(_product(id: 'p1', name: 'กาแฟ', price: 120));
        // A fresh read of the same container is what a route change does.
        expect(container.read(cartCountProvider), 1);
      },
    );
  });

  group('shipping', () {
    test('is free at or above the threshold', () {
      expect(getShippingFee(1000), 0);
      expect(getShippingFee(1500), 0);
    });

    test('is a flat fee below the threshold', () {
      expect(getShippingFee(480), kShippingFee);
    });

    test('is free for an empty cart rather than charging for nothing', () {
      expect(getShippingFee(0), 0);
    });

    test('the total adds the fee to the subtotal', () {
      expect(getCartTotal(480), 480 + kShippingFee);
      expect(getCartTotal(1200), 1200);
    });
  });
}
