import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart' hide AsyncValue;
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/order_model.dart';
import '../../../providers/order_provider.dart';
import '../../../widgets/state_views.dart';
import '../widgets/order_status_timeline.dart';

class OrderTrackingScreen extends ConsumerWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<OrderModel?> order = ref.watch(orderProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('ติดตามสถานะ')),
      body: order.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace stackTrace) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(orderProvider(orderId)),
        ),
        data: (OrderModel? value) {
          if (value == null) {
            return EmptyView(
              title: 'ไม่พบคำสั่งซื้อ',
              body: 'ไม่พบข้อมูลสถานะของคำสั่งซื้อนี้',
              icon: Icons.search_off_rounded,
              actionLabel: 'กลับไปเลือกสินค้า',
              onAction: () => context.go(AppRoutes.home),
            );
          }
          return _TrackingContent(order: value);
        },
      ),
    );
  }
}

class _TrackingContent extends StatelessWidget {
  const _TrackingContent({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final _StatusPresentation status = _presentStatus(order);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: <Widget>[
                CircleAvatar(
                  radius: 28,
                  backgroundColor: status.background,
                  child: Icon(status.icon, color: status.foreground, size: 30),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  status.title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: status.foreground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  status.detail,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('ความคืบหน้า', style: AppTextStyles.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: OrderStatusTimeline(order: order),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('ข้อมูลคำสั่งซื้อ', style: AppTextStyles.labelMedium),
                const SizedBox(height: AppSpacing.md),
                _TrackingInfo(label: 'ร้านค้า', value: order.storeName),
                _TrackingInfo(label: 'หมายเลขคำสั่งซื้อ', value: order.id),
                _TrackingInfo(label: 'ยอดรวม', value: Fmt.price(order.total)),
                if (order.trackingNumber != null)
                  _TrackingInfo(
                    label: 'เลขพัสดุ',
                    value: order.trackingNumber!,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: () => context.go(AppRoutes.home),
          icon: const Icon(Icons.storefront_outlined),
          label: const Text('เลือกสินค้าต่อ'),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _TrackingInfo extends StatelessWidget {
  const _TrackingInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 138,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.inkMuted,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: AppTextStyles.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _StatusPresentation {
  const _StatusPresentation({
    required this.title,
    required this.detail,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final String title;
  final String detail;
  final IconData icon;
  final Color foreground;
  final Color background;
}

_StatusPresentation _presentStatus(OrderModel order) {
  if (order.isCancelled) {
    return const _StatusPresentation(
      title: 'คำสั่งซื้อถูกยกเลิก',
      detail: 'คำสั่งซื้อนี้สิ้นสุดแล้ว',
      icon: Icons.cancel_outlined,
      foreground: AppColors.danger,
      background: AppColors.dangerLight,
    );
  }

  return switch (order.status) {
    OrderStatus.pendingPayment
        when order.paymentStatus == PaymentStatus.submitted =>
      const _StatusPresentation(
        title: 'รอตรวจสอบการชำระเงิน',
        detail: 'ร้านค้าจะตรวจสอบหลักฐานก่อนเริ่มเตรียมจัดส่ง',
        icon: Icons.hourglass_top_rounded,
        foreground: AppColors.warning,
        background: AppColors.warningLight,
      ),
    OrderStatus.pendingPayment => const _StatusPresentation(
      title: 'รอชำระเงิน',
      detail: 'คำสั่งซื้อจะดำเนินต่อเมื่อยืนยันการชำระเงินแล้ว',
      icon: Icons.payments_outlined,
      foreground: AppColors.warning,
      background: AppColors.warningLight,
    ),
    OrderStatus.paid => const _StatusPresentation(
      title: 'ชำระแล้ว',
      detail: 'ร้านค้ากำลังเตรียมคำสั่งซื้อ',
      icon: Icons.inventory_2_outlined,
      foreground: AppColors.primary,
      background: AppColors.primaryLight,
    ),
    OrderStatus.awaitingShipment => const _StatusPresentation(
      title: 'รอจัดส่ง',
      detail: 'ร้านค้าเตรียมสินค้าเสร็จและกำลังจัดส่ง',
      icon: Icons.local_shipping_outlined,
      foreground: AppColors.primary,
      background: AppColors.primaryLight,
    ),
    OrderStatus.shipped => const _StatusPresentation(
      title: 'กำลังจัดส่ง',
      detail: 'ร้านค้าส่งสินค้าแล้ว ตรวจสอบเลขพัสดุด้านล่างได้',
      icon: Icons.local_shipping_rounded,
      foreground: AppColors.primary,
      background: AppColors.primaryLight,
    ),
    OrderStatus.completed => const _StatusPresentation(
      title: 'จัดส่งสำเร็จ',
      detail: 'คำสั่งซื้อนี้เสร็จสมบูรณ์แล้ว',
      icon: Icons.check_circle_outline_rounded,
      foreground: AppColors.success,
      background: AppColors.successLight,
    ),
    OrderStatus.cancelled => throw StateError('Handled above'),
  };
}
