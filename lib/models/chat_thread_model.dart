import 'firestore_codec.dart';

/// หนึ่งบทสนทนาระหว่างผู้ซื้อกับร้านค้า
///
/// thread เป็นเอกสารหลัก: ทุกกฎที่คุมข้อความจะ hop กลับมาที่เอกสารนี้เพื่ออ่าน
/// `participantUids` ฟิลด์ในนี้จึงเป็นสัญญาที่ส่วนอื่นของฟีเจอร์แชทอ่าน — เก็บ
/// `storeId` ไว้ที่ thread ด้วย เพื่อให้กฎฝั่งผู้ขายตรวจจากเอกสารนี้ได้เอง
///
/// `unreadByBuyer` / `unreadBySeller` นับว่าใครยังไม่ได้อ่านข้อความล่าสุด ผู้ส่ง
/// จะไม่เพิ่มตัวนับของตัวเอง ค่าจึงมากกว่าศูนย์เฉพาะเมื่อมีของใหม่ให้อ่าน
class ChatThreadModel {
  const ChatThreadModel({
    required this.id,
    required this.storeId,
    required this.participantUids,
    required this.lastAt,
    this.storeName = '',
    this.buyerUid = '',
    this.sellerUid = '',
    this.lastMessage = '',
    this.unreadByBuyer = 0,
    this.unreadBySeller = 0,
  });

  /// รหัสเอกสารของห้องแชท
  final String id;

  /// รหัสร้านค้าที่ผู้ซื้อคุยด้วย
  final String storeId;

  /// ชื่อร้านค้า ใช้เป็นหัวเรื่องของห้อง
  final String storeName;

  /// uid ของผู้ซื้อในห้องนี้
  final String buyerUid;

  /// uid ของผู้ขาย (เจ้าของร้าน) ในห้องนี้
  final String sellerUid;

  /// ทุกคนที่เข้าห้องได้ — ฟิลด์ที่ `firestore.rules.isParticipant()` อ่าน
  /// และเป็นค่าที่ query รายการห้องกรอง
  final List<String> participantUids;

  /// ข้อความล่าสุด ใช้เป็นตัวอย่างในรายการห้อง
  final String lastMessage;

  /// จำนวนข้อความที่ยังไม่อ่าน แยกตามบทบาท
  /// ตัวนับของผู้ซื้อจะเพิ่มเมื่อผู้ขายพิมพ์ และกลับกัน
  final int unreadByBuyer;
  final int unreadBySeller;

  /// เวลาของข้อความล่าสุด (หรือตอนสร้างห้อง) ใช้เรียงลำดับในรายการ
  final DateTime lastAt;

  /// จำนวนที่ยังไม่อ่านของ [uid] — โมเดลเดียวจึงใช้ได้ทั้งฝั่งผู้ซื้อและผู้ขาย
  int unreadFor(String uid) => uid == buyerUid ? unreadByBuyer : unreadBySeller;

  /// เป็นจริงเมื่อ [uid] ยังมีข้อความที่ยังไม่ได้อ่าน
  bool hasUnreadFor(String uid) => unreadFor(uid) > 0;

  /// เป็นจริงเมื่อห้องยังไม่มีข้อความ (สร้างห้องแล้วแต่ยังไม่ทัก)
  bool get isEmpty => lastMessage.isEmpty;

  /// สร้างโมเดลจากเอกสาร Firestore
  factory ChatThreadModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final FirestoreReader r = FirestoreReader(data);
    return ChatThreadModel(
      id: id,
      storeId: r.string('storeId'),
      storeName: r.string('storeName'),
      buyerUid: r.string('buyerUid'),
      sellerUid: r.string('sellerUid'),
      participantUids: r.stringList('participantUids'),
      lastMessage: r.string('lastMessage'),
      unreadByBuyer: r.integer('unreadByBuyer'),
      unreadBySeller: r.integer('unreadBySeller'),
      lastAt: r.dateTimeOr(
        'lastAt',
        DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
  }
}