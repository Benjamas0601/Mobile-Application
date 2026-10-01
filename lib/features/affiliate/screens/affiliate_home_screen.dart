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
import '../../../widgets/design_system.dart';
import '../../../widgets/state_views.dart';

/// The affiliate console's front door, matching the HTML design: four KPI
/// tiles, a "สร้างลิงก์" action, the affiliate's own links, then the commission
/// table with an explicit no-payout caveat.
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
              _channelLabel(user),
              style: AppTextStyles.labelSmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
          children: <Widget>[
            const _ChannelBanner(),
            const _KpiGrid(),
            const _CreateLinkSection(),
            const _MyLinksSection(),
            const _CommissionTable(),
          ],
        ),
      ),
    );
  }

  /// `otop.boran · TikTok` — the design's channel line.
  ///
  /// The `otop.` prefix is only added when the stored handle lacks one: the
  /// seeded and registered handles already read `otop.boran`, and blindly
  /// prefixing rendered that as `otop.otop.boran` on the banner and the AppBar.
  static String _channelLabel(UserModel user) {
    final String raw = user.affiliateHandle.trim();
    if (raw.isEmpty) return 'ยังไม่ได้ตั้งชื่อบัญชี';
    final String handle = raw.startsWith('otop.') ? raw : 'otop.$raw';
    final String platform = user.affiliatePlatform.trim();
    return platform.isEmpty ? handle : '$handle · $platform';
  }
}

/// Shows which account and channel the links belong to — the thing that makes
/// an affiliate's numbers credible to a merchant reviewing them.
class _ChannelBanner extends ConsumerWidget {
  const _ChannelBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserModel? user = ref.watch(authUserProvider).asData?.value;
    if (user == null) return const SizedBox.shrink();

    final bool hasChannel = user.affiliateHandle.isNotEmpty;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.primaryLight,
      borderColor: AppColors.primaryBorder,
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
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
                  user.shortName,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: AppColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  hasChannel
                      ? AffiliateHomeScreen._channelLabel(user)
                      : 'กรุณาให้ผู้ดูแลระบบตั้งชื่อบัญชีของคุณ',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: hasChannel
                        ? AppColors.primaryBorder
                        : AppColors.warning,
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

/// The four figures the design promises: clicks, orders, conversion,
/// commission. Gross sales moves to a single line beneath the grid because it
/// is context for the commission rather than a fifth metric.
class _KpiGrid extends ConsumerWidget {
  const _KpiGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AffiliateDashboardMetrics> metrics = ref.watch(
      affiliateDashboardMetricsProvider,
    );

    return metrics.when(
      loading: () => const SkeletonCards(itemCount: 2, height: 88),
      error: (Object e, StackTrace _) => InlineErrorBanner(
        message: AppStrings.errorBody,
        detail: '$e',
        onRetry: () => ref.invalidate(myAffiliateLinksProvider),
      ),
      data: (AffiliateDashboardMetrics m) {
        return Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _KpiTile(
                    label: 'คลิกสะสม',
                    value: Fmt.compactCount(m.totalClicks),
                    caption: '${m.linkCount} ลิงก์ที่ใช้งาน',
                    tone: AppTone.info,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _KpiTile(
                    label: 'ออเดอร์',
                    value: '${m.attributedOrders}',
                    caption: 'รวมทุกลิงก์ของคุณ',
                    tone: AppTone.wait,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: _KpiTile(
                    label: 'Conversion',
                    value: '${m.conversionRate.toStringAsFixed(1)}%',
                    caption:
                        'ออเดอร์ ${m.attributedOrders} จากคลิก '
                        '${m.totalClicks}',
                    tone: AppTone.off,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _KpiTile(
                    label: 'คอมมิชชัน',
                    value: Fmt.price(m.approvedCommission),
                    caption:
                        'อนุมัติ ${Fmt.price(m.approvedCommission)} · '
                        'รอ ${Fmt.price(m.pendingCommission)}',
                    tone: AppTone.good,
                    highlight: true,
                  ),
                ),
              ],
            ),
            // One line of context rather than a fifth tile: the design puts
            // "ยอดขายที่ลิงก์ของคุณทำให้เกิด" under the grid, because it explains
            // the commission rather than standing as its own KPI.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.cardGutter,
                AppSpacing.sm,
                AppSpacing.cardGutter,
                0,
              ),
              child: Text(
                'ยอดขายที่ลิงก์ของคุณทำให้เกิด ${Fmt.price(m.attributedSales)}',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One KPI tile. [highlight] gives the commission figure a turmeric foreground —
/// it is the number the affiliate is actually here for.
class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.caption,
    required this.tone,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String caption;
  final AppTone tone;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: highlight ? AppColors.accentDark : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: tone.foreground,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// The one action this screen offers: promote another product. It sits in the
/// AppBar row of the design, so here it is a full-width chunky button directly
/// under the KPI grid — the most reachable position without a bottom bar.
class _CreateLinkSection extends ConsumerWidget {
  const _CreateLinkSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool busy = ref.watch(affiliateLinkProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardGutter,
        AppSpacing.lg,
        AppSpacing.cardGutter,
        0,
      ),
      child: AppChunkyButton(
        label: 'สร้างลิงก์',
        icon: Icons.add_link_rounded,
        onPressed: busy ? null : () => _openProductPicker(context, ref),
      ),
    );
  }
}

/// Opens the product picker and reports whether a link was created.
Future<void> _openProductPicker(BuildContext context, WidgetRef ref) async {
  final bool? created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => const _ProductPickerSheet(),
  );
  if (created == true && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('สร้างลิงก์เรียบร้อยแล้ว')));
  }
}

