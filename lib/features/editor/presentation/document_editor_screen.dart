import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/image_editor_config.dart';
import '../../../data/providers.dart';
import '../../../data/services/pdf_service.dart';
import '../application/editor_controller.dart';
import 'widgets/editor_page_card.dart';

/// Module D, second half: reorder, add and remove pages.
///
/// The page you are working on fills the screen and you swipe sideways to move
/// through the document; the strip above the dock is the map — drag a frame to
/// change the order. Controls sit at the edges so the document keeps the middle.
class DocumentEditorScreen extends ConsumerStatefulWidget {
  const DocumentEditorScreen({super.key, required this.documentId});

  final int documentId;

  @override
  ConsumerState<DocumentEditorScreen> createState() =>
      _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends ConsumerState<DocumentEditorScreen> {
  final _pager = PageController();
  final _strip = ScrollController();
  int _index = 0;

  /// True while the page under the finger is being rasterised for the image
  /// editor — a second tap on "Modifica" would start a second render.
  bool _preparing = false;

  @override
  void dispose() {
    _pager.dispose();
    _strip.dispose();
    super.dispose();
  }

  EditorController get _controller =>
      ref.read(editorControllerProvider(widget.documentId).notifier);

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

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final async = ref.watch(editorControllerProvider(widget.documentId));
    final state = async.value;

    // A page added or removed elsewhere must not leave the pager past the end.
    if (state != null && _index >= state.pages.length) {
      _index = state.pages.isEmpty ? 0 : state.pages.length - 1;
    }

    return PopScope(
      canPop: !(state?.dirty ?? false),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || state == null) return;
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
              if (state != null && state.pages.isNotEmpty)
                Text(
                  strings('viewer_page_of', {
                    'a': _index + 1,
                    'b': state.pages.length,
                  }),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xs),
              child: FilledButton(
                onPressed: (state?.dirty ?? false) && !(state?.saving ?? false)
                    ? _save
                    : null,
                child: Text(strings('editor_save')),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            switch (async) {
              AsyncData(:final value) => _Editor(
                state: value,
                strings: strings,
                pager: _pager,
                strip: _strip,
                index: _index,
                onPageChanged: (index) => setState(() {
                  _index = index;
                  _keepThumbVisible(index);
                }),
                onThumbTap: _goTo,
                onReorder: (oldIndex, newIndex) {
                  _controller.reorder(oldIndex, newIndex);
                  setState(() => _index = newIndex);
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _goTo(newIndex, animate: false),
                  );
                },
              ),
              AsyncError() => EmptyState(
                icon: Icons.error_outline_rounded,
                title: strings('common_error'),
                body: strings('viewer_open_failed'),
              ),
              _ => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: Space.md),
                    Text(
                      strings('editor_loading_pages'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            },
            if (state?.saving ?? false)
              BusyOverlay(label: strings('editor_saving')),
            if (_preparing)
              BusyOverlay(label: strings('editor_rendering_page')),
          ],
        ),
        bottomNavigationBar: state == null
            ? null
            : _EditorDock(
                strings: strings,
                canDelete: state.pages.length > 1,
                onAdd: _showAddSheet,
                onEditPage: _editPage,
                onDuplicate: () {
                  _controller.duplicate(_index);
                  // The copy lands right after the original: follow it.
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _goTo(_index + 1),
                  );
                },
                onDelete: () => _controller.remove(_index),
              ),
      ),
    );
  }

  /// Opens the page on screen in the image editor and puts the result back in
  /// its slot: crop, draw, annotate, blur — on one page, in place.
  Future<void> _editPage() async {
    if (_preparing) return;
    final strings = ref.read(stringsProvider);
    final state = ref.read(editorControllerProvider(widget.documentId)).value;
    if (state == null || _index < 0 || _index >= state.pages.length) return;

    final index = _index;
    setState(() => _preparing = true);
    final bytes = await _pageBitmap(state.document.file, state.pages[index]);
    if (!mounted) return;
    setState(() => _preparing = false);

    if (bytes == null) {
      showSnack(
        context,
        strings('editor_edit_failed'),
        icon: Icons.error_outline_rounded,
      );
      return;
    }

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
    _controller.replaceWithImage(index, result);
    _goTo(index, animate: false);
    showSnack(
      context,
      strings('editor_page_edited'),
      icon: Icons.check_rounded,
    );
  }

  /// What the page looks like right now, as PNG bytes.
  Future<Uint8List?> _pageBitmap(File file, EditorPageItem page) async {
    if (page.imageBytes != null) return page.imageBytes;
    if (page.blank) return _whiteSheet();

    final index = page.sourceIndex;
    if (index == null) return null;
    final rendered = await ref
        .read(pdfServiceProvider)
        .pageImage(
          file,
          index,
          // ~190 dpi: the edited page still prints cleanly, and a single sheet
          // stays a few megabytes instead of tens.
          dpi: PdfService.dpiForWidth(PdfService.a4, 1600),
        );
    if (rendered == null) return null;
    return rendered.readAsBytes();
  }

  /// A blank page has nothing to rasterise, so the editor gets a white sheet
  /// to draw on — A4 at 150 dpi.
  Future<Uint8List?> _whiteSheet() async {
    const size = Size(1240, 1754);
    final recorder = ui.PictureRecorder();
    ui.Canvas(
      recorder,
      Offset.zero & size,
    ).drawRect(Offset.zero & size, ui.Paint()..color = const Color(0xFFFFFFFF));
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.round(),
      size.height.round(),
    );
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  Future<void> _save() async {
    final strings = ref.read(stringsProvider);
    final ok = await _controller.save();
    if (!mounted) return;
    showSnack(
      context,
      ok ? strings('editor_saved') : strings('editor_save_failed'),
      icon: ok ? Icons.check_rounded : Icons.error_outline_rounded,
    );
  }

  Future<void> _showAddSheet() async {
    final strings = ref.read(stringsProvider);
    final picker = ImagePicker();

    Future<void> appended() async {
      final pages = ref.read(editorControllerProvider(widget.documentId)).value;
      if (pages == null || pages.pages.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _goTo(pages.pages.length - 1),
      );
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
              final shot = await picker.pickImage(
                source: ImageSource.camera,
                // A page added mid-edit ends up on an A4 sheet; past 2400 px
                // the print cannot resolve the difference anyway.
                imageQuality: 92,
                maxWidth: 2400,
              );
              if (shot == null) return;
              _controller.addImage(await shot.readAsBytes());
              await appended();
            },
          ),
          SheetAction(
            icon: Icons.photo_library_outlined,
            label: strings('editor_add_gallery'),
            detail: strings('editor_add_gallery_detail'),
            onTap: () async {
              Navigator.pop(context);
              final shot = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 92,
                maxWidth: 2400,
              );
              if (shot == null) return;
              _controller.addImage(await shot.readAsBytes());
              await appended();
            },
          ),
          SheetAction(
            icon: Icons.insert_page_break_outlined,
            label: strings('editor_add_blank'),
            detail: strings('editor_add_blank_detail'),
            onTap: () async {
              Navigator.pop(context);
              _controller.addBlank();
              await appended();
            },
          ),
          const SheetFooterSpace(),
        ],
      ),
    );
  }
}

