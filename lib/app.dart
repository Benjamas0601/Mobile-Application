import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/firebase_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'widgets/bootstrap_gate.dart';

/// Root widget.
///
/// Keeps three concerns separate on purpose:
///  1. localisations  — Thai is the primary language
///  2. theme          — light + dark from the design tokens
///  3. startup gate   — blocks the app with a readable message if Firebase
///                      could not start, so we never render a white screen
class ThaiOtopApp extends ConsumerWidget {
  const ThaiOtopApp({super.key, required this.startup});

  final FirebaseStartupResult startup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching the router provider rebuilds navigation when the auth stream
    // changes, which is what keeps the redirect honest after sign-out.
    final GoRouter router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Thai OTOP Marketplace',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,

      // Thai-first: `th` is the fallback so a device set to English still
      // shows Thai product content correctly rather than falling back to
      // an English-only date/number format.
      locale: const Locale('th', 'TH'),
      supportedLocales: const <Locale>[Locale('th', 'TH'), Locale('en', 'US')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      routerConfig: router,

      builder: (BuildContext context, Widget? child) {
        return BootstrapGate(startup: startup, child: child);
      },
    );
  }
}
