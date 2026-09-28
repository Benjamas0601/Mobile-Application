import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_enums.dart';
import '../core/constants/app_strings.dart';
import '../models/user_model.dart';

/// Thrown by [AuthRepository] with a message already written for the user.
///
/// Firebase errors are English SDK codes (`invalid-email`, `wrong-password`),
/// which must never reach a Thai-first UI, so every failure crosses this
/// boundary as Thai text.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Signs in, registers, and loads the caller's profile document.
///
/// The Auth object owns the credential; this repository owns the
/// `users/{uid}` profile that the app actually reads. Keeping the two in step
/// here is what stops a signed-in user from having a null profile.
class AuthRepository {
  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? db})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  static const String _users = 'users';

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentAuthUser => _auth.currentUser;

  /// Returns null when signed out. A missing profile is *not* an error —
  /// a seeded or half-migrated account should still be able to browse.
  Future<UserModel?> loadUser(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _db
        .collection(_users)
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(uid, doc.data() ?? <String, dynamic>{});
  }

  /// Loads the profile for the currently signed-in user, or null.
  Future<UserModel?> loadCurrentUser() async {
    final User? user = _auth.currentUser;
    if (user == null) return null;
    return loadUser(user.uid);
  }

  /// Signs in and returns the profile.
  ///
  /// Throws [AuthFailure] with a Thai message on any failure.
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final UserModel? profile = await loadUser(credential.user!.uid);
      // Signing in without a profile is survivable — browsing is public — so
      // fall back to a profile built from the Auth token rather than failing.
      return profile ??
          UserModel(
            uid: credential.user!.uid,
            displayName:
                credential.user!.displayName ?? credential.user!.email ?? '',
            email: credential.user!.email ?? email.trim(),
          );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    } catch (e) {
      throw AuthFailure('เข้าสู่ระบบไม่สำเร็จ: $e');
    }
  }

  /// Creates the Auth account, then writes the `users/{uid}` profile.
  ///
  /// The document is written to match `firestore.rules` exactly: first role
  /// must be `customer`, email must equal the token email, and `createdAt`
  /// must be the server timestamp — otherwise the write is rejected.
  Future<UserModel> register({
    required String email,
    required String password,
    required String displayName,
    String phone = '',
    String province = '',
  }) async {
    final String cleanEmail = email.trim();
    try {
      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          );

      final String uid = credential.user!.uid;
      await credential.user!.updateDisplayName(displayName);

      final Map<String, dynamic> profile = <String, dynamic>{
        'displayName': displayName,
        'email': cleanEmail,
        'roles': <String>['customer'],
        'createdAt': FieldValue.serverTimestamp(),
        if (phone.isNotEmpty) 'phone': phone,
        if (province.isNotEmpty) 'province': province,
      };

      await _db.collection(_users).doc(uid).set(profile);

      return UserModel(
        uid: uid,
        displayName: displayName,
        email: cleanEmail,
        phone: phone,
        province: province,
        roles: const <UserRole>[UserRole.customer],
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    } on FirebaseException catch (e) {
      // The rules rejected the profile write — usually a rules/schema drift.
      throw AuthFailure('สมัครสมาชิกไม่สำเร็จ: ${e.message ?? e.code}');
    } catch (e) {
      throw AuthFailure('สมัครสมาชิกไม่สำเร็จ: $e');
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// Translates SDK codes into the wording in [AppStrings].
  static String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
      case 'invalid-credential':
        return AppStrings.errEmailFormat;
      case 'user-disabled':
        return 'บัญชีนี้ถูกปิดใช้งาน กรุณาติดต่อผู้ดูแล';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-login-credentials':
        return AppStrings.errInvalidCredentials;
      case 'email-already-in-use':
        return AppStrings.errEmailInUse;
      case 'weak-password':
        return 'รหัสผ่านอ่อนเกินไป กรุณาใช้อย่างน้อย 6 ตัวอักษร';
      case 'network-request-failed':
        return 'เชื่อมต่ออินเทอร์เน็ตไม่สำเร็จ กรุณาลองใหม่';
      case 'too-many-requests':
        return 'พยายามหลายครั้งเกินไป กรุณารอสักครู่แล้วลองใหม่';
      default:
        return e.message ?? AppStrings.errorBody;
    }
  }
}
