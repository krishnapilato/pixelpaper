import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:pro_image_editor/pro_image_editor.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/image_editor_config.dart';
import '../../../core/widgets/motion.dart';
import '../../../data/models/document_page.dart';
import '../../camera/presentation/camera_screen.dart';
import '../application/album_editor_controller.dart';

/// The album editor: the page on screen fills the canvas, the strip is the
/// map, the dock holds the four verbs. Pages are images the album owns, so
/// nothing is rasterised or re-encoded.
class AlbumEditorScreen extends ConsumerStatefulWidget {
  const AlbumEditorScreen({super.key, required this.documentId});

  final int documentId;

  @override
  ConsumerState<AlbumEditorScreen> createState() => _AlbumEditorScreenState();
}

class _AlbumEditorScreenState extends ConsumerState<AlbumEditorScreen> {
  final _pager = PageController();
  final _strip = ScrollController();

  AlbumEditorController get _editor =>
      ref.read(albumEditorProvider(widget.documentId).notifier);

  @override
  void dispose() {
    _pager.dispose();
    _strip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final async = ref.watch(albumEditorProvider(widget.documentId));
    final editor = async.value;

    if (editor == null) {
      return Scaffold(
        appBar: AppBar(),
        body: async.hasError
            ? EmptyState(
                icon: Icons.description_outlined,
                title: strings('viewer_open_failed'),
                body: strings('documents_empty_body'),
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final pages = editor.pages;
    return PopScope(
      canPop: !editor.dirty && editor.isIdle,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !editor.isIdle) return;
        final leave = await confirmAction(
          context,
          title: strings('editor_discard_title'),
          message: strings('editor_discard_body'),
          confirmLabel: strings('editor_discard_action'),
          cancelLabel: strings('common_cancel'),
        );
        if (!leave) return;
        await _editor.discard();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(strings('editor_title')),
              if (pages.isNotEmpty)
                Swapped(
                  value: '${editor.index}/${pages.length}',
                  child: Text(
                    strings('viewer_page_of', {
                      'a': editor.index + 1,
                      'b': pages.length,
                    }),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xs),
              child: FilledButton(
                onPressed: editor.dirty && editor.isIdle ? _save : null,
                child: Text(strings('editor_save')),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            if (pages.isEmpty)
              EmptyState(
                icon: Icons.description_outlined,
                title: strings('viewer_open_failed'),
                body: strings('documents_empty_body'),
              )
            else
              _Body(
                albumDir: editor.document.path,
                pages: pages,
                pager: _pager,
                strip: _strip,
                index: editor.index,
                hint: strings('editor_hint'),
                onPageChanged: (index) {
                  _editor.show(index);
                  _keepThumbVisible(index);
                },
                onThumbTap: _goTo,
                onReorder: (from, to) {
                  _editor.reorder(from, to);
                  _afterFrame(() => _goTo(to, animate: false));
                },
              ),
            if (editor.activity == EditorActivity.saving)
              BusyOverlay(label: strings('editor_saving')),
            if (editor.activity == EditorActivity.working)
              BusyOverlay(label: strings('editor_rendering_page')),
          ],
        ),
        bottomNavigationBar: _EditorDock(
          strings: strings,
          canDelete: editor.canDelete,
          onAdd: () => unawaited(_showAddSheet()),
          onEditPage: () => unawaited(_editPage(editor)),
          onDuplicate: () => unawaited(
            _run(() async {
              await _editor.duplicateCurrent();
              _afterFrame(() => _goTo(_editorIndex));
            }),
          ),
          onDelete: () {
            _editor.deleteCurrent();
            _afterFrame(() => _goTo(_editorIndex, animate: false));
          },
        ),
      ),
    );
  }

  int get _editorIndex =>
      ref.read(albumEditorProvider(widget.documentId)).value?.index ?? 0;

  void _afterFrame(VoidCallback action) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) action();
      });

  void _goTo(int index, {bool animate = true}) {
    if (!_pager.hasClients) return;
    if (animate && !Motion.reduced(context)) {
      unawaited(
        _pager.animateToPage(index, duration: Motion.base, curve: Motion.enter),
      );
    } else {
      _pager.jumpToPage(index);
    }
    _keepThumbVisible(index);
  }

  void _keepThumbVisible(int index) {
    if (!_strip.hasClients) return;
    const thumb = 64.0 + Space.xs;
    final target =
        (index * thumb) - (_strip.position.viewportDimension / 2) + (thumb / 2);
    unawaited(
      _strip.animateTo(
        target.clamp(0, _strip.position.maxScrollExtent),
        duration: Motion.of(context, Motion.quick),
        curve: Motion.enter,
      ),
    );
  }

  /// Runs a file operation and reports a failure instead of dropping it.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      if (mounted) {
        showSnack(
          context,
          ref.read(stringsProvider)('editor_edit_failed'),
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  /// Opens the page on screen in the image editor; the result becomes a new
  /// file so every image cache sees the change.
  Future<void> _editPage(AlbumEditorState editor) async {
    final page = editor.current;
    if (page == null || !editor.isIdle) return;
    final strings = ref.read(stringsProvider);

    final Uint8List bytes;
    try {
      bytes = await page.fileIn(editor.document.directory).readAsBytes();
    } on Object {
      if (mounted) {
        showSnack(
          context,
          strings('editor_edit_failed'),
          icon: Icons.error_outline_rounded,
        );
      }
      return;
    }
    if (!mounted) return;

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
    if (result == null || !mounted) return;
    await _run(() async {
      await _editor.replaceCurrent(result);
      if (mounted) {
        showSnack(
          context,
          strings('editor_page_edited'),
          icon: Icons.check_rounded,
        );
      }
    });
  }

  Future<void> _showAddSheet() async {
    final strings = ref.read(stringsProvider);

    Future<void> append(String? path) async {
      if (path == null || !mounted) return;
      await _run(() async {
        await _editor.append(File(path));
        _afterFrame(() => _goTo(_editorIndex));
      });
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
              final shot = await CameraScreen.takePage(context);
              await append(shot?.path);
            },
          ),
          SheetAction(
            icon: Icons.photo_library_outlined,
            label: strings('editor_add_gallery'),
            detail: strings('editor_add_gallery_detail'),
            onTap: () async {
              Navigator.pop(context);
              final picked = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                requestFullMetadata: false,
              );
              await append(picked?.path);
            },
          ),
          const SheetFooterSpace(),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final strings = ref.read(stringsProvider);
    final ok = await _editor.save();
    if (!mounted) return;
    showSnack(
      context,
      ok ? strings('editor_saved') : strings('common_error'),
      icon: ok ? Icons.check_rounded : Icons.error_outline_rounded,
    );
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
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Centred, and lifted clear of the strip: it is an instruction about
        // the strip, not a label stuck to it.
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.drag_indicator_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: Space.xs),
              Flexible(
                child: Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
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
