import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'rows.dart';

/// One page of an album: an image the album owns, at a position.
@immutable
class DocumentPage {
  const DocumentPage({
    required this.id,
    required this.documentId,
    required this.fileName,
    required this.position,
    required this.createdAt,
    this.sourcePath,
  });

  final int id;
  final int documentId;

  /// A bare name inside the album directory, never a path.
  final String fileName;
  final int position;
  final DateTime createdAt;

  /// The gallery photo this page was copied from, if any.
  final String? sourcePath;

  File fileIn(Directory albumDir) => File(p.join(albumDir.path, fileName));

  DocumentPage copyWith({int? id, int? documentId, int? position}) =>
      DocumentPage(
        id: id ?? this.id,
        documentId: documentId ?? this.documentId,
        fileName: fileName,
        position: position ?? this.position,
        createdAt: createdAt,
        sourcePath: sourcePath,
      );

  Map<String, Object?> toRow() => {
    'document_id': documentId,
    'file_name': fileName,
    'position': position,
    'created_at': createdAt.millisecondsSinceEpoch,
    'source_path': sourcePath,
  };

  static DocumentPage fromRow(Map<String, Object?> row) {
    final fileName = Rows.text(row, 'file_name');
    if (p.basename(fileName) != fileName || fileName.startsWith('.')) {
      throw FormatException('Page name is not a bare file name', fileName);
    }
    return DocumentPage(
      id: Rows.integer(row, 'id'),
      documentId: Rows.integer(row, 'document_id'),
      fileName: fileName,
      position: Rows.integer(row, 'position'),
      createdAt: Rows.time(row, 'created_at'),
      sourcePath: Rows.textOrNull(row, 'source_path'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DocumentPage &&
      other.id == id &&
      other.documentId == documentId &&
      other.fileName == fileName &&
      other.position == position &&
      other.createdAt == createdAt &&
      other.sourcePath == sourcePath;

  @override
  int get hashCode =>
      Object.hash(id, documentId, fileName, position, createdAt, sourcePath);
}
