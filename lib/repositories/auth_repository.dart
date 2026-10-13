import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_enums.dart';
import '../core/constants/app_strings.dart';
import '../models/user_model.dart';

//ไฟล์นี้เป็นตัวจัดการการยืนยันตัวตนของผู้ใช้ (Auth) โดยใช้ Firebase Auth และ Firestore เป็น backend
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
/// รวมการยืนยันตัวตนกับการอ่าน/สร้างโปรไฟล์ผู้ใช้ใน Firestore
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
      final User user = credential.user!;
      final UserModel? profile = await loadUser(user.uid);
      if (profile != null) return profile;

      // บัญชีที่เพิ่มผ่าน Firebase Console โดยตรง (เช่น gogo@mail.com) ไม่มี
      // โพรไฟล์ใน Firestore — สร้างให้อัตโนมัติตอนล็อกอินครั้งแรก ทำงานบน
      // บทบาทเป็น customer ธรรมดา และ firestore.rules ยืนยันอีกชั้นว่า
      // ตั้งเป็น admin ไม่ได้
      final String displayName =
          user.displayName ?? user.email ?? email.trim();
      final String profileEmail = user.email ?? email.trim();
      await _db.collection(_users).doc(user.uid).set(<String, dynamic>{
        'displayName': displayName,
        'email': profileEmail,
        'roles': <String>[UserRole.customer.value],
        'createdAt': FieldValue.serverTimestamp(),
        'phone': '',
        'province': '',
      });
      return UserModel(
        uid: user.uid,
        displayName: displayName,
        email: profileEmail,
        phone: '',
        province: '',
        roles: const <UserRole>[UserRole.customer],
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
    required String phone,
    required String province,
    required UserRole accountType,
    String storeName = '',
    String community = '',
    String storeDescription = '',
    String region = '',
  }) async {
    final String cleanEmail = email.trim();
    final String cleanName = displayName.trim();
    final String cleanPhone = phone.trim();
    final String cleanProvince = province.trim();
    // แอปสมัครสดได้เฉพาะ customer/seller เท่านั้น — ไม่มีทางขอ role admin
    // จากฝั่ง client (firestore.rules users.create จำกัด hasOnly อยู่อีกชั้นหนึ่ง)
    if (!<UserRole>{UserRole.customer, UserRole.seller}.contains(accountType)) {
      throw const AuthFailure('ประเภทบัญชีไม่ถูกต้อง');
    }
    if (cleanName.isEmpty || cleanPhone.isEmpty) {
      throw const AuthFailure('กรุณากรอกชื่อและเบอร์โทรให้ครบ');
    }
    if (accountType == UserRole.seller &&
        (cleanProvince.isEmpty ||
            storeName.trim().isEmpty ||
            community.trim().isEmpty ||
            storeDescription.trim().isEmpty ||
            ThaiRegion.fromValue(region) == null)) {
      throw const AuthFailure('กรุณากรอกข้อมูลร้านค้าให้ครบ');
    }

    User? createdUser;
    DocumentReference<Map<String, dynamic>>? profileRef;
    try {
      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          );

      final String uid = credential.user!.uid;
      createdUser = credential.user;
      await createdUser!.updateDisplayName(cleanName);

      final List<UserRole> roles = <UserRole>[
        UserRole.customer,
        if (accountType != UserRole.customer) accountType,
      ];

      final Map<String, dynamic> profile = <String, dynamic>{
        'displayName': cleanName,
        'email': cleanEmail,
        'roles': roles.map((UserRole role) => role.value).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'phone': cleanPhone,
        // ลูกค้าส่ง province เป็น '' (ไม่กรอก) — ยังต้องมีคีย์นี้เพราะ
        // firestore.rules users.create บังคับว่า province ต้องเป็น string
        'province': cleanProvince,
      };

      profileRef = _db.collection(_users).doc(uid);
      await profileRef.set(profile);

      if (accountType == UserRole.seller) {
        await _db.collection('stores').doc().set(<String, dynamic>{
          'ownerUid': uid,
          'name': storeName.trim(),
          'province': cleanProvince,
          'region': region,
          'community': community.trim(),
          'description': storeDescription.trim(),
          'coverImageUrl': '',
          'logoUrl': '',
          'otopCertified': false,
          'ratingAvg': 0.0,
          'ratingCount': 0,
          'commissionRate': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return UserModel(
        uid: uid,
        displayName: cleanName,
        email: cleanEmail,
        phone: cleanPhone,
        province: cleanProvince,
        roles: roles,
      );
    } on FirebaseAuthException catch (e) {
      await _rollbackRegistration(createdUser, profileRef);
      throw AuthFailure(_messageFor(e));
    } on FirebaseException catch (e) {
      await _rollbackRegistration(createdUser, profileRef);
      // The rules rejected the profile write — usually a rules/schema drift.
      throw AuthFailure('สมัครสมาชิกไม่สำเร็จ: ${e.message ?? e.code}');
    } catch (e) {
      await _rollbackRegistration(createdUser, profileRef);
      throw AuthFailure('สมัครสมาชิกไม่สำเร็จ: $e');
    }
  }

  Future<void> _rollbackRegistration(
    User? user,
    DocumentReference<Map<String, dynamic>>? profileRef,
  ) async {
    try {
      await profileRef?.delete();
    } catch (_) {}
    try {
      await user?.delete();
    } catch (_) {}
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// อัปเดตข้อมูลส่วนตัวที่ผู้ใช้แก้ได้เอง (ชื่อ / เบอร์โทร)
  ///
  /// สอดคล้องกับ `firestore.rules` `users.update` ที่ห้ามผู้ใช้แตะ
  /// `roles` / `email` / `createdAt` — ฟอร์มแก้โปรไฟล์จึงส่งเฉพาะฟิลด์ที่
  /// แก้ได้จริง ไม่งั้นกฎจะปฏิเสธทั้งเอกสาร (Firestore ส่งทั้งเอกสารไปตรวจ
  /// กับกฎเสมอ)
  Future<UserModel> updateProfile({
    required String displayName,
    required String phone,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('กรุณาเข้าสู่ระบบก่อนแก้ไขข้อมูล');
    }
    final String cleanName = displayName.trim();
    final String cleanPhone = phone.trim();
    if (cleanName.isEmpty || cleanPhone.isEmpty) {
      throw const AuthFailure('กรุณากรอกชื่อและเบอร์โทรให้ครบ');
    }

    try {
      await _db.collection(_users).doc(user.uid).update(<String, dynamic>{
        'displayName': cleanName,
        'phone': cleanPhone,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AuthFailure('บันทึกข้อมูลไม่สำเร็จ: ${e.message ?? e.code}');
    } catch (e) {
      throw AuthFailure('บันทึกข้อมูลไม่สำเร็จ: $e');
    }

    // คืนโปรไฟล์ล่าสุด เพื่อให้ผู้เรียกแสดงผลได้ทันทีโดยไม่ต้องอ่านรอบคืน;
    // ถ้าอ่านไม่เจอ (โพรไฟล์ถูกลบ) ให้ย้อนกลับไปใช้ค่าที่เพิ่งบันทึกแทน
    final UserModel? profile = await loadUser(user.uid);
    return profile ??
        UserModel(
          uid: user.uid,
          displayName: cleanName,
          email: user.email ?? '',
          phone: cleanPhone,
          province: '',
          roles: const <UserRole>[UserRole.customer],
        );
  }

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
