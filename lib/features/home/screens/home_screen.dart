import 'dart:async';

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
import '../../../widgets/state_views.dart';
import '../../products/widgets/product_card.dart';

/// Home tab: greeting, category filter row, and the product grid.
///
/// Reads straight from Firestore, so whatever was seeded in the console
/// appears here with no extra wiring.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final products = ref.watch(productsProvider);
    final filter = ref.watch(productFilterProvider);
    final user = ref.watch(authUserProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.gutter,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(AppStrings.appName, style: AppTextStyles.headlineSmall),
            Text(
              user == null
                  ? 'เลือกดูสินค้า OTOP ทั่วไทย'
                  : 'สวัสดี ${user.shortName} 👋',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: AppStrings.stores,
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => context.push(AppRoutes.stores),
          ),
          _cartButton(context, ref.watch(cartCountProvider)),
          // Guests get an explicit way in; the cart is not an obvious cue.
          if (user == null)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xs,
                right: AppSpacing.md,
              ),
              child: TextButton.icon(
                onPressed: () => context.push(AppRoutes.login),
                icon: const Icon(Icons.person_outline_rounded, size: 18),
                label: const Text(AppStrings.login),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            )
          // Sign-out only makes sense when there is a session to end.
          else ...<Widget>[
            // Seller console — only meaningful to an account that can write a
            // store, so it joins the cart button behind the sign-in wall. It
            // opens the hub, not the product list, so the seller's orders and
            // store profile are one tap away instead of buried in a route
            // nobody would guess.
            if (user.isSeller || user.isAdmin)
              IconButton(
                tooltip: AppStrings.navSellerDashboard,
                icon: const Icon(Icons.storefront_outlined),
                onPressed: () => context.push(AppRoutes.sellerRoot),
              ),
            // Affiliate console. Its own button rather than a shared "console"
            // entry because one account can be both: `docs/01_product_problem.md`
            // argues a real OTOP producer sells *and* promotes, so each console
            // has to stay one tap away instead of the other being unreachable.
            if (user.isAffiliate || user.isAdmin)
              IconButton(
                tooltip: AppStrings.navAffiliateDashboard,
                icon: const Icon(Icons.campaign_outlined),
                onPressed: () => context.push(AppRoutes.affiliateRoot),
              ),
            IconButton(
              tooltip: AppStrings.navOrders,
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () => context.push(AppRoutes.orders),
            ),
            IconButton(
              tooltip: AppStrings.logout,
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(categoriesProvider);
          ref.invalidate(productsProvider);
        },
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(child: const _SearchBar()),
            SliverToBoxAdapter(child: _categories(categories, ref, filter)),
            SliverToBoxAdapter(child: _regionFilter(ref, filter)),
            SliverToBoxAdapter(
              child: _sectionHeader(
                filter.search == null
                    ? AppStrings.navExplore
                    : AppStrings.searchResults,
              ),
            ),
            ..._products(context, ref, products),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
          ],
        ),
      ),
    );
  }

  // --- Categories -----------------------------------------------------------

  Widget _categories(
    AsyncValue<List<CategoryModel>> categories,
    WidgetRef ref,
    ProductFilter filter,
  ) {
    if (categories.isLoading) {
      return const SizedBox(
        height: 72,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (categories.hasError) {
      return InlineErrorBanner(
        message: 'โหลดหมวดหมู่ไม่สำเร็จ',
        onRetry: () => ref.invalidate(categoriesProvider),
      );
    }

    final List<CategoryModel> items =
        categories.asData?.value ?? const <CategoryModel>[];
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.gutter),
        child: Text(
          'ยังไม่มีหมวดหมู่ — ให้ผู้ดูแลระบบเพิ่มใน Firestore',
          style: TextStyle(color: AppColors.inkMuted),
        ),
      );
    }

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        itemCount: items.length + 1,
        separatorBuilder: (BuildContext context, int _) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return FilterChipTile(
              label: 'ทั้งหมด',
              selected: filter.categoryId == null,
              onTap: () => _selectCategory(ref, null),
            );
          }
          final CategoryModel category = items[index - 1];
          return FilterChipTile(
            label: category.name,
            icon: category.icon.isEmpty ? null : category.icon,
            selected: filter.categoryId == category.id,
            onTap: () => _selectCategory(ref, category.id),
          );
        },
      ),
    );
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
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        children: <Widget>[
          for (final ThaiRegion region in ThaiRegion.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilterChipTile(
                label: region.label,
                selected: filter.region == region,
                onTap: () => ref
                    .read(productFilterProvider.notifier)
                    .toggleRegion(region),
              ),
            ),
        ],
      ),
    );
  }

  /// Cart entry point with a live item count.
  Widget _cartButton(BuildContext context, int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        IconButton(
          tooltip: AppStrings.cart,
          icon: const Icon(Icons.shopping_basket_outlined),
          onPressed: () => context.push(AppRoutes.cart),
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall.copyWith(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

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

/// Free-text product search, available to guests.
///
/// Keystrokes are debounced: the repository issues a Firestore query per
/// filter change, so querying on every character would burn reads and make the
/// grid flicker.
class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar();

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  static const Duration _debounce = Duration(milliseconds: 350);

  final TextEditingController _controller = TextEditingController();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      ref.read(productFilterProvider.notifier).setSearch(value);
    });
  }

  void _clear() {
    _timer?.cancel();
    _controller.clear();
    ref.read(productFilterProvider.notifier).setSearch('');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        0,
      ),
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        textInputAction: TextInputAction.search,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: AppStrings.searchHint,
          hintStyle: AppTextStyles.bodySmall.copyWith(
            color: AppColors.inkSubtle,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.inkMuted,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder:
                (BuildContext context, TextEditingValue value, Widget? child) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    tooltip: AppStrings.clearSearch,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: _clear,
                  );
                },
          ),
          isDense: true,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          border: OutlineInputBorder(
            borderRadius: AppRadius.cardRadius,
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.cardRadius,
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }
}
