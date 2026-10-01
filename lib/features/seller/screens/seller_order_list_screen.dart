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
import '../../../models/store_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/seller_catalog_provider.dart';
import '../../../widgets/state_views.dart';
import '../../orders/screens/order_list_screen.dart' show StatusChip;

/// The seller's order inbox: every order placed against one of their stores.
///
/// This is the screen that makes the demo-only advance control on the buyer's
/// order detail unnecessary — the same [AdvanceOrderStatusController] drives
/// the step button here, but it now sits in a screen the seller chose to open
/// rather than one a customer happens to be looking at.
/// กล่องออเดอร์ของร้านผู้ขาย พร้อมควบคุมการเดินสถานะและเลขพัสดุ
class SellerOrderListScreen extends ConsumerStatefulWidget {
  const SellerOrderListScreen({super.key});

  @override
  ConsumerState<SellerOrderListScreen> createState() =>
      _SellerOrderListScreenState();
}

class _SellerOrderListScreenState extends ConsumerState<SellerOrderListScreen> {
  /// The single status the inbox is filtered by, or null for all of them.
  ///
  /// The filter is client-side on purpose: the rules prove `storeId` ownership
  /// from the query, and a `where('status', ...)` on top of it would need a
  /// composite index. A store's order list is small enough to filter in Dart.
  OrderStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final UserModel? user = ref.watch(authUserProvider).asData?.value;

    // Layer 2 of the role gate (layer 1 is firestore.rules): a customer who
    // types the URL sees a sentence, not a list of denied reads.
    if (user == null || (!user.isSeller && !user.isAdmin)) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.sellerOrders)),
        body: const EmptyView(
          icon: Icons.lock_outline_rounded,
          title: AppStrings.errNotAuthorised,
        ),
      );
    }

    final storeState = ref.watch(myStoreProvider);
    if (storeState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.sellerOrders)),
        body: const LoadingView(),
      );
    }
    if (storeState.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.sellerOrders)),
        body: ErrorView(
          message: '${storeState.error}',
          onRetry: () => ref.invalidate(myStoreProvider),
        ),
      );
    }

    final StoreModel? store = storeState.asData?.value;
    if (store == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.sellerOrders)),
        body: const EmptyView(
          icon: Icons.storefront_outlined,
          title: AppStrings.sellerNoStoreTitle,
          body: AppStrings.sellerNoStoreHint,
        ),
      );
    }

    final String storeId = store.id;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.sellerOrders)),
      body: Column(
        children: <Widget>[
          _statusFilterBar(),
          Expanded(child: _ordersBody(storeId)),
        ],
      ),
    );
  }

  Widget _statusFilterBar() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.sm,
        ),
        children: <Widget>[
          _filterChip(AppStrings.sellerOrderFilterAll, status: null),
          // `paid` is where a seller has work to do (confirm the transfer);
          // `awaitingShipment` is where the parcel goes out.
          for (final OrderStatus status in <OrderStatus>[
            OrderStatus.paid,
            OrderStatus.awaitingShipment,
            OrderStatus.shipped,
            OrderStatus.completed,
            OrderStatus.cancelled,
          ])
            _filterChip(status.label, status: status),
        ],
      ),
    );
  }

  Widget _filterChip(String label, {required OrderStatus? status}) {
    final bool selected = _statusFilter == status;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => setState(() => _statusFilter = status),
      ),
    );
  }

  Widget _ordersBody(String storeId) {
    final orders = ref.watch(storeOrdersProvider(storeId));
    return orders.when(
      loading: () => const SkeletonListView(itemCount: 4, height: 120),
      error: (Object e, StackTrace _) => ErrorView(
        message: '$e',
        onRetry: () => ref.invalidate(storeOrdersProvider(storeId)),
      ),
      data: (List<OrderModel> all) {
        final List<OrderModel> visible = _statusFilter == null
            ? all
            : all
                  .where((OrderModel o) => o.status == _statusFilter)
                  .toList(growable: false);

        if (all.isEmpty) {
          return const EmptyView(
            icon: Icons.receipt_long_outlined,
            title: AppStrings.sellerNoOrders,
            body: AppStrings.sellerNoOrdersHint,
          );
        }
        if (visible.isEmpty) {
          return const EmptyView(
            icon: Icons.filter_alt_off_outlined,
            title: AppStrings.emptyOrders,
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(storeOrdersProvider(storeId).future),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            itemCount: visible.length,
            separatorBuilder: (BuildContext context, int _) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int i) =>
                _OrderRow(order: visible[i]),
          ),
        );
      },
    );
  }
}

