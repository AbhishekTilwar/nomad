import 'package:flutter/material.dart';

/// Result of [PhotoSourceSheet]: where the photo should come from.
enum PhotoSource { camera, gallery }

/// Bottom sheet: "Take photo" or "Choose from gallery".
class PhotoSourceSheet {
  const PhotoSourceSheet._();

  static Future<PhotoSource?> show(BuildContext context) =>
      showModalBottomSheet<PhotoSource>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(sheet, PhotoSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(sheet, PhotoSource.gallery),
              ),
            ],
          ),
        ),
      );
}
