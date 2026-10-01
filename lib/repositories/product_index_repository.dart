import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_enums.dart';

/// A lightweight province/region pair used only to count products on the
/// Explore map.
///
/// The Explore screen needs "how many products are in this province", not the
/// products themselves, so the query projects two fields instead of building
/// full [ProductModel]s. That keeps the map cheap enough to re-query on every
/// region filter change.
/// ข้อมูลสรุปจำนวนสินค้ารายจังหวัดสำหรับหน้าสำรวจ
class ProductProvinceSummary {
  const ProductProvinceSummary({required this.province, required this.region});

  final String province;
  final String region;

  ThaiRegion? get regionEnum => ThaiRegion.fromValue(region);
}

/// Reads the geographic fields of `products` for the Explore screen.
class ProductIndexRepository {
  ProductIndexRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String _products = 'products';
  static const int _maxLimit = 200;

  /// Province/region pairs for every customer-visible product.
  ///
  /// Only three fields are kept from each document, so the extra bytes of
  /// description/stories do not matter at this size — but the list is capped
  /// so the map never reads an unbounded collection.
  ///
  /// Drafts are filtered out in Dart rather than in the query: a
  /// `where('status', ...)` would need a composite index on
  /// `status` + `createdAt` and buys nothing at this collection size.
  Future<List<ProductProvinceSummary>> listVisibleProductProvinces() async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _db
        .collection(_products)
        .limit(_maxLimit)
        .get();

    final List<ProductProvinceSummary> all = <ProductProvinceSummary>[];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
      final Map<String, dynamic> data = doc.data();
      final ProductStatus status = ProductStatus.fromValue(
        data['status'] as String?,
      );
      if (!status.isVisibleToCustomers) continue;

      final String province = data['province'] as String? ?? '';
      if (province.isEmpty) continue;

      all.add(
        ProductProvinceSummary(
          province: province,
          region: data['region'] as String? ?? '',
        ),
      );
    }

    return all;
  }
}
