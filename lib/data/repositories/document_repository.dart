import 'dart:io';

import '../../core/utils/formatters.dart';
import '../local/document_dao.dart';
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

    final missing = rows.where((row) => !onDisk.containsKey(row.path));
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
    return _persistNew(
      target: target,
      title: Fmt.stem(target.path),
      pageCount: imagePaths.length,
      stat: stat,
      thumbnailPath: (await _pdf.thumbnail(target))?.path,
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
  Future<ScannedDocument?> rename(ScannedDocument document, String title) async {
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
    await _dao.deleteIds(list.map((d) => d.id));
    await _storage.deleteFiles([
      ...list.map((d) => d.path),
      ...list.map((d) => d.thumbnailPath).whereType<String>(),
    ]);
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
