import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the single sqflite connection.
///
/// Opening is guarded by one cached Future, so concurrent callers during
/// start-up share the same open operation instead of racing.
class AppDatabase {
  AppDatabase({this.fileName = 'pixelpaper.db'});

  /// v1 archive + gallery, v2 folders and trash, v3 albums, v4 page origins.
  static const int schemaVersion = 4;

  final String fileName;
  Future<Database>? _opening;

  Future<Database> get instance => _opening ??= _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), fileName);
    return openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        // onCreate already runs inside a transaction opened by sqflite.
        await _createV1(db);
        await _upgradeToV2(db);
        await _upgradeToV3(db);
        await _upgradeToV4(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _upgradeToV2(db);
        if (oldVersion < 3) await _upgradeToV3(db);
        if (oldVersion < 4) await _upgradeToV4(db);
      },
    );
  }

  Future<void> _createV1(Database db) async {
    await db.execute('''
      CREATE TABLE documents (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        path           TEXT    NOT NULL UNIQUE,
        title          TEXT    NOT NULL,
        created_at     INTEGER NOT NULL,
        updated_at     INTEGER NOT NULL,
        page_count     INTEGER NOT NULL DEFAULT 0,
        size_bytes     INTEGER NOT NULL DEFAULT 0,
        thumbnail_path TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE captures (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        path       TEXT    NOT NULL UNIQUE,
        created_at INTEGER NOT NULL,
        size_bytes INTEGER NOT NULL DEFAULT 0,
        source     TEXT    NOT NULL DEFAULT 'camera',
        width      INTEGER NOT NULL DEFAULT 0,
        height     INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_documents_updated ON documents(updated_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_captures_created ON captures(created_at DESC)',
    );
  }

  /// Folders and a recycle bin.
  ///
  /// `folder_id` is nullable and set to NULL when its folder is deleted, so
  /// removing a folder never removes the files inside it — deleting a
  /// container should never be a way to lose documents by accident.
  Future<void> _upgradeToV2(Database db) async {
    await db.execute('''
      CREATE TABLE folders (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT    NOT NULL,
        kind       TEXT    NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX idx_folders_name_kind ON folders(name, kind)',
    );

    for (final table in ['documents', 'captures']) {
      await db.execute(
        'ALTER TABLE $table ADD COLUMN folder_id INTEGER '
        'REFERENCES folders(id) ON DELETE SET NULL',
      );
      // Soft delete: the row is hidden everywhere but the bin, and the file
      // stays on disk until the user empties it or 30 days pass.
      await db.execute('ALTER TABLE $table ADD COLUMN deleted_at INTEGER');
      await db.execute(
        'CREATE INDEX idx_${table}_deleted ON $table(deleted_at)',
      );
      await db.execute(
        'CREATE INDEX idx_${table}_folder ON $table(folder_id)',
      );
    }
  }

  /// Albums: a document that is an ordered set of page images rather than a
  /// PDF file.
  ///
  /// Building a PDF was costing minutes and a second copy of every photo, and
  /// changing the page order rewrote the whole file — Syncfusion has no
  /// move-page operation, so a reorder redraws every page onto a fresh
  /// document. As an album, creating is a row and a file copy, reordering is
  /// an integer, and the PDF is built once, on export.
  ///
  /// `kind` defaults to 'pdf' so every document that already exists on a
  /// user's phone keeps behaving exactly as it did. Albums are only ever the
  /// new ones; nothing is converted underneath anybody.
  ///
  /// Page order lives in `position`, never in the file name: renaming a dozen
  /// files on every drag would be the same mistake this table exists to undo.
  Future<void> _upgradeToV3(Database db) async {
    await db.execute(
      "ALTER TABLE documents ADD COLUMN kind TEXT NOT NULL DEFAULT 'pdf'",
    );
    await db.execute('''
      CREATE TABLE document_pages (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL
                    REFERENCES documents(id) ON DELETE CASCADE,
        file_name   TEXT    NOT NULL,
        position    INTEGER NOT NULL,
        created_at  INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_pages_document ON document_pages(document_id, position)',
    );
  }

  /// Where a page came from.
  ///
  /// An album owns a copy of every page, so a document built from the gallery
  /// leaves the same pixels on the phone twice — once as a capture, once as a
  /// page. That is the price of a document nothing else can break, but the
  /// user should be able to see the bill and pay it off.
  ///
  /// Recording the path it was copied from is what makes that possible: a
  /// capture whose path shows up here is already safe inside a document, and
  /// deleting it from the gallery costs nothing. A plain path, not a foreign
  /// key: the capture may be gone, and the page must not care.
  Future<void> _upgradeToV4(Database db) async {
    await db.execute('ALTER TABLE document_pages ADD COLUMN source_path TEXT');
    await db.execute(
      'CREATE INDEX idx_pages_source ON document_pages(source_path)',
    );
  }

  Future<void> close() async {
    final db = await _opening;
    await db?.close();
    _opening = null;
  }
}
