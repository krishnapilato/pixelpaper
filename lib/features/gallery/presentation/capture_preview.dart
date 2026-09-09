import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_cache.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/image_editor_config.dart';
import '../../../data/models/capture.dart';
import '../../../data/providers.dart';
import '../application/gallery_controller.dart';
import 'ocr_sheet.dart';

/// Full-screen photo: pinch to zoom, swipe between shots, and the four things
/// worth doing with a raw capture — inspect it, read it, fix it, send it.
///
/// Deliberately no camera button here: this screen is about the photo you
/// already have, and the shutter is one back-swipe away.
class CapturePreview extends ConsumerStatefulWidget {
  const CapturePreview({
    super.key,
    required this.captures,
    required this.initialIndex,
  });

  final List<Capture> captures;
  final int initialIndex;

  @override
  ConsumerState<CapturePreview> createState() => _CapturePreviewState();
}

class _CapturePreviewState extends ConsumerState<CapturePreview>
    with SingleTickerProviderStateMixin {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  bool _reading = false;
  int _revision = 0;

  /// Drag-to-dismiss state. Flicking a photo away is faster than reaching for
  /// the back arrow, and it is the gesture every gallery has taught people.
  final _zoom = TransformationController();
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: Motion.quick,
  );

  double _drag = 0;
  double _settleFrom = 0;
  bool _settling = false;
  bool _zoomed = false;

  static const double _dismissDistance = 130;
  static const double _dismissVelocity = 700;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(_onZoomChanged);
    _settle.addListener(_onSettleTick);
  }

  /// Runs the photo back to its resting place after a drag that stopped short.
  void _onSettleTick() {
    if (!_settling) return;
    setState(() => _drag = _settleFrom * (1 - _settle.value));
  }

  @override
  void dispose() {
    _zoom
      ..removeListener(_onZoomChanged)
      ..dispose();
    _settle.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// While the photo is zoomed the drag belongs to panning, not to dismissing.
  void _onZoomChanged() {
    final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_zoomed) return;
    if (_settle.isAnimating) _settle.stop();
    setState(() {
      _settling = false;
      _drag += details.delta.dy;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_zoomed) return;
    final velocity = details.velocity.pixelsPerSecond.dy;
    final shouldClose =
        _drag.abs() > _dismissDistance || velocity.abs() > _dismissVelocity;

    if (shouldClose) {
      Navigator.of(context).pop();
      return;
    }
    // Not far enough: spring back instead of snapping, so a half-gesture reads
    // as "not yet" rather than as a glitch.
    _settleFrom = _drag;
    _settling = true;
    _settle.forward(from: 0);
  }

  /// Always read the live row: an edit changes size and dimensions underneath.
  Capture get _capture {
    final live = ref.read(galleryControllerProvider).value;
    final current = widget.captures[_index];
    if (live == null) return current;
    for (final item in live) {
      if (item.id == current.id) return item;
    }
    return current;
  }

  Future<void> _showInfo() async {
    final strings = ref.read(stringsProvider);
    final capture = _capture;

    await showAppSheet<void>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(
            title: strings('fullscreen_info'),
            subtitle: Fmt.stem(capture.path),
          ),
          _InfoRow(
            label: strings('image_detail_resolution'),
            value: capture.resolutionLabel,
          ),
          _InfoRow(
            label: strings('image_detail_size'),
            value: Fmt.bytes(capture.sizeBytes),
          ),
          _InfoRow(
            label: strings('image_detail_created'),
            value: Fmt.dateTime(capture.createdAt),
          ),
          _InfoRow(
            label: strings('image_detail_source'),
            value: switch (capture.source) {
              CaptureSource.camera => strings('image_source_camera'),
              CaptureSource.gallery => strings('image_source_gallery'),
            },
          ),
          const SheetFooterSpace(),
        ],
      ),
    );
  }

  Future<void> _extractText() async {
    if (_reading) return;
    setState(() => _reading = true);
    final strings = ref.read(stringsProvider);

    try {
      final text = await ref.read(ocrServiceProvider).read(_capture.file);
      if (!mounted) return;
      await showOcrResult(context, ref, text);
    } on Object {
      if (mounted) {
        showSnack(
          context,
          strings('ocr_failed'),
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _edit() async {
    final strings = ref.read(stringsProvider);
    final capture = _capture;
    Future<void>? write;

    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (editorContext) => ProImageEditor.file(
          capture.file,
          configs: italianImageEditor,
          callbacks: ProImageEditorCallbacks(
            // Overwrite in place: the gallery is a working set, and a second
            // near-identical copy per tweak is how photo libraries rot.
            onImageEditingComplete: (bytes) async {
              write = capture.file.writeAsBytes(bytes, flush: true);
              await write;
            },
            onCloseEditor: (mode) => Navigator.of(editorContext).pop(),
          ),
        ),
      ),
    );

    // The editor closes as soon as it hands the bytes over, so the write can
    // still be in flight; re-reading now would show the old picture again.
    await write;
    if (write == null || !mounted) return; // closed without saving

    await forgetCachedImage(capture.file);
    await ref.read(galleryControllerProvider.notifier).remeasure(capture);
    if (!mounted) return;
    // A new key on the image forces a fresh decode of the same path.
    setState(() => _revision++);
    showSnack(context, strings('image_edited'), icon: Icons.check_rounded);
  }

  Future<void> _share() async {
    final strings = ref.read(stringsProvider);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(_capture.path, mimeType: _capture.mimeType)],
        ),
      );
    } on Object {
      if (!mounted) return;
      showSnack(
        context,
        strings('share_failed'),
        icon: Icons.error_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final decodeWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context) *
                2)
            .round();

    // How far the photo has been dragged, as a fraction of the dismiss travel.
    final progress = (_drag.abs() / 320).clamp(0.0, 1.0);
    final chrome = 1 - progress;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Opacity(
          opacity: chrome,
          child: AppBar(
            title: Text('${_index + 1} / ${widget.captures.length}'),
          ),
        ),
      ),
      // Swipe up or down to leave: the photo follows the finger and shrinks,
      // so the gesture shows where it is going before it commits. Disabled
      // while zoomed, where a vertical drag means "pan", not "close".
      body: GestureDetector(
        onVerticalDragUpdate: _zoomed ? null : _onDragUpdate,
        onVerticalDragEnd: _zoomed ? null : _onDragEnd,
        child: Transform.translate(
          offset: Offset(0, _drag),
          child: Transform.scale(
            scale: 1 - progress * 0.12,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.captures.length,
              onPageChanged: (index) => setState(() {
                _index = index;
                _zoom.value = Matrix4.identity();
              }),
              itemBuilder: (context, index) {
                final item = widget.captures[index];
                return InteractiveViewer(
                  // Only the page in front owns the zoom: an offscreen page
                  // sharing it would arrive already zoomed in.
                  transformationController: index == _index ? _zoom : null,
                  maxScale: 6,
                  child: Center(
                    child: Hero(
                      tag: 'capture-${item.id}',
                      child: Image.file(
                        File(item.path),
                        key: ValueKey('${item.path}#$_revision'),
                        fit: BoxFit.contain,
                        // Decoded at twice the screen width: sharp well into a pinch
                        // zoom, while a 12 MP original decoded at full size would
                        // cost ~48 MB per page and three pages can be alive at once.
                        cacheWidth: decodeWidth,
                        filterQuality: FilterQuality.medium,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stack) => Center(
                          child: Text(
                            strings('common_error'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: Opacity(
        opacity: chrome,
        child: BottomAppBar(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Action(
                icon: Icons.info_outline_rounded,
                label: strings('fullscreen_info'),
                onPressed: _showInfo,
              ),
              _Action(
                icon: Icons.text_fields_rounded,
                label: strings('fullscreen_text'),
                busy: _reading,
                onPressed: _extractText,
              ),
              _Action(
                icon: Icons.tune_rounded,
                label: strings('fullscreen_edit'),
                onPressed: _edit,
              ),
              _Action(
                icon: Icons.ios_share_rounded,
                label: strings('fullscreen_share'),
                onPressed: _share,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: busy ? null : onPressed,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.xxs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 22,
              child: busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      icon,
                      size: 22,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
            ),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.sm,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}
