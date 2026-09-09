import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../data/models/document_page.dart';
import '../../../../data/models/scanned_document.dart';

/// The reader for an album: one page image per screen, swiped vertically.
///
/// Deliberately not a PDF viewer. An album's pages are already images, so
/// there is nothing to rasterise — this is the same decode-at-display-size
/// path the gallery grid uses, which is the fastest thing in the app.
///
/// Same shape as [PdfPager] on purpose, down to the card and the zoom: the
/// user has one archive, not two, and which kind of document they are looking
/// at is ours to keep quiet about.
class AlbumPager extends StatelessWidget {
  const AlbumPager({
    super.key,
    required this.document,
    required this.pages,
    this.onPageChanged,
    this.padding = EdgeInsets.zero,
  });

  final ScannedDocument document;
  final List<DocumentPage> pages;
  final ValueChanged<int>? onPageChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Decoded at the width it is drawn, never at the width it was shot: a
    // 12 MP page costs a couple of megabytes on screen instead of forty-eight.
    final decodeWidth =
        (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context))
            .round();

    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: pages.length,
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
              child: Image.file(
                File(p.join(document.path, pages[index].fileName)),
                fit: BoxFit.contain,
                cacheWidth: decodeWidth,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
                errorBuilder: (context, error, stack) => AspectRatio(
                  aspectRatio: 0.707,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
