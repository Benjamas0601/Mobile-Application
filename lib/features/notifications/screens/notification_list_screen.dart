import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/app_notification_model.dart';
import '../../../providers/notification_provider.dart';
import '../../../widgets/state_views.dart';

//ไฟล์นี้คือหน้าจอสำหรับแสดงรายการการแจ้งเตือนทั้งหมดของผู้ใช้ โดยมีฟังก์ชันการทำงานดังนี้:
/// - แสดงรายการการแจ้งเตือนทั้งหมดที่ผู้ใช้ได้รับ
/// // - สามารถทำเครื่องหมายการแจ้งเตือนทั้งหมดเป็นอ่านแล้วได้ 
/// // - สามารถทำเครื่องหมายการแจ้งเตือนแต่ละรายการเป็นอ่านแล้วได้เมื่อผู้ใช้แตะที่รายการนั้น
/// // - สามารถเปิดหน้ารายละเอียดของการแจ้งเตือนได้เมื่อผู้ใช้แตะที่รายการนั้น 
/// The in-app notification inbox.
///
/// Read-only plus a "read" flip on tap: notifications are created by the
/// counterparty (order / chat side), never typed here, so the actions never go
/// past marking a row read and following the entity that produced it.
class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AppNotificationModel>> notifications = ref.watch(
      myNotificationsProvider,
    );
    final int unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: AppStrings.backToHome,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        title: const Text(AppStrings.navNotifications),
        actions: <Widget>[
          if (unread > 0)
            TextButton(
              onPressed: () => ref.read(markAllNotificationsReadProvider)(),
              child: const Text(AppStrings.markAllRead),
            ),
        ],
      ),
      body: notifications.when(
        loading: () => const SkeletonListView(itemCount: 4, height: 76),
        error: (Object e, StackTrace _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(myNotificationsProvider),
        ),
        data: (List<AppNotificationModel> list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.notifications_off_outlined,
              title: AppStrings.notificationsEmpty,
              body: AppStrings.notificationsEmptyHint,
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(myNotificationsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              itemCount: list.length,
              separatorBuilder: (BuildContext context, int _) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (BuildContext context, int i) =>
                  _NotificationRow(notification: list[i]),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationRow extends ConsumerWidget {
  const _NotificationRow({required this.notification});

  final AppNotificationModel notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      color: notification.read ? AppColors.surface : AppColors.primaryLight,
      child: InkWell(
        onTap: () => _open(context, ref),
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                notification.iconFor(),
                size: 22,
                color: notification.read
                    ? AppColors.inkMuted
                    : AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      notification.title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: notification.read
                            ? FontWeight.w500
                            : FontWeight.w700,
                      ),
                    ),
                    if (notification.body.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        notification.body,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: notification.read
                              ? AppColors.inkMuted
                              : AppColors.ink,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      Fmt.dateTime(notification.createdAt),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.inkSubtle,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notification.read) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (!notification.read) {
      await ref
          .read(notificationRepositoryProvider)
          .markRead(notification.id);
      if (!context.mounted) return;
      ref.invalidate(myNotificationsProvider);
    }
    if (!context.mounted) return;
    if (notification.orderId != null && notification.orderId!.isNotEmpty) {
      context.push(AppRoutes.orderDetail(notification.orderId!));
    } else if (notification.threadId != null &&
        notification.threadId!.isNotEmpty) {
      context.push(AppRoutes.chatThread(notification.threadId!));
    }
  }
}