import '../core/constants/app_enums.dart';
import 'firestore_codec.dart';

/// An `affiliate_commissions/{id}` document — what one affiliate earned from one
/// attributed order.
///
/// [orderTotal] is denormalised on purpose. `firestore.rules` lets an affiliate
/// read their own commission rows but not the `orders` collection (an order
/// names its buyer and its sellers), so the sales figure this dashboard leads
/// with cannot be joined at read time. Copying the total when the commission is
/// recorded keeps the number right even after the order is later cancelled.
/// ยอดคอมมิชชันที่ผูกกับออเดอร์และ Affiliate หนึ่งราย
class AffiliateCommissionModel {
  const AffiliateCommissionModel({
    required this.id,
    required this.affiliateUid,
    required this.orderId,
    required this.amount,
    required this.rate,
    required this.status,
    required this.orderTotal,
    this.productName = '',
    this.createdAt,
  });

  final String id;
  final String affiliateUid;
  final String orderId;

  /// The commission earned, in baht.
  final double amount;

  /// The rate as a percentage number (5 means 5%), matching how the flow is
  /// described to the affiliate: 500 × 5% = 25.
  final double rate;

  final CommissionStatus status;

  /// The order total the commission was calculated from.
  final double orderTotal;

  final String productName;
  final DateTime? createdAt;

  /// Whether this row counts towards the sales the affiliate actually drove.
  ///
  /// A rejected or cancelled commission is money the affiliate will never see,
  /// so folding it into the headline sales number would overstate their
  /// performance — while a *pending* one is real revenue that is merely awaiting
  /// review and must stay in.
  bool get countsAsSales =>
      status != CommissionStatus.rejected &&
      status != CommissionStatus.cancelled;

  bool get isPending => status == CommissionStatus.pending;

  bool get isApproved => status == CommissionStatus.approved;

  factory AffiliateCommissionModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final FirestoreReader r = FirestoreReader(data);
    return AffiliateCommissionModel(
      id: id,
      affiliateUid: r.string('affiliateUid'),
      orderId: r.string('orderId'),
      amount: r.decimal('amount'),
      rate: r.decimal('rate'),
      status: CommissionStatus.fromValue(r.string('status')),
      orderTotal: r.decimal('orderTotal'),
      productName: r.string('productName'),
      createdAt: r.dateTime('createdAt'),
    );
  }
}
