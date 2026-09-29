import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart' hide AsyncValue;
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
import '../../../providers/seller_catalog_provider.dart';
import '../../../widgets/state_views.dart';

/// The seller console's first screen: manage the catalogue of the seller's
/// own store(s).
///
/// Drafts are listed here — a seller must be able to finish a product they
/// started — which is why the customer-facing catalogue never shares this
/// provider.
class SellerProductListScreen extends ConsumerStatefulWidget {
  const SellerProductListScreen({super.key});

  @override
  ConsumerState<SellerProductListScreen> createState() =>
      _SellerProductListScreenState();
}

class _SellerProductListScreenState
    extends ConsumerState<SellerProductListScreen> {
  @override
  Widget build(BuildContext context) {
    final UserModel? user = ref.watch(authUserProvider).asData?.value;

    // Layer 2 of the role gate (layer 1 is firestore.rules): a customer who
    // types the URL sees a sentence, not a broken screen full of denied reads.
    if (user == null || (!user.isSeller && !user.isAdmin)) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.sellerProducts)),
        body: const EmptyView(
          icon: Icons.lock_outline_rounded,
          title: AppStrings.errNotAuthorised,
        ),
      );
    }

    final storeState = ref.watch(myStoreProvider);
    if (storeState.isLoading) {
      return _Scaffold(title: AppStrings.sellerProducts, child: const LoadingView());
    }
    if (storeState.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.sellerProducts)),
        body: ErrorView(
          message: '${storeState.error}',
          onRetry: () => ref.invalidate(myStoreProvider),
        ),
      );
    }

    final StoreModel? store = storeState.asData?.value;
    if (store == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.sellerProducts)),
        body: const EmptyView(
          icon: Icons.storefront_outlined,
          title: AppStrings.sellerNoStoreTitle,
          body: AppStrings.sellerNoStoreHint,
        ),
      );
    }

    final String storeId = store.id;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.sellerProducts)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'seller-add-product',
        onPressed: () =>
            context.push(AppRoutes.sellerProductNew(storeId)),
        icon: const Icon(Icons.add_rounded),
        label: const Text(AppStrings.sellerAddProduct),
      ),
      body: _productsBody(storeId),
    );
  }

  Widget _productsBody(String storeId) {
    final state = ref.watch(myProductsProvider(storeId));
    if (state.isLoading) {
      return const SkeletonListView(itemCount: 5, height: 88);
    }
    if (state.hasError) {
      return ErrorView(
        message: '${state.error}',
        onRetry: () => ref.invalidate(myProductsProvider(storeId)),
      );
    }
    final List<ProductModel> products = state.asData?.value ?? const <ProductModel>[];
    if (products.isEmpty) {
      return const EmptyView(
        icon: Icons.inventory_2_outlined,
        title: AppStrings.sellerNoProducts,
        body: AppStrings.sellerNoProductsHint,
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.refresh(myProductsProvider(storeId).future),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        itemCount: products.length,
        separatorBuilder: (BuildContext context, int _) =>
            const SizedBox(height: AppSpacing.sm),
        itemBuilder: (BuildContext context, int index) =>
            _productRow(products[index]),
      ),
    );
  }

  Widget _productRow(ProductModel product) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppSpacing.sm),
        leading: _thumbnail(product),
        title: Text(
          product.name,
          style: AppTextStyles.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxs),
          child: Row(
            children: <Widget>[
              _statusChip(product.status),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${Fmt.price(product.priceBaht)} · '
                  '${Fmt.fill(AppStrings.stockLeft, count: product.stockTotal)}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.inkMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              tooltip: AppStrings.sellerEditProduct,
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () =>
                  context.push(AppRoutes.sellerProductEdit(product.id)),
            ),
            IconButton(
              tooltip: AppStrings.delete,
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: AppColors.danger,
              onPressed: () => _confirmDelete(product),
            ),
          ],
        ),
        onTap: () => context.push(AppRoutes.sellerProductEdit(product.id)),
      ),
    );
  }

  Widget _thumbnail(ProductModel product) {
    final String? url = product.coverImageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: AppRadius.cardRadius,
        ),
        child: const Icon(Icons.image_outlined, color: AppColors.inkSubtle),
      );
    }
    return ClipRRect(
      borderRadius: AppRadius.cardRadius,
      child: CachedNetworkImage(
        imageUrl: url,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorWidget: (BuildContext context, String _, Object _) => Container(
          width: 56,
          height: 56,
          color: AppColors.surfaceMuted,
          child: const Icon(
            Icons.broken_image_outlined,
            color: AppColors.inkSubtle,
          ),
        ),
      ),
    );
  }

  Widget _statusChip(ProductStatus status) {
    final Color color = switch (status) {
      ProductStatus.active => AppColors.success,
      ProductStatus.draft => AppColors.inkMuted,
      ProductStatus.outOfStock => AppColors.warning,
      ProductStatus.archived => AppColors.inkSubtle,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillRadius,
      ),
      child: Text(
        status.label,
        style: AppTextStyles.labelSmall.copyWith(color: color, fontSize: 11),
      ),
    );
  }

  Future<void> _confirmDelete(ProductModel product) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text(AppStrings.deleteProductConfirm),
        content: const Text(AppStrings.deleteProductHint),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String? id = await ref
        .read(deleteProductProvider.notifier)
        .delete(product);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          id == null ? AppStrings.deleteProductFailed : AppStrings.productDeleted,
        ),
      ),
    );
  }
}

/// A memuable scaffold wrapper so the gate early-returns stay one-liners.
class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text(title)), body: child);
}