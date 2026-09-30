import 'firestore_codec.dart';

/// An `affiliate_links/{linkId}` document — one promotional link an affiliate
/// generated for a product they chose to promote.
///
/// `clicks` and `orders` are counters the backend maintains, deliberately not a
/// count of `affiliate_clicks` rows: `firestore.rules` keeps that collection
/// admin-only because a raw click row carries the visitor's identity, which is
/// none of the affiliate's business. The totals therefore have to live on the
/// one document the affiliate is actually allowed to read.
class AffiliateLinkModel {
  const AffiliateLinkModel({
    required this.id,
    required this.affiliateUid,
    required this.productId,
    required this.code,
    required this.clicks,
    required this.orders,
    this.productName = '',
    this.productImageUrl = '',
    this.createdAt,
  });

  final String id;
  final String affiliateUid;
  final String productId;

  /// The short referral code carried in the shared URL's `ref` parameter.
  final String code;

  final int clicks;
  final int orders;

  /// Denormalised from the product so the links list paints in one read
  /// instead of a second round trip per row.
  ///
  /// The shop name is deliberately absent: `products` carries `storeId` but not
  /// the store's name, so showing it would mean a second lookup per link.
  final String productName;
  final String productImageUrl;

  final DateTime? createdAt;

  /// Clicks that turned into an order, as a percentage.
  ///
  /// Guarded against a zero denominator: a brand-new link has no clicks yet,
  /// and a plain division would put `NaN` in the UI.
  double get conversionRate {
    if (clicks <= 0) return 0;
    return orders / clicks * 100;
  }

  factory AffiliateLinkModel.fromFirestore(String id, Map<String, dynamic> data) {
    final FirestoreReader r = FirestoreReader(data);
    return AffiliateLinkModel(
      id: id,
      affiliateUid: r.string('affiliateUid'),
      productId: r.string('productId'),
      code: r.string('code'),
      clicks: r.integer('clicks'),
      orders: r.integer('orders'),
      productName: r.string('productName'),
      productImageUrl: r.string('productImageUrl'),
      createdAt: r.dateTime('createdAt'),
    );
  }
}
