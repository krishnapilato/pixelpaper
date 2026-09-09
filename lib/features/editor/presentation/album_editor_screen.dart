import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:pro_image_editor/pro_image_editor.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/image_editor_config.dart';
import '../../../data/models/document_page.dart';
import '../../../data/models/scanned_document.dart';
import '../../../data/providers.dart';
import '../../documents/application/documents_controller.dart';

/// The editor for an album.
///
/// Same shape as the PDF editor — the page you are working on fills the
/// screen, the strip above the dock is the map, the four verbs sit at the
/// bottom — because it is the same job and should not feel like a different
/// app. What changed is underneath: a page is an image the album owns, so
/// reordering is a list of integers, duplicating is a file copy, and editing
/// one page is editing one image. Nothing is rasterised and nothing is
/// re-encoded, so the pages stay the pixels the camera produced.
class AlbumEditorScreen extends ConsumerStatefulWidget {
  const AlbumEditorScreen({super.key, required this.documentId});

  final int documentId;

  @override
  ConsumerState<AlbumEditorScreen> createState() => _AlbumEditorScreenState();
}

class _AlbumEditorScreenState extends ConsumerState<AlbumEditorScreen> {
  final _pager = PageController();
  final _strip = ScrollController();

  /// The order being edited. Null until the pages have loaded; from then on
  /// this is the truth on screen, and the database only hears about it on save.
  List<DocumentPage>? _pages;
  String? _loadedFor;
  int _index = 0;
  bool _dirty = false;
  bool _saving = false;
  bool _busy = false;