/// One order in the inbox, with the step the seller can take right now.
class _OrderRow extends ConsumerWidget {
  const _OrderRow({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OrderStatus? next = order.nextStatus;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.orderDetail(order.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      order.buyerName.isEmpty
                          ? AppStrings.navOrders
                          : order.buyerName,
                      style: AppTextStyles.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    Fmt.price(order.total),
                    style: AppTextStyles.priceMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: <Widget>[
                  Text(
                    '${AppStrings.orderIdPrefix} ${order.id}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.inkMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  StatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: <Widget>[
                  Text(
                    Fmt.fill(
                      AppStrings.sellerOrderItems,
                      count: order.itemCount,
                    ),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.inkSubtle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      Fmt.dateTime(order.createdAt),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.inkSubtle,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (order.isCancelled) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.sellerOrderCancelledNote,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ] else ...<Widget>[
                if (order.trackingNumber != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${AppStrings.trackingNumberPrefix} ${order.trackingNumber}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.inkMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (next != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      // An unpaid order is not the seller's job yet, but the
                      // seller does need to see that it is sitting there.
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: _statusChipFor(),
                      ),
                      const Spacer(),
                      FilledButton.tonalIcon(
                        onPressed: () => _advance(context, ref, next),
                        icon: const Icon(Icons.trending_up_rounded, size: 18),
                        label: Text(
                          Fmt.fill(
                            AppStrings.advanceToStatus,
                            status: next.label,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChipFor() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Text(
        order.status == OrderStatus.pendingPayment
            ? AppStrings.sellerOrderAwaitingPayment
            : AppStrings.sellerOrderNeedsAction,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.warning),
      ),
    );
  }

  Future<void> _advance(
    BuildContext context,
    WidgetRef ref,
    OrderStatus next,
  ) async {
    // Shipping is the one step that carries data the buyer cannot know: the
    // courier number. Ask for it here rather than after the fact, and allow it
    // to stay empty because an OTOP seller often hands the parcel over in
    // person.
    String? trackingNumber;
    if (next == OrderStatus.shipped) {
      trackingNumber = await _askTrackingNumber(context);
      // `null` means the seller backed out of the sheet, not "no number".
      if (trackingNumber == null || !context.mounted) return;
    }

    if (!context.mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(advanceOrderStatusProvider.notifier)
          .advance(order.id, next, trackingNumber: trackingNumber);
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            Fmt.fill(AppStrings.advanceStatusDone, status: next.label),
          ),
        ),
      );
    } on Object catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${AppStrings.advanceStatusFailed}: $e')),
      );
    }
  }

  /// Returns the typed number, `''` when left blank, or `null` if dismissed.
  Future<String?> _askTrackingNumber(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (BuildContext _) =>
          _ShipTrackingSheet(initialValue: order.trackingNumber),
    );
  }
}

/// The tracking-number sheet shown when a seller marks an order shipped.
///
/// A `StatefulWidget` rather than a bare `AlertDialog` with a controller made
/// in the caller: `showDialog`'s future resolves as soon as the route is popped,
/// while its exit animation is still building the field. Disposing the
/// controller at that point throws "a TextEditingController was used after being
/// disposed". A widget that owns the controller disposes it when the element is
/// actually gone, however the dialog was dismissed.
class _ShipTrackingSheet extends StatefulWidget {
  const _ShipTrackingSheet({this.initialValue});

  final String? initialValue;

  @override
  State<_ShipTrackingSheet> createState() => _ShipTrackingSheetState();
}

class _ShipTrackingSheetState extends State<_ShipTrackingSheet> {
  late final TextEditingController _field = TextEditingController(
    text: widget.initialValue ?? '',
  );

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.sellerShipTrackingTitle),
      content: TextField(
        controller: _field,
        autofocus: true,
        keyboardType: TextInputType.text,
        decoration: const InputDecoration(
          labelText: AppStrings.sellerShipTrackingLabel,
          hintText: AppStrings.sellerShipTrackingHint,
          border: OutlineInputBorder(),
        ),
        onSubmitted: (String value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.sellerShipCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_field.text.trim()),
          child: const Text(AppStrings.sellerShipConfirm),
        ),
      ],
    );
  }
}
