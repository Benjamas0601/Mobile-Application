import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../config/cloudinary_config.dart';
import 'image_storage_service.dart';

/// เก็บรูปภาพบน Cloudinary (free tier ไม่ต้องผูกบัตรเครดิต)
///
/// อัปโหลดแบบ **unsigned** — ปลอดภัยสำหรับแอปมือถือเพราะไม่ต้องฝัง API secret
/// ไว้ในตัวแอป (secret ในไฟล์ที่คนอื่นแก้ APK ได้ = รั่วแน่นอน)
class CloudinaryImageService implements ImageStorageService {
  CloudinaryImageService({
    String? cloudName,
    String? uploadPreset,
    String? apiKey,
    String? apiSecret,
    http.Client? httpClient,
  }) : _cloudName = cloudName ?? CloudinaryConfig.cloudName,
       _uploadPreset = uploadPreset ?? CloudinaryConfig.uploadPreset,
       _apiKey = apiKey ?? CloudinaryConfig.apiKey,
       _apiSecret = apiSecret ?? CloudinaryConfig.apiSecret,
       _client = httpClient ?? http.Client();

  final String _cloudName;
  final String _uploadPreset;

  /// ใช้เฉพาะตอน dev เพื่อทดสอบการลบรูป — ห้ามส่งเข้า production build
  final String? _apiKey;
  final String? _apiSecret;

  final http.Client _client;

  Uri _apiUri(String action) =>
      Uri.https('api.cloudinary.com', '/v1_1/$_cloudName/image/$action');

  Uri _deliveryUri() =>
      Uri.https('res.cloudinary.com', '/$_cloudName/image/upload');

  @override
  Future<UploadedImage> uploadImage({
    required XFile file,
    required String folder,
  }) async {
    if (!CloudinaryConfig.isConfigured && _cloudName.isEmpty) {
      throw const ImageUploadException(CloudinaryConfig.notConfiguredMessage);
    }

    await ImageUploadPolicy.validate(file);

    try {
      final http.MultipartRequest request =
          http.MultipartRequest('POST', _apiUri('upload'))
            ..fields['upload_preset'] = _uploadPreset
            ..fields['folder'] = folder
            ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final http.StreamedResponse streamed = await _client.send(request);
      final String body = await streamed.stream.bytesToString();
      final int status = streamed.statusCode;
      final Map<String, dynamic> json = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;

      if (status != 200) {
        final Map<String, dynamic> error =
            json['error'] as Map<String, dynamic>? ?? <String, dynamic>{};
        throw ImageUploadException(
          'อัปโหลดรูปไม่สำเร็จ: ${error['message'] ?? 'HTTP $status'}',
        );
      }

      return UploadedImage(
        url: json['secure_url'] as String,
        publicId: json['public_id'] as String,
        format: json['format'] as String?,
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
        bytes: (json['bytes'] as num?)?.toInt(),
      );
    } on ImageUploadException {
      rethrow;
    } catch (error) {
      throw ImageUploadException('อัปโหลดรูปไม่สำเร็จ: $error');
    }
  }

  @override
  String buildUrl({
    required String publicId,
    int? width,
    int? height,
    String gravity = 'auto',
  }) {
    final List<String> transform = <String>[];

    if (width != null && height != null) {
      transform.addAll(<String>[
        'c_fill',
        'g_$gravity',
        'w_$width',
        'h_$height',
      ]);
    } else if (width != null) {
      transform.addAll(<String>['c_limit', 'w_$width']);
    } else if (height != null) {
      transform.addAll(<String>['c_limit', 'h_$height']);
    }

    // q_auto = เลือกคุณภาพให้เหมาะกับอุปกรณ์, f_auto = เลือก WebP/AVIF อัตโนมัติ
    transform.addAll(<String>['q_auto', 'f_auto']);

    return '$_deliveryUri/${transform.join(',')}/$publicId';
  }

  @override
  Future<void> deleteImage(String publicId) async {
    if (_apiKey == null ||
        _apiKey.isEmpty ||
        _apiSecret == null ||
        _apiSecret.isEmpty) {
      throw const ImageUploadException(
        'Unsigned preset ลบรูปไม่ได้ (ต้องมี API key/secret) — '
        'ให้ใช้การ "ซ่อนรูป" ใน Firestore แทนการลบไฟล์จริง',
      );
    }

    final int timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final String signature = sha1
        .convert(
          utf8.encode('public_id=$publicId&timestamp=$timestamp$_apiSecret'),
        )
        .toString();

    final http.Response response = await _client.post(
      _apiUri('destroy'),
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(<String, dynamic>{
        'public_id': publicId,
        'timestamp': timestamp,
        'api_key': _apiKey,
        'signature': signature,
      }),
    );

    if (response.statusCode != 200) {
      throw ImageUploadException('ลบรูปไม่สำเร็จ: HTTP ${response.statusCode}');
    }
  }

  void dispose() => _client.close();
}
