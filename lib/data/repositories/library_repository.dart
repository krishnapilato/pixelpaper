import '../local/capture_dao.dart';
import '../local/document_dao.dart';
import '../local/folder_dao.dart';
import '../models/capture.dart';
import '../models/folder.dart';
import '../models/scanned_document.dart';
import '../services/storage_service.dart';

/// Everything in the bin, both kinds together.
class TrashContents {
  const TrashContents({required this.documents, required this.captures});

  final List<ScannedDocument> documents;
  final List<Capture> captures;

  bool get isEmpty => documents.isEmpty && captures.isEmpty;
  int get length => documents.length + captures.length;
}

/// Folders and the recycle bin — the two concerns that span both libraries.
class LibraryRepository {
  LibraryRepository({
    required FolderDao folders,
    required DocumentDao documents,
    required CaptureDao captures,
    required StorageService storage,
  })  : _folders = folders,
        _documents = documents,
        _captures = captures,
        _storage = storage;

  final FolderDao _folders;
  final DocumentDao _documents;
  final CaptureDao _captures;
  final StorageService _storage;

  /// How long a trashed item is kept. Long enough to notice the mistake,
  /// short enough that storage does not silently fill up.
  static const Duration retention = Duration(days: 30);

  // --- Folders -------------------------------------------------------------

  Future<List<Folder>> folders(FolderKind kind) => _folders.all(kind);

  Future<Folder?> createFolder(String name, FolderKind kind) =>
      _folders.create(name, kind);

  Future<bool> renameFolder(Folder folder, String name) =>
      _folders.rename(folder, name);

  Future<void> deleteFolder(Folder folder) => _folders.delete(folder.id);

  Future<void> moveDocuments(Iterable<int> ids, int? folderId) =>
      _documents.moveToFolder(ids, folderId);

  Future<void> moveCaptures(Iterable<int> ids, int? folderId) =>
      _captures.moveToFolder(ids, folderId);

  // --- Bin -----------------------------------------------------------------

  Future<void> trashDocuments(Iterable<int> ids) =>
      _documents.setTrashed(ids, true);

  Future<void> trashCaptures(Iterable<int> ids) =>
      _captures.setTrashed(ids, true);

  Future<void> restoreDocuments(Iterable<int> ids) =>
      _documents.setTrashed(ids, false);

  Future<void> restoreCaptures(Iterable<int> ids) =>
      _captures.setTrashed(ids, false);

  Future<TrashContents> trash() async => TrashContents(
        documents: await _documents.trashed(),
        captures: await _captures.trashed(),
      );

  /// Deletes rows and files for good.
  Future<void> purge({
    Iterable<ScannedDocument> documents = const [],
    Iterable<Capture> captures = const [],
  }) async {
    final documentList = documents.toList(growable: false);
    final captureList = captures.toList(growable: false);
    if (documentList.isEmpty && captureList.isEmpty) return;

    await _documents.deleteIds(documentList.map((d) => d.id));
    await _captures.deleteIds(captureList.map((c) => c.id));
    await _storage.deleteFiles([
      ...documentList.map((d) => d.path),
      ...documentList.map((d) => d.thumbnailPath).whereType<String>(),
      ...captureList.map((c) => c.path),
    ]);
  }

  Future<void> emptyTrash() async {
    final contents = await trash();
    await purge(documents: contents.documents, captures: contents.captures);
  }

  /// Drops anything trashed longer ago than [retention]. Runs at start-up so
  /// the bin cannot quietly become permanent storage.
  Future<void> purgeExpired() async {
    final cutoff = DateTime.now().subtract(retention);
    await purge(
      documents: await _documents.expired(cutoff),
      captures: await _captures.expired(cutoff),
    );
  }
}
