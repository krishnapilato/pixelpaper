import 'dart:io';

import 'package:path/path.dart' as p;

/// One page of an album: an image the document owns, plus its place in the
/// order.
///
/// The album owns its copy rather than pointing at a gallery capture, so
/// deleting a photo from the gallery can never take a page out of a finished
/// document. It costs the disk space of the copy, which is the price of a
/// document that cannot be broken from somewhere else in the app.
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

  /// Name only. The album's directory comes from the document, so moving or
  /// renaming the album never has to touch a page row.
  final String fileName;

  /// Zero-based place in the document. Ordering lives here and nowhere else.
  final int position;

  final DateTime createdAt;

  /// The file this page was copied from, when it came from the gallery.
  ///
  /// Kept so the app can tell the user which of their photos are already safe
  /// inside a document, and therefore free to delete. Null for a page that was
  /// drawn, edited or shot straight into the album.
  final String? sourcePath;

  File fileIn(Directory albumDir) => File(p.join(albumDir.path, fileName));

  DocumentPage copyWith({int? position, String? fileName}) => DocumentPage(
        id: id,
        documentId: documentId,
        fileName: fileName ?? this.fileName,
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

  static DocumentPage fromRow(Map<String, Object?> row) => DocumentPage(
        id: row['id']! as int,
        documentId: row['document_id']! as int,
        fileName: row['file_name']! as String,
        position: row['position']! as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['created_at']! as int,
        ),
        sourcePath: row['source_path'] as String?,
      );
}
