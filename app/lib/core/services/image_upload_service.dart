import 'dart:math';

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/app_exception.dart';

enum ImageKind { avatar, cover, gallery }

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

/// Size policy per image kind: longest edge in px and the byte budget we
/// compress towards (quality is stepped down until the result fits).
class CompressionPolicy {
  const CompressionPolicy(this.maxEdge, this.targetBytes);
  final int maxEdge;
  final int targetBytes;

  static const avatar = CompressionPolicy(512, 60 * 1024);
  static const gallery = CompressionPolicy(1080, 200 * 1024);
  static const cover = CompressionPolicy(1280, 220 * 1024);

  static CompressionPolicy of(ImageKind k) => switch (k) {
    ImageKind.avatar => avatar,
    ImageKind.gallery => gallery,
    ImageKind.cover => cover,
  };
}

/// Re-encodes as JPEG within [policy]. Starts at quality 82 and steps down to
/// 40, returning the first result under the byte budget (or the smallest).
Future<Uint8List> compressImage(
  Uint8List input,
  CompressionPolicy policy,
) async {
  Uint8List? best;
  for (var q = 82; q >= 40; q -= 14) {
    final out = await FlutterImageCompress.compressWithList(
      input,
      minWidth: policy.maxEdge,
      minHeight: policy.maxEdge,
      quality: q,
      format: CompressFormat.jpeg,
    );
    if (best == null || out.length < best.length) best = out;
    if (out.length <= policy.targetBytes) break;
  }
  return best ?? input;
}

/// Compresses on-device (max dimension + JPEG quality) before upload and writes
/// to a random, non-guessable path covered by `storage.rules`.
class FirebaseImageUploadService implements ImageUploadService {
  FirebaseImageUploadService({FirebaseStorage? storage, ImagePicker? picker})
    : _storage = storage ?? FirebaseStorage.instance,
      _picker = picker ?? ImagePicker();

  final FirebaseStorage _storage;
  final ImagePicker _picker;

  /// Cap on the original pick; what gets stored is the compressed copy.
  static const maxBytes = 20 * 1024 * 1024;

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
      // Bounds memory while decoding; compressImage does the real shrinking.
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (file == null) return null;
    final raw = await file.readAsBytes();
    if (raw.length > maxBytes) {
      throw const AppException(
        'That photo is too large. Pick one under 20 MB.',
      );
    }
    final Uint8List bytes;
    try {
      bytes = await compressImage(raw, CompressionPolicy.of(kind));
    } catch (_) {
      throw const AppException('Couldn\'t read that photo. Try another one.');
    }
    final folder = switch (kind) {
      ImageKind.avatar => 'users/$uid/avatar',
      ImageKind.gallery => 'users/$uid/photos',
      ImageKind.cover => 'activities/$uid/covers',
    };
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
