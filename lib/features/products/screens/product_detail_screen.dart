import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/product_model.dart';
import '../../../models/store_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/catalog_provider.dart';
import '../../../widgets/state_views.dart';

/// Product detail — the screen that has to sell the "story", so the four
/// story blocks get as much space as the price does.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(productId));

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.productStory)),
      body: product.isLoading
          ? const LoadingView()
          : product.hasError
          ? ErrorView(
              message: '${product.error}',
              onRetry: () => ref.invalidate(productProvider(productId)),
            )
          : (product.asData?.value == null
                ? const EmptyView(
                    icon: Icons.inventory_2_outlined,
                    title: 'ไม่พบสินค้านี้',
                    body: 'สินค้าอาจถูกลบหรือยังไม่เผยแพร่',
                  )
                : _body(context, ref, product.asData!.value!)),
      bottomNavigationBar:
          (product.asData?.value != null && product.asData!.value!.isInStock)
          ? _bottomBar(context, ref, product.asData!.value!)
          : null,
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, ProductModel product) {
    final store = ref.watch(storeProvider(product.storeId)).asData?.value;
    final variants = ref
        .watch(productVariantsProvider(product.id))
        .asData
        ?.value;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
      children: <Widget>[
        _gallery(product),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(product.name, style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              _metaRow(product),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    Fmt.price(product.priceBaht),
                    style: AppTextStyles.priceLarge,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (product.soldCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text(
                        Fmt.fill(AppStrings.sold, count: product.soldCount),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(product.description, style: AppTextStyles.bodyMedium),
              if (variants != null && variants.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xl),
                _variants(variants),
              ],
              if (store != null) _store(store),
              const Divider(height: AppSpacing.huge * 2),
              if (product.story.isEmpty)
                const EmptyView(
                  icon: Icons.auto_stories_outlined,
                  title: 'ยังไม่มีเรื่องราวสินค้านี้',
                  body: 'ผู้ขายยังไม่ได้เพิ่มข้อมูลชุมชนผู้ผลิตและวิธีผลิต',
                )
              else
                _story(product.story),
            ],
          ),
        ),
      ],
    );
  }

  // --- Sections -------------------------------------------------------------

  Widget _gallery(ProductModel product) {
    if (product.imageUrls.isEmpty) {
      return Container(
        height: 240,
        color: AppColors.surfaceMuted,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_outlined,
          size: 40,
          color: AppColors.inkSubtle,
        ),
      );
    }
    return SizedBox(
      height: 280,
      child: PageView.builder(
        itemCount: product.imageUrls.length,
        itemBuilder: (BuildContext context, int index) {
          return CachedNetworkImage(
            imageUrl: product.imageUrls[index],
            fit: BoxFit.cover,
            placeholder: (BuildContext context, String _) =>
                Container(color: AppColors.surfaceMuted),
            errorWidget: (BuildContext context, String _, Object _) =>
                Container(
                  color: AppColors.surfaceMuted,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    size: 40,
                    color: AppColors.inkSubtle,
                  ),
                ),
          );
        },
      ),
    );
  }

  Widget _metaRow(ProductModel product) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        _tag(Icons.place_outlined, product.province),
        _tag(Icons.map_outlined, product.regionLabel),
        if (product.ratingCount > 0)
          _tag(
            Icons.star_rounded,
            '${Fmt.rating(product.ratingAvg)} (${product.ratingCount})',
          ),
        _tag(
          product.isInStock
              ? Icons.inventory_2_outlined
              : Icons.remove_shopping_cart_outlined,
          product.isInStock
              ? Fmt.fill(AppStrings.stockLeft, count: product.stockTotal)
              : AppStrings.outOfStock,
        ),
      ],
    );
  }

  Widget _tag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppColors.inkMuted),
          const SizedBox(width: AppSpacing.xs),
          Text(
            text,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _variants(List<ProductVariantModel> variants) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(AppStrings.selectVariant, style: AppTextStyles.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: variants
              .map(
                (ProductVariantModel v) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: v.isInStock
                        ? AppColors.surface
                        : AppColors.surfaceMuted,
                    borderRadius: AppRadius.pillRadius,
                    border: Border.all(
                      color: v.isInStock ? AppColors.border : AppColors.border,
                    ),
                  ),
                  child: Text(
                    v.priceDelta > 0
                        ? '${v.name} (+${Fmt.price(v.priceDelta)})'
                        : v.name,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: v.isInStock ? AppColors.ink : AppColors.inkSubtle,
                      decoration: v.isInStock
                          ? null
                          : TextDecoration.lineThrough,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _store(StoreModel store) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: AppRadius.cardRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(store.name, style: AppTextStyles.bodyLarge),
                ),
                if (store.otopCertified)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: AppRadius.pillRadius,
                    ),
                    child: Text(
                      'OTOP',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              store.community,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _story(ProductStory story) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(AppStrings.productStory, style: AppTextStyles.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        if (story.community.isNotEmpty)
          _block(AppStrings.community, story.community, Icons.groups_outlined),
        if (story.ingredients.isNotEmpty)
          _block(AppStrings.ingredients, story.ingredients, Icons.eco_outlined),
        if (story.productionMethod.isNotEmpty)
          _block(
            AppStrings.productionMethod,
            story.productionMethod,
            Icons.handyman_outlined,
          ),
        if (story.uniqueness.isNotEmpty)
          _block(
            AppStrings.uniqueness,
            story.uniqueness,
            Icons.auto_awesome_outlined,
          ),
      ],
    );
  }

  Widget _block(String title, String body, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppTextStyles.labelMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  body,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(BuildContext context, WidgetRef ref, ProductModel product) {
    // Out of stock disables the button rather than failing on tap.
    final bool inStock = product.stockTotal > 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: FilledButton.icon(
          // Works for guests too: the cart is local, and signing in is only
          // required later, at checkout.
          onPressed: inStock ? () => _addToCart(context, ref, product) : null,
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: Text(inStock ? AppStrings.addToCart : AppStrings.outOfStock),
        ),
      ),
    );
  }

  void _addToCart(BuildContext context, WidgetRef ref, ProductModel product) {
    ref.read(cartProvider.notifier).add(product);
    final int count = ref.read(cartCountProvider);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('${AppStrings.addedToCart} ($count)'),
          action: SnackBarAction(
            label: AppStrings.cart,
            onPressed: () => context.push(AppRoutes.cart),
          ),
        ),
      );
  }
}