class _Editor extends StatelessWidget {
  const _Editor({
    required this.state,
    required this.strings,
    required this.pager,
    required this.strip,
    required this.index,
    required this.onPageChanged,
    required this.onThumbTap,
    required this.onReorder,
  });

  final EditorState state;
  final Strings strings;
  final PageController pager;
  final ScrollController strip;
  final int index;
  final ValueChanged<int> onPageChanged;
  final void Function(int index, {bool animate}) onThumbTap;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final width = MediaQuery.sizeOf(context).width;

    // The canvas is rendered for the screen; the strip for a 64 px frame.
    final canvasDpi = PdfService.dpiForWidth(
      PdfService.a4,
      (width * ratio).clamp(600, 1400),
    );
    final thumbDpi = PdfService.dpiForWidth(PdfService.a4, 64 * ratio);

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: pager,
            itemCount: state.pages.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, i) => EditorPageCanvas(
              key: ValueKey('canvas-${state.pages[i].id}'),
              document: state.document,
              page: state.pages[i],
              dpi: canvasDpi,
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
              Expanded(
                child: Text(
                  strings('editor_hint'),
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
            itemCount: state.pages.length,
            // Flutter 3.47's callback already accounts for the removed item,
            // so the index arrives ready to insert at.
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
              key: ValueKey('thumb-${state.pages[i].id}'),
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(right: Space.xs),
                child: EditorFilmstripThumb(
                  document: state.document,
                  page: state.pages[i],
                  position: i + 1,
                  dpi: thumbDpi,
                  current: i == index,
                  onTap: () => onThumbTap(i),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.xs),
      ],
    );
  }
}

/// Add always; edit, duplicate and delete act on the page currently on screen.
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
      // Equal shares rather than free spacing: four labels have to fit on a
      // narrow phone without the row ever overflowing.
      child: Row(
        children: [
          Expanded(
            child: _DockButton(
              icon: Icons.add_rounded,
              label: strings('editor_dock_add'),
              onPressed: onAdd,
            ),
          ),
          Expanded(
            child: _DockButton(
              icon: Icons.brush_outlined,
              label: strings('editor_dock_edit'),
              onPressed: onEditPage,
            ),
          ),
          Expanded(
            child: _DockButton(
              icon: Icons.copy_all_outlined,
              label: strings('editor_duplicate'),
              onPressed: onDuplicate,
            ),
          ),
          Expanded(
            child: _DockButton(
              icon: Icons.delete_outline_rounded,
              label: strings('editor_dock_delete'),
              onPressed: canDelete ? onDelete : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    final color = enabled
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.38);

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.xs,
          vertical: Space.xxs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
