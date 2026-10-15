import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/product_model.dart';
import '../../../providers/favorite_provider.dart';
import '../../../widgets/state_views.dart';
import '../../products/widgets/product_card.dart';

/// หน้าสินค้าที่ผู้ซื้อกด "ถูกใจ"
///
/// ดึงรหัสถูกใจจาก Firestore แบบเรียลไทม์ แล้วจึงดึงข้อมูลสินค้าล่าสุดของรหัส
/// เหล่านั้น ราคา/สต็อกจึงตรงกับหน้าร้านเสมอ และเมื่อกดหัวใจในหน้านี้
/// รายการจะอัปเดตเองทันทีโดยไม่ต้องรีเฟรช
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: AppStrings.backToHome,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        title: const Text(AppStrings.favoritesTitle),
      ),
      body: ref
          .watch(favoriteProductsProvider)
          .when(
            loading: () => const LoadingView(),
            error: (Object error, StackTrace stack) => ErrorView(
              message: '$error',
              onRetry: () => ref.invalidate(favoriteProductsProvider),
            ),
            data: (List<ProductModel> products) {
              if (products.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const <Widget>[
                    SizedBox(
                      height: 360,
                      child: EmptyView(
                        icon: Icons.favorite_border_rounded,
                        title: AppStrings.favoritesEmpty,
                        body: AppStrings.favoritesEmptyHint,
                      ),
                    ),
                  ],
                );
              }

              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(favoriteProductsProvider),
                child: GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: products.length,
                  itemBuilder: (BuildContext context, int index) {
                    final ProductModel product = products[index];
                    return ProductCard(
                      product: product,
                      onTap: () =>
                          context.push(AppRoutes.productDetail(product.id)),
                    );
                  },
                ),
              );
            },
          ),
    );
  }
}
