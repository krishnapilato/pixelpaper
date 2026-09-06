import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import 'storage_service.dart';

/// One page in a rewrite: kept from the source document, a new image, or blank.
/// Plain fields only — instances cross an isolate boundary.
class PageBlueprint {
  const PageBlueprint.fromSource(this.sourceIndex)
      : imageBytes = null,
        blank = false;

  const PageBlueprint.image(this.imageBytes)
      : sourceIndex = null,
        blank = false;

  const PageBlueprint.blank()
      : sourceIndex = null,
        imageBytes = null,
        blank = true;

  final int? sourceIndex;
  final Uint8List? imageBytes;
  final bool blank;
}

/// All PDF work: composing, rendering, rewriting, printing.
///
/// Two rules hold everywhere in this file:
///  * every raster is bounded by [dpiFor] / [dpiForWidth], because a page's
///    size in points is attacker-shaped data — a poster-sized page rendered at
///    a fixed DPI allocates hundreds of megabytes and kills the process;
///  * pure-Dart work (compose, rewrite) runs through [compute]; `Printing.raster`
///    is a platform channel and must stay on the platform thread.
class PdfService {
  PdfService(this._storage);

  final StorageService _storage;

  static const Size a4 = Size(595, 842);

  // --- Creating ------------------------------------------------------------

  /// Builds a PDF with one page per image, each page shaped like its photo but
  /// measured in points and capped to A4's long edge.
  Future<Uint8List> composeFromImages(List<String> imagePaths) async {
    final pages = <Uint8List>[];
    for (final path in imagePaths) {
      final file = File(path);
      if (await file.exists()) pages.add(await file.readAsBytes());
    }
    return compute(_composeIsolate, pages);
  }

  // --- Reading -------------------------------------------------------------

  Future<int> pageCount(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return await compute(_pageCountIsolate, bytes);
    } on Object {
      return 0;
    }
  }

  /// Size of the first page in points; A4 when the document cannot be parsed.
  static Size firstPageSize(Uint8List bytes) {
    try {
      final doc = sf.PdfDocument(inputBytes: bytes);
      final size = doc.pages.count > 0 ? doc.pages[0].size : a4;
      doc.dispose();
      return size;
    } on Object {
      return a4;
    }
  }

  /// DPI that renders [page] to roughly [targetPx] on its long edge.
  static double dpiFor(Size page, double targetPx) {
    final longest = math.max(page.width, page.height);
    if (longest <= 0) return 72;
    return (targetPx * 72 / longest).clamp(8.0, 220.0);
  }

  /// DPI that renders [page] to roughly [targetPx] wide.
  static double dpiForWidth(Size page, double targetPx) {
    if (page.width <= 0) return 72;
    return (targetPx * 72 / page.width).clamp(8.0, 220.0);
  }

  /// One rendered page, cached on disk. The key includes the file's
  /// modification stamp, so an edited document re-renders exactly once and
  /// paging back and forth is free.
  Future<File?> pageImage(
    File pdf,
    int index, {
    required double dpi,
    Uint8List? source,
  }) async {
    try {
      final stat = await pdf.stat();
      final cached = await _cacheFile(
        '${pdf.path}|${stat.modified.millisecondsSinceEpoch}|$index|${dpi.round()}',
      );
      if (await cached.exists()) return cached;

      final bytes = source ?? await pdf.readAsBytes();
      await for (final page in Printing.raster(
        bytes,
        pages: [index],
        dpi: dpi,
      )) {
        await cached.writeAsBytes(await page.toPng(), flush: true);
        return cached;
      }
    } on Object {
      return null;
    }
    return null;
  }

  /// First-page thumbnail for the archive list.
  Future<File?> thumbnail(File pdf, {double targetPx = 420}) async {
    try {
      final bytes = await pdf.readAsBytes();
      return await pageImage(
        pdf,
        0,
        dpi: dpiFor(firstPageSize(bytes), targetPx),
        source: bytes,
      );
    } on Object {
      return null;
    }
  }

  /// Stores an already-rendered image (e.g. a JPEG straight from the ML Kit
  /// scanner) as a document thumbnail — far cheaper than rasterising the PDF.
  Future<File?> adoptThumbnail(File source, String cacheKey) async {
    try {
      final target = await _cacheFile(cacheKey);
      await source.copy(target.path);
      return target;
    } on Object {
      return null;
    }
  }

  Future<File> _cacheFile(String key) async {
    final dir = await _storage.previewsDir();
    final name = md5.convert(utf8.encode(key)).toString();
    return File(p.join(dir.path, '$name.png'));
  }

  // --- Editing -------------------------------------------------------------

  /// Rewrites [target] so its pages match [pages], off the UI isolate.
  ///
  /// Syncfusion for Flutter has no page-move or page-import API, so a reorder
  /// is a redraw: every kept page is stamped onto a fresh document as a
  /// template. Deletion-only edits take the cheap path instead, which mutates
  /// the loaded document in place and preserves annotations and bookmarks.
  Future<void> rewrite({
    required File target,
    required List<PageBlueprint> pages,
  }) async {
    final source = await target.readAsBytes();
    final bytes = await compute(
      _rewriteIsolate,
      _RewriteRequest(source: source, pages: pages),
    );
    await target.writeAsBytes(bytes, flush: true);
  }

  // --- Sharing -------------------------------------------------------------

  Future<void> printDocument(File file, String name) async {
    final bytes = await file.readAsBytes();
    await Printing.layoutPdf(
      onLayout: (_) => bytes,
      name: name,
      // The bytes are final: never ask the plugin to re-lay-out per printer.
      dynamicLayout: false,
    );
  }
}

