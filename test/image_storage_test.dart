import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_otop_marketplace/core/config/cloudinary_config.dart';
import 'package:thai_otop_marketplace/core/services/image/cloudinary_image_service.dart';
import 'package:thai_otop_marketplace/core/services/image/image_storage_service.dart';
import 'package:thai_otop_marketplace/providers/image_storage_provider.dart';

void main() {
  group('the image service is reachable from the app', () {
    test('a provider returns a usable uploader', () {
      // The service used to exist with no caller, so nothing in the app could
      // reach it. This is the wiring that makes it injectable and swappable.
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(imageStorageServiceProvider),
        isA<CloudinaryImageService>(),
      );
    });

    test('the provider can be swapped for a fake', () {
      // What makes the unconfigured path testable without a network call.
      final ProviderContainer container = ProviderContainer(
        overrides: [
          imageStorageServiceProvider.overrideWithValue(_FakeUploader()),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(imageStorageServiceProvider), isA<_FakeUploader>());
    });
  });

  group('the config carries the project defaults, with a way out', () {
    test('isConfigured is true out of the box', () {
      // Both defaults are public by design (see cloudinary_config.dart), so a
      // fresh clone must be able to upload without anyone remembering a flag.
      // If this fails, the build lost its credentials and every upload breaks.
      expect(CloudinaryConfig.cloudName, isNotEmpty);
      expect(CloudinaryConfig.uploadPreset, isNotEmpty);
      expect(CloudinaryConfig.isConfigured, isTrue);
    });

    test('the provider reports the configuration as present', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(cloudinaryConfiguredProvider), isTrue);
      expect(container.read(cloudinaryMissingConfigProvider), isNull);
    });

    test('the hint still names the flags, as the escape hatch', () {
      // Someone pointing a build at a different cloud needs to know which
      // flags to pass; the message is what tells them.
      expect(
        CloudinaryConfig.notConfiguredMessage,
        contains('CLOUDINARY_CLOUD_NAME'),
      );
      expect(
        CloudinaryConfig.notConfiguredMessage,
        contains('CLOUDINARY_UPLOAD_PRESET'),
      );
    });

    test('uploading without credentials fails with that same message', () async {
      // Guarding in the UI is not enough: a direct call must fail loudly too.
      final CloudinaryImageService service = CloudinaryImageService(
        cloudName: '',
        uploadPreset: '',
      );

      await expectLater(
        service.uploadImage(
          file: _fakeImage(),
          folder: 'payments/x/slips',
        ),
        throwsA(
          isA<ImageUploadException>().having(
            (ImageUploadException e) => e.message,
            'message',
            contains('CLOUDINARY_CLOUD_NAME'),
          ),
        ),
      );
    });
  });

  group('a folder the user could tamper with cannot escape its own path', () {
    // The folder is built from ids that end up in Firestore, so it is treated
    // as untrusted input. Without this a crafted id could write outside the
    // folder the app intended.
    test('traversal segments are dropped', () {
      expect(
        ImageUploadPolicy.sanitizeFolder('stores/../users'),
        'stores/users',
      );
    });

    test('a path made only of traversal is rejected outright', () {
      // Nothing survives the filter, so there is no safe folder left to use.
      // Failing loudly beats uploading to the account root.
      expect(
        () => ImageUploadPolicy.sanitizeFolder('../..'),
        throwsA(isA<ImageUploadException>()),
      );
    });

    test('an empty folder is rejected', () {
      expect(
        () => ImageUploadPolicy.sanitizeFolder('  //  '),
        throwsA(isA<ImageUploadException>()),
      );
    });
  });

  group('a rejected file never reaches the network', () {
    test('an empty file is refused', () async {
      // `path` as well as `name`: on the IO implementation `XFile.fromData`
      // ignores `name` and derives it from `path`, while the web one does the
      // opposite.
      await expectLater(
        ImageUploadPolicy.validate(
          XFile.fromData(Uint8List(0), path: 'a.jpg', name: 'a.jpg'),
        ),
        throwsA(
          isA<ImageUploadException>().having(
            (ImageUploadException e) => e.message,
            'message',
            contains('ว่างเปล่า'),
          ),
        ),
      );
    });

    test('a file over the limit is refused with its size in the message', () async {
      final Uint8List tooBig = Uint8List(ImageUploadPolicy.maxBytes + 1);

      await expectLater(
        ImageUploadPolicy.validate(
          XFile.fromData(tooBig, path: 'big.jpg', name: 'big.jpg'),
        ),
        throwsA(
          isA<ImageUploadException>().having(
            (ImageUploadException e) => e.message,
            'message',
            contains('5 MB'),
          ),
        ),
      );
    });

    test('a valid image passes validation', () async {
      // The happy path, so the guards above are not simply rejecting everything.
      await expectLater(ImageUploadPolicy.validate(_fakeImage()), completes);
    });
  });

  group('the storage interface stays backend-agnostic', () {
    test('upload folders mirror the Firestore layout', () {
      // The folder paths were designed to match `storage.rules` so the app can
      // move to Firebase Storage later without reshaping any data.
      expect(
        ImageUploadPolicy.folderForPaymentSlip(paymentId: 'pay-1'),
        'payments/pay-1/slips',
      );
      expect(
        ImageUploadPolicy.folderForProduct(storeId: 's1', productId: 'p1'),
        'stores/s1/products/p1',
      );
    });

    test('folder paths follow the same shape for every upload type', () {
      // Cheap to assert, and it is the guard a user hits most often.
      expect(
        ImageUploadPolicy.folderForStoreCover(storeId: 's1'),
        'stores/s1/cover',
      );
      expect(
        ImageUploadPolicy.folderForProfile(uid: 'u1'),
        'users/u1/profile',
      );
      expect(
        ImageUploadPolicy.folderForReview(reviewId: 'r1'),
        'reviews/r1',
      );
    });

    test('a non-image extension is not on the allow list', () {
      expect(
        ImageUploadPolicy.allowedExtensions,
        isNot(contains(ImageUploadPolicy.extensionOf('payload.exe'))),
      );
      expect(
        ImageUploadPolicy.extensionOf('photo.JPG'),
        'jpg',
        reason: 'the check must be case-insensitive',
      );
    });
  });
}

/// A stand-in so the provider override test does not need a real service.
class _FakeUploader implements ImageStorageService {
  @override
  Future<UploadedImage> uploadImage({
    required XFile file,
    required String folder,
  }) async => const UploadedImage(url: '', publicId: '');

  @override
  Future<void> deleteImage(String publicId) async {}

  @override
  String buildUrl({
    required String publicId,
    int? width,
    int? height,
    String gravity = 'auto',
  }) => '';
}

/// A file that reports its size without touching the disk.
XFile _fakeImage() => XFile.fromData(
  Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0]),
  path: 'slip.jpg',
  name: 'slip.jpg',
);
