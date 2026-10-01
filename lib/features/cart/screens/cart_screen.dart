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
import '../../../providers/cart_provider.dart';
import '../../../widgets/state_views.dart';

/// The local cart. Reachable by a guest — signing in is a checkout step, not a
/// cart step.
/// แสดงรายการตะกร้า ยอดรวม และทางไป checkout ของร้านเดียว
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<CartLine> lines = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.cart)),
      body: lines.isEmpty
          ? EmptyView(
              icon: Icons.shopping_basket_outlined,
              title: AppStrings.emptyCart,
              body: AppStrings.emptyCartHint,
              actionLabel: AppStrings.navExplore,
              onAction: () => context.go(AppRoutes.home),
            )
          : Column(
              children: <Widget>[
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.gutter),
                    itemCount: lines.length,
                    separatorBuilder: (BuildContext context, int _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (BuildContext context, int index) =>
                        _CartLineTile(line: lines[index]),
                  ),
                ),
                _Summary(lines: lines),
              ],
            ),
    );
  }
}

class _CartLineTile extends ConsumerWidget {
  const _CartLineTile({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CartNotifier cart = ref.read(cartProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _thumb(),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(line.name, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    Fmt.price(line.price),
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      _StepButton(
                        icon: Icons.remove,
                        onTap: () =>
                            cart.setQuantity(line.productId, line.quantity - 1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Text(
                          '${line.quantity}',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ),
                      _StepButton(
                        icon: Icons.add,
                        // Disabled at the stock ceiling so the button never
                        // silently does nothing.
                        onTap: line.stock > 0 && line.quantity >= line.stock
                            ? null
                            : () => cart.setQuantity(
                                line.productId,
                                line.quantity + 1,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                IconButton(
                  tooltip: AppStrings.remove,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppColors.danger,
                  onPressed: () => cart.remove(line.productId),
                ),
                Text(
                  Fmt.price(line.lineTotal),
                  style: AppTextStyles.labelMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb() {
    final Widget fallback = Container(
      color: AppColors.surfaceMuted,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: AppColors.inkSubtle),
    );

    return ClipRRect(
      borderRadius: AppRadius.cardRadius,
      child: SizedBox(
        width: 72,
        height: 72,
        child: (line.imageUrl == null || line.imageUrl!.isEmpty)
            ? fallback
            : CachedNetworkImage(
                imageUrl: line.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (BuildContext context, String _) => fallback,
                errorWidget: (BuildContext context, String _, Object _) =>
                    fallback,
              ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillRadius,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: AppRadius.pillRadius,
        ),
        child: Icon(icon, size: 18, color: AppColors.ink),
      ),
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.lines});

  final List<CartLine> lines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double subtotal = lines.fold(
      0.0,
      (double s, CartLine l) => s + l.lineTotal,
    );
    final double shipping = getShippingFee(subtotal);
    final double total = getCartTotal(subtotal);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _row('สินค้า ${lines.length} รายการ', Fmt.price(subtotal)),
            const SizedBox(height: AppSpacing.xs),
            _row('ค่าจัดส่ง', shipping == 0 ? 'ฟรี' : Fmt.price(shipping)),
            const Divider(height: AppSpacing.xl),
            _row('ยอดรวม', Fmt.price(total), emphasise: true),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.push(AppRoutes.checkout),
                child: const Text(AppStrings.checkout),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool emphasise = false}) {
    final TextStyle style = emphasise
        ? AppTextStyles.labelLarge
        : AppTextStyles.bodyMedium;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}
