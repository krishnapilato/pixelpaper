import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/utils/formatters.dart';
import '../local/document_dao.dart';
import '../models/document_page.dart';
import '../models/scanned_document.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';

/// The archive: sqflite rows for metadata, the file system for truth about
/// what actually exists. Every read reconciles the two, so a file restored
/// from a backup shows up and a row whose file vanished disappears.
class DocumentRepository {
  /// Private named parameters (Dart 3.10+): the fields stay private while the
  /// call site still reads `DocumentRepository(dao: …, storage: …, pdf: …)`.
  DocumentRepository({
    required DocumentDao dao,
    required StorageService storage,
    required PdfService pdf,
  })  : _dao = dao,
        _storage = storage,
        _pdf = pdf;

  final DocumentDao _dao;
  final StorageService _storage;
  final PdfService _pdf;

  static const Set<String> _pdfExtension = {'.pdf'};

  Future<List<ScannedDocument>> load() async {
    final rows = await _dao.all();
    final dir = await _storage.documentsDir();
    final files = await _storage.listFiles(dir, _pdfExtension);
    final onDisk = {for (final file in files) file.path: file};

    // An album's path is a directory, so it is never in [onDisk] and the
    // reconcile below would delete every album on the first read. Albums are
    // checked against their own directory instead.
    final albums = rows.where((row) => row.isAlbum).toList(growable: false);
    final liveAlbums = <int>{};
    for (final album in albums) {
      if (await album.directory.exists()) liveAlbums.add(album.id);
    }

    final missing = rows.where(
      (row) => row.isAlbum
          ? !liveAlbums.contains(row.id)
          : !onDisk.containsKey(row.path),
    );
    if (missing.isNotEmpty) {
      await _dao.deleteIds(missing.map((row) => row.id));
      await _storage.deleteFiles(
        missing.map((row) => row.thumbnailPath).whereType<String>(),
      );
    }

    // Every path the table knows, trashed rows included: a file sitting in
    // the bin must not be adopted back as a brand-new document.
    final known = await _dao.knownPaths();
    final adopted = <ScannedDocument>[];
    for (final file in files.where((f) => !known.contains(f.path))) {
      final stat = await file.stat();
      adopted.add(
        ScannedDocument(
          id: 0,
          path: file.path,
          title: Fmt.stem(file.path),
          createdAt: stat.modified,
          updatedAt: stat.modified,
          pageCount: await _pdf.pageCount(file),
          sizeBytes: stat.size,
        ),
      );
    }
    if (adopted.isNotEmpty) await _dao.insertMissing(adopted);

    // Re-read so adopted rows carry their assigned ids, then refresh the size
    // of anything edited outside the app.
    final fresh = await _dao.all();
    final result = <ScannedDocument>[];
    for (final row in fresh) {
      if (row.isAlbum) {
        // Nothing outside the app writes into an album, so its row is already
        // right: the page table and the size were updated by whoever changed
        // it. Re-walking a dozen files per album on every archive read would
        // cost more than it could ever catch.
        result.add(row);
        continue;
      }
      final file = onDisk[row.path];
      if (file == null) continue;
      final stat = await file.stat();
      if (stat.size != row.sizeBytes) {
        final updated = row.copyWith(
          sizeBytes: stat.size,
          updatedAt: stat.modified,
        );
        await _dao.update(updated);
        result.add(updated);
      } else {
        result.add(row);
      }
    }
    return result;
  }

  Future<ScannedDocument?> byId(int id) => _dao.byId(id);

  /// Files the PDF produced by the ML Kit scanner. The scanner writes into a
  /// cache directory it owns, so the copy has to happen before anything else.
  Future<ScannedDocument> importScan({
    required File pdfSource,
    required String title,
    required int pageCount,
    File? thumbnailSource,
  }) async {
    final dir = await _storage.documentsDir();
    final target = await _storage.uniqueFile(dir, title, '.pdf');
    await pdfSource.copy(target.path);

    final stat = await target.stat();
    String? thumbnailPath;
    if (thumbnailSource != null && await thumbnailSource.exists()) {
      // The scanner already handed us a clean page image — reuse it instead of
      // rasterising the PDF we just wrote.
      final thumb = await _pdf.adoptThumbnail(
        thumbnailSource,
        '${target.path}|${stat.modified.millisecondsSinceEpoch}|thumb',
      );
      thumbnailPath = thumb?.path;
    }

    return _persistNew(
      target: target,
      title: Fmt.stem(target.path),
      pageCount: pageCount,
      stat: stat,
      thumbnailPath: thumbnailPath,
    );
  }

