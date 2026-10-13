import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification_model.dart';
import '../repositories/notification_repository.dart';

/// Injected once and overridden in tests with a fake, so the notification UI
/// can be driven without a live Firestore.
final Provider<NotificationRepository> notificationRepositoryProvider =
    Provider<NotificationRepository>((Ref ref) => NotificationRepository());

/// The signed-in user's notifications, newest first.
final StreamProvider<List<AppNotificationModel>> myNotificationsProvider =
    StreamProvider.autoDispose<List<AppNotificationModel>>((Ref ref) {
      final NotificationRepository repository = ref.watch(
        notificationRepositoryProvider,
      );
      return repository.watchMine();
    });

/// How many of the user's notifications are still unread — the app-bar badge.
final Provider<int> unreadNotificationCountProvider = Provider<int>((Ref ref) {
  final AsyncValue<List<AppNotificationModel>> value =
      ref.watch(myNotificationsProvider);
  final List<AppNotificationModel>? items = value.value;
  if (items == null) return 0;
  return items.where((AppNotificationModel n) => !n.read).length;
});

/// Marks every unread notification as read (the "read all" action).
final Provider<void Function()> markAllNotificationsReadProvider =
    Provider<void Function()>((Ref ref) {
      final NotificationRepository repository = ref.watch(
        notificationRepositoryProvider,
      );
      return () async {
        final List<AppNotificationModel>? items = ref
            .read(myNotificationsProvider)
            .value;
        if (items == null) return;
        final List<String> unread = items
            .where((AppNotificationModel n) => !n.read)
            .map((AppNotificationModel n) => n.id)
            .toList(growable: false);
        await repository.markAllRead(unread);
      };
    });