  @override
  void dispose() {
    _pager.dispose();
    _strip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final document = ref.watch(documentByIdProvider(widget.documentId));

    if (document == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.description_outlined,
          title: strings('viewer_open_failed'),
          body: strings('documents_empty_body'),
        ),
      );
    }

    // Adopt the stored order once per document version. Re-adopting on every
    // build would throw away the drag the user just made.
    final async = ref.watch(documentPagesProvider(widget.documentId));
    if (_loadedFor != document.signature && async.hasValue && !_dirty) {
      _loadedFor = document.signature;
      _pages = [...async.requireValue];
    }
    final pages = _pages;
    if (pages != null && _index >= pages.length) {
      _index = pages.isEmpty ? 0 : pages.length - 1;
    }

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmAction(
          context,
          title: strings('editor_discard_title'),
          message: strings('editor_discard_body'),
          confirmLabel: strings('editor_discard_action'),
          cancelLabel: strings('common_cancel'),
        );
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(strings('editor_title')),
              if (pages != null && pages.isNotEmpty)
                Text(
                  strings('viewer_page_of', {
                    'a': _index + 1,
                    'b': pages.length,
                  }),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xs),
              child: FilledButton(
                onPressed: _dirty && !_saving ? _save : null,
                child: Text(strings('editor_save')),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            if (pages == null)
              const Center(child: CircularProgressIndicator())
            else if (pages.isEmpty)
              EmptyState(
                icon: Icons.description_outlined,
                title: strings('viewer_open_failed'),
                body: strings('documents_empty_body'),
              )
            else
              _Body(
                albumDir: document.path,
                pages: pages,
                pager: _pager,
                strip: _strip,
                index: _index,
                hint: strings('editor_hint'),
                onPageChanged: (index) => setState(() {
                  _index = index;
                  _keepThumbVisible(index);
                }),
                onThumbTap: _goTo,
                onReorder: _reorder,
              ),
            if (_saving) BusyOverlay(label: strings('editor_saving')),
            if (_busy) BusyOverlay(label: strings('editor_rendering_page')),
          ],
        ),
        bottomNavigationBar: pages == null
            ? null
            : _EditorDock(
                strings: strings,
                canDelete: pages.length > 1,
                onAdd: () => _showAddSheet(document),
                onEditPage: () => _editPage(document),
                onDuplicate: () => _duplicate(document),
                onDelete: _delete,
              ),
      ),
    );
  }

  void _goTo(int index, {bool animate = true}) {
    if (!_pager.hasClients) return;
    if (animate) {
      _pager.animateToPage(index, duration: Motion.base, curve: Motion.enter);
    } else {
      _pager.jumpToPage(index);
    }
    _keepThumbVisible(index);
  }

  /// Keeps the current frame inside the strip after a jump or a reorder.
  void _keepThumbVisible(int index) {
    if (!_strip.hasClients) return;
    const thumb = 64.0 + Space.xs;
    final target =
        (index * thumb) - (_strip.position.viewportDimension / 2) + (thumb / 2);
    _strip.animateTo(
      target.clamp(0, _strip.position.maxScrollExtent),
      duration: Motion.quick,
      curve: Motion.enter,
    );
  }

  void _reorder(int oldIndex, int newIndex) {
    final pages = _pages;
    if (pages == null) return;
    setState(() {
      pages.insert(newIndex, pages.removeAt(oldIndex));
      _index = newIndex;
      _dirty = true;
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _goTo(newIndex, animate: false));
  }

  void _delete() {
    final pages = _pages;
    if (pages == null || pages.length <= 1) return;
    setState(() {
      pages.removeAt(_index);
      if (_index >= pages.length) _index = pages.length - 1;
      _dirty = true;
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _goTo(_index, animate: false));
  }

  /// Duplicating copies the file, because the copy has to be editable on its
  /// own: two pages pointing at one image would edit each other.
  Future<void> _duplicate(ScannedDocument document) async {
    final pages = _pages;
    if (pages == null || pages.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final source = p.join(document.path, pages[_index].fileName);
      final copy = await ref
          .read(documentRepositoryProvider)
          .addPageFile(document, source);
      if (!mounted) return;
      setState(() {
        pages.insert(_index + 1, copy);
        _dirty = true;
        _busy = false;
      });
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _goTo(_index + 1));
    } on Object {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Opens the page on screen in the image editor and puts the result back in
  /// its slot: crop, rotate, draw, annotate, blur — the same editor the
  /// gallery uses on a photo, because that is exactly what this page is.
  ///
  /// The result is written to a *new* file rather than over the old one. The
  /// path is what every image cache in Flutter keys on, so overwriting in
  /// place leaves the grid, the strip and the reader all showing the picture
  /// from before the edit. A new name makes the change visible everywhere for
  /// free, and [DocumentRepository.savePages] deletes the file left behind.
  Future<void> _editPage(ScannedDocument document) async {
    final pages = _pages;
    if (pages == null || pages.isEmpty || _busy) return;

    final strings = ref.read(stringsProvider);
    final index = _index;
    final file = File(p.join(document.path, pages[index].fileName));

    setState(() => _busy = true);
    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(
        context,
        strings('editor_edit_failed'),
        icon: Icons.error_outline_rounded,
      );
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    Uint8List? edited;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (editorContext) => ProImageEditor.memory(
          bytes,
          configs: italianImageEditor,
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (result) async => edited = result,
            onCloseEditor: (mode) => Navigator.of(editorContext).pop(),
          ),
        ),
      ),
    );

    final result = edited;
    if (result == null || !mounted) return; // closed without saving

    final replacement = await ref
        .read(documentRepositoryProvider)
        .addPageBytes(document, result);
    if (!mounted) return;
    setState(() {
      pages[index] = replacement;
      _dirty = true;
    });
    showSnack(
      context,
      strings('editor_page_edited'),
      icon: Icons.check_rounded,
    );
  }

  Future<void> _showAddSheet(ScannedDocument document) async {
    final strings = ref.read(stringsProvider);
    final picker = ImagePicker();

    Future<void> append(XFile? shot) async {
      if (shot == null || !mounted) return;
      final pages = _pages;
      if (pages == null) return;
      final page = await ref
          .read(documentRepositoryProvider)
          .addPageFile(document, shot.path);
      if (!mounted) return;
      setState(() {
        pages.add(page);
        _index = pages.length - 1;
        _dirty = true;
      });
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _goTo(pages.length - 1));
    }

    await showAppSheet<void>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(title: strings('editor_add_page')),
          SheetAction(
            icon: Icons.photo_camera_outlined,
            label: strings('editor_add_camera'),
            detail: strings('editor_add_camera_detail'),
            emphasised: true,
            onTap: () async {
              Navigator.pop(context);
              // Full resolution, like every other page: a page added later is
              // an archive page too.
              await append(await picker.pickImage(source: ImageSource.camera));
            },
          ),
          SheetAction(
            icon: Icons.photo_library_outlined,
            label: strings('editor_add_gallery'),
            detail: strings('editor_add_gallery_detail'),
            onTap: () async {
              Navigator.pop(context);
              await append(await picker.pickImage(source: ImageSource.gallery));
            },
          ),
          const SheetFooterSpace(),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final pages = _pages;
    final document = ref.read(documentByIdProvider(widget.documentId));
    if (pages == null || document == null) return;

    final strings = ref.read(stringsProvider);
    setState(() => _saving = true);
    try {
      await ref
          .read(documentsControllerProvider.notifier)
          .savePages(document, pages);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _dirty = false;
      });
      showSnack(context, strings('editor_saved'), icon: Icons.check_rounded);
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(
        context,
        strings('common_error'),
        icon: Icons.error_outline_rounded,
      );
    }
  }
}

