import 'package:sqflite/sqflite.dart';

import '../models/document_page.dart';
import '../models/scanned_document.dart';
import 'app_database.dart';

/// Row-level access to the `documents` table. No file-system work happens
/// here — that belongs to the repository.
class DocumentDao {
  DocumentDao(this._database);

  final AppDatabase _database;
  static const String table = 'documents';


  /// Live rows only; the bin has its own query.
  Future<List<ScannedDocument>> all() async {
    final db = await _database.instance;
    final rows = await db.query(
      table,
      where: 'deleted_at IS NULL',
      orderBy: 'updated_at DESC',
    );
    return rows.map(ScannedDocument.fromRow).toList(growable: false);
  }

  Future<List<ScannedDocument>> trashed() async {
    final db = await _database.instance;
    final rows = await db.query(
      table,
      where: 'deleted_at IS NOT NULL',
      orderBy: 'deleted_at DESC',
    );
    return rows.map(ScannedDocument.fromRow).toList(growable: false);
  }

  /// Every path the database knows about, trashed included — used by the
  /// disk reconcile so a trashed file is not adopted back as a new one.
  Future<Set<String>> knownPaths() async {
    final db = await _database.instance;
    final rows = await db.query(table, columns: ['path']);
    return {for (final row in rows) row['path']! as String};
  }

  Future<void> moveToFolder(Iterable<int> ids, int? folderId) async {
    if (ids.isEmpty) return;
    final db = await _database.instance;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.update(
      table,
      {'folder_id': folderId},
      where: 'id IN ($placeholders)',
      whereArgs: ids.toList(growable: false),
    );
  }

  Future<void> setTrashed(Iterable<int> ids, bool trashed) async {
    if (ids.isEmpty) return;
    final db = await _database.instance;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.update(
      table,
      {'deleted_at': trashed ? DateTime.now().millisecondsSinceEpoch : null},
      where: 'id IN ($placeholders)',
      whereArgs: ids.toList(growable: false),
    );
  }

  /// Rows trashed before [cutoff], so their files can be deleted too.
  Future<List<ScannedDocument>> expired(DateTime cutoff) async {
    final db = await _database.instance;
    final rows = await db.query(
      table,
      where: 'deleted_at IS NOT NULL AND deleted_at < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
    return rows.map(ScannedDocument.fromRow).toList(growable: false);
  }

  Future<ScannedDocument?> byId(int id) async {
    final db = await _database.instance;
    final rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : ScannedDocument.fromRow(rows.first);
  }

  Future<ScannedDocument?> byPath(String path) async {
    final db = await _database.instance;
    final rows = await db.query(
      table,
      where: 'path = ?',
      whereArgs: [path],
      limit: 1,
    );
    return rows.isEmpty ? null : ScannedDocument.fromRow(rows.first);
  }

  Future<int> insert(ScannedDocument document) async {
    final db = await _database.instance;
    return db.insert(
      table,
      document.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(ScannedDocument document) async {
    final db = await _database.instance;
    await db.update(
      table,
      document.toRow(),
      where: 'id = ?',
      whereArgs: [document.id],
    );
  }

  Future<void> deleteIds(Iterable<int> ids) async {
    if (ids.isEmpty) return;
    final db = await _database.instance;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete(
      table,
      where: 'id IN ($placeholders)',
      whereArgs: ids.toList(growable: false),
    );
  }

  /// Adds rows for files found on disk that the database does not know about
  /// (e.g. restored from a backup) in a single transaction.
  Future<void> insertMissing(Iterable<ScannedDocument> documents) async {
    if (documents.isEmpty) return;
    final db = await _database.instance;
    await db.transaction((txn) async {
      for (final document in documents) {
        await txn.insert(
          table,
          document.toRow(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  // --- Album pages ---------------------------------------------------------

  static const String pagesTable = 'document_pages';

  Future<List<DocumentPage>> pagesOf(int documentId) async {
    final db = await _database.instance;
    final rows = await db.query(
      pagesTable,
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'position ASC, id ASC',
    );
    return rows.map(DocumentPage.fromRow).toList(growable: false);
  }

  /// Replaces the page list of one album, in a transaction.
  ///
  /// The whole list rather than a diff: a reorder, an insert and a delete all
  /// arrive here as "these are the pages now, in this order", which is a dozen
  /// integer writes and impossible to leave half-applied. Positions are
  /// renumbered from zero so gaps can never accumulate.
  ///
  /// Returns the rows as they were written, so callers get the ids sqflite
  /// assigned to pages that did not exist yet.
  Future<List<DocumentPage>> replacePages(
    int documentId,
    List<DocumentPage> pages,
  ) async {
    final db = await _database.instance;
    final written = <DocumentPage>[];
    await db.transaction((txn) async {
      await txn.delete(
        pagesTable,
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
      for (var i = 0; i < pages.length; i++) {
        final page = pages[i];
        // [documentId] is the authority, not the page's own field: a page
        // being written for the first time was built before its document had
        // an id, and taking the id off the page wrote every row against
        // document 0 — the album then had no pages at all and the reader said
        // it could not open the document it had just created.
        final id = await txn.insert(pagesTable, {
          ...page.toRow(),
          'document_id': documentId,
          'position': i,
        });
        written.add(
          DocumentPage(
            id: id,
            documentId: documentId,
            fileName: page.fileName,
            position: i,
            createdAt: page.createdAt,
            sourcePath: page.sourcePath,
          ),
        );
      }
    });
    return written;
  }

  /// Every gallery file that is already a page of a live document.
  ///
  /// Trashed documents are left out on purpose: their pages still exist, but a
  /// document in the bin is one the user may be about to lose, and calling its
  /// source photo redundant would be a good way to lose both.
  Future<Set<String>> pageSourcePaths() async {
    final db = await _database.instance;
    final rows = await db.rawQuery(
      'SELECT DISTINCT p.source_path AS source_path '
      'FROM $pagesTable p JOIN $table d ON d.id = p.document_id '
      'WHERE p.source_path IS NOT NULL AND d.deleted_at IS NULL',
    );
    return {for (final row in rows) row['source_path']! as String};
  }

  /// Page file names for a set of documents, so deleting albums for good can
  /// find their files without opening every directory.
  Future<Map<int, List<String>>> pageFilesFor(Iterable<int> documentIds) async {
    if (documentIds.isEmpty) return const {};
    final db = await _database.instance;
    final placeholders = List.filled(documentIds.length, '?').join(',');
    final rows = await db.query(
      pagesTable,
      columns: ['document_id', 'file_name'],
      where: 'document_id IN ($placeholders)',
      whereArgs: documentIds.toList(growable: false),
      orderBy: 'position ASC',
    );
    final out = <int, List<String>>{};
    for (final row in rows) {
      out
          .putIfAbsent(row['document_id']! as int, () => <String>[])
          .add(row['file_name']! as String);
    }
    return out;
  }
}
