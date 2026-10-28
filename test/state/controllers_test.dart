import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_paper/data/models/capture.dart';
import 'package:pixel_paper/data/models/folder.dart';
import 'package:pixel_paper/features/documents/application/documents_controller.dart';
import 'package:pixel_paper/features/editor/application/album_editor_controller.dart';
import 'package:pixel_paper/features/folders/application/folders_controller.dart';
import 'package:pixel_paper/features/gallery/application/gallery_controller.dart';
import 'package:pixel_paper/features/trash/application/trash_controller.dart';

import '../support/harness.dart';

void main() {
  late Sandbox sandbox;
  late ProviderContainer container;

  setUp(() async {
    sandbox = await Sandbox.create();
    container = containerFor(sandbox);
  });

  tearDown(() => sandbox.dispose());

  Future<Capture> shoot() async {
    final shot = await sandbox.write(
      sandbox.temporary,
      '${DateTime.now().microsecondsSinceEpoch}.jpg',
      jpegWithMetadata(),
    );
    await container.read(galleryControllerProvider.future);
    return container
        .read(galleryControllerProvider.notifier)
        .adopt(shot, origin: CaptureSource.camera);
  }

  test('the bin and folder counts follow every write', () async {
    final folders = container.read(
      foldersProvider(FolderKind.capture).notifier,
    );
    await container.read(foldersProvider(FolderKind.capture).future);
    final folder = (await folders.create('Ricevute'))!;
    final photo = await shoot();

    await container.read(galleryControllerProvider.notifier).move([
      photo.id,
    ], folder.id);
    expect(
      (await container.read(foldersProvider(FolderKind.capture).future))
          .single
          .itemCount,
      1,
    );

    await container.read(galleryControllerProvider.notifier).moveToTrash([
      photo.id,
    ]);
    expect(container.read(galleryControllerProvider).value, isEmpty);
    expect(
      (await container.read(trashControllerProvider.future)).captures.single.id,
      photo.id,
    );
    expect(
      (await container.read(foldersProvider(FolderKind.capture).future))
          .single
          .itemCount,
      0,
    );

    await container
        .read(trashControllerProvider.notifier)
        .undoTrash(captureIds: [photo.id]);
    expect(
      (await container.read(galleryControllerProvider.future)).single.id,
      photo.id,
    );
    expect(
      (await container.read(trashControllerProvider.future)).isEmpty,
      isTrue,
    );
  });

  test('selection is cleared by a move and pruned by a refresh', () async {
    final a = await shoot();
    final b = await shoot();
    final selection = container.read(gallerySelectionProvider.notifier)
      ..selectAll([a.id, b.id]);

    await container.read(galleryControllerProvider.notifier).move([a.id], null);
    expect(container.read(gallerySelectionProvider), isEmpty);

    selection.selectAll([a.id, b.id, 999]);
    await container.read(galleryControllerProvider.notifier).refresh();
    expect(container.read(gallerySelectionProvider), {a.id, b.id});
  });

  test('deleting a folder returns its items to the root', () async {
    final folders = container.read(
      foldersProvider(FolderKind.capture).notifier,
    );
    await container.read(foldersProvider(FolderKind.capture).future);
    final folder = (await folders.create('Temp'))!;
    final photo = await shoot();
    await container.read(galleryControllerProvider.notifier).move([
      photo.id,
    ], folder.id);
    container
        .read(currentFolderProvider(FolderKind.capture).notifier)
        .open(folder.id);

    await folders.delete(folder);

    expect(container.read(currentFolderProvider(FolderKind.capture)), isNull);
    final reloaded = await container.read(galleryControllerProvider.future);
    expect(reloaded.single.folderId, isNull);
  });

  test('concurrent writes do not lose each other', () async {
    final photos = [for (var i = 0; i < 6; i++) await shoot()];
    final gallery = container.read(galleryControllerProvider.notifier);
    await Future.wait([
      gallery.moveToTrash([photos[0].id]),
      gallery.moveToTrash([photos[1].id]),
      gallery.refresh(),
      gallery.moveToTrash([photos[2].id]),
    ]);
    expect(container.read(galleryControllerProvider).value!.length, 3);
    expect(
      (await container.read(trashControllerProvider.future)).captures.length,
      3,
    );
  });

  group('album editor', () {
    Future<int> album() async {
      final a = await shoot();
      final b = await shoot();
      await container.read(documentsControllerProvider.future);
      final doc = await container
          .read(documentsControllerProvider.notifier)
          .createAlbum(imagePaths: [a.path, b.path], title: 'Album');
      container.listen(albumEditorProvider(doc.id), (_, _) {});
      return doc.id;
    }

    test('edits stay in memory until saved', () async {
      final id = await album();
      final editor = container.read(albumEditorProvider(id).notifier);
      final before = await container.read(albumEditorProvider(id).future);

      editor.reorder(0, 1);
      final moved = container.read(albumEditorProvider(id)).value!;
      expect(moved.dirty, isTrue);
      expect(moved.pages.first, before.pages.last);
      expect(
        (await container.read(documentPagesProvider(id).future)).first,
        before.pages.first,
      );

      expect(await editor.save(), isTrue);
      final saved = container.read(albumEditorProvider(id)).value!;
      expect(saved.dirty, isFalse);
      expect(saved.pages.first.fileName, before.pages.last.fileName);
    });

    test('a discarded session deletes the files it wrote', () async {
      final id = await album();
      final editor = container.read(albumEditorProvider(id).notifier);
      await container.read(albumEditorProvider(id).future);

      await editor.duplicateCurrent();
      final state = container.read(albumEditorProvider(id)).value!;
      expect(state.pages.length, 3);
      final copy = state.pages[1].fileIn(state.document.directory);
      expect(await copy.exists(), isTrue);

      await editor.discard();
      expect(await copy.exists(), isFalse);
    });

    test('the last page cannot be deleted and indexes stay in range', () async {
      final id = await album();
      final editor = container.read(albumEditorProvider(id).notifier);
      await container.read(albumEditorProvider(id).future);

      editor
        ..show(1)
        ..deleteCurrent()
        ..deleteCurrent()
        ..reorder(5, -3)
        ..show(99);
      final state = container.read(albumEditorProvider(id)).value!;
      expect(state.pages.length, 1);
      expect(state.index, 0);
      expect(state.canDelete, isFalse);
    });
  });
}
