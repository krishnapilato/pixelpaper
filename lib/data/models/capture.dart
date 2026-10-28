import 'dart:io';

import 'package:flutter/foundation.dart';

import 'rows.dart';

enum CaptureSource { camera, gallery }

/// A full-resolution photo kept in the app's private storage.
@immutable
class Capture {
  const Capture({
    required this.id,
    required this.path,
    required this.createdAt,
    required this.sizeBytes,
    required this.source,
    this.width = 0,
    this.height = 0,
    this.folderId,
    this.deletedAt,
  });

  final int id;
  final String path;
  final DateTime createdAt;
  final int sizeBytes;
  final CaptureSource source;
  final int width;
  final int height;
  final int? folderId;
  final DateTime? deletedAt;

  bool get isTrashed => deletedAt != null;
  File get file => File(path);

  String get mimeType =>
      path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

  bool get hasResolution => width > 0 && height > 0;
  String get resolutionLabel => hasResolution ? '$width × $height' : '—';

  String get signature =>
      '$id|$path|$sizeBytes|${createdAt.millisecondsSinceEpoch}';

  Capture copyWith({
    int? id,
    int? sizeBytes,
    int? width,
    int? height,
    int? folderId,
    bool clearFolder = false,
  }) => Capture(
    id: id ?? this.id,
    path: path,
    createdAt: createdAt,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    source: source,
    width: width ?? this.width,
    height: height ?? this.height,
    folderId: clearFolder ? null : (folderId ?? this.folderId),
    deletedAt: deletedAt,
  );

  Map<String, Object?> toRow() => {
    'path': path,
    'created_at': createdAt.millisecondsSinceEpoch,
    'size_bytes': sizeBytes,
    'source': source.name,
    'width': width,
    'height': height,
    'folder_id': folderId,
    'deleted_at': deletedAt?.millisecondsSinceEpoch,
  };

  static Capture fromRow(Map<String, Object?> row) => Capture(
    id: Rows.integer(row, 'id'),
    path: Rows.text(row, 'path'),
    createdAt: Rows.time(row, 'created_at'),
    sizeBytes: Rows.integerOr(row, 'size_bytes'),
    source: CaptureSource.values.firstWhere(
      (s) => s.name == row['source'],
      orElse: () => CaptureSource.camera,
    ),
    width: Rows.integerOr(row, 'width'),
    height: Rows.integerOr(row, 'height'),
    folderId: Rows.integerOrNull(row, 'folder_id'),
    deletedAt: Rows.timeOrNull(row, 'deleted_at'),
  );

  @override
  bool operator ==(Object other) =>
      other is Capture &&
      other.id == id &&
      other.path == path &&
      other.createdAt == createdAt &&
      other.sizeBytes == sizeBytes &&
      other.source == source &&
      other.width == width &&
      other.height == height &&
      other.folderId == folderId &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hash(
    id,
    path,
    createdAt,
    sizeBytes,
    source,
    width,
    height,
    folderId,
    deletedAt,
  );
}
