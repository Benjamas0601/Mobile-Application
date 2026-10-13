import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_strings.dart';
import '../core/utils/formatters.dart';
import '../models/coupon_model.dart';
import '../repositories/coupon_repository.dart';

/// Injected once and overridden in tests with a fake, so the coupon box can be
/// driven without a live Firestore.
final Provider<CouponRepository> couponRepositoryProvider =
    Provider<CouponRepository>((Ref ref) => CouponRepository());

/// The coupon the buyer accepted on the checkout step, carried to the payment
/// step (same pattern as [checkoutDraftProvider]). Cleared once the order is
/// written so a stale coupon cannot discount a later, unrelated basket.
class AppliedCouponController extends Notifier<CouponModel?> {
  @override
  CouponModel? build() => null;

  void apply(CouponModel coupon) => state = coupon;

  void clear() => state = null;
}

final NotifierProvider<AppliedCouponController, CouponModel?>
appliedCouponProvider =
    NotifierProvider<AppliedCouponController, CouponModel?>(
      AppliedCouponController.new,
    );

/// Why [coupon] cannot be used for this basket, or null when it can.
///
/// Returns complete Thai sentences so the checkout can show them next to the
/// code field instead of a generic "not valid".
String? couponValidationError(
  CouponModel coupon, {
  required String? storeId,
  required double subtotal,
}) {
  if (!coupon.active) return AppStrings.couponDisabled;
  final DateTime now = DateTime.now();
  if (coupon.startsAt != null && now.isBefore(coupon.startsAt!)) {
    return AppStrings.couponNotYetStart;
  }
  if (coupon.expiresAt != null && now.isAfter(coupon.expiresAt!)) {
    return AppStrings.couponExpired;
  }
  if (coupon.usageLimit != null && coupon.usedCount >= coupon.usageLimit!) {
    return AppStrings.couponUsageExhausted;
  }
  if (coupon.storeId != null && coupon.storeId != storeId) {
    return AppStrings.couponWrongStore;
  }
  if (coupon.minSpend > 0 && subtotal < coupon.minSpend) {
    return Fmt.fill(
      AppStrings.couponMinSpend,
      amount: coupon.minSpend.toStringAsFixed(0),
    );
  }
  return null;
}