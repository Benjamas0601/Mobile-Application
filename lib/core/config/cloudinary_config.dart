/// ค่าคอนฟิก Cloudinary ของโปรเจกต์
///
/// ค่าสองตัวแรกมี `defaultValue` ฝังไว้ เพื่อให้ clone ใหม่ build แล้วอัปโหลดรูปได้เลย
/// โดยไม่ต้องส่ง flag — ทั้งสองค่านี้ **ไม่ใช่ความลับ**:
///  - `cloudName` โผล่ใน URL ของรูปทุกใบ (`res.cloudinary.com/<cloud>/...`)
///    ใครก็อ่านได้จากรูปที่เห็นอยู่แล้ว
///  - `uploadPreset` เป็น unsigned preset ที่ Cloudinary ออกแบบมาให้เป็น public
///    ตั้งแต่ต้น มิฉะนั้นมือถือจะอัปโหลดโดยไม่ฝัง secret ไม่ได้เลย
///
/// ใช้ override เมื่ออยากชี้คนละคลาวด์:
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
  static const String cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'zqaixbny',
  );

  /// ชื่อ Unsigned upload preset (สร้างไว้ใน Settings → Upload presets)
  static const String uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'otop_shop',
  );

  /// ตั้งค่าครบทุกตัวแล้วหรือยัง — ใช้ตอน dev เพื่อไม่ให้ล้มตอนอัปโหลดรูป
  static bool get isConfigured =>
      cloudName.isNotEmpty && uploadPreset.isNotEmpty;

  /// API key — ใช้ตอน dev เท่านั้น (ดูรายละเอียดในคำเตือนด้านล่าง)
  static const String apiKey = String.fromEnvironment('CLOUDINARY_API_KEY');

  /// API secret — ใช้ตอน dev เท่านั้น
  static const String apiSecret = String.fromEnvironment(
    'CLOUDINARY_API_SECRET',
  );

  /// ข้อความสำหรับแสดงผลตอนยังไม่ได้ตั้งค่า
  ///
  /// ค่า default ฝังไว้แล้ว ข้อความนี้จึงโผล่ก็ต่อเมื่อ build ถูกส่งมาด้วยค่าว่างเปล่า
  /// โดยเจตนา (เช่นทดสอบเส้นทางที่ยังไม่ได้ตั้งค่า) จึงต้องบอกให้ชัดว่าเป็นกรณีนั้น
  /// ไม่ใช่คำสั่งที่ต้องรันทุกครั้ง
  static const String notConfiguredMessage =
      'build นี้ถูกส่งเข้ามาด้วยค่า Cloudinary ที่ว่างเปล่า '
      '(--dart-define=CLOUDINARY_CLOUD_NAME / CLOUDINARY_UPLOAD_PRESET) '
      '— ค่า default ปกติตั้งไว้ใน cloudinary_config.dart แล้ว';
}
