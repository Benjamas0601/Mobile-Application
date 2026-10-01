import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/affiliate_commission_model.dart';
import '../models/affiliate_link_model.dart';
import '../models/product_model.dart';
import '../repositories/affiliate_repository.dart';
import 'auth_provider.dart';

/// Injected once and overridden in tests with a fake, so the affiliate screens
/// can be driven without a live Firestore — same contract as
/// `sellerCatalogRepositoryProvider`.
final Provider<AffiliateRepository> affiliateRepositoryProvider =
    Provider<AffiliateRepository>((Ref ref) => AffiliateRepository());

/// The affiliate's own links, best-performing first.
final FutureProvider<List<AffiliateLinkModel>> myAffiliateLinksProvider =
    FutureProvider<List<AffiliateLinkModel>>((Ref ref) {
      final String? uid = ref.watch(authUserProvider).asData?.value?.uid;
      if (uid == null) return Future.value(const <AffiliateLinkModel>[]);
      return ref.watch(affiliateRepositoryProvider).listMyLinks();
    });

/// The affiliate's commission rows, newest first.
final FutureProvider<List<AffiliateCommissionModel>>
myAffiliateCommissionsProvider = FutureProvider<List<AffiliateCommissionModel>>(
  (Ref ref) {
    final String? uid = ref.watch(authUserProvider).asData?.value?.uid;
    if (uid == null) {
      return Future.value(const <AffiliateCommissionModel>[]);
    }
    return ref.watch(affiliateRepositoryProvider).listMyCommissions();
  },
);

/// Live KPIs for the Affiliate Dashboard.
///
/// Mirrors `SellerDashboardMetrics`: derived in Dart from the two collections
/// the rules already let this account read, so no extra query is issued.
class AffiliateDashboardMetrics {
  const AffiliateDashboardMetrics({
    required this.attributedSales,
    required this.approvedCommission,
    required this.pendingCommission,
    required this.attributedOrders,
    required this.totalClicks,
    required this.linkCount,
    required this.conversionRate,
  });

  /// Gross value of the orders this affiliate drove, in baht.
  final double attributedSales;

  /// Commission actually payable — approved rows only.
  final double approvedCommission;

  /// Commission earned but still awaiting review.
  final double pendingCommission;

  /// Orders that counted, i.e. everything not rejected or cancelled.
  final int attributedOrders;

  /// Clicks summed across the affiliate's links.
  final int totalClicks;

  final int linkCount;

  /// [attributedOrders] as a percentage of [totalClicks].
  final double conversionRate;

  /// Commission across every counted row, paid out or still pending.
  double get totalCommission => approvedCommission + pendingCommission;

  static const AffiliateDashboardMetrics zero = AffiliateDashboardMetrics(
    attributedSales: 0,
    approvedCommission: 0,
    pendingCommission: 0,
    attributedOrders: 0,
    totalClicks: 0,
    linkCount: 0,
    conversionRate: 0,
  );
}

/// Computes the dashboard KPIs from the affiliate's own links and commissions.
final affiliateDashboardMetricsProvider =
    Provider.autoDispose<AsyncValue<AffiliateDashboardMetrics>>((Ref ref) {
      final AsyncValue<List<AffiliateLinkModel>> linksAsync = ref.watch(
        myAffiliateLinksProvider,
      );
      final AsyncValue<List<AffiliateCommissionModel>> commissionsAsync = ref
          .watch(myAffiliateCommissionsProvider);

      if (linksAsync.isLoading || commissionsAsync.isLoading) {
        return const AsyncValue.loading();
      }
      if (linksAsync.hasError) {
        return AsyncValue.error(linksAsync.error!, linksAsync.stackTrace!);
      }
      if (commissionsAsync.hasError) {
        return AsyncValue.error(
          commissionsAsync.error!,
          commissionsAsync.stackTrace!,
        );
      }

      final List<AffiliateLinkModel> links =
          linksAsync.value ?? const <AffiliateLinkModel>[];
      final List<AffiliateCommissionModel> commissions =
          commissionsAsync.value ?? const <AffiliateCommissionModel>[];

      int clicks = 0;
      for (final AffiliateLinkModel link in links) {
        clicks += link.clicks;
      }

      double sales = 0;
      double approved = 0;
      double pending = 0;
      int orders = 0;
      for (final AffiliateCommissionModel c in commissions) {
        if (!c.countsAsSales) continue;
        orders++;
        sales += c.orderTotal;
        if (c.isApproved) {
          approved += c.amount;
        } else if (c.isPending) {
          pending += c.amount;
        }
      }

      return AsyncValue.data(
        AffiliateDashboardMetrics(
          attributedSales: sales,
          approvedCommission: approved,
          pendingCommission: pending,
          attributedOrders: orders,
          totalClicks: clicks,
          linkCount: links.length,
          // A link with no clicks yet has no conversion; dividing anyway would
          // surface NaN in a KPI tile.
          conversionRate: clicks <= 0 ? 0 : orders / clicks * 100,
        ),
      );
    });

/// Creates a link for a chosen product, or deletes an existing one.
///
/// The busy guard mirrors `SaveProductController`: an affiliate double-tapping
/// "สร้างลิงก์" should not end up with two links for the same product.
class AffiliateLinkController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<bool> create(ProductModel product) async {
    if (state) return false;
    state = true;
    try {
      await ref.read(affiliateRepositoryProvider).createLink(product);
      ref.invalidate(myAffiliateLinksProvider);
      return true;
    } on Object {
      return false;
    } finally {
      state = false;
    }
  }

  Future<bool> remove(String linkId) async {
    if (state) return false;
    state = true;
    try {
      await ref.read(affiliateRepositoryProvider).deleteLink(linkId);
      ref.invalidate(myAffiliateLinksProvider);
      return true;
    } on Object {
      return false;
    } finally {
      state = false;
    }
  }
}

final NotifierProvider<AffiliateLinkController, bool> affiliateLinkProvider =
    NotifierProvider<AffiliateLinkController, bool>(
      AffiliateLinkController.new,
    );
