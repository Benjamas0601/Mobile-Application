import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:thai_otop_marketplace/core/constants/app_enums.dart';
import 'package:thai_otop_marketplace/core/constants/app_strings.dart';
import 'package:thai_otop_marketplace/core/routes/app_router.dart';
import 'package:thai_otop_marketplace/features/notifications/screens/notification_list_screen.dart';
import 'package:thai_otop_marketplace/models/app_notification_model.dart';
import 'package:thai_otop_marketplace/providers/notification_provider.dart';
import 'package:thai_otop_marketplace/repositories/notification_repository.dart';

AppNotificationModel _n({
  String id = 'n1',
  NotificationType type = NotificationType.orderStatus,
  String title = 'มีคำสั่งซื้อใหม่',
  String body = 'ออเดอร์ #o1',
  String? orderId,
  String? threadId,
  bool read = false,
}) {
  return AppNotificationModel(
    id: id,
    userId: 'me',
    type: type,
    title: title,
    body: body,
    orderId: orderId,
    threadId: threadId,
    read: read,
    createdAt: DateTime(2026, 1, 1, 9),
  );
}

/// Notifications with no Firestore, recording every ack so the test can assert.
class _FakeNotificationRepository implements NotificationRepository {
  _FakeNotificationRepository(this.items);

  final List<AppNotificationModel> items;
  final List<String> marked = <String>[];
  final List<String> markedAll = <String>[];

  @override
  Stream<List<AppNotificationModel>> watchMine() =>
      Stream<List<AppNotificationModel>>.value(items);

  @override
  Future<void> markRead(String notificationId) async {
    marked.add(notificationId);
  }

  @override
  Future<void> markAllRead(Iterable<String> ids) async {
    markedAll.addAll(ids);
  }

  @override
  Future<void> create({
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    String? orderId,
    String? threadId,
  }) async {}
}

Future<void> _pump(WidgetTester tester, _FakeNotificationRepository repo) async {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      notificationRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);

  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.notifications,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.notifications,
        builder: (BuildContext context, GoRouterState state) =>
            const NotificationListScreen(),
      ),
      GoRoute(
        path: '/order/:orderId',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Center(child: Text('order-detail'))),
      ),
      GoRoute(
        path: '/chat/:threadId',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Center(child: Text('chat-thread'))),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    // Fmt.dateTime (ในแถวใบแจ้งเตือน) ใช้ตัวเลขไทย ต้องลงทะเบียน locale ก่อน
    initializeDateFormatting('th');
  });

  group('notification list', () {
    testWidgets('an empty inbox explains itself', (WidgetTester tester) async {
      await _pump(tester, _FakeNotificationRepository(<AppNotificationModel>[]));

      expect(find.text(AppStrings.notificationsEmpty), findsOneWidget);
      expect(find.text(AppStrings.notificationsEmptyHint), findsOneWidget);
      expect(find.text(AppStrings.markAllRead), findsNothing);
    });

    testWidgets('lists rows with their title and no read-all when all read',
        (WidgetTester tester) async {
      await _pump(
        tester,
        _FakeNotificationRepository(<AppNotificationModel>[
          _n(id: 'n1', title: 'มีคำสั่งซื้อใหม่', orderId: 'o1'),
          _n(id: 'n2', title: 'ข้อความใหม่', type: NotificationType.newMessage, threadId: 't1', read: true),
        ]),
      );

      expect(find.text('มีคำสั่งซื้อใหม่'), findsOneWidget);
      expect(find.text('ข้อความใหม่'), findsOneWidget);
      // มี unread อยู่ 1 รายการ → ปุ่ม "อ่านทั้งหมด" โผล่
      expect(find.text(AppStrings.markAllRead), findsOneWidget);
    });

    testWidgets('read-all marks every unread row', (WidgetTester tester) async {
      final _FakeNotificationRepository repo = _FakeNotificationRepository(
        <AppNotificationModel>[
          _n(id: 'n1', orderId: 'o1'),
          _n(id: 'n2', threadId: 't1'),
          _n(id: 'n3', read: true),
        ],
      );
      await _pump(tester, repo);

      await tester.tap(find.text(AppStrings.markAllRead));
      await tester.pumpAndSettle();

      expect(repo.markedAll, <String>['n1', 'n2']);
      expect(repo.marked, isEmpty);
    });

    testWidgets('tapping an order row reads it and opens the order',
        (WidgetTester tester) async {
      final _FakeNotificationRepository repo = _FakeNotificationRepository(
        <AppNotificationModel>[
          _n(id: 'n1', orderId: 'o1'),
        ],
      );
      await _pump(tester, repo);

      await tester.tap(find.text('มีคำสั่งซื้อใหม่'));
      await tester.pumpAndSettle();

      expect(repo.marked, <String>['n1']);
      expect(find.text('order-detail'), findsOneWidget);
    });

    testWidgets('tapping a chat row opens the thread', (WidgetTester tester) async {
      final _FakeNotificationRepository repo = _FakeNotificationRepository(
        <AppNotificationModel>[
          _n(id: 'n1', title: 'ข้อความใหม่', type: NotificationType.newMessage, threadId: 't1'),
        ],
      );
      await _pump(tester, repo);

      await tester.tap(find.text('ข้อความใหม่'));
      await tester.pumpAndSettle();

      expect(repo.marked, <String>['n1']);
      expect(find.text('chat-thread'), findsOneWidget);
    });
  });
}