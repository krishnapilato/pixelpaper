import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/feedback.dart';
import '../../../data/models/folder.dart';
import '../../../data/models/scanned_document.dart';
import '../../folders/application/folders_controller.dart';
import '../../folders/presentation/draggable_item.dart';
import '../../folders/presentation/folder_sheets.dart';
import '../../folders/presentation/folder_strip.dart';
import '../application/document_actions.dart';
import '../application/documents_controller.dart';
import 'widgets/document_actions_sheet.dart';
import 'widgets/document_thumbnail.dart';
import 'widgets/document_tile.dart';

/// Module C: the archive.
class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchController.clear();
        ref.read(documentQueryProvider.notifier).clear();
      }
    });
  }

  void _open(ScannedDocument document) {
    final selection = ref.read(documentSelectionProvider);
    if (selection.isEmpty) {
      context.push(Routes.viewer(document.id));
    } else {
      ref.read(documentSelectionProvider.notifier).toggle(document.id);
    }
  }

  List<ScannedDocument> _selectedFrom(List<ScannedDocument> documents) {
    final ids = ref.read(documentSelectionProvider);
    return documents.where((d) => ids.contains(d.id)).toList(growable: false);
  }

  Future<void> _move(Set<int> ids, int? folderId) async {
    final strings = ref.read(stringsProvider);
    await ref.read(documentsControllerProvider.notifier).move(ids, folderId);
    if (!mounted) return;
    showSnack(context, strings('folders_moved'),
        icon: Icons.drive_file_move_outline);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final documents = ref.watch(visibleDocumentsProvider);
    final selection = ref.watch(documentSelectionProvider);
    final isGrid = ref.watch(documentGridProvider);
    final folder = ref.watch(currentFolderDetailProvider(FolderKind.document));
    final all = documents.value ?? const <ScannedDocument>[];

    return PopScope(
      // Back unwinds one layer at a time: selection, then search, then the
      // open folder, and only then the app.
      canPop: selection.isEmpty && !_searching && folder == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (selection.isNotEmpty) {
          ref.read(documentSelectionProvider.notifier).clear();
        } else if (_searching) {
          _toggleSearch();
        } else if (folder != null) {
          ref.read(currentFolderProvider(FolderKind.document).notifier).clear();
        }
      },
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () =>
              ref.read(documentsControllerProvider.notifier).refresh(),
          child: CustomScrollView(
            slivers: [
              _appBar(strings, selection, all, isGrid, folder),
              if (!_searching)
                PinnedFolderStrip(kind: FolderKind.document, onMove: _move),
              ...switch (documents) {
                AsyncData(:final value) when value.isEmpty => [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: ref.watch(documentQueryProvider).isEmpty
                            ? Icons.folder_open_outlined
                            : Icons.search_off_rounded,
                        title: ref.watch(documentQueryProvider).isEmpty
                            ? strings('documents_empty_title')
                            : strings('documents_search_empty_title'),
                        body: ref.watch(documentQueryProvider).isEmpty
                            ? strings('documents_empty_body')
                            : strings('documents_search_empty_body'),
                      ),
                    ),
                  ],
                AsyncData(:final value) => [
                    if (isGrid)
                      _grid(value, selection)
                    else
                      _list(value, selection),
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
                        body: strings('documents_empty_body'),
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
    Strings strings,
    Set<int> selection,
    List<ScannedDocument> documents,
    bool isGrid,
    Folder? folder,
  ) {
    if (selection.isNotEmpty) {
      final selected = _selectedFrom(documents);
      return SliverAppBar(
        pinned: true,
        leading: IconButton(
          onPressed: ref.read(documentSelectionProvider.notifier).clear,
          icon: const Icon(Icons.close_rounded),
          tooltip: strings('common_close'),
        ),
        title: Text(strings.plural('documents_selected', selection.length)),
        actions: [
          IconButton(
            onPressed: () => DocumentActions.share(context, ref, selected),
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: strings('common_share'),
          ),
          IconButton(
            onPressed: () => DocumentActions.delete(context, ref, selected),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: strings('common_delete'),
          ),
          MenuAnchor(
            menuChildren: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.select_all_rounded),
                onPressed: () => ref
                    .read(documentSelectionProvider.notifier)
                    .selectAll(documents.map((d) => d.id)),
                child: Text(strings('gallery_select_all')),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.drive_file_move_outline),
                onPressed: () => showMoveToFolderSheet(
                  context,
                  ref,
                  kind: FolderKind.document,
                  ids: selection,
                  onMove: _move,
                ),
                child: Text(strings('folders_move_title')),
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

    if (_searching) {
      return SliverAppBar(
        pinned: true,
        leading: IconButton(
          onPressed: _toggleSearch,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: ref.read(documentQueryProvider.notifier).update,
          decoration: InputDecoration(
            hintText: strings('documents_search_hint'),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              _searchController.clear();
              ref.read(documentQueryProvider.notifier).clear();
            },
            icon: const Icon(Icons.backspace_outlined),
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
                  .read(currentFolderProvider(FolderKind.document).notifier)
                  .clear(),
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: strings('folders_all'),
            ),
      title: Text(folder?.name ?? strings('documents_title')),
      actions: [
        IconButton(
          onPressed: _toggleSearch,
          icon: const Icon(Icons.search_rounded),
          tooltip: strings('documents_search_hint'),
        ),
        IconButton(
          onPressed: () =>
              ref.read(documentGridProvider.notifier).setGrid(!isGrid),
          icon: Icon(
            isGrid ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
          ),
          tooltip: isGrid ? strings('view_list') : strings('view_grid'),
        ),
        IconButton(
          onPressed: _showSortSheet,
          icon: const Icon(Icons.swap_vert_rounded),
          tooltip: strings('documents_sort_title'),
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

  Widget _list(List<ScannedDocument> documents, Set<int> selection) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, 0),
      sliver: SliverList.builder(
        itemCount: documents.length,
        addAutomaticKeepAlives: false,
        itemBuilder: (context, index) {
          final document = documents[index];
          return LibraryDraggable(
            key: ValueKey(document.id),
            kind: FolderKind.document,
            id: document.id,
            selectionProvider: documentSelectionProvider,
            preview: DocumentThumbnail(
              document: document,
              width: 76,
              height: 92,
              radius: 0,
            ),
            child: DocumentTile(
              document: document,
              selected: selection.contains(document.id),
              selectionActive: selection.isNotEmpty,
              onTap: () => _open(document),
              onMore: () => showDocumentActions(context, ref, document),
            ),
          );
        },
      ),
    );
  }

  Widget _grid(List<ScannedDocument> documents, Set<int> selection) {
    final width =
        (MediaQuery.sizeOf(context).width - Space.md * 2 - Space.sm) / 2;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, 0),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: Space.sm,
          crossAxisSpacing: Space.sm,
          childAspectRatio: width / (width * 1.3 + 58),
        ),
        itemCount: documents.length,
        addAutomaticKeepAlives: false,
        itemBuilder: (context, index) {
          final document = documents[index];
          return LibraryDraggable(
            key: ValueKey(document.id),
            kind: FolderKind.document,
            id: document.id,
            selectionProvider: documentSelectionProvider,
            preview: DocumentThumbnail(
              document: document,
              width: 76,
              height: 92,
              radius: 0,
            ),
            child: DocumentCard(
              document: document,
              width: width,
              selected: selection.contains(document.id),
              onTap: () => _open(document),
              onMore: () => showDocumentActions(context, ref, document),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showSortSheet() async {
    final strings = ref.read(stringsProvider);
    final current = ref.read(documentSortProvider);

    await showAppSheet<void>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(title: strings('documents_sort_title')),
          // A checked row rather than a radio: the sheet closes on choice, so
          // the control never lives long enough to need a radio's affordance.
          for (final sort in DocumentSort.values)
            ListTile(
              title: Text(strings(sort.labelKey)),
              trailing: sort == current
                  ? Icon(
                      Icons.check_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                ref.read(documentSortProvider.notifier).select(sort);
                Navigator.pop(context);
              },
            ),
          const SheetFooterSpace(),
        ],
      ),
    );
  }
}