// --- Isolate entry points ----------------------------------------------------

class _RewriteRequest {
  const _RewriteRequest({required this.source, required this.pages});
  final Uint8List source;
  final List<PageBlueprint> pages;
}

Future<Uint8List> _composeIsolate(List<Uint8List> images) async {
  const longEdge = 842.0; // A4 long side in points.
  final doc = pw.Document(compress: true);

  for (final bytes in images) {
    final image = pw.MemoryImage(bytes);
    final width = (image.width ?? 1240).toDouble();
    final height = (image.height ?? 1754).toDouble();
    // A photo is thousands of pixels wide; a page must not be thousands of
    // POINTS wide, or every later render of this document explodes in memory.
    final scale = longEdge / math.max(width, height);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(width * scale, height * scale),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(image, fit: pw.BoxFit.fill),
      ),
    );
  }
  return doc.save();
}

int _pageCountIsolate(Uint8List bytes) {
  try {
    final doc = sf.PdfDocument(inputBytes: bytes);
    final count = doc.pages.count;
    doc.dispose();
    return count;
  } on Object {
    return 0;
  }
}

Future<Uint8List> _rewriteIsolate(_RewriteRequest request) async {
  final source = sf.PdfDocument(inputBytes: request.source);

  // Deletion-only edit: mutate in place, keeping annotations and bookmarks.
  final keptInOrder = request.pages
      .where((page) => page.sourceIndex != null)
      .map((page) => page.sourceIndex!)
      .toList(growable: false);
  final isDeletionOnly = keptInOrder.length == request.pages.length &&
      _isStrictlyIncreasing(keptInOrder) &&
      keptInOrder.length < source.pages.count;

  if (isDeletionOnly) {
    try {
      final kept = keptInOrder.toSet();
      for (var i = source.pages.count - 1; i >= 0; i--) {
        if (!kept.contains(i)) source.pages.removeAt(i);
      }
      return Uint8List.fromList(await source.save());
    } finally {
      source.dispose();
    }
  }

  final output = sf.PdfDocument();
  try {
    for (final page in request.pages) {
      if (page.blank) {
        output.pageSettings
          ..size = PdfService.a4
          ..margins.all = 0
          ..rotate = sf.PdfPageRotateAngle.rotateAngle0;
        output.pages.add();
        continue;
      }

      if (page.imageBytes != null) {
        final bitmap = sf.PdfBitmap(page.imageBytes!);
        final scale = 842.0 /
            math.max(bitmap.width.toDouble(), bitmap.height.toDouble());
        final size = Size(bitmap.width * scale, bitmap.height * scale);
        output.pageSettings
          ..size = size
          ..margins.all = 0
          ..rotate = sf.PdfPageRotateAngle.rotateAngle0;
        output.pages.add().graphics.drawImage(
              bitmap,
              Rect.fromLTWH(0, 0, size.width, size.height),
            );
        continue;
      }

      final index = page.sourceIndex;
      if (index == null || index < 0 || index >= source.pages.count) continue;
      final original = source.pages[index];

      // Page geometry is snapshotted by add(): it must be set BEFORE the page
      // exists. Rotation likewise — PdfPage.rotation's setter is a no-op on a
      // page this document created, so /Rotate has to come from pageSettings.
      output.pageSettings
        ..size = original.size
        ..margins.all = 0
        ..rotate = original.rotation;

      output.pages.add().graphics.drawPdfTemplate(
            original.createTemplate(),
            Offset.zero,
            original.size,
          );
    }
    return Uint8List.fromList(await output.save());
  } finally {
    output.dispose();
    source.dispose();
  }
}

bool _isStrictlyIncreasing(List<int> values) {
  for (var i = 1; i < values.length; i++) {
    if (values[i] <= values[i - 1]) return false;
  }
  return true;
}
