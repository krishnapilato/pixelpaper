import 'dart:io';

import 'package:path/path.dart' as p;

/// What a document is made of.
enum DocumentKind {
  /// An ordered set of page images the document owns. Created instantly,
  /// reordered instantly, turned into a PDF only on export.
  album,

  /// A PDF file, opaque to us: everything made before albums existed, plus
  /// anything imported from outside the app.
  pdf;

  static DocumentKind fromRow(Object? value) =>
      value == 'album' ? DocumentKind.album : DocumentKind.pdf;

  String get row => name;
}

/// A document in the archive, as stored in the `documents` table.
///
/// The row is the source of truth for metadata the file system cannot answer
/// cheaply (title, page count, thumbnail); the file system is the source of
/// truth for existence and size.
///
/// [path] means different things per [kind], and this is the one place where
/// that matters: for a PDF it is the file, for an album it is the directory
/// holding its pages. Everything else goes through [file] or [directory],
/// which are guarded.
class ScannedDocument {
  const ScannedDocument({
    required this.id,
    required this.path,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.pageCount,
    required this.sizeBytes,
    this.kind = DocumentKind.pdf,
    this.thumbnailPath,
    this.folderId,
    this.deletedAt,
  });

  final int id;
  final String path;
  final DocumentKind kind;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int pageCount;
  final int sizeBytes;
  final String? thumbnailPath;
  final int? folderId;

  /// Set when the document is in the bin; the file stays on disk until the
  /// bin is emptied or the 30-day window passes.
  final DateTime? deletedAt;

  bool get isTrashed => deletedAt != null;
  bool get isAlbum => kind == DocumentKind.album;

  /// The PDF file. Only meaningful for [DocumentKind.pdf]; an album has no
  /// file until somebody exports it.
  File get file => File(path);

  /// The album's directory, where its page images live.
  Directory get directory => Directory(path);

  String get fileName => p.basename(path);

  /// Cheap identity for list diffing and cache keys.
  ///
  /// An album's bytes change without its path changing, so the page count and
  /// the update stamp are what make this move.
  String get signature =>
      '$id|$path|$sizeBytes|${updatedAt.millisecondsSinceEpoch}|$pageCount';

  ScannedDocument copyWith({
    String? path,
    String? title,
    DateTime? updatedAt,
    int? pageCount,
    int? sizeBytes,
    String? thumbnailPath,
    bool clearThumbnail = false,
    int? folderId,
    bool clearFolder = false,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return ScannedDocument(
      id: id,
      path: path ?? this.path,
      kind: kind,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pageCount: pageCount ?? this.pageCount,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      thumbnailPath:
          clearThumbnail ? null : (thumbnailPath ?? this.thumbnailPath),
      folderId: clearFolder ? null : (folderId ?? this.folderId),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, Object?> toRow() => {
        'path': path,
        'kind': kind.row,
        'title': title,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'page_count': pageCount,
        'size_bytes': sizeBytes,
        'thumbnail_path': thumbnailPath,
        'folder_id': folderId,
        'deleted_at': deletedAt?.millisecondsSinceEpoch,
      };

  static ScannedDocument fromRow(Map<String, Object?> row) => ScannedDocument(
        id: row['id']! as int,
        path: row['path']! as String,
        kind: DocumentKind.fromRow(row['kind']),
        title: row['title']! as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['created_at']! as int,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row['updated_at']! as int,
        ),
        pageCount: (row['page_count'] as int?) ?? 0,
        sizeBytes: (row['size_bytes'] as int?) ?? 0,
        thumbnailPath: row['thumbnail_path'] as String?,
        folderId: row['folder_id'] as int?,
        deletedAt: switch (row['deleted_at']) {
          final int stamp => DateTime.fromMillisecondsSinceEpoch(stamp),
          _ => null,
        },
      );
}

/// Ordering offered in the archive.
enum DocumentSort {
  recent,
  oldest,
  nameAsc,
  nameDesc,
  size;

  /// Key into `assets/lang.json`.
  String get labelKey => switch (this) {
        DocumentSort.recent => 'sort_recent',
        DocumentSort.oldest => 'sort_oldest',
        DocumentSort.nameAsc => 'sort_name_az',
        DocumentSort.nameDesc => 'sort_name_za',
        DocumentSort.size => 'sort_size',
      };

  int compare(ScannedDocument a, ScannedDocument b) => switch (this) {
        DocumentSort.recent => b.updatedAt.compareTo(a.updatedAt),
        DocumentSort.oldest => a.updatedAt.compareTo(b.updatedAt),
        DocumentSort.nameAsc =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        DocumentSort.nameDesc =>
          b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        DocumentSort.size => b.sizeBytes.compareTo(a.sizeBytes),
      };
}
