import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/payment_strings.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/store_model.dart';

import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/catalog_provider.dart';
import '../../../providers/image_storage_provider.dart';
import '../../../providers/order_provider.dart';
import '../../../repositories/order_repository.dart' show OrderWriteException;
import '../../../widgets/state_views.dart';

/// Step two of checkout: how to pay.
///
/// Separate from the address form on purpose. Confirming an address is a
/// decision about the goods; paying is a decision about money, and splitting
/// them means a buyer who backs out of payment does not lose the address they
/// just typed.
///
/// Nothing here talks to a payment gateway. Selecting a method records the
/// choice in Firestore, which is the part the rest of the app actually reads.
/// The screen says so plainly instead of showing a fake success.
class PaymentScreen extends ConsumerWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Everything comes from providers so this screen can be reached by URL as
    // well as by tapping through from checkout.
    final CheckoutDraft? draft = ref.watch(checkoutDraftProvider);
    final UserModel? user = ref.watch(authUserProvider).asData?.value;

    if (draft == null || user == null) {
      // Reached without a draft: either a deep link, or the cart was already
      // turned into an order. Send the buyer somewhere that can start over
      // rather than showing an empty payment form.
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.payNow)),
        body: EmptyView(
          title: AppStrings.noDraftTitle,
          body: AppStrings.noDraftHint,
          icon: Icons.shopping_cart_outlined,
          actionLabel: AppStrings.continueShopping,
          onAction: () => context.go(AppRoutes.home),
        ),
      );
    }

    // The store name is written onto the order so history reads correctly even
    // if the store is renamed or removed later.
    final StoreModel? store = ref
        .watch(storeProvider(draft.storeId))
        .asData
        ?.value;

    return _PaymentForm(
      lines: ref.watch(cartProvider),
      user: user,
      storeId: draft.storeId,
      storeName: store?.name ?? '',
      shippingAddress: draft.shippingAddress,
    );
  }
}

class _PaymentForm extends ConsumerStatefulWidget {
  const _PaymentForm({
    required this.lines,
    required this.user,
    required this.storeId,
    required this.storeName,
    required this.shippingAddress,
  });

  final List<CartLine> lines;
  final UserModel user;
  final String storeId;
  final String storeName;
  final String shippingAddress;

