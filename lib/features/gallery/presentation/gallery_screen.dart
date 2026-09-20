import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/text_prompt.dart';
import '../../../data/models/capture.dart';
import '../../../data/models/folder.dart';
import '../../documents/application/documents_controller.dart';
import '../../folders/application/folders_controller.dart';
import '../../folders/presentation/draggable_item.dart';
import '../../folders/presentation/folder_sheets.dart';
import '../../folders/presentation/folder_strip.dart';
import '../../trash/presentation/trash_feedback.dart';
import '../application/capture_flow.dart';
import '../application/gallery_controller.dart';
import 'capture_preview.dart';
import 'widgets/capture_tile.dart';

/// Module B: raw captures, folders, and the path from a selection to an
/// album.
///
/// The screen watches the selection only as far as it has to: whether one
/// exists (for the back button). The contextual bar and each tile watch their
/// own slice of it, so a tap repaints one tile and the bar — not the grid.
class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final captures = ref.watch(visibleCapturesProvider);
    final selecting = ref.watch(
      gallerySelectionProvider.select((s) => s.isNotEmpty),
    );
    final columns = ref.watch(galleryColumnsProvider);
    final folder = ref.watch(currentFolderDetailProvider(FolderKind.capture));
    final folderId = ref.watch(currentFolderProvider(FolderKind.capture));

    return PopScope(
      // Back walks out of selection, then out of the folder, then out of the
      // app — one predictable ladder instead of a surprise exit.
      canPop: !selecting && folder == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (selecting) {
          ref.read(gallerySelectionProvider.notifier).clear();
        } else if (folder != null) {
          ref.read(currentFolderProvider(FolderKind.capture).notifier).clear();
        }
      },
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () =>
              ref.read(galleryControllerProvider.notifier).refresh(),
          child: CustomScrollView(
            slivers: [
              _GalleryAppBar(
                captures: captures.value ?? const <Capture>[],
                columns: columns,
                folder: folder,
              ),
              PinnedFolderStrip(
                kind: FolderKind.capture,
                onMove: (ids, folderId) => _move(context, ref, ids, folderId),
              ),
              ...switch (captures) {
                AsyncData(:final value) when value.isEmpty => [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.photo_camera_outlined,
                        title: strings('gallery_empty_title'),
                        body: strings('gallery_empty_body'),
                        // Both ways in, spelled out: the action button hides
                        // import behind a hold, and an empty gallery is where
                        // someone is most likely to be looking for it.
                        action: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton.icon(
                              onPressed: () => CaptureFlow.openCamera(context),
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: Text(strings('camera_title')),
                            ),
                            const SizedBox(height: Space.xs),
                            TextButton.icon(
                              onPressed: () =>
                                  CaptureFlow.importPhotos(context, ref),
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                              ),
                              label: Text(strings('camera_import')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                AsyncData(:final value) => [
                    EntranceGroup(
                      // A different folder or density is a different grid:
                      // it cascades in again. A new photo enters on its own.
                      epoch: (folderId, columns),
                      ids: value.map((c) => c.id),
                      child: _grid(context, value, columns),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: Space.bottomInset),
                    ),
                  ],
                AsyncError() => [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.error_outline_rounded,
                        title: strings('common_error'),
                        body: strings('gallery_empty_body'),
                      ),
                    ),
                  ],
                _ => const [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(BuildContext context, List<Capture> captures, int columns) {
    final extent =
        (MediaQuery.sizeOf(context).width - Space.md * 2) / columns - Space.xs;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, 0),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: Space.xs,
          crossAxisSpacing: Space.xs,
        ),
        itemCount: captures.length,
        addAutomaticKeepAlives: false,
        itemBuilder: (context, index) => Entrance(
          key: ValueKey(captures[index].id),
          id: captures[index].id,
          index: index,
          child: _GalleryItem(
            captures: captures,
            index: index,
            extent: extent,
          ),
        ),
      ),
    );
  }
}

