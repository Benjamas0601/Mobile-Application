import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
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

/// The seller console's front door: A comprehensive Seller Hub Dashboard
/// featuring Live Analytics KPIs, Quick Actions, and Action-required orders.
///
/// Designed strictly for 1 Seller = 1 Store with isolated store queries.
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
            Text(AppStrings.navSellerDashboard, style: AppTextStyles.headlineSmall),
            Text(
              'สวัสดี ${user.shortName} (ผู้ขาย)',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ),
        actions: <Widget>[
          // A seller who also promotes needs a way into the affiliate console.
          // `/home` redirects sellers here, so this button is the only route to
          // that dashboard for a dual-role account.
          if (user.isAffiliate || user.isAdmin)
            IconButton(
              tooltip: AppStrings.navAffiliateDashboard,
              icon: const Icon(Icons.campaign_outlined),
              onPressed: () => context.push(AppRoutes.affiliateRoot),
            ),
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
        error: (err, _) => ErrorView(
          message: '$err',
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
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myStoreProvider);
              ref.invalidate(myProductsProvider(store.id));
              ref.invalidate(storeOrdersProvider(store.id));
            },
            child: CustomScrollView(
              slivers: <Widget>[
                // 1) Store Banner Profile Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.md,
                      AppSpacing.gutter,
                      AppSpacing.sm,
                    ),
                    child: _StoreBanner(store: store),
                  ),
                ),

                // 2) Analytics KPI Grid
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.gutter,
                      vertical: AppSpacing.xs,
                    ),
                    child: _AnalyticsGrid(storeId: store.id),
                  ),
                ),

                // 3) Quick Action Buttons
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.md,
                      AppSpacing.gutter,
                      AppSpacing.sm,
                    ),
                    child: _QuickActionRow(store: store),
                  ),
                ),

                // 4) Section Header: Action-required Orders
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.lg,
                      AppSpacing.gutter,
                      AppSpacing.xs,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'คำสั่งซื้อที่ต้องดำเนินการ',
                          style: AppTextStyles.headlineSmall,
                        ),
                        TextButton(
                          onPressed: () => context.push(AppRoutes.sellerOrders),
                          child: const Text('ดูทั้งหมด'),
                        ),
                      ],
                    ),
                  ),
                ),

                // 5) Action-required Orders List
                _ActionOrdersList(storeId: store.id),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xxxl),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Store profile header card showing verified badge and navigation to edit.
class _StoreBanner extends StatelessWidget {
  const _StoreBanner({required this.store});

  final StoreModel store;

