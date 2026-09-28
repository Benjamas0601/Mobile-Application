import '../core/constants/app_enums.dart';
import 'firestore_codec.dart';

/// The four-question "story" behind a product.
///
/// This is the differentiator in the brief, so it is modelled as its own
/// object rather than four loose strings on [ProductModel] — the product page
/// renders the blocks in order and can hide a block that is still blank.
class ProductStory {
  const ProductStory({
    this.community = '',
    this.ingredients = '',
    this.productionMethod = '',
    this.uniqueness = '',
  });

  final String community;
  final String ingredients;
  final String productionMethod;
  final String uniqueness;

  bool get isEmpty =>
      community.isEmpty &&
      ingredients.isEmpty &&
      productionMethod.isEmpty &&
      uniqueness.isEmpty;

  factory ProductStory.fromFirestore(FirestoreReader r) {
    return ProductStory(
      community: r.string('community'),
      ingredients: r.string('ingredients'),
      productionMethod: r.string('productionMethod'),
      uniqueness: r.string('uniqueness'),
    );
  }
}

/// A `products/{productId}` document.
class ProductModel {
  const ProductModel({
    required this.id,
    required this.storeId,
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.province,
    required this.region,
    required this.imageUrls,
    required this.stockTotal,
    required this.status,
    required this.story,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.soldCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String storeId;
  final String name;
  final String description;
  final double price;
  final String categoryId;
  final String province;
  final String region;
  final List<String> imageUrls;
  final int stockTotal;
  final ProductStatus status;
  final ProductStory story;
  final double ratingAvg;
  final int ratingCount;
  final int soldCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Only `active` products may be shown to customers or added to a cart.
  bool get isVisible => status.isVisibleToCustomers;

  bool get isInStock => stockTotal > 0;

  /// Buyers pay in whole baht; a double would show "฿1,290.00".
  int get priceBaht => price.round();

  /// The card always needs a URL, and a product may legitimately have none.
  String? get coverImageUrl => imageUrls.isEmpty ? null : imageUrls.first;

  String get regionLabel => ThaiRegion.fromValue(region)?.label ?? region;

  factory ProductModel.fromFirestore(String id, Map<String, dynamic> data) {
    final FirestoreReader r = FirestoreReader(data);
    return ProductModel(
      id: id,
      storeId: r.string('storeId'),
      name: r.string('name'),
      description: r.string('description'),
      price: r.decimal('price'),
      categoryId: r.string('categoryId'),
      province: r.string('province'),
      region: r.string('region'),
      imageUrls: r.stringList('imageUrls'),
      stockTotal: r.integer('stockTotal'),
      status: ProductStatus.fromValue(r.string('status')),
      story:
          r.nested<ProductStory>('story', ProductStory.fromFirestore) ??
          const ProductStory(),
      ratingAvg: r.decimal('ratingAvg'),
      ratingCount: r.integer('ratingCount'),
      soldCount: r.integer('soldCount'),
      createdAt: r.dateTime('createdAt'),
      updatedAt: r.dateTime('updatedAt'),
    );
  }
}

/// A `product_variants/{variantId}` document — a colour or size with its own
/// stock, because "the blue one is out" is a different fact from "sold out".
class ProductVariantModel {
  const ProductVariantModel({
    required this.id,
    required this.productId,
    required this.name,
    required this.color,
    required this.size,
    required this.priceDelta,
    required this.stock,
    this.imageUrl,
  });

  final String id;
  final String productId;
  final String name;
  final String? color;
  final String? size;
  final double priceDelta;
  final int stock;
  final String? imageUrl;

  bool get isInStock => stock > 0;

  factory ProductVariantModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final FirestoreReader r = FirestoreReader(data);
    return ProductVariantModel(
      id: id,
      productId: r.string('productId'),
      name: r.string('name'),
      color:
          r.stringOrNull('color') ??
          r.nested<String?>(
            'options',
            (FirestoreReader o) => o.stringOrNull('color'),
          ),
      size:
          r.stringOrNull('size') ??
          r.nested<String?>(
            'options',
            (FirestoreReader o) => o.stringOrNull('size'),
          ),
      priceDelta: r.decimal('priceDelta'),
      stock: r.integer('stock'),
      imageUrl: r.stringOrNull('imageUrl'),
    );
  }
}