/// One tile, watching only its own place in the selection.
class _GalleryItem extends ConsumerWidget {
  const _GalleryItem({
    required this.captures,
    required this.index,
    required this.extent,
  });

  final List<Capture> captures;
  final int index;
  final double extent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capture = captures[index];
    final order = ref.watch(
      gallerySelectionProvider.select((s) => selectionOrder(s, capture.id)),
    );
    final selecting = ref.watch(
      gallerySelectionProvider.select((s) => s.isNotEmpty),
    );

    return LibraryDraggable(
      kind: FolderKind.capture,
      id: capture.id,
      selectionProvider: gallerySelectionProvider,
      preview: Image.file(
        capture.file,
        fit: BoxFit.cover,
        cacheWidth: 200,
        gaplessPlayback: true,
      ),
      child: CaptureTile(
        capture: capture,
        extent: extent,
        order: order,
        selectionActive: selecting,
        onTap: () {
          if (!selecting) {
            // rootNavigator: a full-screen photo must cover the shell —
            // pushing inside the tab would leave the button and the bottom
            // bar floating over the image.
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    CapturePreview(captures: captures, initialIndex: index),
              ),
            );
          } else {
            ref.read(gallerySelectionProvider.notifier).toggle(capture.id);
          }
        },
      ),
    );
  }
}

/// 1-based position of [id] in the selection, in the order it was picked.
int? selectionOrder(Set<int> selection, int id) {
  var position = 0;
  for (final selected in selection) {
    position++;
    if (selected == id) return position;
  }
  return null;
}

/// The large title at rest, the contextual bar while photos are selected.
class _GalleryAppBar extends ConsumerWidget {
  const _GalleryAppBar({
    required this.captures,
    required this.columns,
    required this.folder,
  });

  final List<Capture> captures;
  final int columns;
  final Folder? folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final selection = ref.watch(gallerySelectionProvider);

    if (selection.isNotEmpty) {
      // In the order the photos were picked: that is the order an album
      // made from them will have.
      final byId = {for (final capture in captures) capture.id: capture};
      final selected = [for (final id in selection) ?byId[id]];

      return SliverAppBar(
        pinned: true,
        leading: IconButton(
          onPressed: ref.read(gallerySelectionProvider.notifier).clear,
          icon: const Icon(Icons.close_rounded),
          tooltip: strings('common_close'),
        ),
        title: Swapped(
          value: selection.length,
          child: Text(strings.plural('gallery_selected', selection.length)),
        ),
        actions: [
          IconButton(
            onPressed: () => _share(context, ref, selected),
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: strings('common_share'),
          ),
          IconButton(
            onPressed: () => _createAlbum(context, ref, selected),
            icon: const Icon(Icons.photo_album_outlined),
            tooltip: strings('gallery_create_album'),
          ),
          // The rest lives in an overflow: four visible actions is where a
          // contextual bar stops being readable at a glance.
          MenuAnchor(
            menuChildren: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.select_all_rounded),
                onPressed: () => ref
                    .read(gallerySelectionProvider.notifier)
                    .selectAll(captures.map((c) => c.id)),
                child: Text(strings('gallery_select_all')),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.drive_file_move_outline),
                onPressed: () => showMoveToFolderSheet(
                  context,
                  ref,
                  kind: FolderKind.capture,
                  ids: selection,
                  onMove: (ids, folderId) => _move(context, ref, ids, folderId),
                ),
                child: Text(strings('folders_move_title')),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => _trash(context, ref, selected),
                child: Text(strings('common_delete')),
              ),
            ],
            builder: (context, controller, child) => IconButton(
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ),
          const SizedBox(width: Space.xxs),
        ],
      );
    }

    return SliverAppBar.large(
      pinned: true,
      leading: folder == null
          ? null
          : IconButton(
              onPressed: () => ref
                  .read(currentFolderProvider(FolderKind.capture).notifier)
                  .clear(),
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: strings('folders_all'),
            ),
      title: AnimatedSwitcher(
        duration: Motion.base,
        switchInCurve: Motion.enter,
        switchOutCurve: Motion.exit,
        child: Text(
          folder?.name ?? strings('gallery_title'),
          key: ValueKey(folder?.id),
        ),
      ),
      actions: [
        IconButton(
          onPressed: ref.read(galleryColumnsProvider.notifier).cycle,
          icon: AnimatedSwitcher(
            duration: Motion.quick,
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              switch (columns) {
                2 => Icons.grid_view_rounded,
                3 => Icons.grid_on_rounded,
                _ => Icons.apps_rounded,
              },
              key: ValueKey(columns),
            ),
          ),
          tooltip: strings('view_grid'),
        ),
        IconButton(
          onPressed: () => context.push(Routes.settings),
          icon: const Icon(Icons.settings_outlined),
          tooltip: strings('settings_title'),
        ),
        const SizedBox(width: Space.xxs),
      ],
    );
  }
}