  @override
  ConsumerState<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends ConsumerState<_PaymentForm> {
  PaymentMethod _method = PaymentMethod.promptPay;
  String? _error;

  static const List<PaymentMethod> _methods = <PaymentMethod>[
    PaymentMethod.promptPay,
    PaymentMethod.bankTransfer,
    PaymentMethod.cashOnDelivery,
  ];

  @override
  Widget build(BuildContext context) {
    final bool busy = ref.watch(placeOrderProvider);
    final double subtotal = widget.lines.fold(
      0.0,
      (double sum, CartLine l) => sum + l.lineTotal,
    );
    final double total = getCartTotal(subtotal);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.payNow)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: <Widget>[
          _orderSummaryCard(subtotal, total),
          const SizedBox(height: AppSpacing.lg),
          Text(AppStrings.paymentMethod, style: AppTextStyles.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final PaymentMethod m in _methods)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _MethodTile(
                method: m,
                selected: m == _method,
                onTap: () => setState(() {
                  _method = m;
                  _error = null;
                }),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          _TransferInstructions(method: _method),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            InlineErrorBanner(message: _error!),
          ],
          const SizedBox(height: AppSpacing.lg),
          // Being honest about the MVP is part of the brief: never let the UI
          // imply a real transfer happened.
          const _MvpNotice(),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : _confirm,
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      '${AppStrings.confirm} ${Fmt.price(total)}',
                      style: AppTextStyles.labelLarge,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderSummaryCard(double subtotal, double total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (widget.storeName.isNotEmpty) ...<Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.storefront_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.storeName,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: AppSpacing.lg),
            ],
            for (final CartLine l in widget.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${l.name} x${l.quantity}',
                        style: AppTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      Fmt.price(l.lineTotal),
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            const Divider(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'ค่าจัดส่ง',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
                Text(
                  total - subtotal == 0
                      ? AppStrings.freeShipping
                      : Fmt.price(total - subtotal),
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(AppStrings.total, style: AppTextStyles.labelLarge),
                Text(
                  Fmt.price(total),
                  style: AppTextStyles.priceLarge.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    setState(() => _error = null);

    String? orderId;
    try {
      orderId = await ref
          .read(placeOrderProvider.notifier)
          .place(
            lines: widget.lines,
            storeId: widget.storeId,
            storeName: widget.storeName,
            buyerName: widget.user.displayName,
            shippingAddress: widget.shippingAddress,
            method: _method,
          );
    } on OrderWriteException catch (e) {
      // A full sentence about the write, not a crash: the repository already
      // shaped the failure into a message worth showing.
      if (!mounted) return;
      setState(() => _error = e.message);
      return;
    }

    if (!mounted) return;

    if (orderId == null) {
      setState(() => _error = AppStrings.orderCreateFailed);
      return;
    }
    // The messenger is captured before navigating because this widget is torn
    // down by the route change.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text(AppStrings.orderPlaced)));
    context.go(AppRoutes.orderDetail(orderId));
  }
}

/// One selectable payment method.
class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  static const Map<PaymentMethod, IconData> _icons =
      <PaymentMethod, IconData>{
        PaymentMethod.promptPay: Icons.qr_code_2_rounded,
        PaymentMethod.bankTransfer: Icons.account_balance_rounded,
        PaymentMethod.cashOnDelivery: Icons.local_shipping_outlined,
      };

  static const Map<PaymentMethod, String> _hints =
      <PaymentMethod, String>{
        PaymentMethod.promptPay: 'สแกน QR ด้วยแอปธนาคาร',
        PaymentMethod.bankTransfer: 'โอนผ่านเลขที่บัญชีของร้าน',
        PaymentMethod.cashOnDelivery: 'จ่ายเงินสดตอนรับสินค้าที่ร้าน',
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              _icons[method],
              color: selected ? AppColors.primary : AppColors.inkMuted,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(method.label, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _hints[method]!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.primary : AppColors.borderStrong,
            ),
          ],
        ),
      ),
    );
  }
}

/// What to do next for the chosen method, plus the slip slot.
class _TransferInstructions extends ConsumerWidget {
  const _TransferInstructions({required this.method});

  final PaymentMethod method;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Cash on delivery has nothing to transfer, so it gets no instructions and
    // no slip slot.
    if (method == PaymentMethod.cashOnDelivery) {
      return Card(
        child: ListTile(
          leading: const Icon(
            Icons.info_outline_rounded,
            color: AppColors.info,
          ),
          title: Text(
            PaymentStrings.codHint,
            style: AppTextStyles.bodyMedium,
          ),
        ),
      );
    }

    final bool canUpload = ref.watch(cloudinaryConfiguredProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              method == PaymentMethod.promptPay
              ? PaymentStrings.promptPayQrPlaceholder
              : PaymentStrings.bankAccountPlaceholder,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            if (canUpload)
              // Wired up but disabled: the upload path needs a picked file and
              // a real Cloudinary preset, which this build has neither of.
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.attach_file_rounded, size: 18),
                label: const Text(AppStrings.uploadSlip),
              )
            else
              _SlipUnavailable(
                reason: ref.watch(cloudinaryMissingConfigProvider) ?? '',
              ),
          ],
        ),
      ),
    );
  }
}

/// Explains why the slip button is absent rather than showing a dead control.
class _SlipUnavailable extends StatelessWidget {
  const _SlipUnavailable({required this.reason});

  /// The configuration hint, shown as supporting detail.
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.cloud_off_rounded,
                size: 18,
                color: AppColors.inkMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  PaymentStrings.slipNotAvailableHint,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
            ],
          ),
          if (reason.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              reason,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.inkSubtle,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The MVP disclaimer, shown above the confirm button.
class _MvpNotice extends StatelessWidget {
  const _MvpNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              AppStrings.mvpPaymentNotice,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
