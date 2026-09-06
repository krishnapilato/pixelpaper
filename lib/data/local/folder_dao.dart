import 'package:sqflite/sqflite.dart';

import '../models/folder.dart';
import 'app_database.dart';

/// Folder rows plus the item counts shown on each folder card.
class FolderDao {
  FolderDao(this._database);

  final AppDatabase _database;
  static const String table = 'folders';

  /// Folders of one library, each with the number of live (non-trashed)
  /// items inside it. One grouped query rather than N counts.
  Future<List<Folder>> all(FolderKind kind) async {
    final db = await _database.instance;
    final rows = await db.query(
      table,
      where: 'kind = ?',
      whereArgs: [kind.name],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    if (rows.isEmpty) return const [];

    final itemTable = kind == FolderKind.document ? 'documents' : 'captures';
    final counts = await db.rawQuery(
      'SELECT folder_id, COUNT(*) AS total FROM $itemTable '
      'WHERE folder_id IS NOT NULL AND deleted_at IS NULL GROUP BY folder_id',
    );
    final byFolder = {
      for (final row in counts) row['folder_id'] as int: row['total'] as int,
    };

    return [
      for (final row in rows)
        Folder.fromRow(row, itemCount: byFolder[row['id'] as int] ?? 0),
    ];
  }

  /// Returns the new folder, or null when that name already exists.
  Future<Folder?> create(String name, FolderKind kind) async {
    final db = await _database.instance;
    final folder = Folder(
      id: 0,
      name: name,
      kind: kind,
      createdAt: DateTime.now(),
    );
    try {
      final id = await db.insert(
        table,
        folder.toRow(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return Folder(
        id: id,
        name: folder.name,
        kind: kind,
        createdAt: folder.createdAt,
      );
    } on DatabaseException {
      // The unique (name, kind) index rejected a duplicate.
      return null;
    }
  }

  Future<bool> rename(Folder folder, String name) async {
    final db = await _database.instance;
    try {
      await db.update(
        table,
        {'name': name},
        where: 'id = ?',
        whereArgs: [folder.id],
      );
      return true;
    } on DatabaseException {
      return false;
    }
  }

  /// Removes the folder. `ON DELETE SET NULL` moves its items back to the
  /// root instead of deleting them.
  Future<void> delete(int id) async {
    final db = await _database.instance;
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }
}