/// "ลิงก์ของฉัน" — each row shows the product, its code and its click count, and
/// can be copied or removed.
class _MyLinksSection extends ConsumerWidget {
  const _MyLinksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AffiliateLinkModel>> linksAsync = ref.watch(
      myAffiliateLinksProvider,
    );

    return linksAsync.when(
      loading: () => const SkeletonCards(itemCount: 2, height: 76),
      error: (Object e, StackTrace _) => InlineErrorBanner(
        message: AppStrings.errorBody,
        detail: '$e',
        onRetry: () => ref.invalidate(myAffiliateLinksProvider),
      ),
      data: (List<AffiliateLinkModel> links) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppSectionLabel(
              links.isEmpty
                  ? 'ลิงก์ของฉัน'
                  : 'ลิงก์ของฉัน · ${links.length} ลิงก์',
            ),
            if (links.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.cardGutter,
                ),
                child: EmptyView(
                  icon: Icons.link_off_rounded,
                  title: 'ยังไม่มีลิงก์',
                  body: 'กดปุ่ม "สร้างลิงก์" เพื่อเลือกสินค้าที่จะโปรโมต',
                  compact: true,
                ),
              )
            else
              for (final AffiliateLinkModel link in links)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.cardGutter,
                    0,
                    AppSpacing.cardGutter,
                    AppSpacing.sm,
                  ),
                  child: _LinkTile(link: link),
                ),
          ],
        );
      },
    );
  }
}

class _LinkTile extends ConsumerWidget {
  const _LinkTile({required this.link});

  final AffiliateLinkModel link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool busy = ref.watch(affiliateLinkProvider);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          _linkThumb(url: link.productImageUrl),
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  link.code,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                Fmt.compactCount(link.clicks),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              Text(
                'คลิกสะสม',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _MiniIconButton(
                    icon: Icons.copy_rounded,
                    tooltip: 'คัดลอกรหัสลิงก์',
                    onPressed: () => _copyCode(context),
                  ),
                  _MiniIconButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'ลบลิงก์',
                    onPressed: busy ? null : () => _confirmDelete(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Product thumbnail, or a woven placeholder when there is no usable URL —
  /// the design leans on texture rather than photography.
  Widget _linkThumb({required String url}) {
    if (url.isEmpty) {
      return const WeaveTexture(
        color: AppColors.weaveIndigo,
        width: 44,
        height: 44,
        radius: AppRadius.md,
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 18,
          color: Colors.white,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Image.network(
        url,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        // A dead Cloudinary URL must not take the tile down.
        errorBuilder: (_, _, _) => const WeaveTexture(
          color: AppColors.weaveIndigo,
          width: 44,
          height: 44,
          radius: AppRadius.md,
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: link.code));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('คัดลอกรหัส ${link.code} แล้ว')));
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

/// A 36px square icon button. The copy/delete actions are secondary, so they
/// stay compact — but the box keeps a 36px hit area rather than shrinking to
/// the 18px glyph.
class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Icon(
              icon,
              size: 17,
              color: enabled
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
      ),
    );
  }
}

/// The commission table: product, amount, status. Rows are laid out as a fixed
/// three-column grid rather than a `DataTable`, so it fits a phone and keeps
/// the Thai status label readable.
class _CommissionTable extends ConsumerWidget {
  const _CommissionTable();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AffiliateCommissionModel>> commissionsAsync = ref
        .watch(myAffiliateCommissionsProvider);

