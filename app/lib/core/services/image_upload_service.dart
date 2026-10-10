import 'dart:math';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/app_exception.dart';

enum ImageKind { avatar, cover }

abstract class ImageUploadService {
  /// Lets the user pick a photo and uploads it. Returns null if cancelled.
  ///
  /// With [camera] true the device camera is used instead of the gallery.
  Future<String?> pickAndUpload(
    String uid,
    ImageKind kind, {
    bool camera = false,
  });
}

/// Compresses on-device (max dimension + JPEG quality) before upload and writes
/// to a random, non-guessable path covered by `storage.rules`.
class FirebaseImageUploadService implements ImageUploadService {
  FirebaseImageUploadService({FirebaseStorage? storage, ImagePicker? picker})
    : _storage = storage ?? FirebaseStorage.instance,
      _picker = picker ?? ImagePicker();

  final FirebaseStorage _storage;
  final ImagePicker _picker;
  static const maxBytes = 5 * 1024 * 1024;

  static String _randomName() {
    final r = Random.secure();
    return List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  @override
  Future<String?> pickAndUpload(
    String uid,
    ImageKind kind, {
    bool camera = false,
  }) async {
    final file = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      preferredCameraDevice: kind == ImageKind.avatar
          ? CameraDevice.front
          : CameraDevice.rear,
      maxWidth: kind == ImageKind.avatar ? 512 : 1280,
      maxHeight: kind == ImageKind.avatar ? 512 : 1280,
      imageQuality: 80,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw const AppException('That photo is too large. Pick one under 5 MB.');
    }
    final folder = kind == ImageKind.avatar
        ? 'users/$uid/avatar'
        : 'activities/$uid/covers';
    final ref = _storage.ref('$folder/${_randomName()}.jpg');
    try {
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } on FirebaseException {
      throw const AppException(
        'Couldn\'t upload the photo. Check your connection and try again.',
        retryable: true,
      );
    }
  }
}
