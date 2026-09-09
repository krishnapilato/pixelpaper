/// Rendering runs on PDFium, through `pdfrx`, and every entry point here takes
/// a **path**.
///
/// That is the whole point. The previous implementation asked the `printing`
/// plugin to rasterise a page, which meant, per page: read the file into a
/// Uint8List, send all of it across the platform channel, render, encode a
/// PNG, send the PNG back, write it to a disk cache, read it again, decode it.
/// On a fifty-megabyte scan that was seconds per page and half a gigabyte of
/// live buffers when a dozen pages asked at once — the crash two people hit on
/// a twelve-photo document.
///
/// PDFium opens the file by path: the operating system maps it, nothing is
/// copied, pages come back as images. No byte cache to share, no render queue
/// to serialise, no PNG round-trip, no cache to sweep.
///
/// One rule survives: [PdfPageView.maximumDpi] stays bounded, because a page's
/// size is data from the file and a poster-sized page at a fixed DPI is still
/// a way to allocate hundreds of megabytes.
library;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../core/theme/dimens.dart';

/// The reader: one page per screen, swiped vertically.
///
/// Vertical because that is the direction every document reader people already
/// use scrolls. One page at a time rather than a continuous roll because a
/// scan is a set of discrete sheets: it keeps "pagina 3 di 12" exact instead of
/// approximate, and gives each page its own zoom, which a continuous scroll
/// cannot do without its pan gesture fighting the scroll.
///
/// `pdfrx` ships a continuous viewer of its own, and it is good — but it does
/// not snap to pages, so this uses its single-page widget and does the paging
/// here. The album reader has the same shape for the same reason: the user has
/// one archive, and the two kinds of document must not feel different.
class PdfPager extends StatelessWidget {
  const PdfPager({
    super.key,
    required this.file,
    required this.pageCount,
    this.onPageChanged,
    this.padding = EdgeInsets.zero,
  });

  final String file;

  /// The count the archive already knows, used while the document opens.
  final int pageCount;
  final ValueChanged<int>? onPageChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PdfDocumentViewBuilder.file(
      file,
      loadingBuilder: (context) =>
          const Center(child: CircularProgressIndicator()),
      errorBuilder: (context, error, stackTrace) => Center(
        child: Icon(
          Icons.error_outline_rounded,
          color: scheme.onSurfaceVariant,
        ),
      ),
      builder: (context, document) {
        if (document == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: document.pages.length,
          onPageChanged: onPageChanged,
          itemBuilder: (context, index) => Padding(
            padding: padding,
            child: Center(
              child: InteractiveViewer(
                maxScale: 5,
                child: Card(
                  color: Colors.white,
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: PdfPageImage(document: document, index: index),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One page of a document, drawn to fit its box.
///
/// Used by the reader for the sheet on screen and by the editor for every
/// frame of its strip. Both share the [document] their screen opened once, so
/// twelve thumbnails cost one open file, not twelve.
class PdfPageImage extends StatelessWidget {
  const PdfPageImage({
    super.key,
    required this.document,
    required this.index,
    this.maximumDpi = 300,
  });

  final PdfDocument document;

  /// Zero-based, like everything else in this app.
  final int index;

  /// Bound on the raster. A thumbnail asks for far less than a full page.
  final double maximumDpi;

  @override
  Widget build(BuildContext context) {
    if (index < 0 || index >= document.pages.length) {
      return const SizedBox.shrink();
    }
    return PdfPageView(
      document: document,
      pageNumber: index + 1,
      maximumDpi: maximumDpi,
      backgroundColor: Colors.white,
      alignment: Alignment.center,
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
