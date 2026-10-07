import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart' hide AsyncValue;
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
import '../../../widgets/design_system.dart';
import '../../../widgets/state_views.dart';

/// The seller console's front door, laid out as the HTML design's dashboard:
/// a today-summary strip, a numbered "what to do next" queue, low-stock
/// warnings per variant, then the new-orders list with an inline status
/// timeline.
///
/// Designed strictly for 1 Seller = 1 Store with isolated store queries.
/// แดชบอร์ดผู้ขาย: สรุปวันนี้, งานที่ต้องทำต่อ, สต็อกใกล้หมด, ออเดอร์ใหม่
class SellerHomeScreen extends ConsumerWidget {
  const SellerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserModel? user = ref.watch(authUserProvider).asData?.value;

    // Layer 2 role-gate
    if (user == null || (!user.isSeller && !user.isAdmin)) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.navSellerDashboard)),
        body: const EmptyView(
          icon: Icons.lock_outline_rounded,
          title: AppStrings.errNotAuthorised,
        ),
      );
    }

    final storeState = ref.watch(myStoreProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.gutter,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              AppStrings.navSellerDashboard,
              style: AppTextStyles.headlineSmall,
            ),
            Text(
              'สวัสดี ${user.shortName}',
              style: AppTextStyles.labelSmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          // ปุ่ม "รายงาน Affiliate" เคยอยู่หลังปุ่มนี้ — ลบแล้ว (6 ต.ค. 2569)
          IconButton(
            tooltip: 'ดูตลาด OTOP',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => context.push(AppRoutes.stores),
          ),
          IconButton(
            tooltip: AppStrings.logout,
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: storeState.when(
        loading: () => const LoadingView(),
        error: (Object err, StackTrace _) => ErrorView(
          detail: '$err',
          onRetry: () => ref.invalidate(myStoreProvider),
        ),
        data: (StoreModel? store) {
          if (store == null) {
            return const EmptyView(
              icon: Icons.storefront_outlined,
              title: AppStrings.sellerNoStoreTitle,
              body: AppStrings.sellerNoStoreHint,
            );
          }
          return _SellerBody(store: store);
        },
      ),
    );
  }
}

/// The dashboard body. Split out so [SellerHomeScreen] only handles the role
/// gate and the store lookup.
class _SellerBody extends ConsumerStatefulWidget {
  const _SellerBody({required this.store});

  final StoreModel store;

  @override
  ConsumerState<_SellerBody> createState() => _SellerBodyState();
}

class _SellerBodyState extends ConsumerState<_SellerBody> {
  /// Which order has its timeline expanded, if any. A single id rather than a
  /// set: the design opens one order at a time, so the seller is never looking
  /// at two timelines at once.
  String? _expandedOrderId;

  /// Drives the `อัปเดตสถานะออเดอร์แล้ว` toast after a successful advance.
  bool _toastVisible = false;

  /// Anchor for the low-stock block, so the queue's "ดูสต็อก" chip can scroll
  /// to it instead of navigating away from the screen the seller is on.
  final GlobalKey _lowStockKey = GlobalKey();

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLowStock() {
    final BuildContext? target = _lowStockKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String storeId = widget.store.id;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myStoreProvider);
        ref.invalidate(myProductsProvider(storeId));
        ref.invalidate(storeOrdersProvider(storeId));
        ref.invalidate(lowStockVariantsProvider(storeId));
      },
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: <Widget>[
          AppTopToast(
            visible: _toastVisible,
            message: 'อัปเดตสถานะออเดอร์แล้ว',
          ),
          _TodayStrip(store: widget.store),
          // The design's seller nav lives in a bottom tab bar, which was ruled
          // out. These four targets are the only way to reach products, orders
          // and the store profile, so they stay as a row under the header.
          _SectionNav(storeId: storeId),
          _TodoQueue(storeId: storeId, onScrollToStock: _scrollToLowStock),
          _LowStockSection(storeId: storeId, sectionKey: _lowStockKey),
          _NewOrdersSection(
            storeId: storeId,
            expandedOrderId: _expandedOrderId,
            onToggle: (String id) => setState(() {
              _expandedOrderId = _expandedOrderId == id ? null : id;
            }),
            onAdvanced: () => setState(() => _toastVisible = true),
          ),
        ],
      ),
    );
  }
}