/// Canvas, hint and filmstrip — the layout the PDF editor established.
class _Body extends StatelessWidget {
  const _Body({
    required this.albumDir,
    required this.pages,
    required this.pager,
    required this.strip,
    required this.index,
    required this.hint,
    required this.onPageChanged,
    required this.onThumbTap,
    required this.onReorder,
  });

  final String albumDir;
  final List<DocumentPage> pages;
  final PageController pager;
  final ScrollController strip;
  final int index;
  final String hint;
  final ValueChanged<int> onPageChanged;
  final void Function(int index, {bool animate}) onThumbTap;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final canvasWidth = (MediaQuery.sizeOf(context).width * ratio).round();
    final thumbWidth = (64 * ratio).round();

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: pager,
            itemCount: pages.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.md,
                vertical: Space.xs,
              ),
              child: Center(
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Radii.sm),
                  clipBehavior: Clip.antiAlias,
                  elevation: 2,
                  child: Image.file(
                    File(p.join(albumDir, pages[i].fileName)),
                    key: ValueKey(pages[i].fileName),
                    fit: BoxFit.contain,
                    cacheWidth: canvasWidth,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xxs),
          child: Row(
            children: [
              Icon(
                Icons.drag_indicator_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: Space.xs),
              Expanded(child: Text(hint, style: theme.textTheme.bodySmall)),
            ],
          ),
        ),
        SizedBox(
          height: 88,
          child: ReorderableListView.builder(
            scrollController: strip,
            scrollDirection: Axis.horizontal,
            // Long press to drag: a plain tap has to stay free for jumping to
            // a page, and a drag-on-touch would fight the strip's own scroll.
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            itemCount: pages.length,
            onReorderItem: onReorder,
            proxyDecorator: (child, i, animation) => AnimatedBuilder(
              animation: animation,
              builder: (context, _) => Transform.scale(
                scale: 1 + 0.1 * animation.value,
                child: Material(
                  color: Colors.transparent,
                  elevation: 8 * animation.value,
                  borderRadius: BorderRadius.circular(Radii.xs),
                  child: child,
                ),
              ),
            ),
            itemBuilder: (context, i) => ReorderableDelayedDragStartListener(
              key: ValueKey('thumb-${pages[i].fileName}'),
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(right: Space.xs),
                child: _Thumb(
                  file: File(p.join(albumDir, pages[i].fileName)),
                  position: i + 1,
                  decodeWidth: thumbWidth,
                  current: i == index,
                  onTap: () => onThumbTap(i),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One frame of the strip: tap to jump, long-press to drag.
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.file,
    required this.position,
    required this.decodeWidth,
    required this.current,
    required this.onTap,
  });

  final File file;
  final int position;
  final int decodeWidth;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        curve: Motion.enter,
        width: 64,
        padding: EdgeInsets.all(current ? 2.5 : 0),
        decoration: BoxDecoration(
          color: current ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.xs + 2),
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Radii.xs),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                file,
                key: ValueKey(file.path),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                cacheWidth: decodeWidth,
                gaplessPlayback: true,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ColoredBox(
                  color: current
                      ? scheme.primary
                      : scheme.scrim.withValues(alpha: 0.6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '$position',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: current ? scheme.onPrimary : Colors.white,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The four verbs, each acting on the page on screen.
class _EditorDock extends StatelessWidget {
  const _EditorDock({
    required this.strings,
    required this.canDelete,
    required this.onAdd,
    required this.onEditPage,
    required this.onDuplicate,
    required this.onDelete,
  });

  final Strings strings;
  final bool canDelete;
  final VoidCallback onAdd;
  final VoidCallback onEditPage;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: Row(
        children: [
          _DockAction(
            icon: Icons.add_rounded,
            label: strings('editor_add_short'),
            onPressed: onAdd,
          ),
          _DockAction(
            icon: Icons.brush_outlined,
            label: strings('common_edit'),
            onPressed: onEditPage,
          ),
          _DockAction(
            icon: Icons.copy_rounded,
            label: strings('editor_duplicate'),
            onPressed: onDuplicate,
          ),
          _DockAction(
            icon: Icons.delete_outline_rounded,
            label: strings('common_delete'),
            onPressed: canDelete ? onDelete : null,
          ),
        ],
      ),
    );
  }
}

class _DockAction extends StatelessWidget {
  const _DockAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextButton(
        onPressed: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
