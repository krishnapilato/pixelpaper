import 'dart:io';
import 'dart:ui' as ui;

import '../local/capture_dao.dart';
import '../models/capture.dart';
import '../services/storage_service.dart';

/// The raw-image gallery. Same reconcile-with-disk contract as the archive.
class CaptureRepository {
  CaptureRepository({required CaptureDao dao, required StorageService storage})
    : _dao = dao,
      _storage = storage;

  final CaptureDao _dao;
  final StorageService _storage;

  static const Set<String> _imageExtensions = {'.jpg', '.jpeg', '.png'};

  Future<List<Capture>> load() async {
    final rows = await _dao.all();
    final dir = await _storage.capturesDir();
    final files = await _storage.listFiles(dir, _imageExtensions);
    final onDisk = {for (final file in files) file.path: file};

    final missing = rows.where((row) => !onDisk.containsKey(row.path));
    if (missing.isNotEmpty) await _dao.deleteIds(missing.map((r) => r.id));

    final known = await _dao.knownPaths();
    final adopted = <Capture>[];
    for (final file in files.where((f) => !known.contains(f.path))) {
      // Bulk adoption skips pixel dimensions on purpose: reading a few hundred
      // JPEGs just to fill a label that only the full-screen preview shows
      // would turn the first launch after a restore into a stall.
      adopted.add(await _describe(file, CaptureSource.camera, measure: false));
    }
    if (adopted.isNotEmpty) await _dao.insertMissing(adopted);

    final fresh = await _dao.all();
    return fresh
        .where((row) => onDisk.containsKey(row.path))
        .toList(growable: false);
  }

  /// Moves a freshly taken photo into the gallery. The source is a temporary
  /// file owned by the camera plugin, so it is copied and then removed.
  Future<Capture> adopt(File source, {required CaptureSource origin}) async {
    final dir = await _storage.capturesDir();
    final stamp = DateTime.now();
    final target = await _storage.uniqueFile(
      dir,
      'IMG_${stamp.millisecondsSinceEpoch}',
      '.jpg',
    );
    await source.copy(target.path);
    try {
      if (await source.exists()) await source.delete();
    } on FileSystemException {
      // The plugin's temp file is disposable; failing to delete is harmless.
    }

    final capture = await _describe(target, origin);
    final id = await _dao.insert(capture);
    return Capture(
      id: id,
      path: capture.path,
      createdAt: capture.createdAt,
      sizeBytes: capture.sizeBytes,
      source: capture.source,
      width: capture.width,
      height: capture.height,
    );
  }

  Future<void> delete(Iterable<Capture> captures) async {
    final list = captures.toList(growable: false);
    if (list.isEmpty) return;
    await _dao.deleteIds(list.map((c) => c.id));
    await _storage.deleteFiles(list.map((c) => c.path));
  }

  /// Re-reads size and pixel dimensions after the image editor overwrote a
  /// photo in place.
  ///
  /// The path never changes, so without this the row — and every cache keyed
  /// on it — would still describe the picture the user just replaced.
  Future<Capture> remeasure(Capture capture) async {
    final measured = await _describe(capture.file, capture.source);
    final updated = capture.copyWith(
      sizeBytes: measured.sizeBytes,
      width: measured.width,
      height: measured.height,
    );
    await _dao.update(updated);
    return updated;
  }

  /// Reads size and pixel dimensions.
  ///
  /// [ui.ImageDescriptor.encoded] parses the header only — decoding a 12 MP
  /// photo just to learn its width would cost ~48 MB of heap per image.
  Future<Capture> _describe(
    File file,
    CaptureSource source, {
    bool measure = true,
  }) async {
    final stat = await file.stat();
    var width = 0;
    var height = 0;

    if (measure) {
      ui.ImmutableBuffer? buffer;
      ui.ImageDescriptor? descriptor;
      try {
        buffer = await ui.ImmutableBuffer.fromUint8List(
          await file.readAsBytes(),
        );
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        width = descriptor.width;
        height = descriptor.height;
      } on Object {
        // Unreadable or unsupported encoding: dimensions stay unknown.
      } finally {
        descriptor?.dispose();
        buffer?.dispose();
      }
    }

    return Capture(
      id: 0,
      path: file.path,
      createdAt: stat.modified,
      sizeBytes: stat.size,
      source: source,
      width: width,
      height: height,
    );
  }
}
