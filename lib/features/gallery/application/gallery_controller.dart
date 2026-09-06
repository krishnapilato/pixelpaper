import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/selection_controller.dart';
import '../../../data/models/capture.dart';
import '../../../data/providers.dart';
import '../../../data/models/folder.dart';
import '../../../data/repositories/capture_repository.dart';
import '../../folders/application/folders_controller.dart';
import '../../trash/application/trash_controller.dart';

/// The raw-image gallery.
class GalleryController extends AsyncNotifier<List<Capture>> {
  CaptureRepository get _repository => ref.read(captureRepositoryProvider);

  @override
  Future<List<Capture>> build() => _repository.load();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.load);
    final live = state.value?.map((c) => c.id).toSet();
    if (live != null) ref.read(gallerySelectionProvider.notifier).retain(live);
  }

  /// Stores a photo the camera just produced.
  Future<Capture> adopt(File source, {required CaptureSource origin}) async {
    final capture = await _repository.adopt(source, origin: origin);
    final current = state.value ?? const <Capture>[];
    state = AsyncData([capture, ...current]);
    return capture;
  }

  /// Called after the image editor overwrote a photo: refreshes its row so the
  /// grid, the details sheet and every image cache see the new picture.
  Future<Capture> remeasure(Capture capture) async {
    final updated = await _repository.remeasure(capture);
    final current = state.value;
    if (current != null) {
      state = AsyncData([
        for (final item in current) item.id == updated.id ? updated : item,
      ]);
    }
    return updated;
  }

  /// Moves photos to the bin (recoverable for 30 days).
  Future<void> moveToTrash(List<Capture> captures) async {
    if (captures.isEmpty) return;
    final removed = captures.map((c) => c.id).toSet();
    await ref.read(libraryRepositoryProvider).trashCaptures(removed);
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.where((c) => !removed.contains(c.id)).toList(growable: false),
      );
    }
    ref.read(gallerySelectionProvider.notifier).clear();
    await ref.read(trashControllerProvider.notifier).refresh();
    await ref.read(foldersProvider(FolderKind.capture).notifier).refresh();
  }

  Future<void> move(Iterable<int> ids, int? folderId) async {
    if (ids.isEmpty) return;
    await ref.read(libraryRepositoryProvider).moveCaptures(ids, folderId);
    final current = state.value;
    if (current != null) {
      state = AsyncData([
        for (final item in current)
          ids.contains(item.id)
              ? Capture(
                  id: item.id,
                  path: item.path,
                  createdAt: item.createdAt,
                  sizeBytes: item.sizeBytes,
                  source: item.source,
                  width: item.width,
                  height: item.height,
                  folderId: folderId,
                )
              : item,
      ]);
    }
    ref.read(gallerySelectionProvider.notifier).clear();
    await ref.read(foldersProvider(FolderKind.capture).notifier).refresh();
  }
}

final galleryControllerProvider =
    AsyncNotifierProvider<GalleryController, List<Capture>>(
      GalleryController.new,
    );

final gallerySelectionProvider =
    NotifierProvider<SelectionController, Set<int>>(SelectionController.new);

/// How many columns the gallery uses. Three is the default: big enough to
/// recognise a page, small enough to scan a roll quickly.
class GalleryColumnsController extends Notifier<int> {
  @override
  int build() => 3;

  void cycle() => state = state >= 4 ? 2 : state + 1;
}

final galleryColumnsProvider = NotifierProvider<GalleryColumnsController, int>(
  GalleryColumnsController.new,
);

/// The photos of the folder currently open (all of them at the root).
final visibleCapturesProvider = Provider<AsyncValue<List<Capture>>>((ref) {
  final captures = ref.watch(galleryControllerProvider);
  final folderId = ref.watch(currentFolderProvider(FolderKind.capture));
  return captures.whenData(
    (list) => folderId == null
        ? list
        : list.where((c) => c.folderId == folderId).toList(growable: false),
  );
});
