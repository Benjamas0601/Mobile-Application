import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// `app_enums` has its own `AsyncValue` (an order/payment status), so it is
// hidden here to leave Riverpod's — the same guard `seller_catalog_provider`
// uses.
import '../../../core/constants/app_enums.dart' hide AsyncValue;
import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/affiliate_commission_model.dart';
import '../../../models/affiliate_link_model.dart';
import '../../../models/product_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/affiliate_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/catalog_provider.dart';
import '../../../widgets/state_views.dart';

/// The affiliate console's front door: an Affiliate Dashboard showing the
/// sales this account drove, what it earned from them, and how its links
/// performed.
///
/// Same shape as `SellerHomeScreen` and the same layer-2 role gate: a role
/// lives in Firestore, not in the route, so the screen checks the signed-in
/// user and the router only requires an account.
///
/// Every number here comes from `affiliate_links` and `affiliate_commissions`
/// filtered to `affiliateUid == me`, which is exactly what `firestore.rules`
/// allows this account to read. The affiliate cannot see other people's orders
/// or raw click rows, and does not need to for the figures the flow promises
/// (Clicks / Orders / Conversion / Commission — `docs/02_user_flows.md:122`).
/// หน้ารวมลิงก์โปรโมตและคอมมิชชันของ Affiliate ที่ล็อกอินอยู่
class AffiliateHomeScreen extends ConsumerWidget {
  const AffiliateHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserModel? user = ref.watch(authUserProvider).asData?.value;

    // Layer 2 role-gate
    if (user == null || (!user.isAffiliate && !user.isAdmin)) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.navAffiliateDashboard)),
        body: const EmptyView(
          icon: Icons.lock_outline_rounded,
          title: AppStrings.errNotAuthorised,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.gutter,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              AppStrings.navAffiliateDashboard,
              style: AppTextStyles.headlineSmall,
            ),
            Text(
              'สวัสดี ${user.shortName} (พาร์ทเนอร์)',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ),
        actions: <Widget>[
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
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myAffiliateLinksProvider);
          ref.invalidate(myAffiliateCommissionsProvider);
        },
        child: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? _) {
            final AsyncValue<List<AffiliateLinkModel>> linksAsync = ref.watch(
              myAffiliateLinksProvider,
            );
            final AsyncValue<List<AffiliateCommissionModel>> commissionsAsync =
                ref.watch(myAffiliateCommissionsProvider);

            if (linksAsync.isLoading || commissionsAsync.isLoading) {
              return const LoadingView();
            }
            if (linksAsync.hasError) {
              return ErrorView(
                message: '${linksAsync.error}',
                onRetry: () => ref.invalidate(myAffiliateLinksProvider),
              );
            }
            if (commissionsAsync.hasError) {
              return ErrorView(
                message: '${commissionsAsync.error}',
                onRetry: () => ref.invalidate(myAffiliateCommissionsProvider),
              );
            }

            final List<AffiliateLinkModel> links =
                linksAsync.value ?? const <AffiliateLinkModel>[];
            final List<AffiliateCommissionModel> commissions =
                commissionsAsync.value ?? const <AffiliateCommissionModel>[];

            return CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.md,
                      AppSpacing.gutter,
                      AppSpacing.sm,
                    ),
                    child: _ChannelBanner(user: user),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.gutter,
                      vertical: AppSpacing.xs,
                    ),
                    child: const _AnalyticsGrid(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.md,
                      AppSpacing.gutter,
                      AppSpacing.sm,
                    ),
                    child: const _CreateLinkAction(),
                  ),
                ),
                _section('ค่าคอมมิชชันล่าสุด', Icons.payments_outlined),
                if (commissions.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.gutter,
                      ),
                      child: EmptyView(
                        icon: Icons.payments_outlined,
                        title: 'ยังไม่มีค่าคอมมิชชัน',
                        body: 'เมื่อมีออเดอร์ผ่านลิงก์ของคุณและผ่านการตรวจสอบ '
                            'ค่าคอมมิชชันจะแสดงที่นี่',
                      ),
                    ),
                  )
                else
                  SliverList.separated(
                    itemCount: _recentCount(commissions),
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (BuildContext context, int index) =>
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.gutter,
                          ),
                          child: _CommissionTile(
                            commission: commissions[index],
                          ),
                        ),
                  ),
                _section('ลิงก์ของฉัน', Icons.link_rounded),
                if (links.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.gutter,
                        AppSpacing.xs,
                        AppSpacing.gutter,
                        0,
                      ),
                      child: EmptyView(
                        icon: Icons.link_off_rounded,
                        title: 'ยังไม่มีลิงก์',
                        body: 'กดปุ่ม "สร้างลิงก์" เพื่อเลือกสินค้าที่จะโปรโมต',
                        actionLabel: 'สร้างลิงก์',
                        onAction: () => _openProductPicker(context, ref),
                      ),
                    ),
                  )
                else
                  SliverList.separated(
                    itemCount: links.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (BuildContext context, int index) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.gutter,
                      ),
                      child: _LinkTile(link: links[index]),
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xxxl),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// How many commission rows the dashboard lists.
  ///
  /// A cap rather than the full list: the dashboard answers "how am I doing",
  /// not "show me every payout ever", and a payout history belongs behind its
  /// own screen.
  static const int _recentLimit = 5;

  static int _recentCount(List<AffiliateCommissionModel> commissions) =>
      commissions.length < _recentLimit ? commissions.length : _recentLimit;

  static SliverToBoxAdapter _section(String title, IconData icon) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.lg,
          AppSpacing.gutter,
          AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: AppColors.inkMuted),
            const SizedBox(width: AppSpacing.xs),
            Text(
              title,
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the product picker and reports whether a link was created.
  static Future<void> _openProductPicker(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? created = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => const _ProductPickerDialog(),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('สร้างลิงก์เรียบร้อยแล้ว')),
        );
    }
  }
}

