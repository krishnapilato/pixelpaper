import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/utils/formatters.dart';

/// The two roots the app may write to: private documents and private cache.
class StorageRoots {
  const StorageRoots({required this.documents, required this.temporary});

  final Directory documents;
  final Directory temporary;
}

typedef StorageRootsLoader = Future<StorageRoots> Function();

Future<StorageRoots> _platformRoots() async => StorageRoots(
  documents: await getApplicationDocumentsDirectory(),
  temporary: await getTemporaryDirectory(),
);

/// Every path in the app is built and every file is removed here.
///
///   documents/pdf/       PDF documents
///   documents/albums/    one directory per album, holding its pages
///   documents/captures/  full-resolution photos
///   cache/previews/      rendered pages, regenerable
///   cache/exports/       PDFs and photos on their way out, deleted after use
///
/// Nothing outside the two roots is ever deleted, whatever a database row says.
class StorageService {
  StorageService({StorageRootsLoader? roots})
    : _loadRoots = roots ?? _platformRoots;

  final StorageRootsLoader _loadRoots;
  Future<StorageRoots>? _roots;
  final Map<String, Future<Directory>> _dirs = {};

  static const int previewCacheBudgetBytes = 64 * 1024 * 1024;
  static const int cacheNudgeBytes = 20 * 1024 * 1024;

  /// Cache folders other plugins leave copies of the user's files in.
  static const List<String> _foreignCaches = ['share_plus', 'camera'];

  Future<StorageRoots> get roots => _roots ??= _loadRoots();

  Future<Directory> documentsDir() => _dir('pdf', temporary: false);
  Future<Directory> albumsDir() => _dir('albums', temporary: false);
  Future<Directory> capturesDir() => _dir('captures', temporary: false);
  Future<Directory> previewsDir() => _dir('previews', temporary: true);
  Future<Directory> exportsDir() => _dir('exports', temporary: true);

  Future<Directory> _dir(String name, {required bool temporary}) =>
      _dirs[name] ??= () async {
        final base = await roots;
        final dir = Directory(
          p.join((temporary ? base.temporary : base.documents).path, name),
        );
        await dir.create(recursive: true);
        return dir;
      }();

  /// True when [path] lies strictly inside one of the app's own roots.
  Future<bool> owns(String path) async {
    final base = await roots;
    final target = p.normalize(p.absolute(path));
    return p.isWithin(p.normalize(base.documents.path), target) ||
        p.isWithin(p.normalize(base.temporary.path), target);
  }

  Future<Directory> newAlbumDir() async {
    final parent = await albumsDir();
    var stamp = DateTime.now().microsecondsSinceEpoch;
    while (true) {
      final candidate = Directory(p.join(parent.path, 'a$stamp'));
      if (!await candidate.exists()) {
        await candidate.create();
        return candidate;
      }
      stamp++;
    }
  }

  /// A free, opaque name inside [albumDir]; only the extension is kept.
  Future<File> newPageFile(Directory albumDir, String extension) async {
    final ext = _safeExtension(extension);
    var stamp = DateTime.now().microsecondsSinceEpoch;
    while (true) {
      final candidate = File(p.join(albumDir.path, 'p$stamp$ext'));
      if (!await candidate.exists()) return candidate;
      stamp++;
    }
  }

  /// A free path for [name] inside [dir]; appends " (2)", " (3)", … on clash.
  Future<File> uniqueFile(Directory dir, String name, String extension) async {
    final safe = Fmt.safeFileName(name);
    final ext = _safeExtension(extension);
    var candidate = File(p.join(dir.path, '$safe$ext'));
    for (var counter = 2; await candidate.exists(); counter++) {
      candidate = File(p.join(dir.path, '$safe ($counter)$ext'));
    }
    return candidate;
  }

  /// Renames [file] within its folder; null when the name is taken.
  Future<File?> rename(File file, String newName) async {
    final target = p.join(
      file.parent.path,
      '${Fmt.safeFileName(newName)}${p.extension(file.path)}',
    );
    if (target == file.path) return file;
    if (await File(target).exists()) return null;
    return file.rename(target);
  }

