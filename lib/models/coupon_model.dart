import 'firestore_codec.dart';

/// How a coupon takes money off.
///
/// Mirrors the `type` stored on `coupons/{couponId}` — see the data-model docs.
enum CouponType {
  percentage('percentage'),
  fixed('fixed');

  const CouponType(this.value);

  /// Value persisted in Firestore.
  final String value;

  static CouponType? fromValue(String? value) {
    if (value == null) return null;
    for (final CouponType type in CouponType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

/// A discount code the buyer can apply at checkout.
///
/// Coupons are administered by an admin (`firestore.rules` only allows admin
/// writes), so this model is read-only from the buyer's point of view. The
/// usage counter is also only maintained by an admin write / a future Cloud
/// Function — clients cannot touch the coupon document, which is why the demo
/// enforces `usageLimit` best-effort in [discountFor].
class CouponModel {
  const CouponModel({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    this.minSpend = 0,
    this.maxDiscount,
    this.storeId,
    this.startsAt,
    this.expiresAt,
    this.usageLimit,
    this.usedCount = 0,
    this.active = true,
  });

  final String id;

  /// Display code such as `SAVE10`. Codes are looked up case-insensitively but
  /// stored and shown upper-case.
  final String code;

  final CouponType type;

  /// Percentage (0-100) for [CouponType.percentage], baht for fixed.
  final double value;

  /// The order subtotal below which the coupon does not apply.
  final double minSpend;

  /// Ceiling on a percentage discount, so `50%` on a huge basket stays sane.
  final double? maxDiscount;

  /// When present, the coupon only applies to orders of this store.
  final String? storeId;

  final DateTime? startsAt;
  final DateTime? expiresAt;

  /// How many times the code may be used in total.
  final int? usageLimit;

  /// Uses so far — informational only for the client, see the class docs.
  final int usedCount;

  final bool active;

  factory CouponModel.fromFirestore(String id, Map<String, dynamic> data) {
    final FirestoreReader r = FirestoreReader(data);
    return CouponModel(
      id: id,
      code: r.string('code'),
      type: CouponType.fromValue(r.string('type')) ?? CouponType.fixed,
      value: r.decimal('value'),
      minSpend: r.decimal('minSpend'),
      maxDiscount: _nullableDecimal(r, 'maxDiscount'),
      storeId: r.stringOrNull('storeId'),
      startsAt: r.dateTime('startsAt'),
      expiresAt: r.dateTime('expiresAt'),
      usageLimit: r.integer('usageLimit') == 0 ? null : r.integer('usageLimit'),
      usedCount: r.integer('usedCount'),
      active: r.boolean('active', fallback: true),
    );
  }

  static double? _nullableDecimal(FirestoreReader r, String key) {
    final double value = r.decimal(key, fallback: -1);
    return value < 0 ? null : value;
  }

  /// Whether the coupon can be used for a basket of [subtotal] at [storeId].
  ///
  /// The date window and the usage counter can only be judged on the client in
  /// this MVP (see the class docs); [discountFor] returns 0 when they do not
  /// hold, so a discount that silently stops applying never creates an
  /// inconsistent total.
  bool isUsableFor({required double subtotal, required String? storeId}) {
    if (!active) return false;
    final DateTime now = DateTime.now();
    if (startsAt != null && now.isBefore(startsAt!)) return false;
    if (expiresAt != null && now.isAfter(expiresAt!)) return false;
    if (usageLimit != null && usedCount >= usageLimit!) return false;
    if (this.storeId != null && this.storeId != storeId) return false;
    if (subtotal < minSpend) return false;
    return true;
  }

  /// The baht the buyer saves on a basket of [subtotal], 0 when not usable.
  ///
  /// Rounded to whole baht to match the app's no-decimal pricing; capped by
  /// [maxDiscount] and never allowed to exceed the subtotal itself.
  double discountFor({required double subtotal, required String? storeId}) {
    if (!isUsableFor(subtotal: subtotal, storeId: storeId)) return 0;

    final double raw = switch (type) {
      CouponType.percentage => subtotal * value / 100,
      CouponType.fixed => value,
    };
    double discount = raw.roundToDouble();
    if (maxDiscount != null && discount > maxDiscount!) {
      discount = maxDiscount!.roundToDouble();
    }
    if (discount > subtotal) discount = subtotal.roundToDouble();
    if (discount < 0) discount = 0;
    return discount;
  }
}