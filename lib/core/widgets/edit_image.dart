import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../../data/services/storage_service.dart';
import 'image_editor_config.dart';

/// Decodes only a bounded working image. Original files are never overwritten
/// while opening or cancelling the editor. Cached copies are size-budgeted.
Future<File> imageEditingCopy(File source, StorageService storage) async {
  final stat = await source.stat();
  if (stat.size > 64 * 1024 * 1024) {
    throw const FormatException('Image exceeds the import budget');
  }
  final buffer = await ui.ImmutableBuffer.fromFilePath(source.path);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    const maxEdge = 3200;
    final longest = descriptor.width > descriptor.height
        ? descriptor.width
        : descriptor.height;
    if (longest <= maxEdge) return source;
    final cached = await storage.previewFile(
      source.path,
      'edit|${stat.modified.microsecondsSinceEpoch}|${stat.size}|$maxEdge',
    );
    if (await cached.exists()) return cached;
    final scale = maxEdge / longest;
    codec = await descriptor.instantiateCodec(
      targetWidth: (descriptor.width * scale).round().clamp(1, maxEdge),
      targetHeight: (descriptor.height * scale).round().clamp(1, maxEdge),
    );
    final frame = await codec.getNextFrame();
    try {
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw const FormatException('Unreadable image');
      await storage.writeAtomic(cached, png.buffer.asUint8List());
      unawaited(storage.prunePreviewCache());
    } finally {
      frame.image.dispose();
    }
    return cached;
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

/// All image editing entry points share one configuration and lifecycle.
Future<Uint8List?> editImage(
  BuildContext context,
  File source,
  StorageService storage,
) async {
  Uint8List? edited;
  // Open the route immediately; preparation paints a spinner on this route.
  final prepared = imageEditingCopy(source, storage);
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      builder: (editorContext) => FutureBuilder<File>(
        future: prepared,
        builder: (context, snapshot) {
          final image = snapshot.data;
          if (image != null) {
            return ProImageEditor.file(
              image,
              configs: italianImageEditor,
              callbacks: ProImageEditorCallbacks(
                onImageEditingComplete: (bytes) async => edited = bytes,
                onCloseEditor: (_) => Navigator.of(editorContext).pop(),
              ),
            );
          }
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: snapshot.hasError
                  ? const Icon(Icons.error_outline_rounded)
                  : const CircularProgressIndicator(),
            ),
          );
        },
      ),
    ),
  );
  return edited;
}
