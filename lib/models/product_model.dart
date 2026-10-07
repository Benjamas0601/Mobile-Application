import '../core/constants/app_enums.dart';
import 'firestore_codec.dart';

/// เรื่องราวของสินค้า ซึ่งแบ่งเป็น 4 ส่วนตามข้อมูลที่ร้านค้าต้องการเล่า
///
/// แยกเป็นโมเดลเพื่อให้หน้ารายละเอียดสินค้าแสดงแต่ละส่วนตามลำดับ
/// และซ่อนส่วนที่ยังไม่มีข้อมูลได้
class ProductStory {
  const ProductStory({
    this.community = '',
    this.ingredients = '',
    this.productionMethod = '',
    this.uniqueness = '',
  });

  /// เรื่องราวของชุมชนหรือผู้ผลิตที่อยู่เบื้องหลังสินค้า
  final String community;

  /// วัตถุดิบหรือส่วนประกอบสำคัญของสินค้า
  final String ingredients;

  /// วิธีการหรือขั้นตอนการผลิตสินค้า
  final String productionMethod;

  /// จุดเด่นที่ทำให้สินค้าแตกต่างจากสินค้าอื่น
  final String uniqueness;

  /// คืนค่า `true` เมื่อเรื่องราวทั้ง 4 ส่วนยังไม่มีข้อมูล
  bool get isEmpty =>
      community.isEmpty &&
      ingredients.isEmpty &&
      productionMethod.isEmpty &&
      uniqueness.isEmpty;

  /// สร้างเรื่องราวจากข้อมูลซ้อนในเอกสาร Firestore
  factory ProductStory.fromFirestore(FirestoreReader r) {
    return ProductStory(
      community: r.string('community'),
      ingredients: r.string('ingredients'),
      productionMethod: r.string('productionMethod'),
      uniqueness: r.string('uniqueness'),
    );
  }
}

