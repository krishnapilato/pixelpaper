import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/library_revision.dart';
import '../../../core/state/limits.dart';
import '../../../core/state/selection_controller.dart';
import '../../../core/state/serial.dart';
import '../../../data/models/document_page.dart';
import '../../../data/models/folder.dart';
import '../../../data/models/scanned_document.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/document_repository.dart';
import '../../../data/services/scanner_service.dart';
import '../../folders/application/folders_controller.dart';

/// The archive. Writes are serialised and patch the loaded list in place.
class DocumentsController extends AsyncNotifier<List<ScannedDocument>> {
  final Serial _serial = Serial();

  DocumentRepository get _repository => ref.read(documentRepositoryProvider);

  @override
  Future<List<ScannedDocument>> build() {
    ref.watch(folderReleasedProvider(FolderKind.document));
    return _repository.load().bounded();
  }

  Future<void> refresh() => _serial.run(() async {
    final next = await AsyncValue.guard(() => _repository.load().bounded());
    if (!ref.mounted) return;
    state = next;
    final live = next.value?.map((d) => d.id).toSet();
    if (live != null) ref.read(documentSelectionProvider.notifier).retain(live);
  });

  Future<ScannedDocument> importScan(ScanResult scan, String title) => _write(
    () => _repository.importScan(scan, title),
    (list, doc) => [doc, ...list],
  );

  Future<ScannedDocument> createAlbum({
    required List<String> imagePaths,
    required String title,
  }) => _write(
    () => _repository.createAlbum(imagePaths: imagePaths, title: title),
    (list, doc) => [doc, ...list],
  );

  /// False when the name is taken or empty.
  Future<bool> rename(ScannedDocument document, String title) async {
    final renamed = await _write(
      () => _repository.rename(document, title),
      (list, doc) => doc == null ? list : _replaced(list, doc),
    );
    return renamed != null;
  }

  Future<void> moveToTrash(Iterable<int> ids) {
    final removed = ids.toSet();
    return _write(
      () => ref.read(libraryRepositoryProvider).trashDocuments(removed),
      (list, _) => [
        for (final d in list)
          if (!removed.contains(d.id)) d,
      ],
      clearSelection: true,
    );
  }

  Future<void> move(Iterable<int> ids, int? folderId) {
    final moved = ids.toSet();
    return _write(
      () => ref.read(libraryRepositoryProvider).moveDocuments(moved, folderId),
      (list, _) => [
        for (final d in list)
          moved.contains(d.id)
              ? d.copyWith(folderId: folderId, clearFolder: folderId == null)
              : d,
      ],
      clearSelection: true,
    );
  }

  Future<ScannedDocument> savePages(
    ScannedDocument document,
    List<DocumentPage> pages,
  ) => _write(() => _repository.savePages(document, pages), _replaced);

  /// After a PDF was rewritten on disk.
  Future<ScannedDocument> reload(
    ScannedDocument document, {
    required int pageCount,
  }) => _write(
    () => _repository.refresh(document, pageCount: pageCount),
    _replaced,
  );

  Future<T> _write<T>(
    Future<T> Function() write,
    List<ScannedDocument> Function(List<ScannedDocument> list, T result)
    patch, {
    bool clearSelection = false,
  }) => _serial.run(() async {
    final result = await write();
    if (!ref.mounted) return result;
    final current = state.value;
    if (current != null) {
      state = AsyncData(List.unmodifiable(patch(current, result)));
    }
    if (clearSelection) ref.read(documentSelectionProvider.notifier).clear();
    ref.libraryChanged();
    return result;
  });

  static List<ScannedDocument> _replaced(
    List<ScannedDocument> list,
    ScannedDocument document,
  ) => [for (final d in list) d.id == document.id ? document : d];
}

final documentsControllerProvider =
    AsyncNotifierProvider<DocumentsController, List<ScannedDocument>>(
      DocumentsController.new,
    );

final documentSelectionProvider =
    NotifierProvider<SelectionController, Set<int>>(SelectionController.new);

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
  static const int maxLength = 100;

  @override
  String build() => '';

  void update(String value) =>
      state = value.length > maxLength ? value.substring(0, maxLength) : value;

  void clear() => state = '';
}

final documentQueryProvider = NotifierProvider<DocumentQueryController, String>(
  DocumentQueryController.new,
);

class DocumentLayoutController extends Notifier<bool> {
  @override
  bool build() => false;

  void setGrid(bool value) => state = value;
}

final documentGridProvider = NotifierProvider<DocumentLayoutController, bool>(
  DocumentLayoutController.new,
);

/// The archive as shown: searched across every folder, otherwise scoped to
/// the open one, then sorted.
List<ScannedDocument> visibleDocuments(
  List<ScannedDocument> all, {
  required DocumentSort sort,
  required String query,
  required int? folderId,
}) {
  final needle = query.trim().toLowerCase();
  return [
    for (final d in all)
      if (needle.isNotEmpty
          ? d.title.toLowerCase().contains(needle)
          : folderId == null || d.folderId == folderId)
        d,
  ]..sort(sort.compare);
}

final visibleDocumentsProvider = Provider<AsyncValue<List<ScannedDocument>>>((
  ref,
) {
  final sort = ref.watch(documentSortProvider);
  final query = ref.watch(documentQueryProvider);
  final folderId = ref.watch(currentFolderProvider(FolderKind.document));
  return ref
      .watch(documentsControllerProvider)
      .whenData(
        (list) => visibleDocuments(
          list,
          sort: sort,
          query: query,
          folderId: folderId,
        ),
      );
});

final documentByIdProvider = Provider.family<ScannedDocument?, int>((ref, id) {
  final documents = ref.watch(documentsControllerProvider).value;
  if (documents == null) return null;
  for (final document in documents) {
    if (document.id == id) return document;
  }
  return null;
});

/// Whether [documentByIdProvider] can still turn up the document: false once
/// the archive has loaded without it.
final documentMissingProvider = Provider.family<bool, int>((ref, id) {
  final documents = ref.watch(documentsControllerProvider);
  return documents.hasValue &&
      !documents.isLoading &&
      ref.watch(documentByIdProvider(id)) == null;
});

final documentPagesProvider = FutureProvider.family<List<DocumentPage>, int>((
  ref,
  id,
) async {
  final document = ref.watch(documentByIdProvider(id));
  if (document == null || !document.isAlbum) return const <DocumentPage>[];
  return ref.watch(documentRepositoryProvider).pagesOf(document);
});
