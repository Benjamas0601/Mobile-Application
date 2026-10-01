import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/config/cloudinary_config.dart';
import '../core/services/image/cloudinary_image_service.dart';
import '../core/services/image/image_storage_service.dart';

/// Where uploaded images are stored.
///
/// Exposed through Riverpod rather than constructed at the call site so the
/// choice lives in exactly one place: swapping to Firebase Storage later is a
/// one-line change here, not an edit in every screen that uploads a photo.
///
/// Overridden in tests with a fake, which is also how the not-configured path
/// is exercised without network access.
/// เลือก storage ผ่าน interface เพื่อสลับเป็น fake ในการทดสอบได้
final Provider<ImageStorageService> imageStorageServiceProvider =
    Provider<ImageStorageService>((Ref ref) => CloudinaryImageService());

/// Whether upload credentials were compiled into this build.
///
/// Credentials arrive via `--dart-define`, so a build made without them still
/// runs — the app must explain that instead of crashing on the first upload.
final Provider<bool> cloudinaryConfiguredProvider = Provider<bool>(
  (Ref ref) => CloudinaryConfig.isConfigured,
);

/// Reason to show when uploads are unavailable, empty when they are available.
final Provider<String?> cloudinaryMissingConfigProvider = Provider<String?>(
  (Ref ref) => ref.watch(cloudinaryConfiguredProvider)
      ? null
      : CloudinaryConfig.notConfiguredMessage,
);

abstract interface class PaymentSlipPicker {
  Future<XFile?> pickImage();
}

class GalleryPaymentSlipPicker implements PaymentSlipPicker {
  GalleryPaymentSlipPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<XFile?> pickImage() =>
      _picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
}

final Provider<PaymentSlipPicker> paymentSlipPickerProvider =
    Provider<PaymentSlipPicker>((Ref ref) => GalleryPaymentSlipPicker());
