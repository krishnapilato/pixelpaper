import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/widgets/feedback.dart';
import '../../../data/models/capture.dart';
import '../../../data/models/folder.dart';
import '../../camera/presentation/camera_screen.dart';
import '../../folders/application/folders_controller.dart';
import 'gallery_controller.dart';

/// Module B end to end: photos into the gallery, shot or imported.
abstract final class CaptureFlow {
  /// Opens the camera for a roll into the Galleria (the folder on screen).
  ///
  /// The Galleria's own action button does not come through here: it grows
  /// into the camera with a container transform. This is for every other
  /// door — the empty state, the scanner's fallback.
  static Future<void> openCamera(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      cameraRoute<void>(),
    );
  }

  /// Brings existing photos into the app's own gallery, in the folder on
  /// screen.
  ///
  /// Uses the system photo picker, so it needs no storage permission and the
  /// user only ever exposes the images they choose.
  static Future<void> importPhotos(BuildContext context, WidgetRef ref) async {
    final strings = ref.read(stringsProvider);
    final gallery = ref.read(galleryControllerProvider.notifier);
    final folderId = ref.read(currentFolderProvider(FolderKind.capture));
    try {
      final picked = await ImagePicker().pickMultiImage();
      if (picked.isEmpty) return;
      for (final file in picked) {
        await gallery.adopt(
          File(file.path),
          origin: CaptureSource.gallery,
          folderId: folderId,
        );
      }
      if (!context.mounted) return;
      showSnack(
        context,
        strings.plural('camera_imported', picked.length),
        icon: Icons.check_circle_outline_rounded,
      );
    } on Object {
      if (!context.mounted) return;
      showSnack(
        context,
        strings('camera_import_failed'),
        icon: Icons.error_outline_rounded,
      );
    }
  }

  /// Android may stop PixelPaper while the photo picker is in front, when the
  /// phone is short of memory. The photos chosen then are handed over at the
  /// next start: keep them instead of losing them.
  static Future<void> recoverLostPhotos(WidgetRef ref) async {
    if (!Platform.isAndroid) return;
    try {
      final lost = await ImagePicker().retrieveLostData();
      final files = lost.files;
      if (lost.isEmpty || files == null || files.isEmpty) return;
      // Wait for the gallery to load: adopting into an empty list would
      // hide every other photo until the next refresh.
      await ref.read(galleryControllerProvider.future);
      final gallery = ref.read(galleryControllerProvider.notifier);
      for (final file in files) {
        await gallery.adopt(File(file.path), origin: CaptureSource.gallery);
      }
    } on Object {
      // Nothing recoverable: nothing to report.
    }
  }

  /// Clears what a previous session left in the cache: the folder
  /// image_picker copies each imported photo into, and shots the camera
  /// wrote but never got to file. Runs at start-up, when neither can still
  /// be in use; only picker folders that are already empty are removed, so
  /// a photo still waiting to be recovered is never touched.
  static Future<void> clearLeftovers() async {
    if (!Platform.isAndroid) return;
    try {
      final cache = await getTemporaryDirectory();
      await for (final entry in cache.list(followLinks: false)) {
        final name = p.basename(entry.path);
        try {
          if (entry is Directory && name == 'camera') {
            await entry.delete(recursive: true);
          } else if (_pickerName.hasMatch(name)) {
            if (entry is File && name.endsWith('.jpg')) {
              if (await entry.length() == 0) await entry.delete();
            } else if (entry is Directory) {
              // Not recursive: a folder that still holds a file stays.
              await entry.delete();
            }
          }
        } on FileSystemException {
          // Not empty, or in use: it stays.
        }
      }
    } on Object {
      // Housekeeping only; the next start tries again.
    }
  }

  /// image_picker names its files and folders after a random UUID.
  static final RegExp _pickerName = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
  );
}
