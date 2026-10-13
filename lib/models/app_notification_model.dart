import 'package:flutter/material.dart';

import '../core/constants/app_enums.dart';
import 'firestore_codec.dart';

/// A single in-app notification from `notifications/{notificationId}`.
///
/// Kept deliberately small: unlike chat or orders there is no nested history,
/// just a headline, a body and a link back to whatever produced it (an order or
/// a chat thread). `firestore.rules` only lets the owner read/update/delete
/// theirs, and only lets the counterparty create one — see the `notifications`
/// block in `firestore.rules`.
class AppNotificationModel {
  const AppNotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.orderId,
    this.threadId,
    this.read = false,
    this.readAt,
  });

  final String id;

  /// Who this notification is for — the receiver, not the author.
  final String userId;

  final NotificationType type;
  final String title;
  final String body;

  /// The entity that produced it, so tapping the row can deep-link back.
  final String? orderId;
  final String? threadId;

  final bool read;
  final DateTime? readAt;
  final DateTime createdAt;

  factory AppNotificationModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final FirestoreReader r = FirestoreReader(data);
    return AppNotificationModel(
      id: id,
      userId: r.string('userId'),
      type: NotificationType.fromValue(r.string('type')),
      title: r.string('title'),
      body: r.string('body', fallback: ''),
      orderId: r.stringOrNull('orderId'),
      threadId: r.stringOrNull('threadId'),
      read: r.boolean('read'),
      readAt: r.dateTime('readAt'),
      createdAt: r.dateTimeOr(
        'createdAt',
        DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
  }

  /// The icon the list shows for this notification.
  IconData iconFor() => switch (type) {
    NotificationType.orderStatus => Icons.receipt_long_outlined,
    NotificationType.newMessage => Icons.chat_bubble_outline_rounded,
    NotificationType.promotion => Icons.local_offer_outlined,
    NotificationType.reviewReply => Icons.rate_review_outlined,
    NotificationType.system => Icons.notifications_outlined,
  };
}