/// ทางลัดจัดการสินค้า ออเดอร์ และร้าน — คู่กับปุ่มเพิ่มสินค้า
///
/// The four destinations from the design's seller tab bar. Rendered as a row of
/// labelled buttons rather than icons, because `สินค้า` and `ออเดอร์` are two
/// different words a new seller will not tell apart by glyph.
class _SectionNav extends StatelessWidget {
  const _SectionNav({required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context) {
    final List<(IconData, String, VoidCallback)> targets =
        <(IconData, String, VoidCallback)>[
          (
            Icons.add_circle_outline_rounded,
            AppStrings.sellerAddProduct,
            () => context.push(AppRoutes.sellerProductNew(storeId)),
          ),
          (
            Icons.inventory_2_outlined,
            AppStrings.navSellerProducts,
            () => context.push(AppRoutes.sellerProducts),
          ),
          (
            Icons.receipt_long_outlined,
            AppStrings.navSellerOrders,
            () => context.push(AppRoutes.sellerOrders),
          ),
          (
            Icons.settings_outlined,
            AppStrings.navSellerStore,
            () => context.push(AppRoutes.sellerStoreProfile),
          ),
        ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardGutter,
        AppSpacing.md,
        AppSpacing.cardGutter,
        0,
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < targets.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(child: _SectionNavButton(targets[i])),
          ],
        ],
      ),
    );
  }
}

class _SectionNavButton extends StatelessWidget {
  const _SectionNavButton(this.target);

  final (IconData, String, VoidCallback) target;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label, VoidCallback onTap) = target;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          // 48px keeps the whole button above the touch-target floor.
          constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The indigo header strip: store name, "ภาพรวมวันนี้" and today's takings.
///
/// Today's revenue is computed from orders created today rather than shipped
/// today, because a seller thinks of "ขายได้วันนี้" as what customers bought
/// today. Cancelled and unpaid orders are excluded — money that has not
/// arrived is not a sale.
class _TodayStrip extends ConsumerWidget {
  const _TodayStrip({required this.store});

  final StoreModel store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<OrderModel>> orders = ref.watch(
      storeOrdersProvider(store.id),
    );

    final double todayRevenue = orders.maybeWhen(
      data: (List<OrderModel> all) {
        final DateTime now = DateTime.now();
        return all
            .where(
              (OrderModel o) =>
                  !o.isCancelled &&
                  o.status != OrderStatus.pendingPayment &&
                  o.createdAt.year == now.year &&
                  o.createdAt.month == now.month &&
                  o.createdAt.day == now.day,
            )
            .fold<double>(0, (double sum, OrderModel o) => sum + o.total);
      },
      orElse: () => 0,
    );

    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardGutter,
        AppSpacing.md,
        AppSpacing.cardGutter,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  store.name,
                  style: const TextStyle(
                    color: AppColors.onPrimaryMuted,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  store.province.isEmpty ? 'ภาพรวมวันนี้' : 'ภาพรวมวันนีี',
                  style: const TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                const Text(
                  'ขายได้วันนี้',
                  style: TextStyle(
                    color: AppColors.onPrimaryMuted,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  Fmt.price(todayRevenue),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The numbered "ทำอะไรต่อ" queue.
///
/// Each row is an *action*, not a metric: the design's point is that the seller
/// opens this screen and immediately knows which three things to fix, in the
/// order they matter. Rows with nothing to do are dropped entirely rather than
/// shown greyed out, so the list never teaches the seller to skim past it.
class _TodoQueue extends ConsumerWidget {
  const _TodoQueue({required this.storeId, required this.onScrollToStock});

  final String storeId;

  /// Scrolls the low-stock block into view — the design's chip behaviour.
  final VoidCallback onScrollToStock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SellerDashboardMetrics> metrics = ref.watch(
      sellerDashboardMetricsProvider(storeId),
    );

    // Nothing to rank until metrics land, so the queue stays absent rather than
    // flashing an empty "ทำอะไรต่อ" heading.
    final List<_TodoItem> items = metrics.maybeWhen(
      data: _build,
      orElse: () => const <_TodoItem>[],
    );

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const AppSectionLabel('ทำอะไรต่อ เรียงตามลำดับที่ต้องแก้'),
        for (int i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardGutter,
              0,
              AppSpacing.cardGutter,
              AppSpacing.sm,
            ),
            child: _TodoRow(
              index: i + 1,
              item: items[i],
              onTap: items[i].target == _TodoTarget.stock
                  ? onScrollToStock
                  : () => context.push(AppRoutes.sellerOrders),
            ),
          ),
      ],
    );
  }

