import 'package:sqflite/sqflite.dart';

import '../models/capture.dart';
import 'app_database.dart';

/// Row-level access to the `captures` table.
class CaptureDao {
  CaptureDao(this._database);

  final AppDatabase _database;
  static const String table = 'captures';

  /// Live rows only; the bin has its own query.
  Future<List<Capture>> all() async {
    final db = await _database.instance;
    final rows = await db.query(
      table,
      where: 'deleted_at IS NULL',
      orderBy: 'created_at DESC',
    );
    return rows.map(Capture.fromRow).toList(growable: false);
  }

  Future<List<Capture>> trashed() async {
    final db = await _database.instance;
    final rows = await db.query(
      table,
      where: 'deleted_at IS NOT NULL',
      orderBy: 'deleted_at DESC',
    );
    return rows.map(Capture.fromRow).toList(growable: false);
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
  Future<List<Capture>> expired(DateTime cutoff) async {
    final db = await _database.instance;
    final rows = await db.query(
      table,
      where: 'deleted_at IS NOT NULL AND deleted_at < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
    return rows.map(Capture.fromRow).toList(growable: false);
  }

  Future<int> insert(Capture capture) async {
    final db = await _database.instance;
    return db.insert(
      table,
      capture.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Capture capture) async {
    final db = await _database.instance;
    await db.update(
      table,
      capture.toRow(),
      where: 'id = ?',
      whereArgs: [capture.id],
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

  Future<void> insertMissing(Iterable<Capture> captures) async {
    if (captures.isEmpty) return;
    final db = await _database.instance;
    await db.transaction((txn) async {
      for (final capture in captures) {
        await txn.insert(
          table,
          capture.toRow(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }
}
