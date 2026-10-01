import '../core/constants/app_enums.dart';
import 'firestore_codec.dart';

/// A `stores/{storeId}` document — an OTOP producer's shop.
/// ข้อมูลร้านที่ใช้แสดงหน้าร้านและตรวจความเป็นเจ้าของโดยผู้ขาย
class StoreModel {
  const StoreModel({
    required this.id,
    required this.ownerUid,
    required this.name,
    required this.province,
    required this.region,
    required this.community,
    required this.description,
    this.coverImageUrl = '',
    this.logoUrl,
    this.promptPayId = '',
    this.bankName = '',
    this.bankAccountName = '',
    this.bankAccountNumber = '',
    this.otopCertified = false,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.commissionRate = 0,
  });

  final String id;
  final String ownerUid;
  final String name;
  final String province;
  final String region;
  final String community;
  final String description;
  final String coverImageUrl;
  final String? logoUrl;
  final String promptPayId;
  final String bankName;
  final String bankAccountName;
  final String bankAccountNumber;
  final bool otopCertified;
  final double ratingAvg;
  final int ratingCount;

  /// Platform commission as a fraction (0.08 = 8%).
  final double commissionRate;

  ThaiRegion? get regionEnum => ThaiRegion.fromValue(region);

  factory StoreModel.fromFirestore(String id, Map<String, dynamic> data) {
    final FirestoreReader r = FirestoreReader(data);
    return StoreModel(
      id: id,
      ownerUid: r.string('ownerUid'),
      name: r.string('name'),
      province: r.string('province'),
      region: r.string('region'),
      community: r.string('community'),
      description: r.string('description'),
      coverImageUrl: r.string('coverImageUrl'),
      logoUrl: r.stringOrNull('logoUrl'),
      promptPayId: r.string('promptPayId'),
      bankName: r.string('bankName'),
      bankAccountName: r.string('bankAccountName'),
      bankAccountNumber: r.string('bankAccountNumber'),
      otopCertified: r.boolean('otopCertified'),
      ratingAvg: r.decimal('ratingAvg'),
      ratingCount: r.integer('ratingCount'),
      commissionRate: r.decimal('commissionRate'),
    );
  }
}
