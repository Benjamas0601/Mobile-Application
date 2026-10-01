import '../core/constants/app_enums.dart';
import 'product_model.dart';

/// One variant row being edited in the seller's product form.
///
/// A draft mirrors the stored `product_variants` shape ([ProductVariantModel])
/// but is owned by the form, so it can carry a brand-new variant (no id) and
/// `stock` can be typed before anything is written.
/// ข้อมูลชั่วคราวของ variant ก่อนตรวจสอบและบันทึกสินค้า
class VariantDraft {
  const VariantDraft({
    this.id,
    required this.name,
    this.color,
    this.size,
    this.priceDelta = 0,
    this.stock = 0,
    this.imageUrl,
  });

  /// The stored id when editing an existing variant; null for a new one.
  final String? id;
  final String name;
  final String? color;
  final String? size;
  final double priceDelta;
  final int stock;
  final String? imageUrl;

  bool get isNew => id == null || id!.isEmpty;

  factory VariantDraft.fromModel(ProductVariantModel variant) => VariantDraft(
    id: variant.id,
    name: variant.name,
    color: variant.color,
    size: variant.size,
    priceDelta: variant.priceDelta,
    stock: variant.stock,
    imageUrl: variant.imageUrl,
  );

  VariantDraft copyWith({
    String? id,
    String? name,
    String? color,
    String? size,
    double? priceDelta,
    int? stock,
    String? imageUrl,
  }) {
    return VariantDraft(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      size: size ?? this.size,
      priceDelta: priceDelta ?? this.priceDelta,
      stock: stock ?? this.stock,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  /// The document shape written to `product_variants/{id}`.
  ///
  /// `options` keeps the same map shape the seed data writes (`color`/`size`
  /// may legitimately be null), so `ProductVariantModel.fromFirestore` reads
  /// it without a migration.
  Map<String, dynamic> toFirestore({required String productId}) {
    return <String, dynamic>{
      'productId': productId,
      'name': name,
      'options': <String, dynamic>{'color': color, 'size': size},
      'priceDelta': priceDelta,
      'stock': stock,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
    };
  }
}

/// Everything the seller's form collects before it becomes a product doc.
///
/// Kept separate from [ProductModel] because a product being edited is not
/// yet a stored fact: status can still be `draft`, variants have no ids yet,
/// and `stockTotal` is derived from the variant rows instead of being a field
/// the seller can type independently.
class ProductDraft {
  const ProductDraft({
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.imageUrls,
    required this.status,
    required this.story,
    required this.variants,
  });

  final String name;
  final String description;
  final double price;
  final String categoryId;
  final List<String> imageUrls;
  final ProductStatus status;
  final ProductStory story;
  final List<VariantDraft> variants;

  /// The product's selling price is the base price; variants add to it.
  int get priceBaht => price.round();

  /// What the customer sees when they run out of variants to pick from.
  ///
  /// `stockTotal` on the stored product is the sum of its variants, so only
  /// the sum is exposed here — there is no separate "stock" box that could
  /// drift out of sync with the variants.
  int get stockTotal => variants.fold<int>(
    0,
    (int sum, VariantDraft v) => sum + (v.stock < 0 ? 0 : v.stock),
  );

  /// The minimal set of facts a product must have before it can be written.
  ///
  /// The repository re-checks the same invariants before touching Firestore,
  /// because the create path is also reachable from outside the form.
  bool get isValid =>
      name.trim().isNotEmpty &&
      categoryId.isNotEmpty &&
      price >= 0 &&
      price.isFinite;

  factory ProductDraft.fromModel(ProductModel product) => ProductDraft(
    name: product.name,
    description: product.description,
    price: product.price,
    categoryId: product.categoryId,
    imageUrls: List<String>.of(product.imageUrls),
    status: product.status,
    story: ProductStory(
      community: product.story.community,
      ingredients: product.story.ingredients,
      productionMethod: product.story.productionMethod,
      uniqueness: product.story.uniqueness,
    ),
    variants: const <VariantDraft>[],
  );
}
