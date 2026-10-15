import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_otop_marketplace/core/constants/app_enums.dart';
import 'package:thai_otop_marketplace/models/chat_message_model.dart';
import 'package:thai_otop_marketplace/models/chat_thread_model.dart';
import 'package:thai_otop_marketplace/providers/chat_provider.dart';
import 'package:thai_otop_marketplace/repositories/chat_repository.dart';

/// Firestore จำลองที่บันทึกว่าแชทสั่งให้ทำอะไร — ใช้ท่า fake-repository
/// เดียวกับเทสต์ของผู้ขายและออเดอร์
class _FakeChatRepository implements ChatRepository {
  final List<({String threadId, String text, String? imageUrl})> sent =
      <({String threadId, String text, String? imageUrl})>[];
  final List<String> markedRead = <String>[];

  /// เมื่อตั้งค่า `sendMessage` จะรอจนกว่าจะปลด — เทสต์ busy-guard จะยิง send
  /// ครั้งที่สองขณะครั้งแรกยังไม่เสร็จ
  Completer<void>? holdSend;

  /// เมื่อตั้งค่า การเขียนครั้งถัดไปจะ throw (สิทธิ์ถูกปฏิเสธ, โควตาเต็ม)
  Object? failWith;

  @override
  Future<String> getOrCreateThread({
    required String storeId,
    required String sellerUid,
    required String storeName,
  }) async =>
      'thread-existing';

  @override
  Future<void> markThreadRead(String threadId) async => markedRead.add(threadId);

  @override
  Future<void> sendMessage({
    required String threadId,
    required String text,
    String? imageUrl,
  }) async {
    if (failWith != null) throw failWith!;
    await holdSend?.future;
    sent.add((threadId: threadId, text: text, imageUrl: imageUrl));
  }

  @override
  Stream<List<ChatThreadModel>> watchMyThreads() =>
      const Stream<List<ChatThreadModel>>.empty();

  @override
  Stream<ChatThreadModel?> watchThread(String threadId) =>
      const Stream<ChatThreadModel?>.empty();

  @override
  Stream<List<ChatMessageModel>> watchMessages(String threadId) =>
      const Stream<List<ChatMessageModel>>.empty();
}

