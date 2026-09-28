import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/cart/screens/cart_screen.dart';
import '../../features/cart/screens/checkout_screen.dart';
import '../../features/cart/screens/payment_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/orders/screens/order_detail_screen.dart';
import '../../features/orders/screens/order_list_screen.dart';
import '../../features/products/screens/product_detail_screen.dart';
import '../../features/stores/screens/stores_screen.dart';
import '../../providers/auth_provider.dart';

/// Every route path lives here as a constant.
///
/// Two reasons: no typo'd string literals scattered through the app, and the
/// navigation map can be read in one place during the demo.
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String explore = '/explore';
  static const String stores = '/stores';
  static const String orders = '/orders';
  static const String ordersHistory = '/order-history';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String payment = '/checkout/payment';
  static const String profile = '/profile';

  /// Takes the product id as a path parameter: `/product/p-silk-scarf-red`.
  static String productDetail(String productId) => '/product/$productId';

  /// Takes the order id: `/order/abc123`.
  static String orderDetail(String orderId) => '/order/$orderId';
}

/// Decides whether the current location is allowed, returning a replacement
/// path or null to stay put.
///
/// The app is browse-first: opening it lands on Home and a guest can read the
/// whole catalogue. Only the account-bound steps are guarded, because those are
/// the ones that must name a person.
///
///  * signed out -> may browse anything except the account-required routes
///  * signed in  -> may reach everything
///  * loading    -> treated as signed out, so a guarded screen never flashes
///                  before the auth stream has reported
String? authRedirect({required bool signedIn, required String location}) {
  // Checkout is deliberately absent: it renders its own gate so the guest sees
  // the choice (sign in / register / keep shopping) instead of a bare redirect,
  // and so signing in can resume it without a redirect race against the auth
  // stream. Guarding it here would also bounce the user straight back to login
  // while the profile is still loading.
  const Set<String> accountRequired = <String>{
    AppRoutes.orders,
    AppRoutes.ordersHistory,
    AppRoutes.profile,
  };

  if (!accountRequired.contains(location)) return null;
  if (signedIn) return null;
  // Hand the destination to the login screen as `redirect` so signing in
  // resumes the original flow instead of dumping the user on Home.
  return '${AppRoutes.login}?redirect=$location';
}

/// The router instance.
///
/// Built by a provider so the redirect can read the current auth state
/// instead of only checking on navigation events.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    redirect: (BuildContext context, GoRouterState state) => authRedirect(
      // `asData` rather than a value getter: it is null while loading *and*
      // when signed out, and this guard only needs "are we definitely in?".
      signedIn: ref.read(authUserProvider).asData?.value != null,
      location: state.matchedLocation,
    ),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.login,
        builder: (BuildContext context, GoRouterState state) =>
            LoginScreen(redirect: state.uri.queryParameters['redirect']),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (BuildContext context, GoRouterState state) =>
            RegisterScreen(redirect: state.uri.queryParameters['redirect']),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (BuildContext context, GoRouterState state) =>
            const HomeScreen(),
      ),
      GoRoute(
        path: '/product/:productId',
        builder: (BuildContext context, GoRouterState state) =>
            ProductDetailScreen(
              productId: state.pathParameters['productId'] ?? '',
            ),
      ),
      GoRoute(
        path: AppRoutes.cart,
        builder: (BuildContext context, GoRouterState state) =>
            const CartScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        builder: (BuildContext context, GoRouterState state) =>
            const CheckoutScreen(),
      ),
      // Step two of checkout. Reads what it needs from providers, so the URL
      // stays a plain path and a reload mid-flow loses nothing.
      GoRoute(
        path: AppRoutes.payment,
        builder: (BuildContext context, GoRouterState state) =>
            const PaymentScreen(),
      ),
      GoRoute(
        path: AppRoutes.stores,
        builder: (BuildContext context, GoRouterState state) =>
            const StoresScreen(),
      ),
      // Account-bound, and guarded: orders name a person. `/checkout` stays
      // unguarded because it renders its own gate.
      GoRoute(
        path: AppRoutes.orders,
        builder: (BuildContext context, GoRouterState state) =>
            const OrderListScreen(),
      ),
      // Deep link from the payment confirmation, so the buyer lands on the
      // order they just made rather than a list they have to search.
      GoRoute(
        path: '/order/:orderId',
        builder: (BuildContext context, GoRouterState state) => OrderDetailScreen(
          orderId: state.pathParameters['orderId'] ?? '',
        ),
      ),
    ],
  );

  // Re-run the redirect whenever the auth stream emits, so signing out kicks
  // the user back to the login screen instead of leaving them on a page whose
  // Firestore reads are about to be denied.
  ref.listen(authUserProvider, (
    AsyncValue<Object?>? _,
    AsyncValue<Object?>? _,
  ) {
    router.refresh();
  });

  ref.onDispose(router.dispose);
  return router;
});