  /// Builds a PDF out of gallery captures.
  Future<ScannedDocument> createFromImages({
    required List<String> imagePaths,
    required String title,
  }) async {
    final bytes = await _pdf.composeFromImages(imagePaths);
    final dir = await _storage.documentsDir();
    final target = await _storage.uniqueFile(dir, title, '.pdf');
    await target.writeAsBytes(bytes, flush: true);

    final stat = await target.stat();

    // Page one is a photo we already have on disk: copy it. Rasterising the
    // PDF instead — which is what this did — meant parsing a fifty-megabyte
    // file and rendering a page out of it just to fill a 52-pixel tile, and on
    // twelve full-resolution photos that took minutes with the progress
    // spinner sitting there. [importScan] had this right all along.
    final thumb = await _pdf.adoptThumbnail(
      File(imagePaths.first),
      '${target.path}|${stat.modified.millisecondsSinceEpoch}|thumb',
    );

    return _persistNew(
      target: target,
      title: Fmt.stem(target.path),
      pageCount: imagePaths.length,
      stat: stat,
      thumbnailPath: thumb?.path,
    );
  }

  // --- Albums --------------------------------------------------------------

  /// Builds a document out of images without building a PDF.
  ///
  /// The photos are copied byte for byte — no re-encoding, no resizing, so the
  /// archive holds exactly what the camera produced. The PDF is a thing the
  /// user exports later, not a thing the app makes behind their back.
  ///
  /// What this replaces: composing twelve full-resolution photos into a PDF
  /// took fifteen seconds and wrote a second, fifty-megabyte copy of the same
  /// pixels, and every later reorder rewrote that file from scratch.
  Future<ScannedDocument> createAlbumFromImages({
    required List<String> imagePaths,
    required String title,
  }) async {
    final dir = await _storage.newAlbumDir();

    final pages = <DocumentPage>[];
    var bytes = 0;
    final now = DateTime.now();
    for (final source in imagePaths) {
      final file = File(source);
      if (!await file.exists()) continue;
      final target = await _storage.newPageFile(dir, source);
      await file.copy(target.path);
      bytes += await target.length();
      pages.add(
        DocumentPage(
          id: 0,
          documentId: 0,
          fileName: p.basename(target.path),
          position: pages.length,
          createdAt: now,
        ),
      );
    }

    final document = ScannedDocument(
      id: 0,
      path: dir.path,
      kind: DocumentKind.album,
      title: title,
      createdAt: now,
      updatedAt: now,
      pageCount: pages.length,
      sizeBytes: bytes,
      // Page one is the thumbnail. Nothing is rendered, nothing is resized:
      // the grid decodes it at tile size like every other image in the app.
      thumbnailPath:
          pages.isEmpty ? null : p.join(dir.path, pages.first.fileName),
    );
    final id = await _dao.insert(document);
    await _dao.replacePages(id, pages);
    return (await _dao.byId(id)) ?? document;
  }

  Future<List<DocumentPage>> pagesOf(ScannedDocument document) =>
      _dao.pagesOf(document.id);

  /// The document as a PDF file, ready to be shared, printed or saved.
  ///
  /// A PDF document is already one and is returned untouched. An album is
  /// composed on the spot, at full resolution, into a temporary file — the one
  /// place in the app where a PDF gets built, and the only time the user pays
  /// for it.
  Future<File> exportPdf(ScannedDocument document) async {
    if (!document.isAlbum) return document.file;

    final pages = await _dao.pagesOf(document.id);
    final bytes = await _pdf.composeFromImages([
      for (final page in pages) p.join(document.path, page.fileName),
    ]);

    // Named after the title so the file arrives with a name the recipient can
    // read, and rebuilt each time so it can never be stale.
    final dir = await _storage.exportsDir();
    final target = File(
      p.join(dir.path, '${Fmt.safeFileName(document.title)}.pdf'),
    );
    await target.writeAsBytes(bytes, flush: true);
    return target;
  }

  /// Writes a new page list — a reorder, a deletion, an insertion, or all
  /// three at once.
  ///
  /// Files are not touched: reordering an album is renumbering a column, which
  /// is why it is instant however large the pages are. Any page dropped from
  /// the list has its file deleted, because an album owns its images and a
  /// file nothing points at is only waste.
  Future<ScannedDocument> savePages(
    ScannedDocument document,
    List<DocumentPage> pages,
  ) async {
    final before = await _dao.pagesOf(document.id);
    final keeping = {for (final page in pages) page.fileName};
    final dropped = before
        .where((page) => !keeping.contains(page.fileName))
        .map((page) => p.join(document.path, page.fileName));

    await _dao.replacePages(document.id, pages);
    await _storage.deleteFiles(dropped);

    var bytes = 0;
    for (final page in pages) {
      final file = File(p.join(document.path, page.fileName));
      if (await file.exists()) bytes += await file.length();
    }

    final updated = document.copyWith(
      pageCount: pages.length,
      sizeBytes: bytes,
      updatedAt: DateTime.now(),
      thumbnailPath: pages.isEmpty
          ? null
          : p.join(document.path, pages.first.fileName),
      clearThumbnail: pages.isEmpty,
    );
    await _dao.update(updated);
    return updated;
  }

