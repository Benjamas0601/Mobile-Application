import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/firebase_bootstrap.dart';

/// จุดเริ่มต้นของแอป: เตรียม Flutter และ Firebase ก่อนแสดง UI
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final Future<FirebaseStartupResult> startup = FirebaseBootstrap.start();

  runApp(ProviderScope(child: ThaiOtopApp(startup: startup)));
}
