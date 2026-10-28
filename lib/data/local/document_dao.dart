import 'package:sqflite/sqflite.dart';

import '../models/document_page.dart';
import '../models/scanned_document.dart';
import 'app_database.dart';
import 'batched.dart';

/// Rows of `documents` and `document_pages`. No file-system work here.
class DocumentDao {
  DocumentDao(this._database);

  final AppDatabase _database;
  static const String table = 'documents';
  static const String pagesTable = 'document_pages';

  Future<List<ScannedDocument>> all() =>
      _query('deleted_at IS NULL', 'updated_at DESC');

  Future<List<ScannedDocument>> trashed() =>
      _query('deleted_at IS NOT NULL', 'deleted_at DESC');

  Future<List<ScannedDocument>> expired(DateTime cutoff) => _query(
    'deleted_at IS NOT NULL AND deleted_at < ?',
    null,
    [cutoff.millisecondsSinceEpoch],
  );

  Future<Set<String>> knownPaths() async {
    final db = await _database.instance;
    final rows = await db.query(table, columns: ['path']);
    return {for (final row in rows) row['path']! as String};
  }

  Future<ScannedDocument?> byId(int id) async {
    final rows = await _query('id = ?', null, [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> moveToFolder(Iterable<int> ids, int? folderId) async =>
      inChunks(await _database.instance, ids, (txn, marks, chunk) async {
        await txn.update(
          table,
          {'folder_id': folderId},
          where: 'id IN ($marks)',
          whereArgs: chunk,
        );
      });

  Future<void> setTrashed(Iterable<int> ids, {required bool trashed}) async {
    final stamp = trashed ? DateTime.now().millisecondsSinceEpoch : null;
    await inChunks(await _database.instance, ids, (txn, marks, chunk) async {
      await txn.update(
        table,
        {'deleted_at': stamp},
        where: 'id IN ($marks)',
        whereArgs: chunk,
      );
    });
  }

  Future<int> insert(ScannedDocument document) async {
    final db = await _database.instance;
    return db.insert(table, document.toRow());
  }

  /// Writes what a document's content defines. Folder and bin state are left
  /// alone: they have their own statements and must not be undone by a stale
  /// copy of the row.
  Future<void> update(ScannedDocument document) async {
    final db = await _database.instance;
    await db.update(
      table,
      {
        'path': document.path,
        'title': document.title,
        'updated_at': document.updatedAt.millisecondsSinceEpoch,
        'page_count': document.pageCount,
        'size_bytes': document.sizeBytes,
        'thumbnail_path': document.thumbnailPath,
      },
      where: 'id = ?',
      whereArgs: [document.id],
    );
  }

  Future<void> deleteIds(Iterable<int> ids) async =>
      inChunks(await _database.instance, ids, (txn, marks, chunk) async {
        await txn.delete(table, where: 'id IN ($marks)', whereArgs: chunk);
      });

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

  /// A new album row and its pages, in one transaction.
  Future<int> insertAlbum(
    ScannedDocument document,
    List<DocumentPage> pages,
  ) async {
    final db = await _database.instance;
    return db.transaction((txn) async {
      final id = await txn.insert(table, document.toRow());
      await _writePages(txn, id, pages);
      return id;
    });
  }

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

  /// Replaces an album's page list and its row together; positions are
  /// renumbered from zero.
  Future<List<DocumentPage>> replacePages(
    ScannedDocument document,
    List<DocumentPage> pages,
  ) async {
    final db = await _database.instance;
    return db.transaction((txn) async {
      final written = await _writePages(txn, document.id, pages);
      await txn.update(
        table,
        {
          'updated_at': document.updatedAt.millisecondsSinceEpoch,
          'page_count': document.pageCount,
          'size_bytes': document.sizeBytes,
          'thumbnail_path': document.thumbnailPath,
        },
        where: 'id = ?',
        whereArgs: [document.id],
      );
      return written;
    });
  }

  Future<List<DocumentPage>> _writePages(
    Transaction txn,
    int documentId,
    List<DocumentPage> pages,
  ) async {
    await txn.delete(
      pagesTable,
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
    final written = <DocumentPage>[];
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i].copyWith(documentId: documentId, position: i);
      final row = page.toRow();
      final id = await txn.insert(pagesTable, row);
      written.add(page.copyWith(id: id));
    }
    return written;
  }

  /// Gallery files already copied into a live document.
  Future<Set<String>> pageSourcePaths() async {
    final db = await _database.instance;
    final rows = await db.rawQuery(
      'SELECT DISTINCT p.source_path AS source_path '
      'FROM $pagesTable p JOIN $table d ON d.id = p.document_id '
      'WHERE p.source_path IS NOT NULL AND d.deleted_at IS NULL',
    );
    return {for (final row in rows) row['source_path']! as String};
  }

  Future<List<ScannedDocument>> _query(
    String where,
    String? orderBy, [
    List<Object?>? args,
  ]) async {
    final db = await _database.instance;
    final rows = await db.query(
      table,
      where: where,
      whereArgs: args,
      orderBy: orderBy,
    );
    return rows.map(ScannedDocument.fromRow).toList(growable: false);
  }
}
