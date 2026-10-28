import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../local/capture_dao.dart';
import '../models/capture.dart';
import '../models/rows.dart';
import '../services/image_sanitizer.dart';
import '../services/storage_service.dart';

class InvalidImageException implements Exception {
  const InvalidImageException(this.reason);
  final String reason;

  @override
  String toString() => 'InvalidImageException($reason)';
}

/// Turns pixels the engine could decode into a JPEG; used for formats the
/// archive does not keep (HEIC, WebP, GIF).
typedef Transcoder = Future<Uint8List> Function(Uint8List encoded);

/// The photo gallery: database rows reconciled with the files on disk.
class CaptureRepository {
  CaptureRepository({
    required CaptureDao dao,
    required StorageService storage,
    Transcoder? transcoder,
  }) : _dao = dao,
       _storage = storage,
       _transcode = transcoder ?? transcodeToJpeg;

  final CaptureDao _dao;
  final StorageService _storage;
  final Transcoder _transcode;

  static const int maxImageBytes = 256 << 20;
  static const int maxPixels = 260000000;
  static const Set<String> _extensions = {'.jpg', '.jpeg', '.png'};

  Future<List<Capture>> load() async {
    final dir = await _storage.capturesDir();
    final files = await _storage.listFiles(dir, _extensions);
    final onDisk = {for (final file in files) file.path};

    final rows = await _dao.all();
    await _dao.deleteIds([
      for (final row in rows)
        if (!onDisk.contains(row.path)) row.id,
    ]);

    final known = await _dao.knownPaths();
    final adopted = <Capture>[];
    for (final file in files) {
      if (known.contains(file.path)) continue;
      final stat = await file.stat();
      if (stat.size == 0) continue;
      adopted.add(
        Capture(
          id: 0,
          path: file.path,
          createdAt: stat.modified.toMillis,
          sizeBytes: stat.size,
          source: CaptureSource.camera,
        ),
      );
    }
    await _dao.insertMissing(adopted);

    return [
      for (final row in await _dao.all())
        if (onDisk.contains(row.path)) row,
    ];
  }

  /// Files a photo shot by the camera or handed over by the picker, then
  /// removes the source if it sits in the app's cache.
  Future<Capture> adopt(
    File source, {
    required CaptureSource origin,
    int? folderId,
  }) async {
    final length = await source.length();
    if (length == 0) throw const InvalidImageException('empty');
    if (length > maxImageBytes) throw const InvalidImageException('too large');

    final archived = await archivalBytes(await source.readAsBytes());
    final target = await _storage.uniqueFile(
      await _storage.capturesDir(),
      'IMG_${DateTime.now().millisecondsSinceEpoch}',
      archived.format.extension,
    );
    await _storage.writeAtomic(target, archived.bytes);
    if (await _storage.owns(source.path) && source.path != target.path) {
      await _storage.deleteFiles([source.path]);
    }

    final stat = await target.stat();
    final draft = Capture(
      id: 0,
      path: target.path,
      createdAt: stat.modified.toMillis,
      sizeBytes: stat.size,
      source: origin,
      width: archived.width,
      height: archived.height,
      folderId: folderId,
    );
    try {
      return draft.copyWith(id: await _dao.insert(draft));
    } on Object {
      await _storage.deleteFiles([target.path]);
      rethrow;
    }
  }

  /// Replaces a photo with the image editor's output, atomically. A change of
  /// format moves the file to the matching extension.
  Future<Capture> replaceContent(Capture capture, Uint8List bytes) async {
    final archived = await archivalBytes(bytes);
    final wanted = archived.format.extension;
    final current = p.extension(capture.path).toLowerCase();
    final sameFormat =
        wanted == current || (wanted == '.jpg' && current == '.jpeg');

    if (sameFormat) {
      await _storage.writeAtomic(capture.file, archived.bytes);
      return _remeasured(capture, capture.path, archived);
    }
    final target = await _storage.uniqueFile(
      capture.file.parent,
      p.basenameWithoutExtension(capture.path),
      wanted,
    );
    await _storage.writeAtomic(target, archived.bytes);
    final moved = await _remeasured(capture, target.path, archived);
    await _storage.deleteFiles([capture.path]);
    return moved;
  }

