import 'store_model.dart';

/// The store fields the seller can edit, in the shape the form collects them.
///
/// Separate from [StoreModel] for the same reason [ProductDraft] exists: a
/// `stores/{id}` document also carries facts the seller must not type —
/// `ownerUid`, `createdAt`, `ratingAvg`, `ratingCount`, `commissionRate`. Those
/// are written by the seed, the platform, or a Cloud Function, so the form has
/// no control for them and this draft cannot carry them either.
/// เก็บเฉพาะช่องที่ผู้ขายแก้ได้ ไม่รวมฟิลด์ที่ระบบเป็นเจ้าของ
class StoreProfileDraft {
  const StoreProfileDraft({
    required this.name,
    required this.description,
    required this.province,
    required this.region,
    required this.community,
    required this.coverImageUrl,
    this.promptPayId = '',
    this.bankName = '',
    this.bankAccountName = '',
    this.bankAccountNumber = '',
    this.logoUrl,
  });

  final String name;
  final String description;
  final String province;
  final String region;
  final String community;
  final String coverImageUrl;
  final String promptPayId;
  final String bankName;
  final String bankAccountName;
  final String bankAccountNumber;
  final String? logoUrl;

  /// A store needs a name to be findable; everything else is optional, and an
  /// empty province/region simply leaves those filters without a match.
  bool get isValid => name.trim().isNotEmpty;

  factory StoreProfileDraft.fromModel(StoreModel store) => StoreProfileDraft(
    name: store.name,
    description: store.description,
    province: store.province,
    region: store.region,
    community: store.community,
    coverImageUrl: store.coverImageUrl,
    promptPayId: store.promptPayId,
    bankName: store.bankName,
    bankAccountName: store.bankAccountName,
    bankAccountNumber: store.bankAccountNumber,
    logoUrl: store.logoUrl,
  );
}