  @override
  Widget build(BuildContext context) {
    final String url = store.logoUrl ?? store.coverImageUrl;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      child: InkWell(
        onTap: () => context.push(AppRoutes.sellerStoreProfile),
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: AppRadius.cardRadius,
                child: Container(
                  width: 60,
                  height: 60,
                  color: AppColors.surfaceMuted,
                  child: url.isEmpty
                      ? const Icon(Icons.storefront_outlined, color: AppColors.inkSubtle, size: 30)
                      : Image.network(
                          url,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, _, _) => const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.inkSubtle,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            store.name,
                            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (store.otopCertified)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.successLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'OTOP รับรอง',
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.success, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      <String>[
                        if (store.community.isNotEmpty) store.community,
                        if (store.province.isNotEmpty) store.province,
                      ].join(' · '),
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.inkMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'ผู้ขาย 1 คน : 1 ร้านค้า',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkSubtle),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live KPI Cards for sales, new orders, awaiting shipment, and stock alert.
class _AnalyticsGrid extends ConsumerWidget {
  const _AnalyticsGrid({required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(sellerDashboardMetricsProvider(storeId));

    return metricsAsync.when(
      loading: () => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: AppRadius.cardRadius,
        ),
        child: const SizedBox(height: 140, width: double.infinity),
      ),
      error: (e, _) => InlineErrorBanner(message: '$e', onRetry: () {}),
      data: (SellerDashboardMetrics m) {
        return Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _KpiCard(
                    title: 'ยอดขายรวม',
                    value: Fmt.price(m.totalRevenue),
                    subtitle: 'จากคำสั่งซื้อที่ชำระแล้ว',
                    icon: Icons.monetization_on_rounded,
                    color: AppColors.primary,
                    bgColor: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _KpiCard(
                    title: 'ออเดอร์ใหม่',
                    value: '${m.pendingOrdersCount}',
                    subtitle: 'รอตรวจสอบ/ยืนยัน',
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.warning,
                    bgColor: AppColors.warningLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: _KpiCard(
                    title: 'ที่ต้องจัดส่ง',
                    value: '${m.awaitingShipmentCount}',
                    subtitle: 'พร้อมส่งพัสดุ',
                    icon: Icons.local_shipping_rounded,
                    color: AppColors.info,
                    bgColor: AppColors.infoLight,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _KpiCard(
                    title: 'สินค้าในร้าน',
                    value: '${m.totalProducts}',
                    subtitle: m.lowStockCount > 0 ? 'ใกล้หมด ${m.lowStockCount} ชิ้น' : 'สต็อกพร้อมขาย',
                    icon: Icons.inventory_2_rounded,
                    color: m.lowStockCount > 0 ? AppColors.danger : AppColors.success,
                    bgColor: m.lowStockCount > 0 ? AppColors.dangerLight : AppColors.successLight,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                title,
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.inkMuted),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            style: AppTextStyles.labelSmall.copyWith(
              color: color == AppColors.danger ? AppColors.danger : AppColors.inkSubtle,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Quick Actions Row
class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({required this.store});

  final StoreModel store;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ActionBtn(
            icon: Icons.add_circle_outline_rounded,
            label: AppStrings.sellerAddProduct,
            color: AppColors.primary,
            onTap: () => context.push(AppRoutes.sellerProductNew(store.id)),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _ActionBtn(
            icon: Icons.inventory_2_outlined,
            label: AppStrings.navSellerProducts,
            color: AppColors.clay,
            onTap: () => context.push(AppRoutes.sellerProducts),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _ActionBtn(
            icon: Icons.receipt_long_outlined,
            label: AppStrings.navSellerOrders,
            color: AppColors.warning,
            onTap: () => context.push(AppRoutes.sellerOrders),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _ActionBtn(
            icon: Icons.settings_outlined,
            label: AppStrings.navSellerStore,
            color: AppColors.inkMuted,
            onTap: () => context.push(AppRoutes.sellerStoreProfile),
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, color: color, size: 24),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Action Required Orders sliver list
class _ActionOrdersList extends ConsumerWidget {
  const _ActionOrdersList({required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(storeOrdersProvider(storeId));

    return ordersAsync.when(
      loading: () => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: AppRadius.cardRadius,
            ),
          ),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: Text('โหลดคำสั่งซื้อไม่สำเร็จ: $e', style: const TextStyle(color: AppColors.danger)),
        ),
      ),
      data: (List<OrderModel> allOrders) {
        // Filter orders requiring action: paid or awaitingShipment
        final List<OrderModel> actionOrders = allOrders
            .where((o) =>
                o.status == OrderStatus.paid ||
                o.status == OrderStatus.awaitingShipment ||
                o.status == OrderStatus.pendingPayment)
            .take(5)
            .toList();

        if (actionOrders.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: Card(
                elevation: 0,
                color: AppColors.surfaceMuted,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 32),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('ไม่มีรายการที่ค้างดำเนินการ', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                            Text('เมื่อมีคำสั่งซื้อเข้ามาใหม่ จะแสดงที่นี่ทันที', style: AppTextStyles.bodySmall.copyWith(color: AppColors.inkMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final order = actionOrders[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _CompactOrderCard(order: order),
                );
              },
              childCount: actionOrders.length,
            ),
          ),
        );
      },
    );
  }
}

class _CompactOrderCard extends ConsumerWidget {
  const _CompactOrderCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OrderStatus? next = order.nextStatus;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      child: InkWell(
        onTap: () => context.push(AppRoutes.orderDetail(order.id)),
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    '#${order.id} · ${order.buyerName}',
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  StatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    '${order.itemCount} ชิ้น · ${Fmt.dateTime(order.createdAt)}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.inkMuted),
                  ),
                  Text(
                    Fmt.price(order.total),
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (next != null) ...<Widget>[
                const Divider(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _advance(context, ref, next),
                      icon: const Icon(Icons.trending_up_rounded, size: 16),
                      label: Text(Fmt.fill(AppStrings.advanceToStatus, status: next.label)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
        builder: (ctx) {
          final controller = TextEditingController(text: order.trackingNumber ?? '');
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
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text(AppStrings.sellerShipCancel)),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text(AppStrings.sellerShipConfirm)),
            ],
          );
        },
      );
      if (trackingNumber == null || !context.mounted) return;
    }

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(advanceOrderStatusProvider.notifier)
          .advance(order.id, next, trackingNumber: trackingNumber);
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(Fmt.fill(AppStrings.advanceStatusDone, status: next.label))),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('${AppStrings.advanceStatusFailed}: $e')));
    }
  }
}
