import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:thai_promptpay/thai_promptpay.dart';

import '../../../core/constants/app_enums.dart' hide AsyncValue;
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/payment_strings.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/services/image/image_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/store_model.dart';

import '../../../models/coupon_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/catalog_provider.dart';
import '../../../providers/coupon_provider.dart';
import '../../../providers/image_storage_provider.dart';
import '../../../providers/order_provider.dart';
import '../../../repositories/order_repository.dart' show OrderWriteException; // การนำเข้า OrderWriteException จาก order_repository.dart เพื่อใช้ในการจัดการข้อผิดพลาดที่เกิดขึ้นเมื่อมีปัญหาในการสร้างคำสั่งซื้อ
import '../../../widgets/state_views.dart';



/// ไฟล์นี้เป็นไฟล์ที่เก็บหน้าจอชำระเงินของแอป โดยมีฟอร์มให้กรอกที่อยู่จัดส่งและปุ่มไปยังหน้าชำระเงิน
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
/// ยืนยันวิธีชำระเงินและสร้างออเดอร์; gateway จริงยังไม่เชื่อมใน MVP
class PaymentScreen extends ConsumerWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Everything comes from providers so this screen can be reached by URL as
    // well as by tapping through from checkout.
    final CheckoutDraft? draft = ref.watch(checkoutDraftProvider);
    final AsyncValue<UserModel?> auth = ref.watch(authUserProvider);
    final UserModel? user = auth.value;

    if (draft == null) {
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

    if (auth.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.payNow)),
        body: const LoadingView(),
      );
    }
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.payNow)),
        body: EmptyView(
          title: AppStrings.noDraftTitle,
          body: AppStrings.noDraftHint,
          icon: Icons.lock_outline_rounded,
          actionLabel: AppStrings.continueShopping,
          onAction: () => context.go(AppRoutes.home),
        ),
      );
    }

    // The store name is written onto the order so history reads correctly even
    // if the store is renamed or removed later.
    final AsyncValue<StoreModel?> storeState = ref.watch(
      storeProvider(draft.storeId),
    );
    if (storeState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.payNow)),
        body: const LoadingView(),
      );
    }
    if (storeState.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.payNow)),
        body: ErrorView(
          message: 'ไม่โหลดข้อมูลร้านค้าได้',
          detail: '${storeState.error}',
          onRetry: () => ref.invalidate(storeProvider(draft.storeId)),
        ),
      );
    }
    final StoreModel? store = storeState.value;

    return _PaymentForm(
      lines: ref.watch(cartProvider),
      user: user,
      storeId: draft.storeId,
      storeName: store?.name ?? '',
      promptPayId: store?.promptPayId ?? '',
      bankName: store?.bankName ?? '',
      bankAccountName: store?.bankAccountName ?? '',
      bankAccountNumber: store?.bankAccountNumber ?? '',
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
    required this.promptPayId,
    required this.bankName,
    required this.bankAccountName,
    required this.bankAccountNumber,
    required this.shippingAddress,
  });

  final List<CartLine> lines;
  final UserModel user;
  final String storeId;
  final String storeName;
  final String promptPayId;
  final String bankName;
  final String bankAccountName;
  final String bankAccountNumber;
  final String shippingAddress;

  @override
  ConsumerState<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends ConsumerState<_PaymentForm> {
  PaymentMethod _method = PaymentMethod.promptPay;
  String? _slipUrl;
  String? _error;
  bool _uploadingSlip = false;

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
    final CouponModel? applied = ref.watch(appliedCouponProvider);
    final double discount =
        applied?.discountFor(subtotal: subtotal, storeId: widget.storeId) ?? 0;
    final double total = getCartTotal(subtotal) - discount;
    final int totalSatang = (total * 100).round();
    final bool destinationReady = _destinationReady(totalSatang);
    final bool canConfirm =
        _method == PaymentMethod.cashOnDelivery ||
        (destinationReady && _slipUrl != null && !_uploadingSlip);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.payNow)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: <Widget>[
          _orderSummaryCard(subtotal, discount, total, couponCode: applied?.code),
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
          _TransferInstructions(
            method: _method,
            promptPayId: widget.promptPayId,
            amountSatang: totalSatang,
            bankName: widget.bankName,
            bankAccountName: widget.bankAccountName,
            bankAccountNumber: widget.bankAccountNumber,
            slipUrl: _slipUrl,
            uploadingSlip: _uploadingSlip,
            onPickSlip: _pickSlip,
            onRemoveSlip: () => setState(() {
              _slipUrl = null;
              _error = null;
            }),
          ),
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
              onPressed: busy || !canConfirm ? null : _confirm,
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

  bool _destinationReady(int amountSatang) {
    if (_method == PaymentMethod.promptPay) {
      return buildPromptPayPayload(widget.promptPayId, amountSatang) != null;
    }
    if (_method == PaymentMethod.bankTransfer) {
      return widget.bankName.trim().isNotEmpty &&
          widget.bankAccountName.trim().isNotEmpty &&
          widget.bankAccountNumber.trim().isNotEmpty;
    }
    return true;
  }

  Future<void> _pickSlip() async {
    if (!ref.read(cloudinaryConfiguredProvider)) {
      setState(() {
        _error =
            ref.read(cloudinaryMissingConfigProvider) ??
            PaymentStrings.slipRequiresConfig;
      });
      return;
    }

    try {
      final XFile? file = await ref.read(paymentSlipPickerProvider).pickImage();
      if (file == null || !mounted) return;
      setState(() {
        _uploadingSlip = true;
        _error = null;
      });
      final UploadedImage uploaded = await ref
          .read(imageStorageServiceProvider)
          .uploadImage(
            file: file,
            folder: ImageUploadPolicy.folderForPaymentSlip(
              paymentId:
                  '${widget.user.uid}-${DateTime.now().microsecondsSinceEpoch}',
            ),
          );
      if (!mounted) return;
      setState(() {
        _slipUrl = uploaded.url;
        _uploadingSlip = false;
      });
    } on ImageUploadException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _uploadingSlip = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'แนบหลักฐานไม่สำเร็จ: $error';
        _uploadingSlip = false;
      });
    }
  }

  Widget _orderSummaryCard(
    double subtotal,
    double discount,
    double total, {
    String? couponCode,
  }) {
    final double shippingFee = getShippingFee(subtotal);
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
                  shippingFee == 0 ? AppStrings.freeShipping : Fmt.price(shippingFee),
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
            if (couponCode != null && discount > 0) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    AppStrings.couponDiscountLabel,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                  Text(
                    '$couponCode · -${Fmt.price(discount)}',
                    style: AppTextStyles.bodySmall.copyWith(
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
            slipUrl: _slipUrl,
            coupon: ref.read(appliedCouponProvider),
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
    messenger.showSnackBar(
      const SnackBar(content: Text(AppStrings.orderPlaced)),
    );
    context.go(AppRoutes.orderTracking(orderId));
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

  static const Map<PaymentMethod, IconData> _icons = <PaymentMethod, IconData>{
    PaymentMethod.promptPay: Icons.qr_code_2_rounded,
    PaymentMethod.bankTransfer: Icons.account_balance_rounded,
    PaymentMethod.cashOnDelivery: Icons.local_shipping_outlined,
  };

  static const Map<PaymentMethod, String> _hints = <PaymentMethod, String>{
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
  const _TransferInstructions({
    required this.method,
    required this.promptPayId,
    required this.amountSatang,
    required this.bankName,
    required this.bankAccountName,
    required this.bankAccountNumber,
    required this.slipUrl,
    required this.uploadingSlip,
    required this.onPickSlip,
    required this.onRemoveSlip,
  });

  final PaymentMethod method;
  final String promptPayId;
  final int amountSatang;
  final String bankName;
  final String bankAccountName;
  final String bankAccountNumber;
  final String? slipUrl;
  final bool uploadingSlip;
  final VoidCallback onPickSlip;
  final VoidCallback onRemoveSlip;

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
          title: Text(PaymentStrings.codHint, style: AppTextStyles.bodyMedium),
        ),
      );
    }

    final bool canUpload = ref.watch(cloudinaryConfiguredProvider); 
    final String? qrPayload = method == PaymentMethod.promptPay  
        ? buildPromptPayPayload(promptPayId, amountSatang) //จะสร้าง payload ของ QR PromptPay โดยใช้ promptPayId และ amountSatang
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (method == PaymentMethod.promptPay) ...<Widget>[
              if (qrPayload == null)
                const _PaymentSetupHint(
                  message: 'ร้านยังไม่ได้ตั้งค่า PromptPay ID ที่ถูกต้อง',
                  detail:
                      'ให้ผู้ขายเพิ่มเบอร์ PromptPay หรือเลขรับเงินในโปรไฟล์ร้าน',
                )
              else ...<Widget>[
                Center(
                  child: QrImageView(
                    data: qrPayload,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                    semanticsLabel:
                        'QR PromptPay สำหรับยอดชำระของคำสั่งซื้อนี้',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: Text(
                    'PromptPay: $promptPayId',
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ] else if (bankName.trim().isEmpty ||
                bankAccountName.trim().isEmpty ||
                bankAccountNumber.trim().isEmpty)
              const _PaymentSetupHint(
                message: 'ร้านยังไม่ได้ตั้งค่าบัญชีธนาคาร',
                detail: 'ให้ผู้ขายเพิ่มข้อมูลบัญชีในโปรไฟล์ร้าน',
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.account_balance_outlined),
                title: Text(bankName),
                subtitle: Text('$bankAccountName\n$bankAccountNumber'),
                isThreeLine: true,
              ),
            const Divider(height: AppSpacing.lg),
            Text('แนบหลักฐานการชำระเงิน', style: AppTextStyles.labelMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'รองรับ JPG, PNG, WebP หรือ HEIC ขนาดไม่เกิน 5 MB',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (slipUrl != null)
              Row(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: AppRadius.cardRadius,
                    child: Image.network(
                      slipUrl!,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (
                            BuildContext context,
                            Object error,
                            StackTrace? stack,
                          ) => const SizedBox.square(
                            dimension: 72,
                            child: Icon(Icons.receipt_long_outlined),
                          ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(child: Text('แนบหลักฐานแล้ว')),
                  IconButton(
                    tooltip: 'เปลี่ยนหลักฐาน',
                    onPressed: uploadingSlip ? null : onPickSlip,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  IconButton(
                    tooltip: 'นำหลักฐานออก',
                    onPressed: uploadingSlip ? null : onRemoveSlip,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              )
            else if (uploadingSlip)
              const Row(
                children: <Widget>[
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text('กำลังอัปโหลดหลักฐาน...'),
                ],
              )
            else if (canUpload)
              OutlinedButton.icon(
                onPressed: onPickSlip,
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

class _PaymentSetupHint extends StatelessWidget {
  const _PaymentSetupHint({required this.message, required this.detail});

  final String message;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.warningLight,
      borderRadius: AppRadius.cardRadius,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(message, style: AppTextStyles.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(detail, style: AppTextStyles.bodySmall),
      ],
    ),
  );
}

String? buildPromptPayPayload(String promptPayId, int amountSatang) { //จะสร้าง payload ของ QR PromptPay โดยใช้ promptPayId และ amountSatang
  final String id = promptPayId.trim();
  if (id.isEmpty) return null;
  final String digits = id.replaceAll(RegExp(r'\D'), '');
  final PromptPayType? type = digits.length == 10 || id.startsWith('+66')
      ? PromptPayType.mobile
      : digits.length == 13
      ? PromptPayType.nationalId
      : digits.length == 15
      ? PromptPayType.eWallet
      : null;
  if (type == null) return null;
  try {
    return encodePromptPay(
      target: PromptPayTarget(type, id),
      amountSatang: amountSatang,
    );
  } on FormatException {
    return null;
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
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.warning,
          ),
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
