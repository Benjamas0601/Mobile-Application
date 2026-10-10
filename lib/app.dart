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
/// ประกอบ router, theme และหน้ารอ Firebase ให้เป็นแอปเดียว
class ThaiOtopApp extends StatefulWidget {
  const ThaiOtopApp({super.key, required this.startup});

  final Future<FirebaseStartupResult> startup;

  @override
  State<ThaiOtopApp> createState() => _ThaiOtopAppState();
}

class _ThaiOtopAppState extends State<ThaiOtopApp> {
  late Future<FirebaseStartupResult> _startup;

  @override
  void initState() {
    super.initState();
    _startup = widget.startup;
  }

  void _retry() {
    setState(() {
      _startup = FirebaseBootstrap.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseStartupResult>(
      future: _startup,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<FirebaseStartupResult> snapshot,
          ) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _StartupStatusApp();
            }

            final FirebaseStartupResult? result = snapshot.data;
            if (result is FirebaseReady) {
              return _ReadyThaiOtopApp(startup: result);
            }

            return _StartupStatusApp(
              startup:
                  result ??
                  FirebaseUnavailable(
                    snapshot.error?.toString() ?? 'ไม่สามารถเริ่มต้นแอปได้',
                  ),
              onRetry: _retry,
            );
          },
    );
  }
}

class _StartupStatusApp extends StatelessWidget {
  const _StartupStatusApp({this.startup, this.onRetry});

  final FirebaseStartupResult? startup;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final Widget home = startup == null
        ? const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('กำลังเตรียมแอป...'),
                ],
              ),
            ),
          )
        : BootstrapGate(startup: startup!, child: null, onRetry: onRetry);

    return MaterialApp(
      title: 'Thai OTOP Marketplace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      locale: const Locale('th', 'TH'),
      supportedLocales: const <Locale>[Locale('th', 'TH'), Locale('en', 'US')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );
  }
}

class _ReadyThaiOtopApp extends ConsumerWidget {
  const _ReadyThaiOtopApp({required this.startup});

  final FirebaseStartupResult startup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
