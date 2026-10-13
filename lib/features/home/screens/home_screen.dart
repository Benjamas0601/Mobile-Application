import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// `app_enums` declares its own AsyncValue for the offline/sync layer, which
// collides with Riverpod's. Home only uses Riverpod's.
import '../../../core/constants/app_enums.dart' hide AsyncValue;
import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/category_model.dart';
import '../../../models/product_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/catalog_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../widgets/otop_components.dart';
import '../../../widgets/state_views.dart';
import '../../products/widgets/product_card.dart';

/// ไฟล์นี้เป็นไฟล์ที่เก็บหน้าจอเลือกดูสินค้าแบบ public พร้อมหมวด ภูมิภาค และค้นหา

/// Home tab: greeting, category filter row, and the product grid.
///
/// Reads straight from Firestore, so whatever was seeded in the console
/// appears here with no extra wiring.
/// หน้าเลือกดูสินค้าแบบ public พร้อมหมวด ภูมิภาค และค้นหา
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final products = ref.watch(productsProvider);
    final filter = ref.watch(productFilterProvider);
    final user = ref.watch(authUserProvider).asData?.value;
    final int unread = ref.watch(unreadNotificationCountProvider);
    final int cartCount = ref.watch(cartCountProvider);
    final double statusBarHeight = MediaQuery.paddingOf(context).top;

    // The jade header (avatar + address + bell + search) replaces the old
    // AppBar icon row. Cart, favourites, coupons and profile live in the
    // bottom navigation bar; orders/chat/stores live in the profile tab.
    //
    // The header is the FIRST SLIVER of the scroll view, so the whole page
    // (header included) scrolls together.
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: <Widget>[
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(categoriesProvider);
              ref.invalidate(productsProvider);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: OtopHomeHeader(
                    unreadCount: unread,
                    onNotifications: () =>
                        context.push(AppRoutes.notifications),
                    onSearchChanged: (String value) => ref
                        .read(productFilterProvider.notifier)
                        .setSearch(value),
                    showLogin: user == null,
                    onLogin: () => context.push(AppRoutes.login),
                    showLogout: user != null,
                    onLogout: () => ref.read(authRepositoryProvider).signOut(),
                    bottom: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _PromoBanner(
                        onAction: () => context.push(AppRoutes.stores),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _categories(categories, ref, filter),
                ),
                SliverToBoxAdapter(child: _regionFilter(ref, filter)),
                SliverToBoxAdapter(
                  child: _sectionHeader(
                    filter.search == null
                        ? AppStrings.navExplore
                        : AppStrings.searchResults,
                  ),
                ),
                ..._products(context, ref, products),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xxxl),
                ),
              ],
            ),
          ),
          // Keeps the status-bar area jade while content scrolls underneath;
          // otherwise the header's white status-bar icons land on white content.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: statusBarHeight,
            child: const ColoredBox(color: AppColors.primary),
          ),
        ],
      ),
      bottomNavigationBar: OtopBottomNav(
        currentIndex: 0,
        onChanged: (int index) => _onBottomNav(context, ref, index),
        cartCount: cartCount,
      ),
    );
  }

  /// แท็บล่าง: ตะกร้า/โปรไฟล์เปิดหน้าได้เลย ส่วนถูกใจยังเป็นถนนว่าง
  /// ส่วนคูปองเปิดหน้า [CouponListScreen] ให้ผู้ซื้อดูโปรโมชัน
  void _onBottomNav(BuildContext context, WidgetRef ref, int index) {
    switch (index) {
      case 0:
        break;
      case 1:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('แท็บถูกใจ — เร็ว ๆ นี้ เดี๋ยวมาเพิ่มจ้ะ')),
          );
      case 2:
        context.push(AppRoutes.cart);
      case 3:
        context.push(AppRoutes.coupons);
      case 4:
        context.push(AppRoutes.profile);
    }
  }

  // --- Categories -----------------------------------------------------------

  /// Round icon categories. The list is a horizontal SingleChildScrollView +
  /// Row (not a fixed-height ListView), so the section is exactly as tall as
  /// its content and no dead space is left under one-line labels.
  Widget _categories(
    AsyncValue<List<CategoryModel>> categories,
    WidgetRef ref,
    ProductFilter filter,
  ) {
    final List<CategoryModel> items =
        (categories.asData?.value ?? const <CategoryModel>[])
            .where((CategoryModel c) => !kHomeHiddenCategoryIds.contains(c.id))
            .toList();

    // Only the very first load shows the spinner. During a pull-to-refresh the
    // old list stays on screen (isLoading is true there too, but hasValue is not).
    final bool firstLoad = categories.isLoading && !categories.hasValue;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text('หมวดหมู่', style: AppTextStyles.headlineSmall),
                ),
                // "ดูทั้งหมด" clears the active category, so it only appears
                // when one is selected (the first round item does the same
                // thing otherwise). The SizedBox keeps the header height stable.
                if (filter.categoryId != null)
                  TextButton(
                    onPressed: () => _selectCategory(ref, null),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size(48, AppSizes.minTapTarget),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('ดูทั้งหมด'),
                  )
                else
                  const SizedBox(height: AppSizes.minTapTarget),
              ],
            ),
          ),
          if (firstLoad)
            const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (categories.hasError && !categories.hasValue)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: InlineErrorBanner(
                message: 'โหลดหมวดหมู่ไม่สำเร็จ',
                onRetry: () => ref.invalidate(categoriesProvider),
              ),
            )
          else if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: Text(
                'ยังไม่มีหมวดหมู่ — ให้ผู้ดูแลระบบเพิ่มใน Firestore',
                style: TextStyle(color: AppColors.inkMuted),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _CategoryItem(
                    label: 'ทั้งหมด',
                    icon: Icons.grid_view_rounded,
                    selected: filter.categoryId == null,
                    onTap: () => _selectCategory(ref, null),
                  ),
                  for (final CategoryModel category in items) ...<Widget>[
                    const SizedBox(width: AppSpacing.md),
                    _CategoryItem(
                      label: category.name,
                      icon: _categoryIcon(category),
                      selected: filter.categoryId == category.id,
                      onTap: () => _selectCategory(ref, category.id),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  IconData _categoryIcon(CategoryModel category) {
    final String label = '${category.name} ${category.slug} ${category.id}'
        .toLowerCase();
    if (label.contains('อาหาร') ||
        label.contains('food') ||
        label.contains('snack')) {
      return Icons.ramen_dining_outlined;
    }
    if (label.contains('เครื่องดื่ม') ||
        label.contains('drink') ||
        label.contains('beverage')) {
      return Icons.local_cafe_outlined;
    }
    if (label.contains('ผ้า') ||
        label.contains('แฟชั่น') ||
        label.contains('เสื้อ') ||
        label.contains('fashion') ||
        label.contains('cloth')) {
      return Icons.checkroom_outlined;
    }
    if (label.contains('ของใช้') ||
        label.contains('เครื่องใช้') ||
        label.contains('basket') ||
        label.contains('ของตกแต่ง')) {
      return Icons.shopping_basket_outlined;
    }
    if (label.contains('ของที่ระลึก') ||
        label.contains('ของฝาก') ||
        label.contains('gift') ||
        label.contains('souvenir')) {
      return Icons.card_giftcard_outlined;
    }
    return Icons.category_outlined;
  }

  void _selectCategory(WidgetRef ref, String? categoryId) {
    // Tapping the selected chip clears it — a toggle, not a radio.
    ref.read(productFilterProvider.notifier).toggleCategory(categoryId);
  }

  /// Region picker, shown above the grid.
  ///
  /// A guest can browse by province without an account, so this sits on Home
  /// rather than behind a profile screen.
  Widget _regionFilter(WidgetRef ref, ProductFilter filter) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: Text(
              'เลือกซื้อตามภูมิภาค',
              style: AppTextStyles.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: AppSizes.minTapTarget,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              itemCount: ThaiRegion.values.length,
              separatorBuilder: (BuildContext context, int _) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (BuildContext context, int index) {
                final ThaiRegion region = ThaiRegion.values[index];
                return _RegionChip(
                  label: region.label,
                  selected: filter.region == region,
                  onTap: () => ref
                      .read(productFilterProvider.notifier)
                      .toggleRegion(region),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Cart and notification entry points moved out of the header — cart lives
  // in [OtopBottomNav], notifications in the header bell ([OtopHomeHeader]).

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.xxl,
        AppSpacing.gutter,
        AppSpacing.md,
      ),
      child: Text(title, style: AppTextStyles.headlineSmall),
    );
  }

  // --- Products -------------------------------------------------------------

  List<Widget> _products(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<ProductModel>> products,
  ) {
    if (products.isLoading) {
      return const <Widget>[
        SliverToBoxAdapter(
          child: SizedBox(
            height: 220,
            child: SkeletonListView(itemCount: 4, height: 90),
          ),
        ),
      ];
    }

    if (products.hasError) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorView(
            message: '${products.error}',
            onRetry: () => ref.invalidate(productsProvider),
          ),
        ),
      ];
    }

    final List<ProductModel> items =
        products.asData?.value ?? const <ProductModel>[];
    if (items.isEmpty) {
      return const <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyView(
            icon: Icons.search_off_rounded,
            title: AppStrings.emptyProducts,
            body: AppStrings.emptyProductsHint,
          ),
        ),
      ];
    }

    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.72,
          ),
          delegate: SliverChildBuilderDelegate((
            BuildContext context,
            int index,
          ) {
            final ProductModel product = items[index];
            return ProductCard(
              product: product,
              onTap: () => context.push(AppRoutes.productDetail(product.id)),
            );
          }, childCount: items.length),
        ),
      ),
    ];
  }
}

/// Clay promo banner that sits inside the jade header, below the search pill.
/// ใช้คอนเทนต์จากดีไซน์อ้างอิง — "ของดีทุกจังหวัด" กับภาพประกอบ isometric
class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.onAction});

  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.clay,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: <Widget>[
          const Positioned(
            right: 4,
            bottom: 0,
            child: OtopIllustration(width: 170, onClay: true),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 190,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'ของดีทุกจังหวัด',
                      style: AppTextStyles.displayMedium.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ค้นพบสินค้าชุมชนจากทั่วทั้ง 77 จังหวัด',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontSize: 13,
                        color: const Color(0xFFFFF1EC),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: onAction,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.onGold,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: const StadiumBorder(),
                        textStyle: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.onGold,
                        ),
                      ),
                      child: const Text('เลือกซื้อเลย'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: SizedBox(
          width: 62,
          child: Column(
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                  border: selected
                      ? Border.all(color: AppColors.primary, width: 2)
                      : null,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 26, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.ink,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegionChip extends StatelessWidget {
  const _RegionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.primary : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: selected ? Colors.white : AppColors.ink,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}