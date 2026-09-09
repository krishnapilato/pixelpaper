import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/text_prompt.dart';
import '../../../data/models/capture.dart';
import '../../../data/models/folder.dart';
import '../../documents/application/documents_controller.dart';
import '../../folders/application/folders_controller.dart';
import '../../folders/presentation/draggable_item.dart';
import '../../folders/presentation/folder_sheets.dart';
import '../../folders/presentation/folder_strip.dart';
import '../../trash/presentation/trash_feedback.dart';
import '../application/gallery_controller.dart';
import 'capture_preview.dart';
import 'widgets/capture_tile.dart';

/// Module B: raw captures, folders, and the path from a selection to a PDF.
class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final captures = ref.watch(visibleCapturesProvider);
    final selection = ref.watch(gallerySelectionProvider);
    final columns = ref.watch(galleryColumnsProvider);
    final folder = ref.watch(currentFolderDetailProvider(FolderKind.capture));
    final items = captures.value ?? const <Capture>[];

    return PopScope(
      // Back walks out of selection, then out of the folder, then out of the
      // app — one predictable ladder instead of a surprise exit.
      canPop: selection.isEmpty && folder == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (selection.isNotEmpty) {
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
              _appBar(context, ref, strings, selection, items, columns, folder),
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
                        action: FilledButton.icon(
                          onPressed: () => context.push(Routes.camera),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: Text(strings('camera_title')),
                        ),
                      ),
                    ),
                  ],
                AsyncData(:final value) => [
                    _grid(context, ref, value, selection, columns),
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

  Widget _appBar(
    BuildContext context,
    WidgetRef ref,
    Strings strings,
    Set<int> selection,
    List<Capture> captures,
    int columns,
    Folder? folder,
  ) {
    if (selection.isNotEmpty) {
      final selected = captures
          .where((c) => selection.contains(c.id))
          .toList(growable: false);

      return SliverAppBar(
        pinned: true,
        leading: IconButton(
          onPressed: ref.read(gallerySelectionProvider.notifier).clear,
          icon: const Icon(Icons.close_rounded),
          tooltip: strings('common_close'),
        ),
        title: Text(strings.plural('gallery_selected', selection.length)),
        actions: [
          IconButton(
            onPressed: () => _share(context, ref, selected),
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: strings('common_share'),
          ),
          IconButton(
            onPressed: () => _createPdf(context, ref, selected),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: strings('gallery_create_pdf'),
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
      title: Text(folder?.name ?? strings('gallery_title')),
      actions: [
        IconButton(
          onPressed: ref.read(galleryColumnsProvider.notifier).cycle,
          icon: Icon(
            switch (columns) {
              2 => Icons.grid_view_rounded,
              3 => Icons.grid_on_rounded,
              _ => Icons.apps_rounded,
            },
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

  Widget _grid(
    BuildContext context,
    WidgetRef ref,
    List<Capture> captures,
    Set<int> selection,
    int columns,
  ) {
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
        itemBuilder: (context, index) {
          final capture = captures[index];
          return LibraryDraggable(
            key: ValueKey(capture.id),
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
              selected: selection.contains(capture.id),
              selectionActive: selection.isNotEmpty,
              onTap: () {
                if (selection.isEmpty) {
                  // rootNavigator: a full-screen photo must cover the shell —
                  // pushing inside the tab would leave the FAB and the bottom
                  // bar floating over the image.
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CapturePreview(
                        captures: captures,
                        initialIndex: index,
                      ),
                    ),
                  );
                } else {
                  ref.read(gallerySelectionProvider.notifier).toggle(capture.id);
                }
              },
            ),
          );
        },
      ),
    );
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

  Future<void> _createPdf(
    BuildContext context,
    WidgetRef ref,
    List<Capture> captures,
  ) async {
    if (captures.isEmpty) return;
    final strings = ref.read(stringsProvider);

    final name = await askForText(
      context,
      title: strings('scan_naming_title'),
      subtitle: captures.length == 1
          ? strings('scan_naming_body_one')
          : strings('scan_naming_body', {'n': captures.length}),
      hint: strings('scan_naming_hint'),
      actionLabel: strings('scan_create_pdf'),
      cancelLabel: strings('common_cancel'),
      initialValue: Fmt.defaultDocumentName(DateTime.now()),
      icon: Icons.picture_as_pdf_outlined,
    );
    if (name == null || !context.mounted) return;

    // Pages follow the order shown on screen, not the order the user tapped:
    // the grid is the mental model of "what my document will look like".
    final paths = captures.map((c) => c.path).toList(growable: false);

    try {
      // Twelve full-resolution photos take seconds to become a PDF, and until
      // now the screen showed nothing at all while it happened.
      final document = await withBusy(
        context,
        strings.plural('gallery_creating_pdf', paths.length),
        () => ref.read(documentsControllerProvider.notifier).createFromImages(
              imagePaths: paths,
              title: name,
            ),
      );
      ref.read(gallerySelectionProvider.notifier).clear();
      if (!context.mounted) return;
      showSnack(context, strings('scan_created'),
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
}
