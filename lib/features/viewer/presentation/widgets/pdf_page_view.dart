import 'dart:io';
import 'dart:typed_data';

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
class PdfPageImage extends ConsumerStatefulWidget {
  const PdfPageImage({
    super.key,
    required this.file,
    required this.index,
    required this.dpi,
    this.source,
    this.fit = BoxFit.contain,
  });

  final File file;
  final int index;
  final double dpi;

  /// Document bytes, read once by the parent and shared with every page, so a
  /// 40-page session reads the file once instead of 40 times.
  final Uint8List? source;
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

  Future<void> _render() async {
    final rendered = await ref.read(pdfServiceProvider).pageImage(
          widget.file,
          widget.index,
          dpi: widget.dpi,
          source: widget.source,
        );
    if (!mounted) return;
    setState(() {
      _image = rendered;
      _failed = rendered == null;
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
      // A blank sheet rather than a spinner: pages arrive in a few frames and
      // a flashing spinner per page reads as jank.
      return const AspectRatio(
        aspectRatio: 0.707,
        child: ColoredBox(color: Colors.white10),
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

/// The reader: one page per screen, swiped horizontally.
///
/// A scan is a set of discrete pages, so paging gives an exact "page 3 of 12"
/// and an independent zoom state per page; a continuous scroll would blur both.
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
  Uint8List? _bytes;
  double _dpi = 96;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      final bytes = await widget.file.readAsBytes();
      if (!mounted) return;
      final width = MediaQuery.sizeOf(context).width *
          MediaQuery.devicePixelRatioOf(context);
      setState(() {
        _bytes = bytes;
        // Cap the render at ~1200 px wide: sharp on any phone, and small
        // enough that three live pages stay well inside the image cache.
        _dpi = PdfService.dpiForWidth(
          PdfService.firstPageSize(bytes),
          width.clamp(600, 1200),
        );
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
    if (_bytes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return PageView.builder(
      controller: _controller,
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
                dpi: _dpi,
                source: _bytes,
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