  /// Writes [bytes] next to [target] and renames over it, so a crash or a full
  /// disk leaves either the old file or the new one, never half of either.
  Future<File> writeAtomic(File target, List<int> bytes) async {
    final part = File(
      '${target.path}.${DateTime.now().microsecondsSinceEpoch}.part',
    );
    try {
      await part.writeAsBytes(bytes, flush: true);
      return await part.rename(target.path);
    } on Object {
      await _deleteQuietly(part);
      rethrow;
    }
  }

  /// Copies [source] to [target] through a temporary sibling.
  Future<File> copyAtomic(File source, File target) async {
    final part = File(
      '${target.path}.${DateTime.now().microsecondsSinceEpoch}.part',
    );
    try {
      await source.copy(part.path);
      return await part.rename(target.path);
    } on Object {
      await _deleteQuietly(part);
      rethrow;
    }
  }

  Future<void> deleteFiles(Iterable<String> paths) async {
    for (final path in paths.toSet()) {
      if (!await owns(path)) continue;
      await _deleteQuietly(File(path));
    }
  }

  Future<void> deleteTree(Directory dir) async {
    if (!await owns(dir.path)) return;
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException {
      return;
    }
  }

  Future<List<File>> listFiles(Directory dir, Set<String> extensions) async {
    if (!await dir.exists()) return const [];
    final files = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File &&
          extensions.contains(p.extension(entity.path).toLowerCase())) {
        files.add(entity);
      }
    }
    return files;
  }

  /// A file in the export area named for the recipient, removed by
  /// [clearExports] or the next start.
  Future<File> exportFile(String name, String extension) async =>
      uniqueFile(await exportsDir(), name, extension);

  Future<void> clearExports() async {
    final dir = await exportsDir();
    await for (final entity in dir.list(followLinks: false)) {
      try {
        await entity.delete(recursive: true);
      } on FileSystemException {
        continue;
      }
    }
  }

  /// Removes what earlier sessions left in the cache: exports, plugin copies
  /// of shared files, half-written `.part` files in the library.
  Future<void> clearTransient() async {
    await clearExports();
    final base = await roots;
    for (final name in _foreignCaches) {
      await deleteTree(Directory(p.join(base.temporary.path, name)));
    }
    for (final dir in [await documentsDir(), await capturesDir()]) {
      for (final part in await listFiles(dir, const {'.part'})) {
        await _deleteQuietly(part);
      }
    }
  }

  /// The cache file for one rendering of [documentPath]; its name starts with
  /// the document's own hash so every rendering can be dropped with it.
  Future<File> previewFile(String documentPath, String variant) async {
    final dir = await previewsDir();
    return File(
      p.join(dir.path, '${_hash(documentPath)}_${_hash(variant)}.png'),
    );
  }

  Future<void> deletePreviewsOf(Iterable<String> documentPaths) async {
    final prefixes = {for (final path in documentPaths) '${_hash(path)}_'};
    if (prefixes.isEmpty) return;
    final dir = await previewsDir();
    await for (final entity in dir.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (entity is File && prefixes.any(name.startsWith)) {
        await _deleteQuietly(entity);
      }
    }
  }

  Future<int> previewCacheSize() async => _dirSize(await previewsDir());

  Future<int> librarySize() async =>
      await _dirSize(await documentsDir()) +
      await _dirSize(await albumsDir()) +
      await _dirSize(await capturesDir());

  Future<void> clearPreviewCache() async {
    final dir = await previewsDir();
    _dirs.remove('previews')?.ignore();
    await deleteTree(dir);
    await previewsDir();
  }

  /// Marks a preview as used; app storage is mounted `noatime`, so the
  /// modification stamp is the only least-recently-used record available.
  Future<void> touchPreview(File file) async {
    try {
      final stat = await file.stat();
      if (DateTime.now().difference(stat.modified) <
          const Duration(minutes: 2)) {
        return;
      }
      await file.setLastModified(DateTime.now());
    } on FileSystemException {
      return;
    }
  }

  /// Trims the preview cache to its budget, least recently used first.
  Future<void> prunePreviewCache() async {
    final dir = await previewsDir();
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
      if (await _deleteQuietly(entry.file)) total -= entry.size;
    }
  }

  Future<int> _dirSize(Directory dir) async {
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      try {
        total += await entity.length();
      } on FileSystemException {
        continue;
      }
    }
    return total;
  }

  static String _safeExtension(String extension) {
    final ext = extension.toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(ext) ? ext : '';
  }

  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString().substring(0, 32);

  static Future<bool> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }
}
