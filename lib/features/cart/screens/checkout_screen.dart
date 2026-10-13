import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_router.dart';
import '../../../providers/order_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/coupon_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/coupon_provider.dart';
import '../../../widgets/state_views.dart';

/// ไฟล์นี้เป็นไฟล์ที่เก็บหน้าจอชำระเงินของแอป โดยมีฟอร์มให้กรอกที่อยู่จัดส่งและปุ่มไปยังหน้าชำระเงิน
/// Checkout, with the authentication gate.
///
/// This is the boundary the whole "browse as guest" flow is built around: the
/// cart is local and works signed out, and the first moment that needs a named
/// person is right here.
/// ตรวจสถานะบัญชีก่อนซื้อ แต่ยังให้ guest เห็น gate และเลือกสมัคร/ล็อกอินได้
class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<CartLine> lines = ref.watch(cartProvider);
    final AsyncValue<UserModel?> auth = ref.watch(authUserProvider);
    final UserModel? user = auth.value;

    if (lines.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.checkout)),
        body: EmptyView(
          icon: Icons.shopping_basket_outlined,
          title: AppStrings.emptyCart,
          body: AppStrings.emptyCartHint,
          actionLabel: AppStrings.navExplore,
          onAction: () => context.go(AppRoutes.home),
        ),
      );
    }

    if (auth.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.checkout)),
        body: const LoadingView(),
      );
    }

    // The router normally prevents this, but a session can end while the
    // screen is open, so the gate is enforced here too.
    if (user == null) return const _AuthGate();

    return _CheckoutForm(lines: lines, user: user);
  }
}