/// The affiliate's own channel, which is what makes their links credible.
class _ChannelBanner extends StatelessWidget {
  const _ChannelBanner({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final bool hasChannel = user.affiliateHandle.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  user.affiliatePlatform.isEmpty
                      ? 'ยังไม่ได้ตั้งช่องทาง'
                      : user.affiliatePlatform,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: hasChannel ? AppColors.primary : AppColors.warning,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  hasChannel
                      ? '@${user.affiliateHandle}'
                      : 'กรุณาให้ผู้ดูแลระบบตั้งชื่อบัญชีของคุณ',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.inkMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The sales figures. Leads with gross sales driven, because that is the
/// question an affiliate asks first.
class _AnalyticsGrid extends ConsumerWidget {
  const _AnalyticsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AffiliateDashboardMetrics> metrics = ref.watch(
      affiliateDashboardMetricsProvider,
    );

    return metrics.when(
      loading: () => const SizedBox(height: 120, child: LoadingView()),
      error: (Object e, _) => InlineErrorBanner(
        message: '$e',
        onRetry: () => ref.invalidate(myAffiliateLinksProvider),
      ),
      data: (AffiliateDashboardMetrics m) {
        return Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _KpiCard(
                    title: 'ยอดขายที่ทำให้เกิด',
                    value: Fmt.price(m.attributedSales),
                    subtitle: 'มูลค่าออเดอร์ที่คุณทำยอด',
                    icon: Icons.trending_up_rounded,
                    color: AppColors.primary,
                    bgColor: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _KpiCard(
                    title: 'ค่าคอมมิชชันที่ได้รับ',
                    value: Fmt.price(m.approvedCommission),
                    subtitle: 'อนุมัติแล้ว ${m.attributedOrders} ออเดอร์',
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.success,
                    bgColor: AppColors.successLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: _KpiCard(
                    title: 'ออเดอร์จากลิงก์',
                    value: '${m.attributedOrders}',
                    subtitle: 'รอตรวจสอบ ${Fmt.price(m.pendingCommission)}',
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.warning,
                    bgColor: AppColors.warningLight,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _KpiCard(
                    title: 'คลิกลิงก์',
                    value: Fmt.compactCount(m.totalClicks),
                    subtitle: 'แปลงเป็นออเดอร์ '
                        '${m.conversionRate.toStringAsFixed(1)}%',
                    icon: Icons.ads_click_rounded,
                    color: AppColors.info,
                    bgColor: AppColors.infoLight,
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
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(
                child: Text(
                  title,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.inkMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.inkSubtle),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// The one action this screen offers: promote another product.
class _CreateLinkAction extends ConsumerWidget {
  const _CreateLinkAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool busy = ref.watch(affiliateLinkProvider);
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: busy
            ? null
            : () => AffiliateHomeScreen._openProductPicker(context, ref),
        icon: const Icon(Icons.add_link_rounded),
        label: const Text('สร้างลิงก์โปรโมต'),
      ),
    );
  }
}

class _CommissionTile extends StatelessWidget {
  const _CommissionTile({required this.commission});

  final AffiliateCommissionModel commission;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  commission.productName.isEmpty
                      ? 'ออเดอร์ #${commission.orderId}'
                      : commission.productName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'ยอด ${Fmt.price(commission.orderTotal)} × '
                  '${commission.rate.toStringAsFixed(0)}% · '
                  '${Fmt.date(commission.createdAt)}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.inkMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                Fmt.price(commission.amount),
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: commission.countsAsSales
                      ? AppColors.success
                      : AppColors.inkSubtle,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              CommissionStatusChip(status: commission.status),
            ],
          ),
        ],
      ),
    );
  }
}

class CommissionStatusChip extends StatelessWidget {
  const CommissionStatusChip({super.key, required this.status});

  final CommissionStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      CommissionStatus.pending => (AppColors.warningLight, AppColors.warning),
      CommissionStatus.approved => (AppColors.successLight, AppColors.success),
      CommissionStatus.rejected => (AppColors.dangerLight, AppColors.danger),
      CommissionStatus.cancelled => (
        AppColors.surfaceMuted,
        AppColors.inkMuted,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Text(
        status.label,
        style: AppTextStyles.labelSmall.copyWith(color: fg),
      ),
    );
  }
}

/// One promotional link: its code, and how much traffic it has produced.
class _LinkTile extends ConsumerWidget {
  const _LinkTile({required this.link});

