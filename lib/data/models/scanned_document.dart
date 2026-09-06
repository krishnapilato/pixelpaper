import 'dart:io';

import 'package:path/path.dart' as p;

/// A generated PDF, as stored in the `documents` table.
///
/// The row is the source of truth for metadata the file system cannot answer
/// cheaply (title, page count, thumbnail); the file itself is the source of
/// truth for existence and size.
class ScannedDocument {
  const ScannedDocument({
    required this.id,
    required this.path,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.pageCount,
    required this.sizeBytes,
    this.thumbnailPath,
    this.folderId,
    this.deletedAt,
  });

  final int id;
  final String path;
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

  File get file => File(path);
  String get fileName => p.basename(path);

  /// Cheap identity for list diffing and cache keys.
  String get signature =>
      '$id|$path|$sizeBytes|${updatedAt.millisecondsSinceEpoch}|$pageCount';

  ScannedDocument copyWith({
    String? path,
    String? title,
    DateTime? updatedAt,
    int? pageCount,
    int? sizeBytes,
    String? thumbnailPath,
    int? folderId,
    bool clearFolder = false,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return ScannedDocument(
      id: id,
      path: path ?? this.path,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pageCount: pageCount ?? this.pageCount,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      folderId: clearFolder ? null : (folderId ?? this.folderId),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, Object?> toRow() => {
        'path': path,
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
