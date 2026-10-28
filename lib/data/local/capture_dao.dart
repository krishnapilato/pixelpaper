import 'package:sqflite/sqflite.dart';

import '../models/capture.dart';
import 'app_database.dart';
import 'batched.dart';

class CaptureDao {
  CaptureDao(this._database);

  final AppDatabase _database;
  static const String table = 'captures';

  Future<List<Capture>> all() =>
      _query('deleted_at IS NULL', 'created_at DESC');

  Future<List<Capture>> trashed() =>
      _query('deleted_at IS NOT NULL', 'deleted_at DESC');

  Future<List<Capture>> expired(DateTime cutoff) => _query(
    'deleted_at IS NOT NULL AND deleted_at < ?',
    null,
    [cutoff.millisecondsSinceEpoch],
  );

  /// Every path known, trashed included, so a trashed file is not adopted
  /// back as a new photo.
  Future<Set<String>> knownPaths() async {
    final db = await _database.instance;
    final rows = await db.query(table, columns: ['path']);
    return {for (final row in rows) row['path']! as String};
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

  Future<int> insert(Capture capture) async {
    final db = await _database.instance;
    return db.insert(table, capture.toRow());
  }

  Future<void> update(Capture capture) async {
    final db = await _database.instance;
    await db.update(
      table,
      {
        'path': capture.path,
        'size_bytes': capture.sizeBytes,
        'width': capture.width,
        'height': capture.height,
      },
      where: 'id = ?',
      whereArgs: [capture.id],
    );
  }

  Future<void> deleteIds(Iterable<int> ids) async =>
      inChunks(await _database.instance, ids, (txn, marks, chunk) async {
        await txn.delete(table, where: 'id IN ($marks)', whereArgs: chunk);
      });

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

  Future<List<Capture>> _query(
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
    return rows.map(Capture.fromRow).toList(growable: false);
  }
}
