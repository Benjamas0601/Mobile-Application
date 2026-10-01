import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_otop_marketplace/core/constants/app_enums.dart';
import 'package:thai_otop_marketplace/core/routes/app_router.dart';
import 'package:thai_otop_marketplace/features/affiliate/screens/affiliate_home_screen.dart';
import 'package:thai_otop_marketplace/models/affiliate_commission_model.dart';
import 'package:thai_otop_marketplace/models/affiliate_link_model.dart';
import 'package:thai_otop_marketplace/models/user_model.dart';
import 'package:thai_otop_marketplace/providers/affiliate_provider.dart';
import 'package:thai_otop_marketplace/providers/auth_provider.dart';

const UserModel _affiliate = UserModel(
  uid: 'af1',
  displayName: 'Boran',
  email: 'affiliate@test.com',
  roles: <UserRole>[UserRole.customer, UserRole.affiliate],
  affiliatePlatform: 'TikTok',
  affiliateHandle: 'otop.boran',
  affiliateProfileUrl: 'https://tiktok.com/@otop.boran',
);

AffiliateLinkModel _link({String id = 'al1', int clicks = 0, int orders = 0}) {
  return AffiliateLinkModel(
    id: id,
    affiliateUid: 'af1',
    productId: 'p1',
    code: 'otop-test',
    clicks: clicks,
    orders: orders,
    productName: 'ผ้าไหมแดงลายไทย',
  );
}

AffiliateCommissionModel _commission({
  String id = 'ac1',
  double amount = 100,
  double orderTotal = 2000,
  CommissionStatus status = CommissionStatus.approved,
}) {
  return AffiliateCommissionModel(
    id: id,
    affiliateUid: 'af1',
    orderId: 'o1',
    amount: amount,
    rate: 5,
    status: status,
    orderTotal: orderTotal,
    productName: 'ผ้าไหมแดงลายไทย',
  );
}

/// Builds a container whose two affiliate collections are fixed, so the
/// dashboard maths is tested without Firestore.
Future<ProviderContainer> _container({
  List<AffiliateLinkModel> links = const <AffiliateLinkModel>[],
  List<AffiliateCommissionModel> commissions =
      const <AffiliateCommissionModel>[],
  UserModel user = _affiliate,
}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      authUserProvider.overrideWith(
        (Ref ref) => Stream<UserModel?>.value(user),
      ),
      myAffiliateLinksProvider.overrideWith((Ref ref) async => links),
      myAffiliateCommissionsProvider.overrideWith(
        (Ref ref) async => commissions,
      ),
    ],
  );
  addTearDown(container.dispose);
  // The overrides are `async`, so the metrics provider sees AsyncLoading on a
  // first synchronous read and would report zeroes for a reason that has
  // nothing to do with the maths. Drain both futures first.
  await container.read(myAffiliateLinksProvider.future);
  await container.read(myAffiliateCommissionsProvider.future);
  return container;
}

Future<AffiliateDashboardMetrics> _metrics({
  List<AffiliateLinkModel> links = const <AffiliateLinkModel>[],
  List<AffiliateCommissionModel> commissions =
      const <AffiliateCommissionModel>[],
  UserModel user = _affiliate,
}) async {
  final ProviderContainer c = await _container(
    links: links,
    commissions: commissions,
    user: user,
  );
  return c.read(affiliateDashboardMetricsProvider).requireValue;
}

