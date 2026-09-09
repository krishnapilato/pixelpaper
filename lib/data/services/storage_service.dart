import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/utils/formatters.dart';

/// Every path in the app is built here.
///
/// Layout inside the app's private storage (no permissions required, invisible
/// to other apps, removed on uninstall):
///
///   documents/pdf/       generated PDFs
///   documents/albums/    one directory per album, holding its page images
///   documents/captures/  full-resolution photos
///   cache/previews/      rendered page images, safe to delete any time
///
/// Everything the user creates lives here and nowhere else. Exported copies go
/// wherever the user points the system folder picker; the library itself stays
/// private, which is why the app needs no storage permission and why a scanned
/// document never turns up in Google Photos.
class StorageService {
  StorageService();

  Directory? _documents;
  Directory? _albums;
  Directory? _captures;
  Directory? _previews;
  Directory? _exports;

  /// Cap on the preview cache. Beyond this the oldest files are dropped, so a
  /// long session browsing large documents cannot grow storage without bound.
  static const int previewCacheBudgetBytes = 64 * 1024 * 1024;

  Future<Directory> documentsDir() async =>
      _documents ??= await _ensure(await getApplicationDocumentsDirectory(), 'pdf');

  Future<Directory> albumsDir() async =>
      _albums ??= await _ensure(await getApplicationDocumentsDirectory(), 'albums');

  Future<Directory> capturesDir() async =>
      _captures ??= await _ensure(await getApplicationDocumentsDirectory(), 'captures');

  /// A fresh directory for one album.
  ///
  /// Named from the clock, not from the title: an album is renamed by editing
  /// a row, and a title that changes must never mean files that move.
  Future<Directory> newAlbumDir() async {
    final parent = await albumsDir();
    var stamp = DateTime.now().millisecondsSinceEpoch;
    var candidate = Directory(p.join(parent.path, 'a$stamp'));
    while (await candidate.exists()) {
      candidate = Directory(p.join(parent.path, 'a${++stamp}'));
    }
    await candidate.create(recursive: true);
    return candidate;
  }

  /// A free name for a page inside [albumDir], keeping the source extension.
  ///
  /// Page names are opaque and permanent. The order is a column in the
  /// database, so dragging a page never renames a file.
  Future<File> newPageFile(Directory albumDir, String sourcePath) async {
    final extension = p.extension(sourcePath).toLowerCase();
    var stamp = DateTime.now().microsecondsSinceEpoch;
    var candidate = File(p.join(albumDir.path, 'p$stamp$extension'));
    while (await candidate.exists()) {
      candidate = File(p.join(albumDir.path, 'p${++stamp}$extension'));
    }
    return candidate;
  }

  Future<Directory> previewsDir() async =>
      _previews ??= await _ensure(await getTemporaryDirectory(), 'previews');

  /// Where an album's PDF is built before it is shared or printed.
  ///
  /// Temporary on purpose: for an album the PDF is an output, not the
  /// document. Keeping it would put a second copy of every page back on disk,
  /// which is the thing albums exist to stop.
  Future<Directory> exportsDir() async =>
      _exports ??= await _ensure(await getTemporaryDirectory(), 'exports');

