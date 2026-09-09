import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/selection_controller.dart';
import '../../../data/models/document_page.dart';
import '../../../data/models/scanned_document.dart';
import '../../../data/providers.dart';
import '../../../data/models/folder.dart';
import '../../../data/repositories/document_repository.dart';
import '../../folders/application/folders_controller.dart';
import '../../trash/application/trash_controller.dart';

/// The archive list.
///
/// Mutations patch the in-memory list instead of re-reading the directory:
/// renaming a document should not make the whole screen flash through a
/// loading state, and a rescan costs one `stat` per file.
class DocumentsController extends AsyncNotifier<List<ScannedDocument>> {
  DocumentRepository get _repository => ref.read(documentRepositoryProvider);

  @override
  Future<List<ScannedDocument>> build() => _repository.load();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.load);
    _pruneSelection();
  }

  /// Registers a PDF produced by the scanner and returns the stored document.
  Future<ScannedDocument> importScan({
    required File pdfSource,
    required String title,
    required int pageCount,
    File? thumbnailSource,
  }) async {
    final document = await _repository.importScan(
      pdfSource: pdfSource,
      title: title,
      pageCount: pageCount,
      thumbnailSource: thumbnailSource,
    );
    _prepend(document);
    return document;
  }

  /// Makes a document out of gallery captures and returns it.
  ///
  /// An album, not a PDF: the pages are the photos themselves, kept at full
  /// resolution, and the PDF is built only when the user exports. Composing
  /// one here cost fifteen seconds and a second copy of every pixel, for a
  /// file most documents never need.
  Future<ScannedDocument> createFromImages({
    required List<String> imagePaths,
    required String title,
  }) async {
    final document = await _repository.createAlbumFromImages(
      imagePaths: imagePaths,
      title: title,
    );
    _prepend(document);
    return document;
  }

  /// Returns false when the name is already taken.
  Future<bool> rename(ScannedDocument document, String title) async {
    final renamed = await _repository.rename(document, title);
    if (renamed == null) return false;
    _replace(renamed);
    return true;
  }

  /// Moves documents to the bin. Nothing is erased: the row is flagged and
  /// the file stays on disk for 30 days, so a mis-tap is always recoverable.
  Future<void> moveToTrash(List<ScannedDocument> documents) async {
    if (documents.isEmpty) return;
    final removed = documents.map((d) => d.id).toSet();
    await ref.read(libraryRepositoryProvider).trashDocuments(removed);
    _dropLocally(removed);
    ref.read(documentSelectionProvider.notifier).clear();
    await ref.read(trashControllerProvider.notifier).refresh();
    await ref.read(foldersProvider(FolderKind.document).notifier).refresh();
  }

  /// Puts documents into [folderId], or back at the root when it is null.
  Future<void> move(Iterable<int> ids, int? folderId) async {
    if (ids.isEmpty) return;
    await ref.read(libraryRepositoryProvider).moveDocuments(ids, folderId);
    final current = state.value;
    if (current != null) {
      state = AsyncData([
        for (final item in current)
          ids.contains(item.id)
              ? item.copyWith(folderId: folderId, clearFolder: folderId == null)
              : item,
      ]);
    }
    ref.read(documentSelectionProvider.notifier).clear();
    await ref.read(foldersProvider(FolderKind.document).notifier).refresh();
  }

  void _dropLocally(Set<int> ids) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.where((d) => !ids.contains(d.id)).toList(growable: false),
    );
  }

  /// Writes a new page order for an album and refreshes the archive row.
  ///
  /// No file is rewritten: the pages keep their names and only their positions
  /// change, which is why this returns before the finger has left the screen.
  Future<ScannedDocument> savePages(
    ScannedDocument document,
    List<DocumentPage> pages,
  ) async {
    final updated = await _repository.savePages(document, pages);
    _replace(updated);
    return updated;
  }

  /// Called after the editor rewrote a document on disk.
  Future<ScannedDocument> reload(ScannedDocument document) async {
    final refreshed = await _repository.refresh(document);
    _replace(refreshed);
    return refreshed;
  }

  void _prepend(ScannedDocument document) {
    final current = state.value ?? const <ScannedDocument>[];
    state = AsyncData([document, ...current]);
  }

  void _replace(ScannedDocument document) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final item in current) item.id == document.id ? document : item,
    ]);
  }

  void _pruneSelection() {
    final live = state.value?.map((d) => d.id).toSet();
    if (live != null) ref.read(documentSelectionProvider.notifier).retain(live);
  }
}

final documentsControllerProvider =
    AsyncNotifierProvider<DocumentsController, List<ScannedDocument>>(
  DocumentsController.new,
);

final documentSelectionProvider =
    NotifierProvider<SelectionController, Set<int>>(SelectionController.new);

/// How the archive is ordered. Kept in memory: a sort order is a momentary
/// intent, not a setting worth persisting across launches.
class DocumentSortController extends Notifier<DocumentSort> {
  @override
  DocumentSort build() => DocumentSort.recent;

  void select(DocumentSort sort) => state = sort;
}

final documentSortProvider =
    NotifierProvider<DocumentSortController, DocumentSort>(
  DocumentSortController.new,
);

class DocumentQueryController extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;
  void clear() => state = '';
}

final documentQueryProvider =
    NotifierProvider<DocumentQueryController, String>(
  DocumentQueryController.new,
);

/// List vs grid. Grid is better for recognising a scan by its look; list is
/// better for reading names — so the choice stays with the user.
class DocumentLayoutController extends Notifier<bool> {
  @override
  bool build() => false;

  void setGrid(bool value) => state = value;
}

final documentGridProvider =
    NotifierProvider<DocumentLayoutController, bool>(
  DocumentLayoutController.new,
);

/// Sorting and filtering happen here, off the widget build path, so the screen
/// only rebuilds when the resulting list actually changes.
final visibleDocumentsProvider =
    Provider<AsyncValue<List<ScannedDocument>>>((ref) {
  final documents = ref.watch(documentsControllerProvider);
  final sort = ref.watch(documentSortProvider);
  final query = ref.watch(documentQueryProvider).trim().toLowerCase();
  final folderId = ref.watch(currentFolderProvider(FolderKind.document));

  return documents.whenData((list) {
    // Search looks through the whole archive, not just the open folder: a
    // name you remember should be findable without remembering where it is.
    final scoped = query.isNotEmpty || folderId == null
        ? list
        : list.where((d) => d.folderId == folderId).toList(growable: false);
    final filtered = query.isEmpty
        ? scoped
        : scoped
            .where((d) => d.title.toLowerCase().contains(query))
            .toList(growable: false);
    return [...filtered]..sort(sort.compare);
  });
});

/// One document by id, derived from the loaded archive so a rename or an edit
/// propagates to the viewer and the editor without another database read.
final documentByIdProvider =
    Provider.family<ScannedDocument?, int>((ref, id) {
  final documents = ref.watch(documentsControllerProvider).value;
  if (documents == null) return null;
  for (final document in documents) {
    if (document.id == id) return document;
  }
  return null;
});

/// The pages of an album, in order.
///
/// Keyed on the document's signature rather than its id, so saving a new order
/// re-reads once and every screen showing that album follows. Empty for a PDF,
/// which has no page rows.
final documentPagesProvider =
    FutureProvider.family<List<DocumentPage>, int>((ref, id) async {
  final document = ref.watch(documentByIdProvider(id));
  if (document == null || !document.isAlbum) return const <DocumentPage>[];
  return ref.watch(documentRepositoryProvider).pagesOf(document);
});