void main() {
  group('ChatThreadModel', () {
    test('fromFirestore parses every field, unread defaulting to zero', () {
      final ChatThreadModel thread = ChatThreadModel.fromFirestore(
        't1',
        <String, dynamic>{
          'participantUids': <String>['u1', 's1'],
          'storeId': 'store-singthai',
          'storeName': 'ชิงไทย ผ้าไหมและของดีล้านนา',
          'buyerUid': 'u1',
          'sellerUid': 's1',
          'lastMessage': 'สวัสดีครับ',
        },
      );

      expect(thread.id, 't1');
      expect(thread.buyerUid, 'u1');
      expect(thread.sellerUid, 's1');
      expect(thread.participantUids, containsAll(<String>['u1', 's1']));
      expect(thread.lastMessage, 'สวัสดีครับ');
      expect(thread.unreadFor('u1'), 0);
      expect(thread.unreadFor('s1'), 0);
      expect(thread.hasUnreadFor('u1'), isFalse);
      // `lastAt` ที่หายไปจะ fallback เป็น epoch แทนที่จะ crash
      expect(thread.lastAt, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('unread is per-role and decays to "read" once cleared', () {
      final ChatThreadModel thread = ChatThreadModel.fromFirestore(
        't1',
        <String, dynamic>{
          'participantUids': <String>['u1', 's1'],
          'storeId': 'store-singthai',
          'buyerUid': 'u1',
          'sellerUid': 's1',
          'unreadByBuyer': 2,
          'unreadBySeller': 0,
        },
      );

      expect(thread.unreadFor('u1'), 2);
      expect(thread.unreadFor('s1'), 0);
      expect(thread.hasUnreadFor('u1'), isTrue);
      expect(thread.hasUnreadFor('s1'), isFalse);
    });
  });

  group('ChatMessageModel', () {
    test('fromFirestore parses text, type and timestamps', () {
      final ChatMessageModel message = ChatMessageModel.fromFirestore(
        'm1',
        <String, dynamic>{
          'threadId': 't1',
          'senderUid': 'u1',
          'senderName': 'ณัฐวุฒิ วัฒนกิจ',
          'type': 'text',
          'text': 'สินค้ามีของไหมครับ',
        },
        threadId: 't1',
      );

      expect(message.senderUid, 'u1');
      expect(message.senderName, 'ณัฐวุฒิ วัฒนกิจ');
      expect(message.type, MessageType.text);
      expect(message.isMine('u1'), isTrue);
      expect(message.isMine('s1'), isFalse);
    });

    test('an unknown type falls back to text (rules allow only text today)', () {
      final ChatMessageModel message = ChatMessageModel.fromFirestore(
        'm1',
        <String, dynamic>{'senderUid': 'u1', 'type': 'voice'},
      );
      expect(message.type, MessageType.text);
    });

    test('an image message parses its url and optional caption', () {
      final ChatMessageModel message = ChatMessageModel.fromFirestore(
        'm2',
        <String, dynamic>{
          'senderUid': 'u1',
          'type': 'image',
          'text': 'ดูรุ่นนี้ได้ไหม',
          'imageUrl': 'https://res.cloudinary.com/demo/image/upload/v1/x.jpg',
        },
      );

      expect(message.type, MessageType.image);
      expect(message.typeLabel, 'รูปภาพ');
      expect(
        message.imageUrl,
        'https://res.cloudinary.com/demo/image/upload/v1/x.jpg',
      );
      expect(message.text, 'ดูรุ่นนี้ได้ไหม');
    });

    test('an image with no caption keeps an empty text', () {
      final ChatMessageModel message = ChatMessageModel.fromFirestore(
        'm3',
        <String, dynamic>{
          'senderUid': 'u1',
          'type': 'image',
          'imageUrl': 'https://res.cloudinary.com/demo/image/upload/v1/y.jpg',
        },
      );
      expect(message.type, MessageType.image);
      expect(message.text, isEmpty);
    });
  });

  group('SendChatMessageController', () {
    test('a second send while the first is in flight is refused', () async {
      final _FakeChatRepository repo = _FakeChatRepository();
      final Completer<void> hold = Completer<void>();
      repo.holdSend = hold;

      final ProviderContainer container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final SendChatMessageController controller =
          container.read(sendChatMessageProvider.notifier);

      final Future<bool> first = controller.send(
        threadId: 't1',
        text: 'สวัสดี',
      );
      // ปล่อยให้ guard พลิกเป็น busy ก่อนที่คำสั่งที่สองจะมาถึง
      await Future<void>.delayed(Duration.zero);

      final Future<bool> second = controller.send(
        threadId: 't1',
        text: 'ซ้ำซ้อน',
      );
      expect(await second, isFalse, reason: 'busy guard must reject the 2nd');

      hold.complete();
      expect(await first, isTrue);

      // repository เขียนเพียงบรรทัดแรกเท่านั้น
      expect(repo.sent.length, 1);
      expect(repo.sent.single.text, 'สวัสดี');
    });

    test('an empty or whitespace-only message is never sent', () async {
      final _FakeChatRepository repo = _FakeChatRepository();

      final ProviderContainer container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final SendChatMessageController controller =
          container.read(sendChatMessageProvider.notifier);

      expect(
        await controller.send(threadId: 't1', text: '   '),
        isFalse,
      );
      expect(
        await controller.send(threadId: 't1', text: ''),
        isFalse,
      );
      expect(repo.sent, isEmpty);
    });

    test('an image with no caption is allowed and reaches the repository', () async {
      final _FakeChatRepository repo = _FakeChatRepository();

      final ProviderContainer container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final SendChatMessageController controller =
          container.read(sendChatMessageProvider.notifier);

      // ข้อความว่างแต่มีรูป → ต้องส่งได้
      expect(
        await controller.send(
          threadId: 't1',
          text: '',
          imageUrl: 'https://res.cloudinary.com/demo/image/upload/v1/z.jpg',
        ),
        isTrue,
      );
      expect(repo.sent.length, 1);
      expect(repo.sent.single.imageUrl, isNotNull);
      expect(repo.sent.single.text, isEmpty);
    });

    test('a failed repository write is rethrown to the caller', () async {
      final _FakeChatRepository repo = _FakeChatRepository()
        ..failWith = const ChatWriteException('ไม่พบห้องแชทนี้');

      final ProviderContainer container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final SendChatMessageController controller =
          container.read(sendChatMessageProvider.notifier);

      await expectLater(
        controller.send(threadId: 't1', text: 'สวัสดี'),
        throwsA(isA<ChatWriteException>().having(
          (ChatWriteException e) => e.message,
          'message',
          'ไม่พบห้องแชทนี้',
        )),
      );
      // busy guard รีเซ็ตแม้ส่งพลาด เพื่อให้ลองใหม่ภายหลังได้
      expect(controller.state, isFalse);
    });
  });
}