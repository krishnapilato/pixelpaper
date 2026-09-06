import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/folder.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/library_repository.dart';

/// Folders of one library.
class FoldersController extends AsyncNotifier<List<Folder>> {
  FoldersController(this.kind);

  final FolderKind kind;

  LibraryRepository get _repository => ref.read(libraryRepositoryProvider);

  @override
  Future<List<Folder>> build() => _repository.folders(kind);

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _repository.folders(kind));
  }

  /// Returns null when a folder with that name already exists.
  Future<Folder?> create(String name) async {
    final folder = await _repository.createFolder(name, kind);
    if (folder != null) await refresh();
    return folder;
  }

  Future<bool> rename(Folder folder, String name) async {
    final ok = await _repository.renameFolder(folder, name);
    if (ok) await refresh();
    return ok;
  }

  /// Deleting a folder never deletes what is inside it: the items return to
  /// the root of the library.
  Future<void> delete(Folder folder) async {
    await _repository.deleteFolder(folder);
    if (ref.read(currentFolderProvider(kind)) == folder.id) {
      ref.read(currentFolderProvider(kind).notifier).clear();
    }
    await refresh();
  }
}

final foldersProvider =
    AsyncNotifierProvider.family<FoldersController, List<Folder>, FolderKind>(
  FoldersController.new,
);

/// Which folder the user is looking at; null means the whole library.
class CurrentFolderController extends Notifier<int?> {
  CurrentFolderController(this.kind);

  final FolderKind kind;

  @override
  int? build() => null;

  void open(int? folderId) => state = folderId;
  void clear() => state = null;
}

final currentFolderProvider =
    NotifierProvider.family<CurrentFolderController, int?, FolderKind>(
  CurrentFolderController.new,
);

/// The folder currently open, resolved to its row (null at the root).
final currentFolderDetailProvider =
    Provider.family<Folder?, FolderKind>((ref, kind) {
  final id = ref.watch(currentFolderProvider(kind));
  if (id == null) return null;
  final folders = ref.watch(foldersProvider(kind)).value;
  if (folders == null) return null;
  for (final folder in folders) {
    if (folder.id == id) return folder;
  }
  return null;
});