  Future<Capture> _remeasured(
    Capture capture,
    String path,
    ArchivalImage archived,
  ) async {
    final updated = Capture(
      id: capture.id,
      path: path,
      createdAt: capture.createdAt,
      sizeBytes: archived.bytes.length,
      source: capture.source,
      width: archived.width,
      height: archived.height,
      folderId: capture.folderId,
      deletedAt: capture.deletedAt,
    );
    await _dao.update(updated);
    return updated;
  }

  /// Rows and files, for good.
  Future<void> deleteForever(Iterable<Capture> captures) async {
    final list = captures.toList(growable: false);
    if (list.isEmpty) return;
    await _dao.deleteIds(list.map((c) => c.id));
    await _storage.deleteFiles(list.map((c) => c.path));
  }

  /// Copies of [captures] without metadata, alive only while [use] runs.
  Future<T> withShareable<T>(
    List<Capture> captures,
    Future<T> Function(List<File> files) use,
  ) async {
    final copies = <File>[];
    try {
      for (final capture in captures) {
        final bytes = await capture.file.readAsBytes();
        final clean = await compute(_strip, bytes);
        final copy = await _storage.exportFile(
          p.basenameWithoutExtension(capture.path),
          p.extension(capture.path),
        );
        copies.add(await _storage.writeAtomic(copy, clean));
      }
      return await use(copies);
    } finally {
      await _storage.deleteFiles(copies.map((f) => f.path));
    }
  }

  /// [bytes] as the gallery keeps them: JPEG or PNG as given, anything the
  /// engine can decode transcoded to JPEG, everything else refused.
  Future<ArchivalImage> archivalBytes(Uint8List bytes) async {
    final format = ImageSanitizer.sniff(bytes);
    if (format == null) throw const InvalidImageException('unknown format');
    final kept = format.isArchival ? bytes : await _transcode(bytes);
    final keptFormat = format.isArchival ? format : ImageFormat.jpeg;
    final size = await _dimensions(kept);
    if (size != null && size.width * size.height > maxPixels) {
      throw const InvalidImageException('too many pixels');
    }
    return ArchivalImage(
      bytes: kept,
      format: keptFormat,
      width: size?.width ?? 0,
      height: size?.height ?? 0,
    );
  }

  /// Header only: decoding a 12 MP photo to learn its width would cost ~48 MB.
  static Future<({int width, int height})?> _dimensions(Uint8List bytes) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      return (width: descriptor.width, height: descriptor.height);
    } on Object {
      return null;
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}

@immutable
class ArchivalImage {
  const ArchivalImage({
    required this.bytes,
    required this.format,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final ImageFormat format;
  final int width;
  final int height;
}

Uint8List _strip(Uint8List bytes) {
  try {
    return ImageSanitizer.stripMetadata(bytes);
  } on FormatException {
    return bytes;
  }
}

/// Decodes with the platform codec (HEIF and WebP included on Android) and
/// re-encodes as JPEG off the UI isolate.
Future<Uint8List> transcodeToJpeg(Uint8List encoded) async {
  final ui.Codec codec;
  try {
    codec = await ui.instantiateImageCodec(encoded);
  } on Object {
    throw const InvalidImageException('undecodable');
  }
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      if (image.width * image.height > CaptureRepository.maxPixels) {
        throw const InvalidImageException('too many pixels');
      }
      final rgba = await image.toByteData();
      if (rgba == null) throw const InvalidImageException('undecodable');
      return await compute(_encodeJpeg, (
        rgba.buffer.asUint8List(),
        image.width,
        image.height,
      ));
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

Uint8List _encodeJpeg((Uint8List, int, int) raw) {
  final (pixels, width, height) = raw;
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: pixels.buffer,
    numChannels: 4,
  );
  return img.encodeJpg(image, quality: 92);
}