  /// Copies [source] into the album and hands back the page for it, unsaved.
  ///
  /// Unsaved on purpose: the editor holds the whole list and writes it once,
  /// so adding a page and moving it are the same single write.
  Future<DocumentPage> addPageFile(
    ScannedDocument document,
    String source,
  ) async {
    final dir = Directory(document.path);
    final target = await _storage.newPageFile(dir, source);
    await File(source).copy(target.path);
    return DocumentPage(
      id: 0,
      documentId: document.id,
      fileName: p.basename(target.path),
      position: 0,
      createdAt: DateTime.now(),
    );
  }

  /// Same, for an image that only exists in memory — a page the image editor
  /// just produced, or a blank sheet.
  Future<DocumentPage> addPageBytes(
    ScannedDocument document,
    List<int> bytes, {
    String extension = '.jpg',
  }) async {
    final dir = Directory(document.path);
    final target = await _storage.newPageFile(dir, 'page$extension');
    await target.writeAsBytes(bytes, flush: true);
    return DocumentPage(
      id: 0,
      documentId: document.id,
      fileName: p.basename(target.path),
      position: 0,
      createdAt: DateTime.now(),
    );
  }

  Future<ScannedDocument> _persistNew({
    required File target,
    required String title,
    required int pageCount,
    required FileStat stat,
    String? thumbnailPath,
  }) async {
    final document = ScannedDocument(
      id: 0,
      path: target.path,
      title: title,
      createdAt: stat.modified,
      updatedAt: stat.modified,
      pageCount: pageCount,
      sizeBytes: stat.size,
      thumbnailPath: thumbnailPath,
    );
    final id = await _dao.insert(document);
    return (await _dao.byId(id)) ?? document;
  }

  /// Returns null when the name is already taken.
  ///
  /// An album is renamed by editing its row and nothing else: its directory is
  /// named from the clock precisely so that a title can change freely without
  /// a dozen page files having to move.
  Future<ScannedDocument?> rename(ScannedDocument document, String title) async {
    if (document.isAlbum) {
      final clean = Fmt.safeFileName(title);
      if (clean.isEmpty) return null;
      final updated = document.copyWith(
        title: clean,
        updatedAt: DateTime.now(),
      );
      await _dao.update(updated);
      return updated;
    }

    final renamed = await _storage.rename(document.file, title);
    if (renamed == null) return null;

    final updated = document.copyWith(
      path: renamed.path,
      title: Fmt.stem(renamed.path),
    );
    await _dao.update(updated);
    return updated;
  }

  Future<void> delete(Iterable<ScannedDocument> documents) async {
    final list = documents.toList(growable: false);
    if (list.isEmpty) return;

    // Album pages go with their album. The rows would fall to the foreign
    // key's ON DELETE CASCADE anyway; the files would not.
    final albums = list.where((d) => d.isAlbum).toList(growable: false);
    await _dao.deleteIds(list.map((d) => d.id));

    await _storage.deleteFiles([
      // A thumbnail path inside an album directory is one of its own pages,
      // removed with the directory below; listing it here would be harmless
      // but the filter keeps the intent readable.
      ...list.where((d) => !d.isAlbum).map((d) => d.path),
      ...list
          .where((d) => !d.isAlbum)
          .map((d) => d.thumbnailPath)
          .whereType<String>(),
    ]);
    for (final album in albums) {
      try {
        final dir = album.directory;
        if (await dir.exists()) await dir.delete(recursive: true);
      } on FileSystemException {
        // Already gone, or held by the system. The row is what matters.
      }
    }
  }

  /// Refreshes size, page count and thumbnail after the editor wrote the file.
  Future<ScannedDocument> refresh(ScannedDocument document) async {
    final stat = await document.file.stat();
    final updated = document.copyWith(
      sizeBytes: stat.size,
      updatedAt: stat.modified,
      pageCount: await _pdf.pageCount(document.file),
      thumbnailPath: (await _pdf.thumbnail(document.file))?.path,
    );
    await _dao.update(updated);
    return updated;
  }
}
