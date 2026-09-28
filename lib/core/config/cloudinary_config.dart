/// ค่าคอนฟิก Cloudinary ที่ส่งเข้ามาตอน build
///
/// ไม่ hardcode ค่าไว้ใน source เพื่อไม่ให้ credential หลุดเข้า Git
/// ใช้คำสั่ง:
/// ```
/// flutter run --dart-define=CLOUDINARY_CLOUD_NAME=<cloud_name> ^
///               --dart-define=CLOUDINARY_UPLOAD_PRESET=<preset_name>
/// ```
/// ดูวิธีหาค่าและสร้าง upload preset ที่ `docs/07_cloudinary_setup.md`
///
/// ⚠️ ห้ามส่ง `CLOUDINARY_API_SECRET` เข้า build ที่ปล่อยจริง
/// ใครก็แก้ไฟล์ APK ได้ แล้วเข้าถึงบัญชี Cloudinary ของเราได้
/// production build ให้ส่งแค่ cloud name กับ upload preset
class CloudinaryConfig {
  const CloudinaryConfig._();

  /// ชื่อ cloud จากหน้า Cloudinary Console เช่น `dxyz12345`
  static const String cloudName = String.fromEnvironment('CLOUDINARY_CLOUD_NAME');

  /// ชื่อ Unsigned upload preset (สร้างไว้ใน Settings → Upload presets)
  static const String uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
  );

  /// ตั้งค่าครบทุกตัวแล้วหรือยัง — ใช้ตอน dev เพื่อไม่ให้ล้มตอนอัปโหลดรูป
  static bool get isConfigured => cloudName.isNotEmpty && uploadPreset.isNotEmpty;

  /// API key — ใช้ตอน dev เท่านั้น (ดูรายละเอียดในคำเตือนด้านล่าง)
  static const String apiKey = String.fromEnvironment('CLOUDINARY_API_KEY');

  /// API secret — ใช้ตอน dev เท่านั้น
  static const String apiSecret = String.fromEnvironment('CLOUDINARY_API_SECRET');

  /// ข้อความสำหรับแสดงผลตอนยังไม่ได้ตั้งค่า
  static const String notConfiguredMessage =
      'ยังไม่ได้ตั้งค่า Cloudinary — รันด้วย '
      '--dart-define=CLOUDINARY_CLOUD_NAME=... '
      '--dart-define=CLOUDINARY_UPLOAD_PRESET=...';
}
