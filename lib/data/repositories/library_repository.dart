import 'package:flutter/foundation.dart';

import '../local/capture_dao.dart';
import '../local/document_dao.dart';
import '../local/folder_dao.dart';
import '../models/capture.dart';
import '../models/folder.dart';
import '../models/scanned_document.dart';
import 'capture_repository.dart';
import 'document_repository.dart';

@immutable
class TrashContents {
  const TrashContents({required this.documents, required this.captures});

  static const TrashContents empty = TrashContents(documents: [], captures: []);

  final List<ScannedDocument> documents;
  final List<Capture> captures;

  bool get isEmpty => documents.isEmpty && captures.isEmpty;
  int get length => documents.length + captures.length;

  int get sizeBytes =>
      documents.fold(0, (sum, d) => sum + d.sizeBytes) +
      captures.fold(0, (sum, c) => sum + c.sizeBytes);

  @override
  bool operator ==(Object other) =>
      other is TrashContents &&
      listEquals(other.documents, documents) &&
      listEquals(other.captures, captures);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(documents), Object.hashAll(captures));
}

/// Folders and the bin: the concerns that span both libraries.
class LibraryRepository {
  LibraryRepository({
    required FolderDao folders,
    required DocumentDao documentRows,
    required CaptureDao captureRows,
    required DocumentRepository documents,
    required CaptureRepository captures,
    DateTime Function()? clock,
  }) : _folders = folders,
       _documentRows = documentRows,
       _captureRows = captureRows,
       _documents = documents,
       _captures = captures,
       _clock = clock ?? DateTime.now;

  final FolderDao _folders;
  final DocumentDao _documentRows;
  final CaptureDao _captureRows;
  final DocumentRepository _documents;
  final CaptureRepository _captures;
  final DateTime Function() _clock;

  static const Duration retention = Duration(days: 30);

  Future<List<Folder>> folders(FolderKind kind) => _folders.all(kind);

  /// Null when the name is empty after cleaning or already used.
  Future<Folder?> createFolder(String name, FolderKind kind) async {
    final clean = Folder.cleanName(name);
    return clean == null ? null : _folders.create(clean, kind);
  }

  Future<bool> renameFolder(Folder folder, String name) async {
    final clean = Folder.cleanName(name);
    return clean != null && await _folders.rename(folder, clean);
  }

  /// Items inside go back to the root (`ON DELETE SET NULL`).
  Future<void> deleteFolder(Folder folder) => _folders.delete(folder.id);

  Future<void> moveDocuments(Iterable<int> ids, int? folderId) =>
      _documentRows.moveToFolder(ids, folderId);

  Future<void> moveCaptures(Iterable<int> ids, int? folderId) =>
      _captureRows.moveToFolder(ids, folderId);

  Future<void> trashDocuments(Iterable<int> ids) =>
      _documentRows.setTrashed(ids, trashed: true);

  Future<void> trashCaptures(Iterable<int> ids) =>
      _captureRows.setTrashed(ids, trashed: true);

  Future<void> restoreDocuments(Iterable<int> ids) =>
      _documentRows.setTrashed(ids, trashed: false);

  Future<void> restoreCaptures(Iterable<int> ids) =>
      _captureRows.setTrashed(ids, trashed: false);

  Future<TrashContents> trash() async => TrashContents(
    documents: await _documentRows.trashed(),
    captures: await _captureRows.trashed(),
  );

  Future<void> purge({
    Iterable<ScannedDocument> documents = const [],
    Iterable<Capture> captures = const [],
  }) async {
    await _documents.deleteForever(documents);
    await _captures.deleteForever(captures);
  }

  Future<void> emptyTrash() async {
    final contents = await trash();
    await purge(documents: contents.documents, captures: contents.captures);
  }

  /// Drops anything trashed longer ago than [retention].
  Future<void> purgeExpired() async {
    final cutoff = _clock().subtract(retention);
    await purge(
      documents: await _documentRows.expired(cutoff),
      captures: await _captureRows.expired(cutoff),
    );
  }
}
