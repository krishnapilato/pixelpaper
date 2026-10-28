import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'rows.dart';

enum DocumentKind {
  /// Ordered page images the document owns; a PDF is made only on export.
  album,

  /// An opaque PDF file.
  pdf;

  static DocumentKind fromRow(Object? value) =>
      value == 'album' ? DocumentKind.album : DocumentKind.pdf;

  String get row => name;
}

/// A document in the archive. [path] is the PDF file, or the album directory.
@immutable
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
  final DateTime? deletedAt;

  bool get isTrashed => deletedAt != null;
  bool get isAlbum => kind == DocumentKind.album;

  File get file => File(path);
  Directory get directory => Directory(path);
  String get fileName => p.basename(path);

  String get signature =>
      '$id|$path|$sizeBytes|${updatedAt.millisecondsSinceEpoch}|$pageCount';

  ScannedDocument copyWith({
    int? id,
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
  }) => ScannedDocument(
    id: id ?? this.id,
    path: path ?? this.path,
    kind: kind,
    title: title ?? this.title,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    pageCount: pageCount ?? this.pageCount,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    thumbnailPath: clearThumbnail
        ? null
        : (thumbnailPath ?? this.thumbnailPath),
    folderId: clearFolder ? null : (folderId ?? this.folderId),
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
  );

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
    id: Rows.integer(row, 'id'),
    path: Rows.text(row, 'path'),
    kind: DocumentKind.fromRow(row['kind']),
    title: Rows.text(row, 'title'),
    createdAt: Rows.time(row, 'created_at'),
    updatedAt: Rows.time(row, 'updated_at'),
    pageCount: Rows.integerOr(row, 'page_count'),
    sizeBytes: Rows.integerOr(row, 'size_bytes'),
    thumbnailPath: Rows.textOrNull(row, 'thumbnail_path'),
    folderId: Rows.integerOrNull(row, 'folder_id'),
    deletedAt: Rows.timeOrNull(row, 'deleted_at'),
  );

  @override
  bool operator ==(Object other) =>
      other is ScannedDocument &&
      other.id == id &&
      other.path == path &&
      other.kind == kind &&
      other.title == title &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.pageCount == pageCount &&
      other.sizeBytes == sizeBytes &&
      other.thumbnailPath == thumbnailPath &&
      other.folderId == folderId &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hash(
    id,
    path,
    kind,
    title,
    createdAt,
    updatedAt,
    pageCount,
    sizeBytes,
    thumbnailPath,
    folderId,
    deletedAt,
  );
}

enum DocumentSort {
  recent,
  oldest,
  nameAsc,
  nameDesc,
  size;

  String get labelKey => switch (this) {
    DocumentSort.recent => 'sort_recent',
    DocumentSort.oldest => 'sort_oldest',
    DocumentSort.nameAsc => 'sort_name_az',
    DocumentSort.nameDesc => 'sort_name_za',
    DocumentSort.size => 'sort_size',
  };

  /// Ties fall back to the id, so equal keys never reorder between builds.
  int compare(ScannedDocument a, ScannedDocument b) {
    final primary = switch (this) {
      DocumentSort.recent => b.updatedAt.compareTo(a.updatedAt),
      DocumentSort.oldest => a.updatedAt.compareTo(b.updatedAt),
      DocumentSort.nameAsc => a.title.toLowerCase().compareTo(
        b.title.toLowerCase(),
      ),
      DocumentSort.nameDesc => b.title.toLowerCase().compareTo(
        a.title.toLowerCase(),
      ),
      DocumentSort.size => b.sizeBytes.compareTo(a.sizeBytes),
    };
    return primary != 0 ? primary : a.id.compareTo(b.id);
  }
}
