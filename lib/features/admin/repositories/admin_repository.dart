import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_enums.dart';
import '../../../models/store_model.dart';
import '../../../models/user_model.dart';

/// อ่านและแก้ข้อมูลระบบเฉพาะที่กฎ Firestore อนุญาตให้ผู้ดูแลจัดการ
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

  /// มุมมองสด (snapshot) ของร้านทุกร้าน เพื่อให้ร้านที่สมัครจากที่อื่นโผล่
  /// ทันทีโดยไม่ต้องรูดรีเฟรช [listStores] ตัวอ่านครั้งเดียวคงไว้ให้ผู้เรียก
  /// ที่ต้องการแค่ภาพนิ่ง
  Stream<List<StoreModel>> watchStores() {
    return _firestore
        .collection('stores')
        .limit(200)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<StoreModel> stores = snapshot.docs
              .map((doc) => StoreModel.fromFirestore(doc.id, doc.data()))
              .toList();
          stores.sort((StoreModel a, StoreModel b) => a.name.compareTo(b.name));
          return stores;
        });
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

  /// มุมมองสด (snapshot) ของผู้ใช้ทุกคน เพื่อให้บัญชีที่เพิ่งสมัครขึ้นในแท็บ
  /// ผู้ดูแลทันทีโดยไม่ต้องรีเฟรช
  Stream<List<UserModel>> watchUsers() {
    return _firestore
        .collection('users')
        .limit(200)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<UserModel> users = snapshot.docs
              .map((doc) => UserModel.fromFirestore(doc.id, doc.data()))
              .toList();
          users.sort(
            (UserModel a, UserModel b) => a.displayName.compareTo(b.displayName),
          );
          return users;
        });
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

  /// ลบร้านพร้อมทุกอย่างที่เป็นของร้าน ข้อมูลออเดอร์ฝังภาพนิ่งของสินค้าไว้
  /// เอง จึงอยู่รอดหลังถูกลบ — นี่คือเหตุผลที่ [firestore.rules] ให้ลบ
  /// เอกสารร้านได้เฉพาะ admin (`allow delete: if isAdmin();`)
  Future<void> deleteStore(String storeId) async {
    final List<DocumentReference> refs = <DocumentReference>[];

    final QuerySnapshot<Map<String, dynamic>> products = await _firestore
        .collection('products')
        .where('storeId', isEqualTo: storeId)
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> product in products.docs) {
      final QuerySnapshot<Map<String, dynamic>> variants = await _firestore
          .collection('product_variants')
          .where('productId', isEqualTo: product.id)
          .get();
      refs.addAll(variants.docs.map((d) => d.reference));

      final QuerySnapshot<Map<String, dynamic>> reviews = await _firestore
          .collection('reviews')
          .where('productId', isEqualTo: product.id)
          .get();
      refs.addAll(reviews.docs.map((d) => d.reference));

      refs.add(product.reference);
    }

    refs.add(_firestore.collection('stores').doc(storeId));
    await _deleteInBatches(refs);
  }

  /// ลบข้อมูลผู้ใช้และร้าน/สินค้าที่เป็นเจ้าของออกจาก Firestore (ใช้ได้บน
  /// แผนฟรี Spark)
  ///
  /// บัญชี Firebase Auth ของ *คนอื่น* ลบจาก client SDK ไม่ได้ — ต้องใช้ Cloud
  /// Function (Admin SDK; ต้องแผน Blaze) หรือลบใน Firebase Console ด้วยมือ
  /// หลังลบโพรไฟล์ไปแล้ว บัญชีที่เหลืออยู่จะถูกแอปมองว่า "ไม่ได้ล็อกอิน" ทันที
  ///
  /// ห้ามลบแอดมินและห้ามลบตัวเอง (ตรวจซ้ำที่ firestore.rules อีกชั้น)
  Future<void> deleteUser({
    required String uid,
    required String actingAdminUid,
  }) async {
    if (uid == actingAdminUid) {
      throw ArgumentError('ไม่สามารถลบบัญชีตัวเองได้');
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .get();
    if (!snapshot.exists) {
      throw StateError('ไม่พบผู้ใช้นี้ในระบบแล้ว');
    }
    final List<Object?> rawRoles = snapshot.data()?['roles'] is List
        ? (snapshot.data()?['roles'] as List<Object?>)
        : const <Object?>[];
    if (rawRoles.contains(UserRole.admin.value)) {
      throw ArgumentError('ไม่สามารถลบบัญชีผู้ดูแลระบบได้');
    }

    final QuerySnapshot<Map<String, dynamic>> stores = await _firestore
        .collection('stores')
        .where('ownerUid', isEqualTo: uid)
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> store in stores.docs) {
      await deleteStore(store.id);
    }

    await _firestore.collection('users').doc(uid).delete();
  }

  /// Firestore batches hold at most 500 writes; a store with many products
  /// can exceed that, so the refs are committed in chunks.
  Future<void> _deleteInBatches(List<DocumentReference> refs) async {
    const int chunk = 400;
    int offset = 0;
    while (offset < refs.length) {
      final WriteBatch batch = _firestore.batch();
      for (final DocumentReference ref in refs.skip(offset).take(chunk)) {
        batch.delete(ref);
      }
      await batch.commit();
      offset += chunk;
    }
  }
}
