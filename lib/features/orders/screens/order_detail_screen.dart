import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart' show OrderStatus;
import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/order_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/order_provider.dart';
import '../../../widgets/state_views.dart';
import '../../orders/widgets/order_status_timeline.dart';
import 'order_list_screen.dart' show StatusChip;

/// One order: what was bought, where it is, and the demo seller control.
///
/// Subscribed to the order document rather than reading it once, so a status
/// change by the seller appears without the buyer pulling to refresh — which is
/// the whole point of having a status at all.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<OrderModel?> order = ref.watch(orderProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.orderDetailTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: order.when(
        loading: () => const SkeletonListView(itemCount: 5, height: 96),
        error: (Object error, StackTrace stackTrace) => ErrorView(
          onRetry: () => ref.invalidate(orderProvider(orderId)),
        ),
        data: (OrderModel? o) {
          if (o == null) {
            return EmptyView(
              title: AppStrings.orderNotFoundTitle,
              body: AppStrings.orderNotFoundHint,
              icon: Icons.search_off_rounded,
              actionLabel: AppStrings.backToOrders,
              onAction: () => context.go(AppRoutes.orders),
            );
          }
          return _Detail(order: o);
        },
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: <Widget>[
        _headerCard(),
        const SizedBox(height: AppSpacing.lg),
        Text(
          AppStrings.orderStatusTitle,
          style: AppTextStyles.labelMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: OrderStatusTimeline(order: order),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(AppStrings.orderItems, style: AppTextStyles.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: <Widget>[
                for (final OrderItem i in order.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                i.name,
                                style: AppTextStyles.bodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (i.variantLabel != null)
                                Text(
                                  i.variantLabel!,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${i.quantity} x ${Fmt.price(i.price)}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          Fmt.price(i.lineTotal),
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                const Divider(height: AppSpacing.lg),
                _totalRow(AppStrings.subtotal, Fmt.price(order.subtotal)),
                _totalRow(
                  AppStrings.shipping,
                  order.shippingFee == 0
                      ? AppStrings.freeShipping
                      : Fmt.price(order.shippingFee),
                ),
                const SizedBox(height: AppSpacing.xs),
                _totalRow(
                  AppStrings.total,
                  Fmt.price(order.total),
                  emphasise: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _metaCard(),
        // The demo control is the last thing on the page and clearly labelled,
        // so it is never mistaken for a control a real customer would have.
        if (_canAdvance(ref)) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _DemoAdvanceControl(order: order),
        ],
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            // เมื่อมาจากการสั่งซื้อ (context.go) หน้าเพจไม่มีลูกศรย้อนกลับ
            // ให้ปุ่มนี้เป็นทางออก ถ้าเป็น path ปกติ (push) ก็ pop กลับตามเดิม
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go(AppRoutes.orders);
              }
            },
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text(AppStrings.backToOrders),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _headerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    order.storeName.isEmpty
                        ? AppStrings.stores
                        : order.storeName,
                    style: AppTextStyles.bodyLarge,
                  ),
                ),
                StatusChip(status: order.status, large: true),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${AppStrings.orderIdPrefix} ${order.id}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              Fmt.dateTime(order.createdAt),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.inkSubtle,
              ),
            ),
            if (order.trackingNumber != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.local_shipping_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${AppStrings.trackingNumberPrefix} ${order.trackingNumber}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metaCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AppStrings.paymentMethod,
              style: AppTextStyles.labelMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              order.paymentMethod.label,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${AppStrings.paymentStatus}: ${order.paymentStatus.label}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              AppStrings.shippingAddress,
              style: AppTextStyles.labelMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(order.shippingAddress, style: AppTextStyles.bodyMedium),
            if (order.note != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(AppStrings.orderNote, style: AppTextStyles.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(order.note!, style: AppTextStyles.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool emphasise = false}) {
    final TextStyle style = emphasise
        ? AppTextStyles.labelLarge
        : AppTextStyles.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: style),
          Text(
            value,
            style: emphasise
                ? AppTextStyles.priceLarge.copyWith(color: AppColors.primary)
                : style,
          ),
        ],
      ),
    );
  }

  /// Only a seller of this order's store, or an admin, may write the status —
  /// the same condition `firestore.rules` enforces. Showing the control to a
  /// plain customer would only produce a permission error.
  bool _canAdvance(WidgetRef ref) {
    final UserModel? user = ref.watch(authUserProvider).asData?.value;
    if (user == null) return false;
    if (user.isAdmin) return true;
    if (order.isFinished) return false;
    return user.isSeller;
  }
}

/// Demo-only: walks the order to its next legal status.
///
/// Deliberately visible only to a seller/admin, matching the rule that only
/// they may change `status`. It exists so the six states can be demonstrated
/// without the seller console, which is later work.
class _DemoAdvanceControl extends ConsumerStatefulWidget {
  const _DemoAdvanceControl({required this.order});

  final OrderModel order;

  @override
  ConsumerState<_DemoAdvanceControl> createState() =>
      _DemoAdvanceControlState();
}

class _DemoAdvanceControlState extends ConsumerState<_DemoAdvanceControl> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final OrderStatus? next = widget.order.nextStatus;
    final bool busy = ref.watch(advanceOrderStatusProvider);

    return Card(
      color: AppColors.surfaceMuted,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.science_outlined,
                  size: 18,
                  color: AppColors.info,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  AppStrings.demoSellerControl,
                  style: AppTextStyles.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppStrings.demoSellerControlHint,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.inkMuted,
              ),
            ),
            if (next != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: busy ? null : () => _advance(next),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          Fmt.fill(
                            AppStrings.advanceToStatus,
                            status: next.label,
                          ),
                        ),
                ),
              ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _advance(OrderStatus next) async {
    setState(() => _error = null);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(advanceOrderStatusProvider.notifier)
          .advance(widget.order.id, next);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            Fmt.fill(AppStrings.advanceStatusDone, status: next.label),
          ),
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = '${AppStrings.advanceStatusFailed}: $e');
    }
  }
}
