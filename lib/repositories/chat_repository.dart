import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_message_model.dart';
import '../models/chat_thread_model.dart';

/// Reads and writes conversations, shaped by `firestore.rules`:
///
///  * a thread may only be created with the creator inside `participantUids`
///    and `lastAt == request.time` — hence [FieldValue.serverTimestamp], which
///    only the server can produce;
///  * a message may only be created by a room participant with
///    `senderUid == auth.uid` and `createdAt == request.time`;
///  * a thread may only be *updated* across `lastMessage / lastAt /
///    unreadByBuyer / unreadBySeller`, which is exactly what this repository
///    writes when a message lands or the recipient opens the room;
///  * messages are immutable once written.
///
/// The thread list read needs the `where('participantUids', arrayContains: uid)`
/// clause to satisfy `isParticipant()` against the query's potential result set
/// (same reasoning as the seller order inbox); the composite index it uses
/// (`participantUids` CONTAINS + `lastAt` DESC) is declared in
/// `firestore.indexes.json` and deployed.
/// สร้าง/เปิดห้องแชท ส่งข้อความ และนับข้อความที่ยังไม่อ่าน
class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const String _threads = 'chat_threads';

  String get _uid {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw const ChatWriteException('ยังไม่ได้เข้าสู่ระบบ');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _threadsCol =>
      _firestore.collection(_threads);

  CollectionReference<Map<String, dynamic>> _messagesCol(String threadId) =>
      _firestore.collection('$_threads/$threadId/messages');

  /// รายการห้องแชทของผู้ใช้ที่ล็อกอิน เรียงข้อความล่าสุดก่อน
  Stream<List<ChatThreadModel>> watchMyThreads() {
    return _threadsCol
        .where('participantUids', arrayContains: _uid)
        .orderBy('lastAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    ChatThreadModel.fromFirestore(d.id, d.data()),
              )
              .toList(growable: false),
        );
  }

  /// เฝ้าดูเอกสารห้องเดียวแบบสด (คืน `null` ถ้ายังไม่มีเอกสาร)
  Stream<ChatThreadModel?> watchThread(String threadId) {
    return _threadsCol.doc(threadId).snapshots().map((snap) {
      final Map<String, dynamic>? data = snap.data();
      if (data == null) return null;
      return ChatThreadModel.fromFirestore(snap.id, data);
    });
  }

  Stream<List<ChatMessageModel>> watchMessages(String threadId) {
    // ต้องมี `where('participantUids', arrayContains: _uid)` เช่นเดียวกับ threads:
    // rules `messages.allow list` อ้าง per-doc ทำให้ query ที่ไม่จำกัดฟิลด์นั้น
    // ถูกประเมินกับเอกสารตัวอย่างที่ไม่มีฟิลด์ → deny ทั้ง query (Bug #26)
    // งด orderBy('createdAt') เพื่อไม่ต้องใช้ composite index เพิ่ม (array-contains
    // + ฟิลด์อื่น = index ใหม่) จึง sort เรียงเวลาใน Dart — ข้อความต่อห้องไม่มาก
    return _messagesCol(threadId)
        .where('participantUids', arrayContains: _uid)
        .limit(200)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
          final List<ChatMessageModel> messages = snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    ChatMessageModel.fromFirestore(d.id, d.data()),
              )
              .toList(growable: false);
          messages.sort((ChatMessageModel a, ChatMessageModel b) =>
              a.createdAt.compareTo(b.createdAt));
          return messages;
        });
  }

  /// Returns the id of the buyer's room with [storeId], creating one when none
  /// exists yet.
  ///
  /// The lookup filters the buyer's own threads in Dart instead of pushing the
  /// whole match into the query, because `buyerUid + storeId + participantUids`
  /// would need yet another composite index for a check that is rare (one room
  /// per store). Reusing an existing thread keeps a buyer who taps twice from
  /// splitting the conversation across two rooms.
  /// หาว่ามีห้องคุยกับร้านนี้อยู่แล้วหรือยัง ถ้ายังไม่มีก็สร้างห้องใหม่
  Future<String> getOrCreateThread({
    required String storeId,
    required String sellerUid,
    required String storeName,
  }) async {
    final String myUid = _uid;

    final QuerySnapshot<Map<String, dynamic>> mine = await _threadsCol
        .where('participantUids', arrayContains: myUid)
        .limit(100)
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> d in mine.docs) {
      final Map<String, dynamic> data = d.data();
      if (data['storeId'] == storeId && data['buyerUid'] == myUid) {
        return d.id;
      }
    }

    final DocumentReference<Map<String, dynamic>> ref = _threadsCol.doc();
    // `lastAt` must equal `request.time` or the rules reject the create.
    await ref.set(<String, dynamic>{
      'participantUids': <String>[myUid, sellerUid],
      'storeId': storeId,
      'storeName': storeName,
      'buyerUid': myUid,
      'sellerUid': sellerUid,
      'lastMessage': '',
      'unreadByBuyer': 0,
      'unreadBySeller': 0,
      'lastAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// เพิ่มข้อความใหม่ และบันทึกลง thread ในคอมมิตเดียวกันเพื่อให้ปลายทางเห็น
  /// ตัวนับยังไม่อ่านจะเพิ่มฝั่ง "ตรงข้าม" กับผู้ส่ง
  ///
  /// เขียนเป็น batch เดียว เพื่อไม่ให้ข้อความถูกส่งแต่ตัวอย่างใน thread ไม่ตรง
  /// หรือตัวอย่างชี้ไปที่ไม่มีอยู่
  Future<void> sendMessage({
    required String threadId,
    required String text,
  }) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const ChatWriteException('พิมพ์ข้อความก่อนส่ง');
    }

    final String myUid = _uid;
    final DocumentSnapshot<Map<String, dynamic>> snap = await _threadsCol
        .doc(threadId)
        .get();
    final Map<String, dynamic>? data = snap.data();
    if (data == null) {
      throw const ChatWriteException('ไม่พบห้องแชทนี้');
    }
    final bool iAmBuyer = data['buyerUid'] == myUid;

    // `participantUids` ถูกเขียนซ้ำลงข้อความทุกฉบับ (denormalize) เพราะ rules
    // ฝั่ง `messages.allow list` ห้าม get() กลับไปที่ thread ต้องตรวจจาก
    // resource.data ของ message เอง — ดู firestore.rules (Bug #26)
    final List<String> room = (data['participantUids'] as List<Object?>?)
            ?.whereType<String>()
            .toList(growable: false) ??
        const <String>[];

    final WriteBatch batch = _firestore.batch();
    batch.set(_messagesCol(threadId).doc(), <String, dynamic>{
      'senderUid': myUid,
      'senderName': _auth.currentUser?.displayName ?? '',
      'type': 'text',
      'text': trimmed,
      'participantUids': room,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(
      _threadsCol.doc(threadId),
      <String, dynamic>{
        'lastMessage': trimmed,
        'lastAt': FieldValue.serverTimestamp(),
        if (iAmBuyer) 'unreadBySeller': FieldValue.increment(1)
        else 'unreadByBuyer': FieldValue.increment(1),
      },
    );
    await batch.commit();
  }

  /// เคลียร์ตัวนับยังไม่อ่านของฝั่งผู้เรียก — เรียกตอนเปิดห้อง
  ///
  /// ตั้งใจล้างแบบไม่มีเงื่อนไข (ไม่สนว่าข้อความล่าสุดใครส่ง) เพราะตอนนี้ผู้เรียก
  /// กำลังเปิดดูห้องอยู่จริง และตัวนับนับเฉพาะข้อความที่ยังไม่ได้เห็น
  Future<void> markThreadRead(String threadId) async {
    final String myUid = _uid;
    final DocumentSnapshot<Map<String, dynamic>> snap = await _threadsCol
        .doc(threadId)
        .get();
    final Map<String, dynamic>? data = snap.data();
    if (data == null) return;

    final bool iAmBuyer = data['buyerUid'] == myUid;
    final String field = iAmBuyer ? 'unreadByBuyer' : 'unreadBySeller';
    if ((data[field] as num? ?? 0) <= 0) return;

    // Increment-free: any value is allowed, so 0 is valid.
    await _threadsCol.doc(threadId).update(<String, dynamic>{field: 0});
  }
}

/// ข้อผิดพลาดที่ควรบอกผู้ใช้ (ไม่ใช่ crash)
class ChatWriteException implements Exception {
  const ChatWriteException(this.message);

  final String message;

  @override
  String toString() => message;
}