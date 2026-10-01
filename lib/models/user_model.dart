import '../core/constants/app_enums.dart';
import 'firestore_codec.dart';

/// A signed-in account, read from `users/{uid}`.
///
/// Roles live in Firestore (not in the Auth token) so a role change takes
/// effect on the next read instead of needing a token refresh.
/// โปรไฟล์ผู้ใช้และบทบาทที่อ่านจากเอกสาร `users/{uid}`
class UserModel {
  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.phone = '',
    this.province = '',
    this.affiliatePlatform = '',
    this.affiliateHandle = '',
    this.affiliateProfileUrl = '',
    this.avatarUrl,
    this.roles = const <UserRole>[],
  });

  final String uid;
  final String displayName;
  final String email;
  final String phone;
  final String province;
  final String affiliatePlatform;
  final String affiliateHandle;
  final String affiliateProfileUrl;
  final String? avatarUrl;
  final List<UserRole> roles;

  bool get isSeller => roles.contains(UserRole.seller);
  bool get isAdmin => roles.contains(UserRole.admin);
  bool get isAffiliate => roles.contains(UserRole.affiliate);

  /// First name only — used for a friendly greeting.
  String get shortName => displayName.split(' ').first;

  factory UserModel.fromFirestore(String uid, Map<String, dynamic> data) {
    final FirestoreReader r = FirestoreReader(data);
    return UserModel(
      uid: uid,
      displayName: r.string('displayName', fallback: 'ไม่ระบุชื่อ'),
      email: r.string('email'),
      phone: r.string('phone'),
      province: r.string('province'),
      affiliatePlatform: r.string('affiliatePlatform'),
      affiliateHandle: r.string('affiliateHandle'),
      affiliateProfileUrl: r.string('affiliateProfileUrl'),
      avatarUrl: r.stringOrNull('avatarUrl'),
      roles: r
          .stringList('roles')
          .map(UserRole.fromValue)
          .whereType<UserRole>()
          .toList(growable: false),
    );
  }
}
