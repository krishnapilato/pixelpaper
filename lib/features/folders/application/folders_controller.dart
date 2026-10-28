import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/library_revision.dart';
import '../../../data/models/folder.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/library_repository.dart';

/// Folders of one library, with live counts; rebuilt on every library write.
class FoldersController extends AsyncNotifier<List<Folder>> {
  FoldersController(this.kind);

  final FolderKind kind;

  LibraryRepository get _repository => ref.read(libraryRepositoryProvider);

  @override
  Future<List<Folder>> build() {
    ref.watch(libraryRevisionProvider);
    return _repository.folders(kind);
  }

  /// Null when the name is empty or already used.
  Future<Folder?> create(String name) async {
    final folder = await _repository.createFolder(name, kind);
    if (folder != null && ref.mounted) ref.libraryChanged();
    return folder;
  }

  Future<bool> rename(Folder folder, String name) async {
    final ok = await _repository.renameFolder(folder, name);
    if (ok && ref.mounted) ref.libraryChanged();
    return ok;
  }

  /// What was inside goes back to the root of the library.
  Future<void> delete(Folder folder) async {
    await _repository.deleteFolder(folder);
    if (!ref.mounted) return;
    final current = ref.read(currentFolderProvider(kind).notifier);
    if (ref.read(currentFolderProvider(kind)) == folder.id) current.clear();
    ref.invalidate(folderReleasedProvider(kind));
    ref.libraryChanged();
  }
}

final foldersProvider =
    AsyncNotifierProvider.family<FoldersController, List<Folder>, FolderKind>(
      FoldersController.new,
    );

/// Watched by the item lists of one library so they reload once a folder is
/// deleted and its items have moved back to the root.
final folderReleasedProvider = Provider.family<Object, FolderKind>(
  (ref, kind) => Object(),
);

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

final currentFolderDetailProvider = Provider.family<Folder?, FolderKind>((
  ref,
  kind,
) {
  final id = ref.watch(currentFolderProvider(kind));
  if (id == null) return null;
  for (final folder
      in ref.watch(foldersProvider(kind)).value ?? const <Folder>[]) {
    if (folder.id == id) return folder;
  }
  return null;
});