  static List<_TodoItem> _build(SellerDashboardMetrics m) => <_TodoItem>[
    if (m.pendingOrdersCount > 0)
      _TodoItem(
        title: 'ยืนยันออเดอร์ ${m.pendingOrdersCount} รายการ',
        caption: 'ค้างมานานที่สุด 6 ชั่วโมง',
        action: 'จัดการ',
        target: _TodoTarget.orders,
      ),
    if (m.lowStockCount > 0)
      _TodoItem(
        title: 'เติมสต็อกที่ใกล้หมด ${m.lowStockCount} รายการ',
        caption: 'ขายได้เกือบหมด อย่าให้ลิงก์ล้ม',
        action: 'ดูสต็อก',
        target: _TodoTarget.stock,
      ),
    if (m.awaitingShipmentCount > 0)
      _TodoItem(
        title: 'จัดส่งออเดอร์ที่ค้าง ${m.awaitingShipmentCount} รายการ',
        caption: 'นัดส่งวันนี้ ก่อน 16:00',
        action: 'ดูออเดอร์',
        target: _TodoTarget.orders,
      ),
  ];
}

/// Where a queue row's chip should take the seller.
enum _TodoTarget { orders, stock }

class _TodoItem {
  const _TodoItem({
    required this.title,
    required this.caption,
    required this.action,
    required this.target,
  });

  final String title;
  final String caption;
  final String action;
  final _TodoTarget target;
}

/// One row of the "what to do next" list: a number badge, the task, and a chip
/// that jumps to the relevant section.
class _TodoRow extends StatelessWidget {
  const _TodoRow({
    required this.index,
    required this.item,
    required this.onTap,
  });

  final int index;
  final _TodoItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.caption,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppChip(label: item.action, onTap: onTap, height: 40),
        ],
      ),
    );
  }
}

/// Low-stock warnings, one row per variant.
///
/// A warning is only worth a row if the seller can act on it, so each one
/// carries the remaining count and a button straight into the edit form at the
/// right step.
class _LowStockSection extends ConsumerWidget {
  const _LowStockSection({required this.storeId, required this.sectionKey});

  final String storeId;

  /// Anchor used by the "ดูสต็อก" chip in the queue above to scroll here.
  final GlobalKey sectionKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<LowStockVariant>> low = ref.watch(
      lowStockVariantsProvider(storeId),
    );

    return low.maybeWhen(
      data: (List<LowStockVariant> items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          key: sectionKey,
          children: <Widget>[
            AppSectionLabel(
              'สต็อกใกล้หมด',
              trailing: Text(
                '${items.length} รายการ',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final LowStockVariant item in items)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.cardGutter,
                  0,
                  AppSpacing.cardGutter,
                  AppSpacing.sm,
                ),
                child: _LowStockRow(item: item),
              ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _LowStockRow extends StatelessWidget {
  const _LowStockRow({required this.item});

  final LowStockVariant item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.warningLight,
      borderColor: AppColors.warning,
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            size: 22,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  item.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'เหลือ ${item.stock} ชิ้น · ขายแล้ว ${item.product.soldCount}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppColors.warning,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppChip(
            label: 'เติมสต็อก',
            height: 40,
            onTap: () =>
                context.push(AppRoutes.sellerProductEdit(item.product.id)),
          ),
        ],
      ),
    );
  }
}

/// The new-orders list. Each row shows a stage rail and can expand into the
/// full status timeline with the legal next action.
class _NewOrdersSection extends ConsumerWidget {
  const _NewOrdersSection({
    required this.storeId,
    required this.expandedOrderId,
    required this.onToggle,
    required this.onAdvanced,
  });

  final String storeId;
  final String? expandedOrderId;
  final ValueChanged<String> onToggle;
  final VoidCallback onAdvanced;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<OrderModel>> ordersAsync = ref.watch(
      storeOrdersProvider(storeId),
    );

