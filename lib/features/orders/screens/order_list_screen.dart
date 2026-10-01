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
import '../../../providers/order_provider.dart';
import '../../../widgets/state_views.dart';

/// The buyer's order history, newest first.
///
/// Read-only from the customer's side on purpose: `firestore.rules` only lets a
/// buyer touch the address while the order is still unpaid, so anything that
/// looks like editing here would fail at write time.
/// แสดงประวัติออเดอร์ของผู้ซื้อ โดยเรียงรายการล่าสุดไว้ก่อน
class OrderListScreen extends ConsumerWidget {
  const OrderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<OrderModel>> orders = ref.watch(myOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.navOrders)),
      // `body` only: a seller signed in as a customer still wants the list
      // first, not a list with a demo panel above it.
      body: orders.when(
        loading: () =>
            const SkeletonListView(itemCount: 4, height: 140),
        error: (Object e, StackTrace _) => ErrorView(
          onRetry: () => ref.invalidate(myOrdersProvider),
        ),
        data: (List<OrderModel> list) {
          if (list.isEmpty) {
            return EmptyView(
              title: AppStrings.emptyOrders,
              body: AppStrings.emptyOrdersHint,
              icon: Icons.receipt_long_rounded,
              actionLabel: AppStrings.continueShopping,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            itemCount: list.length,
            separatorBuilder: (BuildContext context, int _) =>
                const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int i) =>
                _OrderCard(order: list[i]),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push(AppRoutes.orderDetail(order.id)),
        borderRadius: AppRadius.cardRadius,
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
                  ),
                  const Spacer(),
                  StatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                Fmt.dateTime(order.createdAt),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.inkSubtle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact status label, coloured by how far along the order is.
///
/// Colour is the fastest signal a buyer can read at a glance, but the text is
/// always present too, so the state does not depend on colour alone.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.large = false});

  final OrderStatus status;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      OrderStatus.pendingPayment => (AppColors.warningLight, AppColors.warning),
      OrderStatus.paid => (AppColors.primaryLight, AppColors.primary),
      OrderStatus.awaitingShipment => (AppColors.infoLight, AppColors.info),
      OrderStatus.shipped => (AppColors.accentLight, AppColors.accent),
      OrderStatus.completed => (AppColors.successLight, AppColors.success),
      OrderStatus.cancelled => (AppColors.dangerLight, AppColors.danger),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: large ? AppSpacing.sm : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Text(
        status.label,
        style: (large ? AppTextStyles.bodyMedium : AppTextStyles.bodySmall)
            .copyWith(color: fg),
      ),
    );
  }
}
