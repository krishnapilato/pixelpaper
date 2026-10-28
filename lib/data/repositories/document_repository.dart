import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as p;

import '../../core/utils/formatters.dart';
import '../local/document_dao.dart';
import '../models/document_page.dart';
import '../models/rows.dart';
import '../models/scanned_document.dart';
import '../services/pdf_service.dart';
import '../services/scanner_service.dart';
import '../services/storage_service.dart';
import 'capture_repository.dart';

/// The archive: rows for metadata, the file system for existence.
class DocumentRepository {
  DocumentRepository({
    required DocumentDao dao,
    required StorageService storage,
    required PdfService pdf,
    required CaptureRepository images,
  }) : _dao = dao,
       _storage = storage,
       _pdf = pdf,
       _images = images;

  final DocumentDao _dao;
  final StorageService _storage;
  final PdfService _pdf;
  final CaptureRepository _images;

  Future<List<ScannedDocument>> load() async {
    final files = await _storage.listFiles(
      await _storage.documentsDir(),
      const {'.pdf'},
    );
    final onDisk = {for (final file in files) file.path: file};

    final rows = await _dao.all();
    final missing = <ScannedDocument>[];
    for (final row in rows) {
      final exists = row.isAlbum
          ? await row.directory.exists()
          : onDisk.containsKey(row.path);
      if (!exists) missing.add(row);
    }
    await _dao.deleteIds(missing.map((row) => row.id));
    await _storage.deletePreviewsOf(missing.map((row) => row.path));

    final known = await _dao.knownPaths();
    final adopted = <ScannedDocument>[];
    for (final file in files) {
      if (known.contains(file.path)) continue;
      final stat = await file.stat();
      adopted.add(
        ScannedDocument(
          id: 0,
          path: file.path,
          title: Fmt.stem(file.path),
          createdAt: stat.modified.toMillis,
          updatedAt: stat.modified.toMillis,
          pageCount: await _pdf.pageCount(file),
          sizeBytes: stat.size,
        ),
      );
    }
    await _dao.insertMissing(adopted);

    final result = <ScannedDocument>[];
    for (final row in await _dao.all()) {
      final file = onDisk[row.path];
      if (row.isAlbum || file == null) {
        if (row.isAlbum) result.add(row);
        continue;
      }
      final stat = await file.stat();
      if (stat.size == row.sizeBytes) {
        result.add(row);
        continue;
      }
      final updated = row.copyWith(
        sizeBytes: stat.size,
        updatedAt: stat.modified.toMillis,
      );
      await _dao.update(updated);
      result.add(updated);
    }
    return result;
  }

  Future<ScannedDocument?> byId(int id) => _dao.byId(id);

  /// Files the scanner's PDF and deletes everything the scanner left behind.
  Future<ScannedDocument> importScan(ScanResult scan, String title) async {
    try {
      final target = await _storage.uniqueFile(
        await _storage.documentsDir(),
        title,
        '.pdf',
      );
      await _storage.copyAtomic(scan.pdf, target);
      final thumbnail = scan.pageImages.isEmpty
          ? null
          : await _pdf.adoptThumbnail(scan.pageImages.first, target.path);
      return await _insertPdf(target, scan.pageCount, thumbnail?.path);
    } finally {
      await discardScan(scan);
    }
  }

  Future<void> discardScan(ScanResult scan) => _storage.deleteFiles([
    scan.pdf.path,
    for (final image in scan.pageImages) image.path,
  ]);

  Future<ScannedDocument> _insertPdf(
    File target,
    int pageCount,
    String? thumbnailPath,
  ) async {
    final stat = await target.stat();
    final draft = ScannedDocument(
      id: 0,
      path: target.path,
      title: Fmt.stem(target.path),
      createdAt: stat.modified.toMillis,
      updatedAt: stat.modified.toMillis,
      pageCount: pageCount,
      sizeBytes: stat.size,
      thumbnailPath: thumbnailPath,
    );
    try {
      return draft.copyWith(id: await _dao.insert(draft));
    } on Object {
      await _storage.deleteFiles([target.path, ?thumbnailPath]);
      rethrow;
    }
  }

  /// A new album holding byte-exact copies of [imagePaths]. Either every page
  /// and the row exist afterwards, or nothing does.
  Future<ScannedDocument> createAlbum({
    required List<String> imagePaths,
    required String title,
  }) async {
    final dir = await _storage.newAlbumDir();
    try {
      final now = DateTime.now().toMillis;
      final pages = <DocumentPage>[];
      var bytes = 0;
      for (final source in imagePaths) {
        final page = await _copyPage(dir, File(source), sourcePath: source);
        bytes += await page.fileIn(dir).length();
        pages.add(page);
      }
      if (pages.isEmpty) throw StateError('No readable image');

      final draft = ScannedDocument(
        id: 0,
        path: dir.path,
        kind: DocumentKind.album,
        title: Fmt.safeFileName(title),
        createdAt: now,
        updatedAt: now,
        pageCount: pages.length,
        sizeBytes: bytes,
        thumbnailPath: pages.first.fileIn(dir).path,
      );
      return draft.copyWith(id: await _dao.insertAlbum(draft, pages));
    } on Object {
      await _storage.deleteTree(dir);
      rethrow;
    }
  }

  Future<List<DocumentPage>> pagesOf(ScannedDocument document) =>
      _dao.pagesOf(document.id);

  Future<Set<String>> pagedCapturePaths() => _dao.pageSourcePaths();

