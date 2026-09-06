import 'dart:io';

/// Where a raw image came from.
enum CaptureSource { camera, gallery }

/// A raw, uncropped photo kept at full resolution in the app's private
/// storage — the input material for a PDF, and the archive for pages whose
/// detail (faded ink, Latin text) an auto-crop would throw away.
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

  /// MIME type derived from the file itself.
  ///
  /// The gallery also holds PNGs imported from the photo picker: announcing
  /// every share as `image/jpeg` would hand the receiving app a file that does
  /// not match what it was told it is getting.
  String get mimeType =>
      path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

  bool get hasResolution => width > 0 && height > 0;
  String get resolutionLabel => hasResolution ? '$width × $height' : '—';

  String get signature =>
      '$id|$path|$sizeBytes|${createdAt.millisecondsSinceEpoch}';

  /// Only the fields the image editor can change: the path and the capture
  /// date identify the photo and must survive an edit.
  Capture copyWith({int? sizeBytes, int? width, int? height}) => Capture(
    id: id,
    path: path,
    createdAt: createdAt,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    source: source,
    width: width ?? this.width,
    height: height ?? this.height,
    folderId: folderId,
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
    id: row['id']! as int,
    path: row['path']! as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
    sizeBytes: (row['size_bytes'] as int?) ?? 0,
    source: CaptureSource.values.firstWhere(
      (s) => s.name == row['source'],
      orElse: () => CaptureSource.camera,
    ),
    width: (row['width'] as int?) ?? 0,
    height: (row['height'] as int?) ?? 0,
    folderId: row['folder_id'] as int?,
    deletedAt: switch (row['deleted_at']) {
      final int stamp => DateTime.fromMillisecondsSinceEpoch(stamp),
      _ => null,
    },
  );
}
