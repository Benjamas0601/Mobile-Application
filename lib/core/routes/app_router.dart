import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';

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
  static const String orders = '/orders';
  static const String cart = '/cart';
  static const String profile = '/profile';
}

/// Root router.
///
/// WEEK 2 STATE: only the auth entry point is wired. The remaining routes are
/// registered in Week 3 (Auth) and Week 4 (Explore / Cart / Orders) as their
/// screens are built, so we never register a route that renders a blank page.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.login,
  routes: <RouteBase>[
    GoRoute(
      path: AppRoutes.login,
      builder: (BuildContext context, GoRouterState state) => const LoginScreen(),
    ),
  ],
);