  Future<Directory> _ensure(Directory parent, String name) async {
    final dir = Directory(p.join(parent.path, name));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// A free path for [name] inside [dir]; appends " (2)", " (3)", … on clash.
  Future<File> uniqueFile(Directory dir, String name, String extension) async {
    final safe = Fmt.safeFileName(name);
    var candidate = File(p.join(dir.path, '$safe$extension'));
    var counter = 2;
    while (await candidate.exists()) {
      candidate = File(p.join(dir.path, '$safe ($counter)$extension'));
      counter++;
    }
    return candidate;
  }

  /// True when a sibling file of that name already exists — used to reject a
  /// rename before touching the file system.
  Future<bool> nameTaken(File file, String newName) async {
    final target = p.join(
      file.parent.path,
      '${Fmt.safeFileName(newName)}${p.extension(file.path)}',
    );
    if (target == file.path) return false;
    return File(target).exists();
  }

  Future<File?> rename(File file, String newName) async {
    final target = p.join(
      file.parent.path,
      '${Fmt.safeFileName(newName)}${p.extension(file.path)}',
    );
    if (target == file.path) return file;
    if (await File(target).exists()) return null;
    return file.rename(target);
  }

  Future<void> deleteFiles(Iterable<String> paths) async {
    await Future.wait(
      paths.map((path) async {
        final file = File(path);
        try {
          if (await file.exists()) await file.delete();
        } on FileSystemException {
          // Already gone: deleting twice is not an error worth surfacing.
        }
      }),
    );
  }

  Future<List<File>> listFiles(Directory dir, Set<String> extensions) async {
    if (!await dir.exists()) return const [];
    final files = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      if (extensions.contains(p.extension(entity.path).toLowerCase())) {
        files.add(entity);
      }
    }
    return files;
  }

  Future<int> previewCacheSize() async => _dirSize(await previewsDir());

  /// Bytes taken by the documents and photos themselves — the part of the
  /// footprint that clearing the cache will NOT recover.
  Future<int> librarySize() async =>
      await _dirSize(await documentsDir()) +
      await _dirSize(await albumsDir()) +
      await _dirSize(await capturesDir());

  /// Above this, Impostazioni nudges the user towards the cache button: the
  /// previews are all regenerable, so there is never a reason to keep tens of
  /// megabytes of them around on a phone that is filling up.
  static const int cacheNudgeBytes = 20 * 1024 * 1024;

  Future<void> clearPreviewCache() async {
    final dir = await previewsDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      _previews = null;
      await previewsDir();
    }
  }

  /// Records that a preview has just been used.
  ///
  /// This is what turns [prunePreviewCache] from oldest-first into genuinely
  /// least-recently-*used*. Android mounts app storage `noatime`, so nothing
  /// keeps a read timestamp for us; rewriting the modification stamp is the
  /// only record available. Without it, paging back to page 1 of a long
  /// document would find it evicted because it was rendered first.
  ///
  /// Skipped while the stamp is still fresh: otherwise reading a document
  /// would write to disk once per frame, which is the opposite of the point.
  Future<void> touchPreview(File file) async {
    try {
      final stat = await file.stat();
      final age = DateTime.now().difference(stat.modified);
      if (age < const Duration(minutes: 2)) return;
      await file.setLastModified(DateTime.now());
    } on FileSystemException {
      // A preview deleted underneath us needs no bookkeeping.
    }
  }

  /// Trims the preview cache to [previewCacheBudgetBytes], least recently used
  /// first, and stops the moment it is back under budget.
  ///
  /// Called on start-up and again as renders accumulate, so a long reading
  /// session cannot grow the cache without bound between launches. It deletes
  /// only what it must: a sweep after a big document usually removes a handful
  /// of previews and costs a few milliseconds.
  Future<void> prunePreviewCache() async {
    final dir = await previewsDir();
    if (!await dir.exists()) return;

    final entries = <({File file, int size, DateTime modified})>[];
    var total = 0;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      try {
        final stat = await entity.stat();
        entries.add((file: entity, size: stat.size, modified: stat.modified));
        total += stat.size;
      } on FileSystemException {
        continue;
      }
    }
    if (total <= previewCacheBudgetBytes) return;

    entries.sort((a, b) => a.modified.compareTo(b.modified));
    for (final entry in entries) {
      if (total <= previewCacheBudgetBytes) break;
      try {
        await entry.file.delete();
        total -= entry.size;
      } on FileSystemException {
        continue;
      }
    }
  }

  Future<int> _dirSize(Directory dir) async {
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } on FileSystemException {
          continue;
        }
      }
    }
    return total;
  }
}
