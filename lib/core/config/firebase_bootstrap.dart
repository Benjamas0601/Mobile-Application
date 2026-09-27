import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

/// Outcome of starting Firebase.
///
/// Modelled as a result type instead of a bare `Future<void>` so the app can
/// render a helpful screen when Firebase is not configured yet, instead of
/// crashing on a white page. The brief requires every feature to handle
/// loading / success / empty / error — app startup is no different.
sealed class FirebaseStartupResult {
  const FirebaseStartupResult();
}

class FirebaseReady extends FirebaseStartupResult {
  const FirebaseReady();
}

class FirebaseUnavailable extends FirebaseStartupResult {
  const FirebaseUnavailable(this.reason, {this.isConfigurationMissing = false});

  /// Thai, user-readable explanation shown on the blocking screen.
  final String reason;

  /// True when the cause is simply "flutterfire configure has not run yet",
  /// which is a developer problem rather than a user problem.
  final bool isConfigurationMissing;
}

/// Starts Firebase exactly once and reports what happened.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool _initialised = false;

  static Future<FirebaseStartupResult> start() async {
    if (_initialised) return const FirebaseReady();

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initialised = true;
      return const FirebaseReady();
    } on FirebaseNotConfigured {
      return const FirebaseUnavailable(
        'ยังไม่ได้เชื่อมต่อ Firebase\n\n'
        'นักศึกษาต้องรันคำสั่ง:\n'
        'firebase login\n'
        'flutterfire configure --project=thaiotop-587f1 \\\n'
        '    --options-file=lib/core/config/firebase_options.dart',
        isConfigurationMissing: true,
      );
    } catch (error) {
      return FirebaseUnavailable(
        'เชื่อมต่อ Firebase ไม่สำเร็จ\n\n${_describe(error)}',
      );
    }
  }

  /// Turns a raw exception into something a human can act on.
  static String _describe(Object error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => 'ไม่มีสิทธิ์เข้าถึง Firestore — ตรวจสอบ Security Rules',
        'unavailable' => 'เชื่อมต่อเซิร์ฟเวอร์ Firebase ไม่ได้ — ลองเช็คอินเทอร์เน็ต',
        'invalid-api-key' => 'API Key ไม่ถูกต้อง — ตรวจสอบไฟล์ firebase_options.dart',
        _ => '${error.code}: ${error.message ?? 'ไม่ทราบสาเหตุ'}',
      };
    }
    return error.toString();
  }
}
