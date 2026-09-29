import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_enums.dart';
import '../../../models/store_model.dart';
import '../../../models/user_model.dart';

class AdminRepository {
  AdminRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<StoreModel>> listStores() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('stores')
        .limit(200)
        .get();
    final List<StoreModel> stores = snapshot.docs
        .map((doc) => StoreModel.fromFirestore(doc.id, doc.data()))
        .toList();
    stores.sort((StoreModel a, StoreModel b) => a.name.compareTo(b.name));
    return stores;
  }

  Future<List<UserModel>> listUsers() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .limit(200)
        .get();
    final List<UserModel> users = snapshot.docs
        .map((doc) => UserModel.fromFirestore(doc.id, doc.data()))
        .toList();
    users.sort(
      (UserModel a, UserModel b) => a.displayName.compareTo(b.displayName),
    );
    return users;
  }

  Future<List<AdminAffiliateRecord>> listAffiliates() async {
    final List<QuerySnapshot<Map<String, dynamic>>> snapshots =
        await Future.wait(<Future<QuerySnapshot<Map<String, dynamic>>>>[
          _firestore
              .collection('users')
              .where('roles', arrayContains: UserRole.affiliate.value)
              .limit(200)
              .get(),
          _firestore.collection('affiliate_links').limit(500).get(),
          _firestore.collection('affiliate_commissions').limit(500).get(),
        ]);

    final Map<String, int> linksByAffiliate = <String, int>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshots[1].docs) {
      final String? uid = doc.data()['affiliateUid'] as String?;
      if (uid != null) {
        linksByAffiliate.update(
          uid,
          (int count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final Map<String, int> commissionsByAffiliate = <String, int>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshots[2].docs) {
      final String? uid = doc.data()['affiliateUid'] as String?;
      if (uid != null) {
        commissionsByAffiliate.update(
          uid,
          (int count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final List<AdminAffiliateRecord> records = snapshots[0].docs.map((doc) {
      final UserModel user = UserModel.fromFirestore(doc.id, doc.data());
      return AdminAffiliateRecord(
        user: user,
        linkCount: linksByAffiliate[user.uid] ?? 0,
        commissionCount: commissionsByAffiliate[user.uid] ?? 0,
      );
    }).toList();
    records.sort(
      (AdminAffiliateRecord a, AdminAffiliateRecord b) =>
          a.user.displayName.compareTo(b.user.displayName),
    );
    return records;
  }

  Future<void> updateStoreBasics({
    required StoreModel store,
    required String name,
    required String province,
    required String region,
    required String community,
    required String description,
  }) async {
    final String cleanName = name.trim();
    final String cleanProvince = province.trim();
    if (cleanName.isEmpty || cleanProvince.isEmpty) {
      throw ArgumentError('กรุณากรอกชื่อร้านและจังหวัด');
    }

    await _firestore
        .collection('stores')
        .doc(store.id)
        .update(<String, dynamic>{
          'name': cleanName,
          'province': cleanProvince,
          'region': region,
          'community': community.trim(),
          'description': description.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> updateUserBasics({
    required UserModel user,
    required String displayName,
    required String phone,
    required String province,
    required List<UserRole> roles,
  }) async {
    final String cleanName = displayName.trim();
    final List<UserRole> cleanRoles = roles.toSet().toList()
      ..sort((UserRole a, UserRole b) => a.index.compareTo(b.index));
    if (cleanName.isEmpty || cleanRoles.isEmpty) {
      throw ArgumentError('กรุณากรอกชื่อและเลือกอย่างน้อยหนึ่งบทบาท');
    }
    if (cleanRoles.contains(UserRole.admin) != user.isAdmin) {
      throw ArgumentError('ไม่สามารถเปลี่ยนบทบาทผู้ดูแลระบบได้');
    }

    await _firestore.collection('users').doc(user.uid).update(<String, dynamic>{
      'displayName': cleanName,
      'phone': phone.trim(),
      'province': province.trim(),
      'roles': cleanRoles.map((UserRole role) => role.value).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class AdminAffiliateRecord {
  const AdminAffiliateRecord({
    required this.user,
    required this.linkCount,
    required this.commissionCount,
  });

  final UserModel user;
  final int linkCount;
  final int commissionCount;
}