/// Shown to a guest who reached checkout.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.checkout)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 56,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    AppStrings.loginToOrder,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    AppStrings.loginToOrderHint,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // `redirect` carries the destination so signing in resumes
                  // this checkout instead of dropping the user on Home.
                  FilledButton(
                    onPressed: () => context.push(
                      '${AppRoutes.login}?redirect=${AppRoutes.checkout}',
                    ),
                    child: const Text(AppStrings.login),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: () => context.push(
                      '${AppRoutes.register}?redirect=${AppRoutes.checkout}',
                    ),
                    child: const Text(AppStrings.register),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    // Label promises browsing, so go back to the catalogue
                    // rather than the cart the user just came from.
                    onPressed: () => context.go(AppRoutes.home),
                    child: const Text(AppStrings.backToCart),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckoutForm extends ConsumerStatefulWidget {
  const _CheckoutForm({required this.lines, required this.user});

  final List<CartLine> lines;
  final UserModel user;

  @override
  ConsumerState<_CheckoutForm> createState() => _CheckoutFormState(); 
}

class _CheckoutFormState extends ConsumerState<_CheckoutForm> {
  final TextEditingController _address = TextEditingController();
  String? _addressError;
  final TextEditingController _couponField = TextEditingController();
  bool _couponBusy = false;
  String? _couponError;

  @override
  void dispose() {
    _address.dispose();
    _couponField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double subtotal = widget.lines.fold(
      0.0,
      (double s, CartLine l) => s + l.lineTotal,
    );
    final String? storeId = ref.watch(cartProvider).isEmpty
        ? null
        : ref.watch(cartProvider).first.storeId;
    final CouponModel? applied = ref.watch(appliedCouponProvider);
    final double discount =
        applied?.discountFor(subtotal: subtotal, storeId: storeId) ?? 0;
    final double total = getCartTotal(subtotal) - discount;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.checkout)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: <Widget>[
          _buyerCard(),
          const SizedBox(height: AppSpacing.lg),
          Text(AppStrings.shippingAddress, style: AppTextStyles.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _address,
            maxLines: 3,
            onChanged: (_) {
              // Clear the error as soon as the buyer starts fixing it, rather
              // than making them resubmit to find out it was accepted.
              if (_addressError != null) {
                setState(() => _addressError = null);
              }
            },
            decoration: InputDecoration(
              hintText: AppStrings.addressHint,
              border: const OutlineInputBorder(),
              errorText: _addressError,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _couponSection(subtotal: subtotal, storeId: storeId, applied: applied),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: <Widget>[
                  for (final CartLine l in widget.lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '${l.name} x${l.quantity}',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                          Text(
                            Fmt.price(l.lineTotal),
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text('ค่าจัดส่ง', style: AppTextStyles.bodyMedium),
                      Text(
                        getShippingFee(subtotal) == 0
                            ? 'ฟรี'
                            : Fmt.price(getShippingFee(subtotal)),
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                  if (discount > 0) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          AppStrings.couponDiscountLabel,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                        Text(
                          '-${Fmt.price(discount)}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text('ยอดรวม', style: AppTextStyles.labelLarge),
                      Text(
                        Fmt.price(total),
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _placeOrder,
              child: const Text(AppStrings.goToPayment),
            ),
          ),
        ],
      ),
    );
  }

  /// The code box: an input while nothing is applied, otherwise a removable
  /// summary of what the basket now saves.
  Widget _couponSection({
    required double subtotal,
    required String? storeId,
    required CouponModel? applied,
  }) {
    final CouponModel? coupon = applied;
    final double discount =
        coupon?.discountFor(subtotal: subtotal, storeId: storeId) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(AppStrings.couponTitle, style: AppTextStyles.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        if (coupon == null)
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _couponField,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) {
                    if (_couponError != null) {
                      setState(() => _couponError = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: AppStrings.couponHint,
                    border: const OutlineInputBorder(),
                    errorText: _couponError,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.tonal(
                onPressed: _couponBusy ? null : _applyCoupon,
                child: _couponBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(AppStrings.couponApply),
              ),
            ],
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.local_offer_outlined,
                  size: 18,
                  color: AppColors.success,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    AppStrings.couponApplied.replaceAll(
                      '{code}',
                      coupon.code,
                    ),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ),
                if (discount > 0)
                  Text(
                    '-${Fmt.price(discount)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                IconButton(
                  tooltip: AppStrings.couponRemove,
                  onPressed: () {
                    ref.read(appliedCouponProvider.notifier).clear();
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _applyCoupon() async {
    final String raw = _couponField.text.trim();
    if (raw.isEmpty) {
      setState(() => _couponError = AppStrings.couponHint);
      return;
    }
    setState(() {
      _couponBusy = true;
      _couponError = null;
    });
    try {
      final CouponModel? coupon = await ref
          .read(couponRepositoryProvider)
          .findByCode(raw);
      if (!mounted) return;
      if (coupon == null) {
        setState(() {
          _couponBusy = false;
          _couponError = AppStrings.couponNotFound;
        });
        return;
      }
      final String? storeId = widget.lines.isEmpty
          ? null
          : widget.lines.first.storeId;
      final double subtotal = widget.lines.fold(
        0.0,
        (double s, CartLine l) => s + l.lineTotal,
      );
      final String? reason = couponValidationError(
        coupon,
        storeId: storeId,
        subtotal: subtotal,
      );
      if (reason != null) {
        setState(() {
          _couponBusy = false;
          _couponError = reason;
        });
        return;
      }
      ref.read(appliedCouponProvider.notifier).apply(coupon);
      _couponField.clear();
      setState(() => _couponBusy = false);
    } on Object {
      if (!mounted) return;
      setState(() {
        _couponBusy = false;
        _couponError = AppStrings.couponCheckFailed;
      });
    }
  }

  Widget _buyerCard() {
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.person_outline_rounded,
          color: AppColors.primary,
        ),
        title: Text(widget.user.displayName, style: AppTextStyles.bodyLarge),
        subtitle: Text(widget.user.email, style: AppTextStyles.labelSmall),
      ),
    );
  }

  /// Hands the agreed address to the payment step.
  ///
  /// Nothing is written here: confirming an address is a decision about the
  /// goods, not about money, so the order document is only created once the
  /// buyer has picked a payment method. That also means a buyer who backs out
  /// of the payment screen keeps the address they typed.
  void _placeOrder() {
    if (_address.text.trim().isEmpty) {
      setState(() => _addressError = AppStrings.errRequired);
      return;
    }
    final String? storeId = ref.read(cartProvider.notifier).storeId;
    if (storeId == null) return;

    ref
        .read(checkoutDraftProvider.notifier)
        .start(storeId: storeId, shippingAddress: _address.text);
    context.push(AppRoutes.payment);
  }
}
