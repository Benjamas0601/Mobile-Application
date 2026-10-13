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
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/catalog_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../widgets/state_views.dart';


/// Product detail — the screen that has to sell the "story", so the four
/// story blocks get as much space as the price does.
/// หน้ารายละเอียดสินค้า รวมเรื่องราวร้าน ตัวเลือกสินค้า และเพิ่มลงตะกร้า
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(productId));

    // The edit pencil is the seller console's deep link: only the owner of
    // the product's store (or an admin) should ever see it.
    final UserModel? user = ref.watch(authUserProvider).asData?.value;
    final StoreModel? store = product.asData?.value == null
        ? null
        : ref
              .watch(storeProvider(product.asData!.value!.storeId))
              .asData
              ?.value;
    final bool canEdit =
        user != null && store != null && store.ownerUid == user.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(AppStrings.productStory),
        actions: <Widget>[
          if (canEdit)
            IconButton(
              tooltip: AppStrings.sellerEditProduct,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push(AppRoutes.sellerProductEdit(productId)),
            ),
        ],
      ),
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
    final storeState = ref.watch(storeProvider(product.storeId));
    final variantsState = ref.watch(productVariantsProvider(product.id));

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
      children: <Widget>[
        _gallery(product),
        Container(
          margin: const EdgeInsets.only(top: AppSpacing.gutter),
          padding: const EdgeInsets.all(AppSpacing.gutter),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                product.name,
                style: AppTextStyles.headlineSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _metaRow(product),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    Fmt.price(product.priceBaht),
                    style: AppTextStyles.priceLarge.copyWith(
                      color: AppColors.primary,
                    ),
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: AppRadius.cardRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  product.description,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.inkMuted,
                    height: 1.6,
                  ),
                ),
              ),
              if (variantsState.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: InlineErrorBanner(
                    message: 'โหลดตัวเลือกสินค้าไม่สำเร็จ',
                    detail: '${variantsState.error}',
                    onRetry: () => ref.invalidate(
                      productVariantsProvider(product.id),
                    ),
                  ),
                )
              else if (variantsState.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.lg),
                  child: SkeletonTextBlock(lines: 2),
                )
              else if (variantsState.value != null &&
                  variantsState.value!.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xl),
                _variants(variantsState.value!),
              ],
              if (storeState.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: InlineErrorBanner(
                    message: 'โหลดข้อมูลร้านค้าไม่สำเร็จ',
                    detail: '${storeState.error}',
                    onRetry: () =>
                        ref.invalidate(storeProvider(product.storeId)),
                  ),
                )
              else if (storeState.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.lg),
                  child: SkeletonTextBlock(lines: 2),
                )
              else if (storeState.value != null)
                _store(context, ref, storeState.value!),
              const SizedBox(height: AppSpacing.xl),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.xl),
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

  Widget _store(BuildContext context, WidgetRef ref, StoreModel store) {
    // ผู้ขายที่ดูแคตตาล็อกของตัวเองไม่จำเป็นต้องแชทกับตัวเอง
    // ปุ่มนี้สำหรับลูกค้าเท่านั้น
    final UserModel? user = ref.watch(authUserProvider).asData?.value;
    final bool isMyStore = user != null && store.ownerUid == user.uid;

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
            if (!isMyStore) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => _chatWithStore(context, ref, store),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text(AppStrings.chatWithSeller),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// เปิด (หรือสร้าง) ห้องสนทนาของผู้ซื้อกับร้าน [store] แล้วกระโดดเข้าห้อง
  ///
  /// ผู้ที่ยังไม่ล็อกอินจะถูกส่งไปหน้า login พร้อม redirect กลับมาหน้านี้ เพื่อให้
  /// ล็อกอินเสร็จแล้วกลับมากดซ้ำได้ทันที — route แชทบังคับล็อกอินอยู่แล้ว แต่ต้อง
  /// ตัดสินใจ redirect ที่นี่ เพราะ id ของห้องจะเกิดหลังสร้างห้องสำเร็จเท่านั้น
  Future<void> _chatWithStore(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
  ) async {
    final String? myUid = ref.read(authUserProvider).asData?.value?.uid;
    if (myUid == null) {
      final String back = Uri.encodeComponent(AppRoutes.productDetail(productId));
      context.push('${AppRoutes.login}?redirect=$back');
      return;
    }
    try {
      final String id = await ref
          .read(chatRepositoryProvider)
          .getOrCreateThread(
            storeId: store.id,
            sellerUid: store.ownerUid,
            storeName: store.name,
          );
      if (context.mounted) context.push(AppRoutes.chatThread(id));
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text(AppStrings.chatOpenFailed)),
        );
    }
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: AppRadius.pillRadius,
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.inkMuted,
                    height: 1.6,
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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1A146356),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.cardRadius,
              ),
            ),
            // Works for guests too: the cart is local, and signing in is only
            // required later, at checkout.
            onPressed: inStock ? () => _addToCart(context, ref, product) : null,
            icon: const Icon(Icons.add_shopping_cart_rounded),
            label: Text(
              inStock ? AppStrings.addToCart : AppStrings.outOfStock,
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _addToCart(BuildContext context, WidgetRef ref, ProductModel product) {
    final CartAddResult result = ref.read(cartProvider.notifier).add(product);
    final int count = ref.read(cartCountProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context)
      ..clearSnackBars();

    switch (result) {
      case CartAddResult.added:
        messenger.showSnackBar(
          SnackBar(
            content: Text('${AppStrings.addedToCart} ($count)'),
            action: SnackBarAction(
              label: AppStrings.cart,
              onPressed: () => context.push(AppRoutes.cart),
            ),
          ),
        );
      case CartAddResult.differentStore:
        // One order maps to one store, so this cannot be resolved by silently
        // dropping the earlier line. Offer the two real options instead.
        _showDifferentStoreDialog(context, ref);
      case CartAddResult.atStockLimit:
        messenger.showSnackBar(
          SnackBar(content: Text(AppStrings.cartAtStockLimit)),
        );
      case CartAddResult.outOfStock:
        messenger.showSnackBar(
          const SnackBar(content: Text(AppStrings.outOfStock)),
        );
    }
  }

  Future<void> _showDifferentStoreDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? clear = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text(AppStrings.cartDifferentStoreTitle),
        content: const Text(AppStrings.cartDifferentStoreHint),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.keepBrowsing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.clearCartAndRetry),
          ),
        ],
      ),
    );

    // `null` means the dialog was dismissed; `false` means keep browsing.
    if (clear != true || !context.mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    ref.read(cartProvider.notifier).clear();
    messenger.showSnackBar(
      const SnackBar(content: Text(AppStrings.cartCleared)),
    );
  }
}