/// Sharing a whole selection copies every file into the cache first, so this
/// is the call most likely to run out of room. Failing silently made it look
/// like a dead button; see [DocumentActions.share].
Future<void> _share(
  BuildContext context,
  WidgetRef ref,
  List<Capture> captures,
) async {
  if (captures.isEmpty) return;
  final strings = ref.read(stringsProvider);
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          for (final capture in captures)
            XFile(capture.path, mimeType: capture.mimeType),
        ],
      ),
    );
  } on Object {
    if (!context.mounted) return;
    showSnack(
      context,
      strings('share_failed'),
      icon: Icons.error_outline_rounded,
    );
  }
}

Future<void> _move(
  BuildContext context,
  WidgetRef ref,
  Set<int> ids,
  int? folderId,
) async {
  final strings = ref.read(stringsProvider);
  await ref.read(galleryControllerProvider.notifier).move(ids, folderId);
  if (!context.mounted) return;
  showSnack(context, strings('folders_moved'),
      icon: Icons.drive_file_move_outline);
}

/// Copies the selected photos, in the order they were picked, into a new
/// album in the Archivio. No PDF is made here: that happens when the album is
/// shared, printed or exported.
Future<void> _createAlbum(
  BuildContext context,
  WidgetRef ref,
  List<Capture> captures,
) async {
  if (captures.isEmpty) return;
  final strings = ref.read(stringsProvider);

  final name = await askForText(
    context,
    title: strings('gallery_album_title'),
    subtitle: strings.plural('gallery_album_body', captures.length),
    hint: strings('scan_naming_hint'),
    actionLabel: strings('gallery_create_album'),
    cancelLabel: strings('common_cancel'),
    initialValue: Fmt.defaultDocumentName(DateTime.now()),
    icon: Icons.photo_album_outlined,
  );
  if (name == null || !context.mounted) return;

  final paths = captures.map((c) => c.path).toList(growable: false);

  try {
    final document = await withBusy(
      context,
      strings.plural('gallery_creating_album', paths.length),
      () => ref.read(documentsControllerProvider.notifier).createFromImages(
            imagePaths: paths,
            title: name,
          ),
    );
    ref.read(gallerySelectionProvider.notifier).clear();
    if (!context.mounted) return;
    showSnack(context, strings('gallery_album_created'),
        icon: Icons.check_circle_outline_rounded);
    context.push(Routes.viewer(document.id));
  } on Object {
    if (!context.mounted) return;
    showSnack(context, strings('common_error'),
        icon: Icons.error_outline_rounded);
  }
}

Future<void> _trash(
  BuildContext context,
  WidgetRef ref,
  List<Capture> captures,
) async {
  if (captures.isEmpty) return;
  final ids = captures.map((c) => c.id).toSet();
  await ref.read(galleryControllerProvider.notifier).moveToTrash(captures);
  if (!context.mounted) return;
  showTrashedSnack(context, ref, kind: FolderKind.capture, ids: ids);
}
