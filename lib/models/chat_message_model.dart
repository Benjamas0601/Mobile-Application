import '../core/constants/app_enums.dart';
import 'firestore_codec.dart';

/// ข้อความหนึ่งบรรทัดในบทสนทนา
///
/// เอกสารอยู่ใต้ `chat_threads/{threadId}/messages` จึงต้องส่ง `threadId`
/// เข้ามาในโมเดล เพราะเป็น path ที่ listener ผูกอยู่ — ไม่ได้เก็บในเอกสาร
/// `senderName` ถูก snapshot ไว้ในข้อความ เพื่อให้ยังแสดงชื่อได้แม้ผู้ส่งแก้
/// โปรไฟล์ภายหลัง
class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.threadId,
    required this.senderUid,
    required this.type,
    required this.text,
    required this.createdAt,
    this.senderName = '',
    this.imageUrl,
  });

  /// รหัสเอกสารของข้อความ
  final String id;

  /// รหัสห้องแชทที่ข้อความนี้อยู่
  final String threadId;

  /// uid ของผู้ส่ง
  final String senderUid;

  /// ชื่อผู้ส่ง ณ ตอนส่ง (snapshot ไว้)
  final String senderName;

  /// รูปแบบเนื้อหา: `text` สำหรับข้อความที่ส่งวันนี้ ส่วน `image` เตรียมไว้
  /// สำหรับการอัปโหลดในอนาคต (งาน Cloudinary ถูกพักไว้)
  final MessageType type;

  /// เนื้อข้อความ
  final String text;

  /// URL รูปภาพ (ถ้ามี)
  final String? imageUrl;

  /// เวลาที่ส่ง
  final DateTime createdAt;

  /// ใช้จัดข้างฟองข้อความและตอนส่งข้อความว่าเป็นของผู้ใช้เองหรือไม่
  bool isMine(String uid) => senderUid == uid;

  /// ป้ายอ่านง่ายของบรรทัดกิจกรรมล่าสุด ("รูปภาพ", "ข้อความ"...)
  String get typeLabel => type.label;

  /// สร้างโมเดลจากเอกสาร Firestore
  factory ChatMessageModel.fromFirestore(
    String id,
    Map<String, dynamic> data, {
    String? threadId,
  }) {
    final FirestoreReader r = FirestoreReader(data);
    return ChatMessageModel(
      id: id,
      threadId: threadId ?? r.string('threadId'),
      senderUid: r.string('senderUid'),
      senderName: r.string('senderName'),
      type: MessageType.fromValue(r.string('type')),
      text: r.string('text'),
      imageUrl: r.stringOrNull('imageUrl'),
      createdAt: r.dateTimeOr(
        'createdAt',
        DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
  }

  /// ฟิลด์ที่เขียนตอนสร้างข้อความใหม่
  ///
  /// `senderUid` กับ `createdAt` เป็นสองฟิลด์ที่ rules บังคับ (ต้องเป็นผู้ใช้ที่
  /// ล็อกอินอยู่ / ต้องเป็น timestamp ของเซิร์ฟเวอร์) ที่เหลือเขียนได้อิสระ
  Map<String, dynamic> toFirestore() => <String, dynamic>{
    'threadId': threadId,
    'senderUid': senderUid,
    if (senderName.isNotEmpty) 'senderName': senderName,
    'type': type.value,
    if (text.isNotEmpty) 'text': text,
    if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
  };
}