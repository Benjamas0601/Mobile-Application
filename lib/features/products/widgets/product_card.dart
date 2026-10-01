import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/product_model.dart';

/// 2D card for the product grid.
///
/// The brief limits 3D art to the login hero, so a card stays a flat image
/// plus text — that also keeps the grid cheap to scroll on low-end phones.
/// การ์ดสินค้าในกริด; แสดงสถานะหมดสต็อกและราคาให้เห็นก่อนเปิดรายละเอียด
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.onTap});

  final ProductModel product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${product.name} ราคา ${Fmt.price(product.priceBaht)}',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: _image(context)),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product.name,
                      style: AppTextStyles.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      product.province,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.inkMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            Fmt.price(product.priceBaht),
                            style: AppTextStyles.priceMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (product.ratingCount > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                Fmt.rating(product.ratingAvg),
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _image(BuildContext context) {
    final String? url = product.coverImageUrl;

    // A sold-out or image-less product still has to render as a card, so the
    // placeholder carries the status instead of an empty grey box.
    if (!product.isInStock) {
      return _placeholder(
        icon: Icons.remove_shopping_cart_outlined,
        label: AppStrings.outOfStock,
        color: AppColors.inkSubtle,
      );
    }
    if (url == null || url.isEmpty) {
      return _placeholder(
        icon: Icons.image_outlined,
        label: null,
        color: AppColors.inkSubtle,
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (BuildContext context, String _) =>
          Container(color: AppColors.surfaceMuted),
      errorWidget: (BuildContext context, String _, Object _) => _placeholder(
        icon: Icons.broken_image_outlined,
        label: null,
        color: AppColors.inkSubtle,
      ),
    );
  }

  Widget _placeholder({
    required IconData icon,
    required String? label,
    required Color color,
  }) {
    return Container(
      color: AppColors.surfaceMuted,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 28),
          if (label != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
          ],
        ],
      ),
    );
  }
}

/// Chip used for categories and regions on the home screen.
class FilterChipTile extends StatelessWidget {
  const FilterChipTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: AppRadius.pillRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillRadius,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.pillRadius,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Text(icon!, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected ? AppColors.onPrimary : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