void main() {
  // ครอบคลุมโมเดล ค่าคอมมิชชัน และหน้าสรุป Affiliate โดยใช้ข้อมูลจำลอง
  group('AffiliateLinkModel', () {
    test('converts clicks into orders as a percentage', () {
      expect(_link(clicks: 200, orders: 10).conversionRate, 5);
    });

    test('reports 0% rather than NaN before any click arrives', () {
      // A fresh link has clicks == 0; a plain division would render NaN in a
      // KPI tile, which is the whole reason this getter guards.
      expect(_link(clicks: 0, orders: 0).conversionRate, 0);
      expect(_link(clicks: 0, orders: 3).conversionRate.isNaN, isFalse);
    });

    test('reads a Firestore document, tolerating missing counters', () {
      final AffiliateLinkModel link = AffiliateLinkModel.fromFirestore(
        'al9',
        <String, dynamic>{'productId': 'p1', 'productName': 'กาแฟ'},
      );
      expect(link.id, 'al9');
      expect(link.clicks, 0);
      expect(link.orders, 0);
      expect(link.productName, 'กาแฟ');
    });
  });

  group('AffiliateCommissionModel', () {
    test('counts approved and pending towards sales', () {
      expect(
        _commission(status: CommissionStatus.approved).countsAsSales,
        isTrue,
      );
      expect(
        _commission(status: CommissionStatus.pending).countsAsSales,
        isTrue,
      );
    });

    test('excludes rejected and cancelled from sales', () {
      // Money the affiliate will never receive must not inflate the headline
      // sales number.
      expect(
        _commission(status: CommissionStatus.rejected).countsAsSales,
        isFalse,
      );
      expect(
        _commission(status: CommissionStatus.cancelled).countsAsSales,
        isFalse,
      );
    });

    test('an unknown status falls back to pending, not approved', () {
      // `CommissionStatus.fromValue` defaults to pending, so a typo cannot
      // silently pay out.
      final AffiliateCommissionModel c = AffiliateCommissionModel.fromFirestore(
        'ac9',
        <String, dynamic>{'amount': 10, 'status': 'nonsense'},
      );
      expect(c.status, CommissionStatus.pending);
      expect(c.isApproved, isFalse);
    });
  });

  group('affiliateDashboardMetrics', () {
    test('is all zeroes with no links and no commissions', () async {
      final AffiliateDashboardMetrics m = await _metrics();
      expect(m.attributedSales, 0);
      expect(m.totalClicks, 0);
      expect(m.linkCount, 0);
      expect(m.conversionRate, 0);
    });

    test('sums clicks across every link', () async {
      final AffiliateDashboardMetrics m = await _metrics(
        links: <AffiliateLinkModel>[
          _link(id: 'a', clicks: 148, orders: 4),
          _link(id: 'b', clicks: 96, orders: 2),
          _link(id: 'c', clicks: 7),
        ],
      );
      expect(m.totalClicks, 251);
      expect(m.linkCount, 3);
    });

    test(
      'counts sales and approved commission separately from pending',
      () async {
        // The number an affiliate is owed now versus what is still under review.
        final AffiliateDashboardMetrics m = await _metrics(
          links: <AffiliateLinkModel>[_link(clicks: 100, orders: 3)],
          commissions: <AffiliateCommissionModel>[
            _commission(id: '1', amount: 111.5, orderTotal: 2230),
            _commission(
              id: '2',
              amount: 72.5,
              orderTotal: 1450,
              status: CommissionStatus.pending,
            ),
          ],
        );
        expect(m.attributedSales, 3680);
        expect(m.approvedCommission, 111.5);
        expect(m.pendingCommission, 72.5);
        expect(m.totalCommission, 184);
        expect(m.attributedOrders, 2);
      },
    );

    test(
      'drops cancelled and rejected rows from sales but keeps clicks',
      () async {
        final AffiliateDashboardMetrics m = await _metrics(
          links: <AffiliateLinkModel>[_link(clicks: 100, orders: 4)],
          commissions: <AffiliateCommissionModel>[
            _commission(id: '1', amount: 100, orderTotal: 2000),
            _commission(
              id: '2',
              amount: 50,
              orderTotal: 1000,
              status: CommissionStatus.cancelled,
            ),
            _commission(
              id: '3',
              amount: 50,
              orderTotal: 1000,
              status: CommissionStatus.rejected,
            ),
          ],
        );
        expect(m.attributedSales, 2000);
        expect(m.attributedOrders, 1);
        expect(m.approvedCommission, 100);
        // Click counters are maintained by the backend, so they are unaffected by
        // what the affiliate earned.
        expect(m.totalClicks, 100);
        expect(m.conversionRate, 1);
      },
    );

    test('reports 0% conversion when nothing has been clicked', () async {
      final AffiliateDashboardMetrics m = await _metrics(
        commissions: <AffiliateCommissionModel>[_commission()],
      );
      expect(m.totalClicks, 0);
      expect(m.conversionRate, 0);
      expect(m.conversionRate.isNaN, isFalse);
    });

    test('is empty for a signed-out visitor instead of throwing', () async {
      // The screen mounts before auth resolves; the provider must not blow up.
      final AffiliateDashboardMetrics m = await _metrics(
        user: const UserModel(uid: 'x', displayName: 'Guest', email: 'g@t.com'),
      );
      expect(m.totalClicks, 0);
    });
  });

  group('affiliate routes', () {
    test('a guest is sent to login for the affiliate console', () {
      // Guarded by prefix, so a future `/affiliate/links` is covered too.
      expect(
        authRedirect(signedIn: false, location: AppRoutes.affiliateRoot),
        '${AppRoutes.login}?redirect=${AppRoutes.affiliateRoot}',
      );
      expect(
        authRedirect(signedIn: false, location: '/affiliate/links'),
        '${AppRoutes.login}?redirect=/affiliate/links',
      );
    });

    test('a signed-in affiliate lands on their dashboard from /home', () {
      for (final String location in <String>[
        AppRoutes.home,
        AppRoutes.login,
        AppRoutes.register,
      ]) {
        expect(
          authRedirect(signedIn: true, location: location, user: _affiliate),
          AppRoutes.affiliateRoot,
        );
      }
      expect(
        authRedirect(
          signedIn: true,
          location: AppRoutes.affiliateRoot,
          user: _affiliate,
        ),
        isNull,
      );
    });

    test('a seller who also promotes still opens the seller console', () {
      // One account can hold both roles (`docs/01_product_problem.md:79`), and a
      // real OTOP producer sells their own goods *and* promotes them. Affiliate
      // ranks below seller so the seller console never becomes unreachable.
      const both = UserModel(
        uid: 'sa1',
        displayName: 'Both',
        email: 'both@test.com',
        roles: <UserRole>[UserRole.seller, UserRole.affiliate],
      );
      expect(
        authRedirect(signedIn: true, location: AppRoutes.home, user: both),
        AppRoutes.sellerRoot,
      );
      // ...and the affiliate console is still reachable by URL.
      expect(
        authRedirect(
          signedIn: true,
          location: AppRoutes.affiliateRoot,
          user: both,
        ),
        isNull,
      );
    });

    test('a plain customer is not hijacked into a console', () {
      const customer = UserModel(
        uid: 'c1',
        displayName: 'Customer',
        email: 'c@test.com',
        roles: <UserRole>[UserRole.customer],
      );
      expect(
        authRedirect(signedIn: true, location: AppRoutes.home, user: customer),
        isNull,
      );
    });
  });

  group('AffiliateHomeScreen', () {
    Future<void> pumpScreen(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AffiliateHomeScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the sales the affiliate drove', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        await _container(
          links: <AffiliateLinkModel>[_link(clicks: 244, orders: 6)],
          commissions: <AffiliateCommissionModel>[
            _commission(id: '1', amount: 111.5, orderTotal: 2230),
            _commission(
              id: '2',
              amount: 72.5,
              orderTotal: 1450,
              status: CommissionStatus.pending,
            ),
          ],
        ),
      );

      // Headline: gross sales driven, not the commission.
      expect(find.text('ยอดขายที่ลิงก์ของคุณทำให้เกิด ฿3,680'), findsOneWidget);
      expect(find.text('คลิกสะสม'), findsWidgets);
      expect(find.textContaining('244'), findsWidgets);
      expect(find.text('ออเดอร์'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('labels a pending commission as awaiting review', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        await _container(
          commissions: <AffiliateCommissionModel>[
            _commission(amount: 72.5, status: CommissionStatus.pending),
          ],
        ),
      );

      expect(find.text('รอตรวจสอบ'), findsOneWidget);
    });

    testWidgets('invites a first-time affiliate to create a link', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, await _container());

      // The create button sits above the fold; the two empty states are
      // further down the list.
      expect(find.text('สร้างลิงก์'), findsOneWidget);
      expect(find.text('ยังไม่มีค่าคอมมิชชัน'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('ยังไม่มีลิงก์'),
        200,
        // `scrollable` must be the Scrollable itself, not the ListView that
        // wraps it.
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('ยังไม่มีลิงก์'), findsOneWidget);
    });

    testWidgets('shows the affiliate own channel', (WidgetTester tester) async {
      await pumpScreen(tester, await _container());

      expect(find.textContaining('TikTok'), findsWidgets);
      expect(find.textContaining('otop.boran'), findsWidgets);
    });

    testWidgets('locks out an account without the affiliate role', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        await _container(
          user: const UserModel(
            uid: 'c1',
            displayName: 'Customer',
            email: 'c@test.com',
            roles: <UserRole>[UserRole.customer],
          ),
        ),
      );

      expect(find.text('คุณไม่มีสิทธิ์เข้าถึงส่วนนี้'), findsOneWidget);
      expect(
        find.textContaining('ยอดขายที่ลิงก์ของคุณทำให้เกิด'),
        findsNothing,
      );
    });

    testWidgets('an admin may open it too', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        await _container(
          user: const UserModel(
            uid: 'a1',
            displayName: 'Admin',
            email: 'a@test.com',
            roles: <UserRole>[UserRole.admin],
          ),
        ),
      );

      expect(
        find.textContaining('ยอดขายที่ลิงก์ของคุณทำให้เกิด'),
        findsOneWidget,
      );
    });
  });
}
