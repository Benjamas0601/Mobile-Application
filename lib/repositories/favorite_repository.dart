import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/firestore_codec.dart';

/// อ่าน/เขียนรายการสินค้าที่ผู้ซื้อกด "ถูกใจ"
///
/// เก็บหนึ่งเอกสารต่อ (ผู้ใช้, สินค้า) ที่ `favorites/{uid}_{productId}` — รหัส
/// เอกสารที่กำหนดได้เองทำให้การกดซ้ำเป็น idempotent: กดหัวใจสองครั้งก็ไม่เกิด
/// สองแถว และการยกเลิกถูกใจสินค้าที่ไม่เคยถูกใจก็เป็นเพียง delete ที่ไม่ผิดพลาด
/// `firestore.rules` อนุญาตให้เจ้าของอ่าน/เขียนได้เฉพาะแถวที่ `userId` ตรงกับ uid
class FavoriteRepository {
  FavoriteRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const String _favorites = 'favorites';

  /// จำนวนรายการถูกใจสูงสุดที่โหลดมาแสดง — มากพอต่อผู้ใช้ทั่วไป และกันไม่ให้
  /// อ่านทั้งคอลเลกชันโดยไม่ตั้งใจ
  static const int _maxFavorites = 100;

  /// uid ของผู้ใช้ที่ล็อกอินอยู่; โยน [FavoriteAuthException] เมื่อยังไม่ล็อกอิน
  /// เพราะไม่มีสิทธิ์แตะคอลเลกชันนี้
  String get _uid {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw const FavoriteAuthException();
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_favorites);

  String _docId(String uid, String productId) => '${uid}_$productId';

  /// รหัสสินค้าที่ผู้ใช้คนนี้กดถูกใจ เรียงจากใหม่ไปเก่า
  ///
  /// จัดเรียงใน Dart แทน `orderBy('createdAt')` เพื่อเลี่ยงการสร้าง composite
  /// index (where userId + orderBy createdAt) — จำนวนรายการถูกใจมีไม่มาก
  Stream<List<String>> watchMyFavoriteIds() {
    final String uid = _uid;
    return _collection
        .where('userId', isEqualTo: uid)
        .limit(_maxFavorites)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<MapEntry<DateTime, String>> rows = snapshot.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                final FirestoreReader reader = FirestoreReader(doc.data());
                return MapEntry(
                  reader.dateTimeOr(
                    'createdAt',
                    DateTime.fromMillisecondsSinceEpoch(0),
                  ),
                  reader.string('productId'),
                );
              })
              .where((MapEntry<DateTime, String> row) => row.value.isNotEmpty)
              .toList();

          rows.sort(
            (MapEntry<DateTime, String> a, MapEntry<DateTime, String> b) =>
                b.key.compareTo(a.key),
          );
          return rows
              .map((MapEntry<DateTime, String> row) => row.value)
              .toList(growable: false);
        });
  }

  /// บันทึกว่าผู้ใช้กดถูกใจ [productId]
  Future<void> add(String productId) async {
    final String uid = _uid;
    await _collection.doc(_docId(uid, productId)).set(<String, dynamic>{
      'userId': uid,
      'productId': productId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// ยกเลิกถูกใจ [productId]
  Future<void> remove(String productId) async {
    final String uid = _uid;
    await _collection.doc(_docId(uid, productId)).delete();
  }

  /// ตั้งค่าถูกใจตาม [favorite] — ให้ผู้เรียกไม่ต้องเลือก [add]/[remove] เอง
  Future<void> setFavorite(String productId, bool favorite) =>
      favorite ? add(productId) : remove(productId);
}

/// โยนเมื่อเรียกใช้คลังรายการถูกใจโดยที่ยังไม่ได้เข้าสู่ระบบ
class FavoriteAuthException implements Exception {
  const FavoriteAuthException([this.message = 'ยังไม่ได้เข้าสู่ระบบ']);

  final String message;

  @override
  String toString() => message;
}