/// ข้อมูลสินค้าจากเอกสาร `products/{productId}` ใน Firestore
class ProductModel {
  const ProductModel({
    required this.id,
    required this.storeId,
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.province,
    required this.region,
    required this.imageUrls,
    required this.stockTotal,
    required this.status,
    required this.story,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.soldCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// รหัสเอกสารสินค้า
  final String id;

  /// รหัสร้านค้าที่เป็นเจ้าของสินค้า
  final String storeId;

  /// ชื่อสินค้าที่ใช้แสดงแก่ผู้ซื้อ
  final String name;

  /// รายละเอียดสินค้า
  final String description;

  /// ราคาพื้นฐานของสินค้า ก่อนรวมส่วนต่างราคาของตัวเลือก
  final double price;

  /// รหัสหมวดหมู่สินค้าที่ใช้จัดกลุ่มและค้นหา
  final String categoryId;

  /// จังหวัดและภูมิภาคที่ใช้แสดงแหล่งที่มาของสินค้า
  final String province;
  final String region;

  /// URL รูปภาพสินค้า โดยรูปแรกใช้เป็นภาพหน้าปก
  final List<String> imageUrls;

  /// จำนวนสินค้าคงเหลือรวมทุกตัวเลือก
  final int stockTotal;

  /// สถานะสินค้าที่กำหนดว่าสามารถแสดงหรือซื้อได้หรือไม่
  final ProductStatus status;

  /// เรื่องราวเบื้องหลังสินค้า
  final ProductStory story;

  /// ค่าเฉลี่ยคะแนนรีวิวและจำนวนรีวิว
  final double ratingAvg;
  final int ratingCount;

  /// จำนวนชิ้นที่ขายได้
  final int soldCount;

  /// วันเวลาที่สร้างและแก้ไขข้อมูลล่าสุด
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// สินค้าที่มีสถานะพร้อมขายเท่านั้นจึงแสดงให้ลูกค้าหรือเพิ่มลงตะกร้าได้
  bool get isVisible => status.isVisibleToCustomers;

  /// ตรวจว่ามีสินค้าเหลืออยู่ในสต็อกรวมหรือไม่
  bool get isInStock => stockTotal > 0;

  /// ปัดราคาเป็นจำนวนเงินบาทเต็มสำหรับแสดงผลแก่ผู้ซื้อ
  int get priceBaht => price.round();

  /// คืน URL ภาพแรก หรือ `null` เมื่อสินค้าไม่มีรูปภาพ
  String? get coverImageUrl => imageUrls.isEmpty ? null : imageUrls.first;

  /// คืนชื่อภูมิภาคภาษาไทย หากรู้จักค่า มิฉะนั้นใช้ค่าที่บันทึกไว้
  String get regionLabel => ThaiRegion.fromValue(region)?.label ?? region;

  /// แปลงข้อมูลจาก Firestore เป็นโมเดล พร้อมใช้ค่าเริ่มต้นเมื่อเรื่องราวไม่มี
  factory ProductModel.fromFirestore(String id, Map<String, dynamic> data) {
    final FirestoreReader r = FirestoreReader(data);
    return ProductModel(
      id: id,
      storeId: r.string('storeId'),
      name: r.string('name'),
      description: r.string('description'),
      price: r.decimal('price'),
      categoryId: r.string('categoryId'),
      province: r.string('province'),
      region: r.string('region'),
      imageUrls: r.stringList('imageUrls'),
      stockTotal: r.integer('stockTotal'),
      status: ProductStatus.fromValue(r.string('status')),
      story:
          r.nested<ProductStory>('story', ProductStory.fromFirestore) ??
          const ProductStory(),
      ratingAvg: r.decimal('ratingAvg'),
      ratingCount: r.integer('ratingCount'),
      soldCount: r.integer('soldCount'),
      createdAt: r.dateTime('createdAt'),
      updatedAt: r.dateTime('updatedAt'),
    );
  }
}

/// ตัวเลือกสินค้าจากเอกสาร `product_variants/{variantId}` ใน Firestore
///
/// ตัวเลือก เช่น สีหรือขนาด มีสต็อกของตัวเอง จึงตรวจสินค้าแต่ละแบบได้
/// โดยไม่สับสนกับสถานะสต็อกรวมของสินค้าหลัก
class ProductVariantModel {
  const ProductVariantModel({
    required this.id,
    required this.productId,
    required this.name,
    required this.color,
    required this.size,
    required this.priceDelta,
    required this.stock,
    this.imageUrl,
  });

  /// รหัสเอกสารตัวเลือกสินค้า
  final String id;

  /// รหัสสินค้าหลักที่ตัวเลือกนี้สังกัด
  final String productId;

  /// ชื่อที่ใช้แสดงตัวเลือก
  final String name;

  /// สีและขนาดของตัวเลือก (อาจไม่มีค่า)
  final String? color;
  final String? size;

  /// จำนวนเงินที่บวกเพิ่มหรือลดจากราคาพื้นฐาน
  final double priceDelta;

  /// จำนวนคงเหลือเฉพาะตัวเลือกนี้
  final int stock;

  /// URL รูปภาพเฉพาะตัวเลือก (ถ้ามี)
  final String? imageUrl;

  /// ตรวจว่าตัวเลือกนี้ยังมีสินค้าเหลือหรือไม่
  bool get isInStock => stock > 0;

  /// แปลงข้อมูลตัวเลือกจาก Firestore โดยรองรับข้อมูลสี/ขนาด
  /// ที่เก็บไว้ทั้งระดับบนและใน `options`
  factory ProductVariantModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final FirestoreReader r = FirestoreReader(data);
    return ProductVariantModel(
      id: id,
      productId: r.string('productId'),
      name: r.string('name'),
      color:
          r.stringOrNull('color') ??
          r.nested<String?>(
            'options',
            (FirestoreReader o) => o.stringOrNull('color'),
          ),
      size:
          r.stringOrNull('size') ??
          r.nested<String?>(
            'options',
            (FirestoreReader o) => o.stringOrNull('size'),
          ),
      priceDelta: r.decimal('priceDelta'),
      stock: r.integer('stock'),
      imageUrl: r.stringOrNull('imageUrl'),
    );
  }
}
