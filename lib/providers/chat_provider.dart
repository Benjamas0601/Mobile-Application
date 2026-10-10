import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message_model.dart';
import '../models/chat_thread_model.dart';
import '../repositories/chat_repository.dart';

/// Injected once and overridden in tests with a fake, so screens can be driven
/// without a live Firestore.
/// จุดฉีด ChatRepository สำหรับแยก UI ออกจาก Firebase และทดสอบด้วย fake
final Provider<ChatRepository> chatRepositoryProvider =
    Provider<ChatRepository>((Ref ref) => ChatRepository());

/// รายการห้องแชทของผู้ใช้ที่ล็อกอิน เรียงล่าสุดก่อน
///
/// ตั้งใจ *ไม่* ใช้ `autoDispose`: ป้ายข้อความยังไม่อ่านหรือไอคอนแชทของผู้ขาย
/// อาจต้องอ่านค่านี้ขณะอยู่หน้าอื่น ถ้าทิ้ง listener ข้อความที่เข้ามาจะไม่โผล่
/// จนกว่าจะเข้าใหม่
final StreamProvider<List<ChatThreadModel>> myChatThreadsProvider =
    StreamProvider<List<ChatThreadModel>>((Ref ref) {
      final ChatRepository repository = ref.watch(chatRepositoryProvider);
      return repository.watchMyThreads();
    });

/// ห้องเดียว แบบสด เพื่อให้ข้อความที่เข้ามาโผล่ทันทีและอ่านตัวนับยังไม่อ่านได้
final chatThreadProvider = StreamProvider.autoDispose
    .family<ChatThreadModel?, String>((Ref ref, String threadId) {
      final ChatRepository repository = ref.watch(chatRepositoryProvider);
      return repository.watchThread(threadId);
    });

/// ข้อความของห้องเดียว เรียงเก่าก่อน — ใช้เป็นรายการบทสนทนา
final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessageModel>, String>((Ref ref, String threadId) {
      final ChatRepository repository = ref.watch(chatRepositoryProvider);
      return repository.watchMessages(threadId);
    });

/// Sends the text the user typed.
///
/// A single shared busy flag is enough: a buyer can only be typing in one room
/// at a time, and the guard (`if (state) return`) stops a double-tap on the
/// button or the keyboard action from writing the same line twice.
/// กันแชตที่กำลังส่งอยู่ถูกกดซ้ำเป็นข้อความซ้ำซ้อน
class SendChatMessageController extends Notifier<bool> {
  @override
  bool build() => false;

  ChatRepository get _repository => ref.read(chatRepositoryProvider);

  /// คืน `false` เมื่อกำลังส่งอยู่แล้ว (กันกดซ้ำ)
  Future<bool> send({
    required String threadId,
    required String text,
  }) async {
    if (state) return false;
    if (text.trim().isEmpty) return false;
    state = true;
    try {
      await _repository.sendMessage(threadId: threadId, text: text);
      return true;
    } finally {
      state = false;
    }
  }
}

final NotifierProvider<SendChatMessageController, bool>
sendChatMessageProvider =
    NotifierProvider<SendChatMessageController, bool>(
      SendChatMessageController.new,
    );