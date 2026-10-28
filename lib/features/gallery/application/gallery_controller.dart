import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/library_revision.dart';
import '../../../core/state/limits.dart';
import '../../../core/state/selection_controller.dart';
import '../../../core/state/serial.dart';
import '../../../data/models/capture.dart';
import '../../../data/models/folder.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/capture_repository.dart';
import '../../folders/application/folders_controller.dart';

/// The photo gallery. Writes are serialised and patch the loaded list.
class GalleryController extends AsyncNotifier<List<Capture>> {
  final Serial _serial = Serial();

  CaptureRepository get _repository => ref.read(captureRepositoryProvider);

  @override
  Future<List<Capture>> build() {
    ref.watch(folderReleasedProvider(FolderKind.capture));
    return _repository.load().bounded();
  }

  Future<void> refresh() => _serial.run(() async {
    final next = await AsyncValue.guard(() => _repository.load().bounded());
    if (!ref.mounted) return;
    state = next;
    final live = next.value?.map((c) => c.id).toSet();
    if (live != null) ref.read(gallerySelectionProvider.notifier).retain(live);
  });

  Future<Capture> adopt(
    File source, {
    required CaptureSource origin,
    int? folderId,
  }) => _write(
    () => _repository.adopt(source, origin: origin, folderId: folderId),
    (list, capture) => [capture, ...list],
  );

  /// Replaces a photo with an edited version of itself.
  Future<Capture> replaceContent(Capture capture, Uint8List bytes) => _write(
    () => _repository.replaceContent(capture, bytes),
    (list, updated) => [for (final c in list) c.id == updated.id ? updated : c],
  );

  Future<void> moveToTrash(Iterable<int> ids) {
    final removed = ids.toSet();
    return _write(
      () => ref.read(libraryRepositoryProvider).trashCaptures(removed),
      (list, _) => [
        for (final c in list)
          if (!removed.contains(c.id)) c,
      ],
      clearSelection: true,
    );
  }

  Future<void> move(Iterable<int> ids, int? folderId) {
    final moved = ids.toSet();
    return _write(
      () => ref.read(libraryRepositoryProvider).moveCaptures(moved, folderId),
      (list, _) => [
        for (final c in list)
          moved.contains(c.id)
              ? c.copyWith(folderId: folderId, clearFolder: folderId == null)
              : c,
      ],
      clearSelection: true,
    );
  }

  Future<T> _write<T>(
    Future<T> Function() write,
    List<Capture> Function(List<Capture> list, T result) patch, {
    bool clearSelection = false,
  }) => _serial.run(() async {
    final result = await write();
    if (!ref.mounted) return result;
    final current = state.value;
    if (current != null) {
      state = AsyncData(List.unmodifiable(patch(current, result)));
    }
    if (clearSelection) ref.read(gallerySelectionProvider.notifier).clear();
    ref.libraryChanged();
    return result;
  });
}

final galleryControllerProvider =
    AsyncNotifierProvider<GalleryController, List<Capture>>(
      GalleryController.new,
    );

final gallerySelectionProvider =
    NotifierProvider<SelectionController, Set<int>>(SelectionController.new);

class GalleryColumnsController extends Notifier<int> {
  @override
  int build() => 3;

  void cycle() => state = state >= 4 ? 2 : state + 1;
}

final galleryColumnsProvider = NotifierProvider<GalleryColumnsController, int>(
  GalleryColumnsController.new,
);

final visibleCapturesProvider = Provider<AsyncValue<List<Capture>>>((ref) {
  final folderId = ref.watch(currentFolderProvider(FolderKind.capture));
  return ref
      .watch(galleryControllerProvider)
      .whenData(
        (list) => folderId == null
            ? list
            : [
                for (final c in list)
                  if (c.folderId == folderId) c,
              ],
      );
});

/// Photos already copied into a live document, and their weight: safe to
/// delete, nothing is lost.
final duplicatedCapturesProvider =
    FutureProvider.autoDispose<({List<Capture> captures, int bytes})>((
      ref,
    ) async {
      ref.watch(libraryRevisionProvider);
      final captures = ref.watch(galleryControllerProvider).value ?? const [];
      if (captures.isEmpty) return (captures: const <Capture>[], bytes: 0);
      final paged = await ref
          .watch(documentRepositoryProvider)
          .pagedCapturePaths();
      final duplicated = [
        for (final c in captures)
          if (paged.contains(c.path)) c,
      ];
      return (
        captures: duplicated,
        bytes: duplicated.fold(0, (sum, c) => sum + c.sizeBytes),
      );
    });
