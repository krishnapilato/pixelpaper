import 'package:sqflite/sqflite.dart';

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
}
