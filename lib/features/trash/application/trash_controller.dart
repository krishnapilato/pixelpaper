import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/library_revision.dart';
import '../../../core/state/limits.dart';
import '../../../core/state/serial.dart';
import '../../../data/models/capture.dart';
import '../../../data/models/scanned_document.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/library_repository.dart';
import '../../documents/application/documents_controller.dart';
import '../../gallery/application/gallery_controller.dart';

/// The bin, both libraries together; rebuilt on every library write.
class TrashController extends AsyncNotifier<TrashContents> {
  final Serial _serial = Serial();

  LibraryRepository get _repository => ref.read(libraryRepositoryProvider);

  @override
  Future<TrashContents> build() {
    ref.watch(libraryRevisionProvider);
    return _repository.trash().bounded();
  }

  Future<void> restore({
    Iterable<ScannedDocument> documents = const [],
    Iterable<Capture> captures = const [],
  }) => _restoreIds(
    documentIds: documents.map((d) => d.id),
    captureIds: captures.map((c) => c.id),
  );

  /// Undo of a move to the bin, by id.
  Future<void> undoTrash({
    Iterable<int> documentIds = const [],
    Iterable<int> captureIds = const [],
  }) => _restoreIds(documentIds: documentIds, captureIds: captureIds);

  Future<void> _restoreIds({
    required Iterable<int> documentIds,
    required Iterable<int> captureIds,
  }) => _serial.run(() async {
    final docs = documentIds.toSet();
    final caps = captureIds.toSet();
    await _repository.restoreDocuments(docs);
    await _repository.restoreCaptures(caps);
    if (!ref.mounted) return;
    if (docs.isNotEmpty) ref.invalidate(documentsControllerProvider);
    if (caps.isNotEmpty) ref.invalidate(galleryControllerProvider);
    ref.libraryChanged();
  });

  /// Rows and files, for good.
  Future<void> purge({
    Iterable<ScannedDocument> documents = const [],
    Iterable<Capture> captures = const [],
  }) => _serial.run(() async {
    await _repository.purge(documents: documents, captures: captures);
    if (ref.mounted) ref.libraryChanged();
  });

  Future<void> emptyAll() => _serial.run(() async {
    await _repository.emptyTrash();
    if (ref.mounted) ref.libraryChanged();
  });
}

final trashControllerProvider =
    AsyncNotifierProvider<TrashController, TrashContents>(TrashController.new);

final trashCountProvider = Provider<int>(
  (ref) => ref.watch(trashControllerProvider).value?.length ?? 0,
);

final trashSizeProvider = Provider<int>(
  (ref) => ref.watch(trashControllerProvider).value?.sizeBytes ?? 0,
);
