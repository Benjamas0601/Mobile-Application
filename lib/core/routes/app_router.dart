import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/screens/admin_home_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/cart/screens/cart_screen.dart';
import '../../features/cart/screens/checkout_screen.dart';
import '../../features/cart/screens/payment_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/orders/screens/order_detail_screen.dart';
import '../../features/orders/screens/order_list_screen.dart';
import '../../features/orders/screens/order_tracking_screen.dart';
import '../../features/products/screens/product_detail_screen.dart';
import '../../features/seller/screens/product_edit_screen.dart';
import '../../features/seller/screens/seller_home_screen.dart';
import '../../features/seller/screens/seller_order_list_screen.dart';
import '../../features/seller/screens/seller_product_list_screen.dart';
import '../../features/seller/screens/seller_store_edit_screen.dart';
import '../../features/stores/screens/stores_screen.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';

/// Every route path lives here as a constant.
///
/// Two reasons: no typo'd string literals scattered through the app, and the
/// navigation map can be read in one place during the demo.
/// รวม path และกติกา redirect เพื่อควบคุมสิทธิ์เข้าถึงแต่ละหน้าจอ
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String stores = '/stores';
  static const String orders = '/orders';
  static const String ordersHistory = '/order-history';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String payment = '/checkout/payment';
  static const String profile = '/profile';
  static const String adminRoot = '/admin';

  /// Seller console root — every `/seller/...` route is account-bound.
  static const String sellerRoot = '/seller';
  static const String sellerProducts = '/seller/products';
  static const String sellerOrders = '/seller/orders';
  static const String sellerStoreProfile = '/seller/store';

  /// Takes the product id as a path parameter: `/product/p-silk-scarf-red`.
  static String productDetail(String productId) => '/product/$productId';

  /// Takes the order id: `/order/abc123`.
  static String orderDetail(String orderId) => '/order/$orderId';

  /// The post-checkout destination focused on live fulfilment status.
  static String orderTracking(String orderId) => '/order/$orderId/tracking';

  /// Create form for one store: `/seller/products/new?storeId=store-singthai`.
  static String sellerProductNew(String storeId) =>
      '/seller/products/new?storeId=$storeId';

  /// Edit form for one product: `/seller/products/p-xyz`.
  static String sellerProductEdit(String productId) =>
      '/seller/products/$productId';
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
String? authRedirect({
  required bool signedIn,
  required String location,
  UserModel? user,
}) {
  // Checkout is deliberately absent: it renders its own gate so the guest sees
  // the choice (sign in / register / keep shopping) instead of a bare redirect,
  // and so signing in can resume it without a redirect race against the auth
  // stream. Guarding it here would also bounce the user straight back to login
  // while the profile is still loading.
  // The seller console is covered by the prefix check below, so it is absent
  // here on purpose — one list of account-required paths, and one prefix rule
  // that cannot be forgotten when a new `/seller/...` screen is added.
  const Set<String> accountRequired = <String>{
    AppRoutes.orders,
    AppRoutes.ordersHistory,
    AppRoutes.profile,
  };
  final bool isOrderRoute = location.startsWith('/order/');

  // Path-parameter routes (e.g. `/seller/products/p-x`) arrive here with the
  // real id substituted, so membership in the set above is not enough — check
  // the whole seller console by prefix.
  final bool isSellerRoute =
      location.startsWith('${AppRoutes.sellerRoot}/') ||
      location == AppRoutes.sellerRoot;
  final bool isAdminRoute =
      location == AppRoutes.adminRoot ||
      location.startsWith('${AppRoutes.adminRoot}/');

  if (isAdminRoute && user?.isAdmin != true) {
    return signedIn ? AppRoutes.home : '${AppRoutes.login}?redirect=$location';
  }

  if (!signedIn) {
    if (!accountRequired.contains(location) &&
        !isSellerRoute &&
        !isOrderRoute) {
      return null;
    }
    // Hand the destination to the login screen as `redirect` so signing in
    // resumes the original flow instead of dumping the user on Home.
    return '${AppRoutes.login}?redirect=$location';
  }

  // When signed in as a Seller or Admin, navigating to /home, /login, or /register
  // redirects directly to Seller Dashboard.
  if (user?.isAdmin == true &&
      (location == AppRoutes.home ||
          location == AppRoutes.login ||
          location == AppRoutes.register)) {
    return AppRoutes.adminRoot;
  }

  if (user?.isSeller == true) {
    if (location == AppRoutes.home ||
        location == AppRoutes.login ||
        location == AppRoutes.register) {
      return AppRoutes.sellerRoot;
    }
  }

  return null;
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
      user: ref.read(authUserProvider).asData?.value,
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
        path: AppRoutes.adminRoot,
        builder: (BuildContext context, GoRouterState state) =>
            const AdminHomeScreen(),
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
        path: '/order/:orderId/tracking',
        builder: (BuildContext context, GoRouterState state) =>
            OrderTrackingScreen(orderId: state.pathParameters['orderId'] ?? ''),
      ),
      GoRoute(
        path: '/order/:orderId',
        builder: (BuildContext context, GoRouterState state) =>
            OrderDetailScreen(orderId: state.pathParameters['orderId'] ?? ''),
      ),
      // Seller console: account-bound (redirect above) and role-gated inside
      // the screens, because a role lives in Firestore, not in the route.
      GoRoute(
        path: AppRoutes.sellerRoot,
        builder: (BuildContext context, GoRouterState state) =>
            const SellerHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.sellerOrders,
        builder: (BuildContext context, GoRouterState state) =>
            const SellerOrderListScreen(),
      ),
      GoRoute(
        path: AppRoutes.sellerStoreProfile,
        builder: (BuildContext context, GoRouterState state) =>
            const SellerStoreEditScreen(),
      ),
      GoRoute(
        path: AppRoutes.sellerProducts,
        builder: (BuildContext context, GoRouterState state) =>
            const SellerProductListScreen(),
      ),
      GoRoute(
        path: '/seller/products/new',
        builder: (BuildContext context, GoRouterState state) =>
            ProductEditScreen(storeId: state.uri.queryParameters['storeId']),
      ),
      GoRoute(
        path: '/seller/products/:productId',
        builder: (BuildContext context, GoRouterState state) =>
            ProductEditScreen(
              productId: state.pathParameters['productId'] ?? '',
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
