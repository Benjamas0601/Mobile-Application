// PLACEHOLDER — this file is replaced automatically by FlutterFire CLI.
//
// Project: thaiotop-587f1
//
// To generate the real values (run from the project root):
//   firebase login
//   flutterfire configure --project=thaiotop-587f1 \
//       --options-file=lib/core/config/firebase_options.dart
//
// Until that runs, [currentPlatform] throws [FirebaseNotConfigured].
// That is deliberate: we never ship hard-coded API keys that look real but
// are not, and `FirebaseBootstrap` turns the throw into a readable error
// screen instead of a white screen.

import 'package:firebase_core/firebase_core.dart';

/// Thrown when the app starts before `flutterfire configure` has run.
class FirebaseNotConfigured implements Exception {
  const FirebaseNotConfigured();

  @override
  String toString() => 'Firebase ยังไม่ได้ตั้งค่า — กรุณารัน `flutterfire configure`';
}

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    throw const FirebaseNotConfigured();
  }
}
