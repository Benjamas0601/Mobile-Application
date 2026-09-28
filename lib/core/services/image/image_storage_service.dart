import 'package:cross_file/cross_file.dart';

/// ผลลัพธ์หนึ่งรูปที่อัปโหลดสำเร็จ
///
/// เก็บลง Firestore เฉพาะ [url] เท่านั้น ส่วน [publicId] ใช้ลบ/หมุนรูปภายหลัง
class UploadedImage {
  const UploadedImage({
    required this.url,
    required this.publicId,
    this.format,
    this.width,
    this.height,
    this.bytes,
  });

  /// URL แบบ https พร้อมแสดงผลทันที (เก็บลง Firestore ตรงนี้)
  final String url;

  /// รหัสประจำรูป ใช้ `deleteImage()` และสร้าง URL แบบปรับขนาด
  final String publicId;

  final String? format;
  final int? width;
  final int? height;
  final int? bytes;

  @override
  String toString() => 'UploadedImage($publicId, $width x $height)';
}

/// เงื่อนไขการอัปโหลดรูป
///
/// ตั้งไว้ให้ตรงกับข้อกำหนดเดิมใน `storage.rules`
/// เพื่อให้พฤติกรรมเหมือนเดิมไม่ว่าจะเปลี่ยนผู้ให้บริการเก็บรูปทีหลัง
class ImageUploadPolicy {
  const ImageUploadPolicy._();

  /// ไม่เกิน 5 MB
  static const int maxBytes = 5 * 1024 * 1024;

  static const List<String> allowedExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
  ];

  /// เช็คไฟล์ก่อนยิงขึ้นเครือข่าย — เพื่อให้ผู้ใช้รู้ผลเร็วและไม่เผาโควตา
  static Future<void> validate(XFile file) async {
    final int size = await file.length();
    if (size == 0) {
      throw const ImageUploadException('ไฟล์ว่างเปล่า');
    }
    if (size > maxBytes) {
      final double mb = size / (1024 * 1024);
      throw ImageUploadException('ไฟล์ใหญ่เกิน 5 MB (ไฟล์นี้ ${mb.toStringAsFixed(1)} MB)');
    }
    final String ext = extensionOf(file.name);
    if (!allowedExtensions.contains(ext)) {
      throw ImageUploadException(
        'รองรับเฉพาะ ${allowedExtensions.join(', ')} (ไฟล์นี้เป็น .$ext)',
      );
    }
  }

  /// ดึงนามสกุลไฟล์แบบ lowercase โดยไม่สนใจ path
  static String extensionOf(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  /// แปลง path ของแอปให้เป็นโฟลเดอร์ของ Cloudinary
  ///
  /// ออกแบบให้ตรงกับโครงสร้างที่วางไว้ใน `storage.rules` เพื่อให้ย้ายกลับไป
  /// Firebase Storage ทีหลังได้โดยไม่ต้องแก้ฐานข้อมูล
  static String folderForProduct({required String storeId, required String productId}) =>
      'stores/$storeId/products/$productId';

  static String folderForStoreCover({required String storeId}) =>
      'stores/$storeId/cover';

  static String folderForProfile({required String uid}) => 'users/$uid/profile';

  static String folderForChat({required String threadId}) => 'chats/$threadId';

  static String folderForPaymentSlip({required String paymentId}) =>
      'payments/$paymentId/slips';

  static String folderForReview({required String reviewId}) => 'reviews/$reviewId';
}

/// ข้อผิดพลาดที่คาดว่าจะเกิด ควรเอาไปแสดงผลให้ผู้ใช้อ่านได้
class ImageUploadException implements Exception {
  const ImageUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// สัญญาของผู้ให้บริการเก็บรูปภาพ
///
/// ทำเป็น interface เพื่อให้สลับไปใช้ Firebase Storage ทีหลังได้โดยไม่ต้องแก้ UI
abstract class ImageStorageService {
  /// อัปโหลดหนึ่งรูป คืนค่า URL ที่เก็บลง Firestore
  Future<UploadedImage> uploadImage({
    required XFile file,
    required String folder,
  });

  /// ลบรูป (ใช้ตอนผู้ใช้กดลบรูปสินค้า)
  Future<void> deleteImage(String publicId);

  /// สร้าง URL แบบปรับขนาด/ครอปตอนแสดงผล เพื่อลดขนาดและประหยัดโควตา
  String buildUrl({
    required String publicId,
    int? width,
    int? height,
    String gravity = 'auto',
  });
}
