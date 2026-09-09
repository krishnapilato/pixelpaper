import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/capture.dart';
import '../../../data/models/scanned_document.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/library_repository.dart';
import '../../documents/application/documents_controller.dart';
import '../../gallery/application/gallery_controller.dart';

/// The recycle bin, holding both libraries.
class TrashController extends AsyncNotifier<TrashContents> {
  LibraryRepository get _repository => ref.read(libraryRepositoryProvider);

  @override
  Future<TrashContents> build() => _repository.trash();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.trash);
  }

  Future<void> restore({
    List<ScannedDocument> documents = const [],
    List<Capture> captures = const [],
  }) async {
    await _repository.restoreDocuments(documents.map((d) => d.id));
    await _repository.restoreCaptures(captures.map((c) => c.id));
    await _reloadEverything();
  }

  Future<void> purge({
    List<ScannedDocument> documents = const [],
    List<Capture> captures = const [],
  }) async {
    await _repository.purge(documents: documents, captures: captures);
    await refresh();
  }

  Future<void> emptyAll() async {
    await _repository.emptyTrash();
    await refresh();
  }

  Future<void> _reloadEverything() async {
    await refresh();
    await ref.read(documentsControllerProvider.notifier).refresh();
    await ref.read(galleryControllerProvider.notifier).refresh();
  }
}

final trashControllerProvider =
    AsyncNotifierProvider<TrashController, TrashContents>(TrashController.new);

/// Number of items in the bin, for the Impostazioni row.
final trashCountProvider = Provider<int>(
  (ref) => ref.watch(trashControllerProvider).value?.length ?? 0,
);

/// What the bin is holding, in bytes.
///
/// Shown next to "Cestino" so the 30-day window has a visible price. Nothing
/// here shortens that window: a document deleted by mistake three weeks ago
/// is still there, and the user who needs the space empties the bin on
/// purpose instead of having it emptied for them.
final trashSizeProvider = FutureProvider<int>((ref) async {
  final contents = ref.watch(trashControllerProvider).value;
  if (contents == null) return 0;
  var bytes = 0;
  for (final document in contents.documents) {
    bytes += document.sizeBytes;
  }
  for (final capture in contents.captures) {
    bytes += capture.sizeBytes;
  }
  return bytes;
});