  /// Runs [use] with the document as a PDF file. An album's PDF is built for
  /// the occasion and deleted as soon as [use] returns.
  Future<T> withPdf<T>(
    ScannedDocument document,
    Future<T> Function(File pdf) use,
  ) async {
    if (!document.isAlbum) return use(document.file);
    final pages = await _dao.pagesOf(document.id);
    final dir = document.directory;
    final bytes = await _pdf.composeFromImages([
      for (final page in pages) page.fileIn(dir).path,
    ]);
    final target = await _storage.writeAtomic(
      await _storage.exportFile(document.title, '.pdf'),
      bytes,
    );
    try {
      return await use(target);
    } finally {
      await _storage.deleteFiles([target.path]);
    }
  }

  /// Writes the album's new page list; files no page refers to any more are
  /// deleted.
  Future<ScannedDocument> savePages(
    ScannedDocument document,
    List<DocumentPage> pages,
  ) async {
    if (pages.isEmpty) throw ArgumentError.value(pages, 'pages', 'empty');
    final dir = document.directory;
    var bytes = 0;
    for (final page in pages) {
      final file = page.fileIn(dir);
      if (!await file.exists()) throw StateError('Missing ${page.fileName}');
      bytes += await file.length();
    }
    final updated = document.copyWith(
      pageCount: pages.length,
      sizeBytes: bytes,
      updatedAt: DateTime.now().toMillis,
      thumbnailPath: pages.first.fileIn(dir).path,
    );
    await _dao.replacePages(updated, pages);
    await sweepAlbum(updated);
    return updated;
  }

  /// Deletes files inside the album that no saved page refers to: what an
  /// editor session added and then discarded, or a crash left behind.
  Future<void> sweepAlbum(ScannedDocument document) async {
    if (!document.isAlbum) return;
    final kept = {
      for (final page in await _dao.pagesOf(document.id)) page.fileName,
    };
    final dir = document.directory;
    if (!await dir.exists()) return;
    final orphans = <String>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && !kept.contains(p.basename(entity.path))) {
        orphans.add(entity.path);
      }
    }
    await _storage.deleteFiles(orphans);
  }

  /// Copies an image into the album as an unsaved page; [consume] deletes the
  /// source afterwards when it is one of the app's temporary files.
  Future<DocumentPage> addPageFile(
    ScannedDocument document,
    String source, {
    bool consume = false,
  }) async {
    final page = await _copyPage(document.directory, File(source));
    if (consume && !p.isWithin(document.path, source)) {
      final base = await _storage.roots;
      if (p.isWithin(base.temporary.path, source)) {
        await _storage.deleteFiles([source]);
      }
    }
    return page;
  }

  /// Writes an image that exists only in memory as an unsaved page.
  Future<DocumentPage> addPageBytes(
    ScannedDocument document,
    Uint8List bytes,
  ) async {
    final archived = await _images.archivalBytes(bytes);
    final target = await _storage.newPageFile(
      document.directory,
      archived.format.extension,
    );
    await _storage.writeAtomic(target, archived.bytes);
    return _pageFor(target);
  }

  Future<DocumentPage> _copyPage(
    Directory dir,
    File source, {
    String? sourcePath,
  }) async {
    if (await source.length() > CaptureRepository.maxImageBytes) {
      throw const InvalidImageException('too large');
    }
    final archived = await _images.archivalBytes(await source.readAsBytes());
    final target = await _storage.newPageFile(dir, archived.format.extension);
    await _storage.writeAtomic(target, archived.bytes);
    return _pageFor(target, sourcePath: sourcePath);
  }

  DocumentPage _pageFor(File target, {String? sourcePath}) => DocumentPage(
    id: 0,
    documentId: 0,
    fileName: p.basename(target.path),
    position: 0,
    createdAt: DateTime.now().toMillis,
    sourcePath: sourcePath,
  );

  /// Null when the name is taken. An album is renamed in its row only.
  Future<ScannedDocument?> rename(
    ScannedDocument document,
    String title,
  ) async {
    final clean = Fmt.safeFileName(title, fallback: '');
    if (clean.isEmpty) return null;
    if (document.isAlbum) {
      final updated = document.copyWith(
        title: clean,
        updatedAt: DateTime.now().toMillis,
      );
      await _dao.update(updated);
      return updated;
    }
    final renamed = await _storage.rename(document.file, clean);
    if (renamed == null) return null;
    final updated = document.copyWith(
      path: renamed.path,
      title: Fmt.stem(renamed.path),
    );
    try {
      await _dao.update(updated);
    } on Object {
      await renamed.rename(document.path);
      rethrow;
    }
    await _storage.deletePreviewsOf([document.path]);
    return updated;
  }

  /// Rows, files, album directories and cached renderings, for good.
  Future<void> deleteForever(Iterable<ScannedDocument> documents) async {
    final list = documents.toList(growable: false);
    if (list.isEmpty) return;
    await _dao.deleteIds(list.map((d) => d.id));
    for (final document in list) {
      if (document.isAlbum) {
        await _storage.deleteTree(document.directory);
      } else {
        await _storage.deleteFiles([document.path, ?document.thumbnailPath]);
      }
    }
    await _storage.deletePreviewsOf(list.map((d) => d.path));
  }

  /// Records a rewritten PDF: its size and page count. The old thumbnail is
  /// dropped and the list renders a new one when it next shows the document.
  Future<ScannedDocument> refresh(
    ScannedDocument document, {
    required int pageCount,
  }) async {
    final stat = await document.file.stat();
    await _storage.deleteFiles([?document.thumbnailPath]);
    final updated = document.copyWith(
      sizeBytes: stat.size,
      updatedAt: stat.modified.toMillis,
      pageCount: pageCount,
      clearThumbnail: true,
    );
    await _dao.update(updated);
    return updated;
  }
}