    return ordersAsync.when(
      loading: () => const SkeletonCards(itemCount: 3),
      error: (Object e, StackTrace _) => InlineErrorBanner(
        message: AppStrings.errorBody,
        detail: '$e',
        onRetry: () => ref.invalidate(storeOrdersProvider(storeId)),
      ),
      data: (List<OrderModel> allOrders) {
        // Only the statuses a seller can still act on. Cancelled and completed
        // orders are history, not work.
        final List<OrderModel> actionOrders = allOrders
            .where(
              (OrderModel o) =>
                  o.status == OrderStatus.paid ||
                  o.status == OrderStatus.awaitingShipment ||
                  o.status == OrderStatus.pendingPayment,
            )
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppSectionLabel(
              'ออเดอร์ใหม่',
              trailing: TextButton(
                onPressed: () => context.push(AppRoutes.sellerOrders),
                child: const Text('ดูทั้งหมด'),
              ),
            ),
            if (actionOrders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.cardGutter,
                ),
                child: EmptyView(
                  icon: Icons.inbox_outlined,
                  title: 'ไม่มีออเดอร์ที่ต้องดำเนินการ',
                  body: 'เมื่อมีคำสั่งซื้อเข้ามาใหม่ จะแสดงที่นี่ทันที',
                  compact: true,
                ),
              )
            else
              for (final OrderModel order in actionOrders)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.cardGutter,
                    0,
                    AppSpacing.cardGutter,
                    AppSpacing.sm,
                  ),
                  child: _OrderCard(
                    order: order,
                    expanded: order.id == expandedOrderId,
                    onToggle: () => onToggle(order.id),
                    onAdvanced: onAdvanced,
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({
    required this.order,
    required this.expanded,
    required this.onToggle,
    required this.onAdvanced,
  });

  final OrderModel order;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onAdvanced;

  /// The five lifecycle steps in order, matching the HTML timeline.
  static const List<OrderStatus> _steps = <OrderStatus>[
    OrderStatus.pendingPayment,
    OrderStatus.paid,
    OrderStatus.awaitingShipment,
    OrderStatus.shipped,
    OrderStatus.completed,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OrderStatus? next = order.nextStatus;
    final int stageIndex = _steps.indexOf(order.status);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '#${order.id} · ${_relative(order.createdAt)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                Fmt.price(order.total),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            order.items
                .map(
                  (OrderItem i) =>
                      '${i.name}'
                      '${i.variantLabel == null ? '' : ' (${i.variantLabel})'}'
                      ' x${i.quantity}',
                )
                .join(' · '),
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          AppStatusPill.semantic(
            label: order.status.label,
            tone: _tone(order.status),
            dense: true,
          ),
          const SizedBox(height: AppSpacing.md),
          AppStageRail(
            total: _steps.length,
            // A cancelled or unknown stage reads as "at the start" rather than
            // -1, which would render every segment as future work.
            currentIndex: stageIndex < 0 ? 0 : stageIndex,
            semanticsLabel: order.status.label,
          ),
          const SizedBox(height: AppSpacing.md),
          AppChunkyButton(
            label: expanded ? 'ปิด' : 'จัดการ',
            expand: false,
            height: 44,
            onPressed: onToggle,
          ),
          if (expanded) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'ออเดอร์ #${order.id}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTimeline(
              currentIndex: stageIndex < 0 ? 0 : stageIndex,
              items: <TimelineEntry>[
                for (final OrderStatus s in _steps)
                  TimelineEntry(
                    s.label,
                    caption: s == order.status ? 'อยู่ที่ขั้นนี้' : null,
                  ),
              ],
            ),
            if (next != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              AppChunkyButton(
                label: Fmt.fill(AppStrings.advanceToStatus, status: next.label),
                icon: Icons.trending_up_rounded,
                height: 44,
                onPressed: () => _advance(context, ref, next),
              ),
            ],
          ],
        ],
      ),
    );
  }

  static AppTone _tone(OrderStatus status) => switch (status) {
    OrderStatus.paid => AppTone.wait,
    OrderStatus.awaitingShipment => AppTone.info,
    OrderStatus.shipped => AppTone.good,
    OrderStatus.completed => AppTone.good,
    OrderStatus.cancelled => AppTone.bad,
    OrderStatus.pendingPayment => AppTone.off,
  };

  /// `2 ชั่วโมงที่แล้ว` — the design's relative stamp. Falls back to an absolute
  /// date once the order is old enough that "N วันที่แล้ว" stops helping.
  static String _relative(DateTime created) {
    final Duration age = DateTime.now().difference(created);
    if (age.inMinutes < 60) return '${age.inMinutes} นาทีที่แล้ว';
    if (age.inHours < 24) return '${age.inHours} ชั่วโมงที่แล้ว';
    return '${age.inDays} วันที่แล้ว';
  }

  Future<void> _advance(
    BuildContext context,
    WidgetRef ref,
    OrderStatus next,
  ) async {
    String? trackingNumber;
    if (next == OrderStatus.shipped) {
      trackingNumber = await showDialog<String>(
        context: context,
        builder: (BuildContext ctx) {
          final TextEditingController controller = TextEditingController(
            text: order.trackingNumber ?? '',
          );
          return AlertDialog(
            title: const Text(AppStrings.sellerShipTrackingTitle),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: AppStrings.sellerShipTrackingLabel,
                hintText: AppStrings.sellerShipTrackingHint,
                border: OutlineInputBorder(),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(AppStrings.sellerShipCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                child: const Text(AppStrings.sellerShipConfirm),
              ),
            ],
          );
        },
      );
      if (trackingNumber == null || !context.mounted) return;
    }

    if (!context.mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(advanceOrderStatusProvider.notifier)
          .advance(order.id, next, trackingNumber: trackingNumber);
      if (!context.mounted) return;
      onAdvanced();
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
}
