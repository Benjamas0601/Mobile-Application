import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_enums.dart';
import '../models/app_notification_model.dart';

/// Reads, writes and acknowledges the signed-in user's notifications.
///
/// The writes here mirror `firestore.rules`:
///
///  * create is only allowed for the *counterparty* — the other side of an
///    order or a chat thread — never for arbitrary administration;
///  * update is restricted to the owner flipping `read` / `readAt`;
///  * delete is the owner's way of cleaning up.
///
/// The list is sorted in Dart instead of `orderBy` so the `userId` query does
/// not need a composite index (the same trade the seller order inbox makes).
class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const String _notifications = 'notifications';

  String get _uid {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw const NotificationWriteException('ยังไม่ได้เข้าสู่ระบบ');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _col => _firestore.collection(
    _notifications,
  );

  /// The signed-in user's notifications, newest first.
  Stream<List<AppNotificationModel>> watchMine() {
    return _col
        .where('userId', isEqualTo: _uid)
        .limit(50)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
          final List<AppNotificationModel> items = snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    AppNotificationModel.fromFirestore(d.id, d.data()),
              )
              .toList(growable: false);
          items.sort((AppNotificationModel a, AppNotificationModel b) {
            final int byTime = b.createdAt.compareTo(a.createdAt);
            return byTime != 0 ? byTime : a.id.compareTo(b.id);
          });
          return items;
        });
  }

  /// Marks one notification as read; a no-op when it already is.
  Future<void> markRead(String notificationId) async {
    final DocumentSnapshot<Map<String, dynamic>> snap = await _col
        .doc(notificationId)
        .get();
    final Map<String, dynamic>? data = snap.data();
    if (data == null || data['read'] == true) return;
    await _col.doc(notificationId).update(<String, dynamic>{
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  /// Marks a batch read in one commit.
  Future<void> markAllRead(Iterable<String> ids) async {
    final List<String> pending = ids.toList(growable: false);
    if (pending.isEmpty) return;
    final WriteBatch batch = _firestore.batch();
    for (final String id in pending) {
      final DocumentReference<Map<String, dynamic>> ref = _col.doc(id);
      batch.update(ref, <String, dynamic>{
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Creates a notification *for [userId]*, as the current user.
  ///
  /// Callers are the order flow (notifies the seller of a new order / the buyer
  /// of a status change) and chat (notifies the other participant). The rules
  /// check the caller is genuinely the counterparty of [orderId] / [threadId],
  /// so this method can never craft a notification addressed anywhere else.
  Future<void> create({
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    String? orderId,
    String? threadId,
  }) async {
    await _col.add(<String, dynamic>{
      'userId': userId,
      'type': type.value,
      'title': title,
      'body': body,
      'read': false,
      if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
      if (threadId != null && threadId.isNotEmpty) 'threadId': threadId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

/// A failure worth showing the user, as opposed to a crash.
class NotificationWriteException implements Exception {
  const NotificationWriteException(this.message);

  final String message;

  @override
  String toString() => message;
}