    return commissionsAsync.when(
      loading: () => const SkeletonCards(itemCount: 3, height: 56),
      error: (Object e, StackTrace _) => InlineErrorBanner(
        message: AppStrings.errorBody,
        detail: '$e',
        onRetry: () => ref.invalidate(myAffiliateCommissionsProvider),
      ),
      data: (List<AffiliateCommissionModel> commissions) {
        final ColorScheme scheme = Theme.of(context).colorScheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const AppSectionLabel('คอมมิชชัน'),
            if (commissions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.cardGutter,
                ),
                child: EmptyView(
                  icon: Icons.payments_outlined,
                  title: 'ยังไม่มีค่าคอมมิชชัน',
                  body:
                      'เมื่อมีออเดอร์ผ่านลิงก์ของคุณและผ่านการตรวจสอบ '
                      'ค่าคอมมิชชันจะแสดงที่นี่',
                  compact: true,
                ),
              )
            else ...<Widget>[
              for (final AffiliateCommissionModel c in commissions)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.cardGutter,
                    0,
                    AppSpacing.cardGutter,
                    AppSpacing.sm,
                  ),
                  child: _CommissionRow(commission: c),
                ),
              // The MVP caveat is stated on the screen rather than hidden in a
              // doc: an affiliate seeing a commission figure will assume it can
              // be withdrawn, and it cannot.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.cardGutter,
                  AppSpacing.sm,
                  AppSpacing.cardGutter,
                  0,
                ),
                child: AppBanner(
                  tone: AppTone.off,
                  icon: Icons.info_outline_rounded,
                  child: Text(
                    'คอมมิชชันยังไม่มีการถอนเงินจริงในเวอร์ชันนี้ '
                    'ระบบจะสรุปยอดให้ที่เดือน',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _CommissionRow extends StatelessWidget {
  const _CommissionRow({required this.commission});

  final AffiliateCommissionModel commission;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${Fmt.price(commission.orderTotal)} × '
                  '${commission.rate.toStringAsFixed(0)}% · '
                  '${Fmt.date(commission.createdAt)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            Fmt.price(commission.amount),
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: commission.countsAsSales
                  ? AppColors.success
                  : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          CommissionStatusChip(status: commission.status),
        ],
      ),
    );
  }
}

class CommissionStatusChip extends StatelessWidget {
  const CommissionStatusChip({super.key, required this.status});

  final CommissionStatus status;

  /// The design's `.st` badges. Each carries its Thai label as well as its
  /// colour, so the state is legible without colour vision.
  @override
  Widget build(BuildContext context) {
    return AppStatusPill.semantic(
      label: status.label,
      dense: true,
      tone: switch (status) {
        CommissionStatus.pending => AppTone.wait,
        CommissionStatus.approved => AppTone.good,
        CommissionStatus.rejected => AppTone.bad,
        CommissionStatus.cancelled => AppTone.off,
      },
    );
  }
}

/// Picks a product to promote, then writes the link.
///
/// A bottom sheet rather than a dialog: the design uses a sheet, and on a phone
/// a keyboard-height dialog competes with the list for space.
class _ProductPickerSheet extends ConsumerWidget {
  const _ProductPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ProductModel>> products = ref.watch(productsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: AppCard(
          radius: AppRadius.xl * 1.5,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'เลือกสินค้าที่จะโปรโมต',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    AppChip(
                      label: 'ปิด',
                      height: 40,
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: products.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: CircularProgressIndicator(),
                  ),
                  error: (Object e, StackTrace _) => Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text('โหลดสินค้าไม่สำเร็จ: $e'),
                  ),
                  data: (List<ProductModel> all) => _ProductList(products: all),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductList extends ConsumerWidget {
  const _ProductList({required this.products});

  final List<ProductModel> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Drafts are not buyable, so promoting one would produce a link that can
    // never convert.
    final List<ProductModel> visible = products
        .where((ProductModel p) => p.isVisible)
        .toList();

    if (visible.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Text('ยังไม่มีสินค้าที่เปิดขายให้โปรโมต'),
      );
    }

    final bool busy = ref.watch(affiliateLinkProvider);

    // The sheet's `AppCard` is a decorated container, and a `ListTile` paints
    // its ink on the nearest `Material` ancestor — which would be *above* the
    // card, so every tap splash would be hidden by the card's own background.
    // A transparent `Material` here gives the tiles their own ink surface.
    return Material(
      type: MaterialType.transparency,
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: visible.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (BuildContext context, int index) {
          final ProductModel product = visible[index];
          return ListTile(
            title: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('${Fmt.price(product.price)} · ${product.province}'),
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
      ),
    );
  }
}