  final AffiliateLinkModel link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: link.productImageUrl.isEmpty
                      ? const ColoredBox(
                          color: AppColors.surfaceMuted,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: AppColors.inkSubtle,
                            size: 18,
                          ),
                        )
                      : Image.network(
                          link.productImageUrl,
                          fit: BoxFit.cover,
                          // A dead Cloudinary URL must not take the tile down.
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: AppColors.surfaceMuted,
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: AppColors.inkSubtle,
                              size: 18,
                            ),
                          ),
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
                      link.productName.isEmpty
                          ? 'สินค้า #${link.productId}'
                          : link.productName,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${link.clicks} คลิก · ${link.orders} ออเดอร์ · '
                      'แปลง ${link.conversionRate.toStringAsFixed(1)}%',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.inkMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'คัดลอกรหัสลิงก์',
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () => _copyCode(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.productDetail(link.productId)),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('ดูสินค้า'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: ref.watch(affiliateLinkProvider)
                      ? null
                      : () => _confirmDelete(context, ref),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('ลบลิงก์'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: link.code));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('คัดลอกรหัส ${link.code} แล้ว')),
      );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('ลบลิงก์นี้?'),
        content: const Text(
          'ลิงก์ที่แชร์ไปแล้วจะใช้ไม่ได้อีกต่อไป '
          'แต่ค่าคอมมิชชันที่เกิดจากออเดอร์เดิมยังคงอยู่',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await ref.read(affiliateLinkProvider.notifier).remove(link.id);
  }
}

/// Picks a product to promote, then writes the link.
class _ProductPickerDialog extends ConsumerWidget {
  const _ProductPickerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ProductModel>> products = ref.watch(productsProvider);

    return AlertDialog(
      title: const Text('เลือกสินค้าที่จะโปรโมต'),
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
        child: products.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, _) => Center(child: Text('$e')),
          data: (List<ProductModel> all) => _list(context, ref, all),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('ปิด'),
        ),
      ],
    );
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    List<ProductModel> all,
  ) {
    // Drafts are not buyable, so promoting one would produce a link that can
    // never convert.
    final List<ProductModel> products = all
        .where((ProductModel p) => p.isVisible)
        .toList();

    if (products.isEmpty) {
      return const Center(child: Text('ยังไม่มีสินค้าที่เปิดขายให้โปรโมต'));
    }

    final bool busy = ref.watch(affiliateLinkProvider);

    return ListView.separated(
      itemCount: products.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final ProductModel product = products[index];
        return ListTile(
          title: Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(Fmt.price(product.price)),
          trailing: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_link_rounded),
          onTap: busy
              ? null
              : () async {
                  final bool ok = await ref
                      .read(affiliateLinkProvider.notifier)
                      .create(product);
                  if (ok && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
        );
      },
    );
  }
}
