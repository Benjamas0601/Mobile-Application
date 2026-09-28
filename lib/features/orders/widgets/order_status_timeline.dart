import 'package:flutter/material.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/payment_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/order_model.dart';

/// The six delivery states as a vertical track.
///
/// A buyer asks one question — "where is it?" — so the answer is drawn as a
/// path rather than a label: a tick means passed, a filled dot means current,
/// an empty dot means not yet. `cancelled` is not a step on the path, so a
/// cancelled order collapses to a single terminal state instead of pretending
/// to have progressed.
class OrderStatusTimeline extends StatelessWidget {
  const OrderStatusTimeline({super.key, required this.order});

  final OrderModel order;

  /// The happy path, in the order the state machine allows.
  static const List<OrderStatus> _steps = <OrderStatus>[
    OrderStatus.pendingPayment,
    OrderStatus.paid,
    OrderStatus.awaitingShipment,
    OrderStatus.shipped,
    OrderStatus.completed,
  ];

  @override
  Widget build(BuildContext context) {
    if (order.isCancelled) {
      return Row(
        children: <Widget>[
          const Icon(
            Icons.cancel_outlined,
            color: AppColors.danger,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              PaymentStrings.statusCancelledHint,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      );
    }

    final int currentIndex = _steps.indexOf(order.status);
    final List<OrderStatus> shown = currentIndex < 0
        ? _steps
        : _steps.sublist(0, currentIndex + 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < shown.length; i++)
          _Step(
            status: shown[i],
            isCurrent: shown[i] == order.status,
            isFirst: i == 0,
            isLast: i == shown.length - 1,
            // The shipment date is only known once the order actually shipped,
            // so it is attached to that step alone.
            shippedAt: shown[i] == OrderStatus.shipped ? order.shippedAt : null,
          ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.status,
    required this.isCurrent,
    required this.isFirst,
    required this.isLast,
    this.shippedAt,
  });

  final OrderStatus status;
  final bool isCurrent;
  final bool isFirst;
  final bool isLast;
  final DateTime? shippedAt;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            children: <Widget>[
              _dot(),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCurrent ? AppColors.primary : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              // The last step has no connector below it, so its label sits
              // closer to the top than the first one's does.
              padding: EdgeInsets.only(
                top: isFirst ? AppSpacing.xs : 0,
                bottom: isLast ? 0 : AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    status.label,
                    style: isCurrent
                        ? AppTextStyles.labelLarge.copyWith(
                            color: AppColors.primary,
                          )
                        : AppTextStyles.bodyMedium,
                  ),
                  if (shippedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: Text(
                        '${AppStrings.shippedOnPrefix} '
                        '${Fmt.date(shippedAt)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot() {
    if (isCurrent) {
      return Container(
        width: 14,
        height: 14,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      );
    }
    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, size: 8, color: Colors.white),
    );
  }
}
