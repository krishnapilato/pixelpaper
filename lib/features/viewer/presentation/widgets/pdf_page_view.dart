import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../data/providers.dart';
import '../../../../data/services/pdf_service.dart';

/// Renders one page of a PDF, lazily and at a bounded resolution.
///
/// Rendering is per page and cached on disk, so a 60-page document costs the
/// same memory as a 2-page one. The `printing` package's own PdfPreview
/// rasterises every page up front at a DPI derived from the *expected* page
/// size — a document with unusual geometry then allocates hundreds of
/// megabytes and takes the process down.
///
/// The document's bytes belong to [PdfService], which keeps one copy for
/// whatever is being read and serialises the renders. This widget deliberately
/// has no way to supply its own: when it did, every visible page read the whole
/// file for itself and a dozen of them at once was fatal on a large scan.
class PdfPageImage extends ConsumerStatefulWidget {
  const PdfPageImage({
    super.key,
    required this.file,
    required this.index,
    required this.dpi,
    this.fit = BoxFit.contain,
  });

  final File file;
  final int index;
  final double dpi;
  final BoxFit fit;

  @override
  ConsumerState<PdfPageImage> createState() => _PdfPageImageState();
}

class _PdfPageImageState extends ConsumerState<PdfPageImage> {
  File? _image;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _render();
  }

  @override
  void didUpdateWidget(PdfPageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index ||
        oldWidget.file.path != widget.file.path ||
        oldWidget.dpi != widget.dpi) {
      _image = null;
      _failed = false;
      _render();
    }
  }

  /// Bumped whenever the page being shown changes, so a render still queued
  /// for the previous one is dropped rather than drawn into this slot.
  int _request = 0;

  /// True once the render has taken long enough to be worth admitting to.
  bool _slow = false;
  Timer? _slowTimer;

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  Future<void> _render() async {
    final request = ++_request;

    _slowTimer?.cancel();
    _slow = false;
    // Under this threshold a spinner would appear and vanish inside the same
    // gesture, which reads as a flicker rather than as progress. Past it, an
    // unchanging blank sheet reads as a page that failed — and on a document
    // of forty megabytes the first render really does take seconds.
    _slowTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted && _image == null) setState(() => _slow = true);
    });

    final rendered = await ref
        .read(pdfServiceProvider)
        .pageImage(
          widget.file,
          widget.index,
          dpi: widget.dpi,
          wanted: () => mounted && _request == request,
        );
    if (!mounted || _request != request) return;
    _slowTimer?.cancel();
    setState(() {
      _image = rendered;
      _failed = rendered == null;
      _slow = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = _image;

    if (_failed) {
      return Center(
        child: Icon(Icons.error_outline_rounded, color: scheme.onSurfaceVariant),
      );
    }
    if (image == null) {
      // A flat sheet first, a spinner only once the wait is real: see the
      // threshold in [_render].
      return AspectRatio(
        aspectRatio: 0.707,
        child: ColoredBox(
          color: Colors.white10,
          child: _slow
              ? const Center(
                  child: SizedBox(
                    height: 26,
                    width: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              : null,
        ),
      );
    }

    return Image.file(
      image,
      fit: widget.fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// The reader: one page per screen, swiped vertically.
///
/// Vertical because that is the direction every document reader people already
/// use scrolls, and reading a page then reaching for a sideways swipe is a
/// small jolt every single time.
///
/// Still one page per screen rather than a continuous roll: it keeps "pagina 3
/// di 12" exact instead of approximate, and gives each page its own zoom, which
/// a continuous scroll cannot do without fighting the pan gesture.
class PdfPager extends ConsumerStatefulWidget {
  const PdfPager({
    super.key,
    required this.file,
    required this.pageCount,
    this.onPageChanged,
    this.padding = EdgeInsets.zero,
  });

  final File file;
  final int pageCount;
  final ValueChanged<int>? onPageChanged;
  final EdgeInsets padding;

  @override
  ConsumerState<PdfPager> createState() => _PdfPagerState();
}

class _PdfPagerState extends ConsumerState<PdfPager> {
  final _controller = PageController();
  double? _dpi;
  bool _failed = false;

  bool _prepared = false;

  @override
  void initState() {
    super.initState();
    ref.read(pdfServiceProvider).retainDocument();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Not initState: the screen metrics come from an InheritedWidget, and they
    // have to be read here — before the await in [_prepare] — because a
    // context is only safe to touch while its element is still in the tree.
    if (_prepared) return;
    _prepared = true;
    _prepare(
      MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context),
    );
  }

  @override
  void dispose() {
    ref.read(pdfServiceProvider).releaseDocument();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _prepare(double screenWidth) async {
    try {
      final size = await ref
          .read(pdfServiceProvider)
          .firstPageSizeOf(widget.file);
      if (!mounted) return;
      setState(() {
        // Cap the render at ~1200 px wide: sharp on any phone, and small
        // enough that three live pages stay well inside the image cache.
        _dpi = PdfService.dpiForWidth(size, screenWidth.clamp(600, 1200));
      });
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_failed) {
      return Center(
        child: Icon(Icons.error_outline_rounded, color: scheme.onSurfaceVariant),
      );
    }
    final dpi = _dpi;
    if (dpi == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return PageView.builder(
      controller: _controller,
      scrollDirection: Axis.vertical,
      itemCount: widget.pageCount,
      onPageChanged: widget.onPageChanged,
      itemBuilder: (context, index) => Padding(
        padding: widget.padding,
        child: Center(
          child: Card(
            color: Colors.white,
            margin: EdgeInsets.zero,
            child: InteractiveViewer(
              maxScale: 4,
              child: PdfPageImage(
                key: ValueKey('${widget.file.path}#$index'),
                file: widget.file,
                index: index,
                dpi: dpi,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared padding for the reader, leaving room for the two floating bars.
EdgeInsets readerPadding(BuildContext context) => EdgeInsets.fromLTRB(
      Space.md,
      MediaQuery.paddingOf(context).top + kToolbarHeight + Space.sm,
      Space.md,
      MediaQuery.paddingOf(context).bottom + 88,
    );
