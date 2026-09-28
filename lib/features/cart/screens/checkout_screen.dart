import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../widgets/state_views.dart';

/// Checkout, with the authentication gate.
///
/// This is the boundary the whole "browse as guest" flow is built around: the
/// cart is local and works signed out, and the first moment that needs a named
/// person is right here.
class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<CartLine> lines = ref.watch(cartProvider);
    final UserModel? user = ref.watch(authUserProvider).asData?.value;

    if (lines.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.checkout)),
        body: EmptyView(
          icon: Icons.shopping_basket_outlined,
          title: AppStrings.emptyCart,
          body: AppStrings.emptyCartHint,
          actionLabel: AppStrings.navExplore,
          onAction: () => context.go(AppRoutes.home),
        ),
      );
    }

    // The router normally prevents this, but a session can end while the
    // screen is open, so the gate is enforced here too.
    if (user == null) return const _AuthGate();

    return _CheckoutForm(lines: lines, user: user);
  }
}

/// Shown to a guest who reached checkout.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.checkout)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 56,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    AppStrings.loginToOrder,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    AppStrings.loginToOrderHint,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // `redirect` carries the destination so signing in resumes
                  // this checkout instead of dropping the user on Home.
                  FilledButton(
                    onPressed: () => context.push(
                      '${AppRoutes.login}?redirect=${AppRoutes.checkout}',
                    ),
                    child: const Text(AppStrings.login),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: () => context.push(
                      '${AppRoutes.register}?redirect=${AppRoutes.checkout}',
                    ),
                    child: const Text(AppStrings.register),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    // Label promises browsing, so go back to the catalogue
                    // rather than the cart the user just came from.
                    onPressed: () => context.go(AppRoutes.home),
                    child: const Text(AppStrings.backToCart),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckoutForm extends ConsumerStatefulWidget {
  const _CheckoutForm({required this.lines, required this.user});

  final List<CartLine> lines;
  final UserModel user;

  @override
  ConsumerState<_CheckoutForm> createState() => _CheckoutFormState();
}

class _CheckoutFormState extends ConsumerState<_CheckoutForm> {
  final TextEditingController _address = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double subtotal = widget.lines.fold(
      0.0,
      (double s, CartLine l) => s + l.lineTotal,
    );
    final double total = getCartTotal(subtotal);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.checkout)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: <Widget>[
          _buyerCard(),
          const SizedBox(height: AppSpacing.lg),
          Text(AppStrings.shippingAddress, style: AppTextStyles.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _address,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: AppStrings.addressHint,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: <Widget>[
                  for (final CartLine l in widget.lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '${l.name} x${l.quantity}',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                          Text(
                            Fmt.price(l.lineTotal),
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text('ค่าจัดส่ง', style: AppTextStyles.bodyMedium),
                      Text(
                        getShippingFee(subtotal) == 0
                            ? 'ฟรี'
                            : Fmt.price(getShippingFee(subtotal)),
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text('ยอดรวม', style: AppTextStyles.labelLarge),
                      Text(
                        Fmt.price(total),
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _placeOrder,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(AppStrings.placeOrder),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buyerCard() {
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.person_outline_rounded,
          color: AppColors.primary,
        ),
        title: Text(widget.user.displayName, style: AppTextStyles.bodyLarge),
        subtitle: Text(widget.user.email, style: AppTextStyles.labelSmall),
      ),
    );
  }

  Future<void> _placeOrder() async {
    setState(() => _busy = true);
    // Writing the order document and taking payment are Week 4 work; the
    // flow reaches the confirmation step so the gate can be demonstrated.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    ref.read(cartProvider.notifier).clear();
    // Grab the messenger first: this widget is torn down by the navigation
    // below, so looking it up afterwards would hit a deactivated context.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text(AppStrings.orderPlaced)),
    );
    context.go(AppRoutes.home);
  }
}
