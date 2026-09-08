import 'dart:async';
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
  ///
  /// The photos keep every pixel they were shot with: a scan is the archive
  /// copy, so nothing here re-encodes or downscales. Only the page *box* is
  /// scaled, and that is geometry, not pixels.
  ///
  /// Paths cross to the isolate, not bytes. Twelve 12 MP photos are ~45 MB;
  /// reading them here and letting `compute` copy them across meant that much
  /// twice over before the document even existed.
  Future<Uint8List> composeFromImages(List<String> imagePaths) =>
      compute(_composeIsolate, imagePaths);

  // --- Reading -------------------------------------------------------------

  /// The bytes of the document being read, and no other.
  ///
  /// One entry, app-wide, deliberately. A reader or an editor asks for a dozen
  /// pages of the same file within one frame; without this each of them called
  /// `readAsBytes` for itself and a 45 MB scan became half a gigabyte of live
  /// buffers, which is exactly how the editor died on a 12-photo document.
  /// Keyed on the modification stamp, so saving an edit invalidates it.
  String? _loadedKey;
  Uint8List? _loaded;
  int _holders = 0;

  /// Renders in flight, by cache path: two thumbnails that both want page 3
  /// must rasterise it once.
  final Map<String, Future<File?>> _rendering = {};

  /// Rasterisation runs one at a time. `Printing.raster` hands the bytes to a
  /// native PdfRenderer, so a dozen concurrent calls rebuild the same memory
  /// spike on the platform side of the channel.
  Future<void> _renderQueue = Future<void>.value();

  /// Marks a screen as reading [file]; balance it with [releaseDocument].
  void retainDocument() => _holders++;

  /// Drops the cached bytes once the last reader has gone.
  void releaseDocument() {
    _holders = math.max(0, _holders - 1);
    if (_holders == 0) {
      _loadedKey = null;
      _loaded = null;
    }
  }

  Future<Uint8List> _documentBytes(File pdf, DateTime modified) async {
    final key = '${pdf.path}|${modified.millisecondsSinceEpoch}';
    final loaded = _loaded;
    if (loaded != null && _loadedKey == key) return loaded;
    final bytes = await pdf.readAsBytes();
    _loadedKey = key;
    _loaded = bytes;
    return bytes;
  }

  /// Bytes written to the preview cache since it was last checked.
  int _writtenSinceSweep = 0;
  bool _sweeping = false;

  /// Sweeps every [_sweepEveryBytes] of rendered pages rather than once at
  /// launch.
  ///
  /// A single long reading session can render more previews than the whole
  /// budget allows — a 150-page scan is a few hundred megabytes of PNGs — and
  /// checking only on the next launch means living over budget for the entire
  /// session that produced it. Sweeping as we go keeps the cache near its
  /// ceiling instead of far above it.
  ///
  /// Deliberately not awaited by the render that triggers it: the page the
  /// user is waiting for must not wait for housekeeping. And guarded, because
  /// several renders finishing together would otherwise each start a sweep and
  /// they would delete each other's files out from under one another.
  static const int _sweepEveryBytes = 8 * 1024 * 1024;

  void _sweepIfNeeded(int written) {
    _writtenSinceSweep += written;
    if (_writtenSinceSweep < _sweepEveryBytes || _sweeping) return;
    _writtenSinceSweep = 0;
    _sweeping = true;
    unawaited(
      _storage.prunePreviewCache().whenComplete(() => _sweeping = false),
    );
  }

  /// Chains [task] after whatever is already rendering.
  Future<T> _enqueue<T>(Future<T> Function() task) {
    final result = _renderQueue.then((_) => task());
    _renderQueue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<int> pageCount(File file) async {
    try {
      final stat = await file.stat();
      final bytes = await _documentBytes(file, stat.modified);
      return await compute(_pageCountIsolate, bytes);
    } on Object {
      return 0;
    }
  }

  /// Size of the first page in points, reusing the cached bytes.
  ///
  /// Off the UI isolate, and measured rather than assumed: Syncfusion's Dart
  /// parser walks the cross-reference table of the whole file, and on a
  /// fifty-megabyte scan that is not the few milliseconds it is on a small
  /// one. Run inline it froze the app for minutes with a spinner turning.
  /// `compute` copies the bytes across, which is the price of a responsive
  /// screen; it happens once per document opened.
  Future<Size> firstPageSizeOf(File pdf) async {
    try {
      final stat = await pdf.stat();
      final bytes = await _documentBytes(pdf, stat.modified);
      return await compute(_firstPageSizeIsolate, bytes);
    } on Object {
      return a4;
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
  ///
  /// [source] is for one-shot callers working on a document nobody is reading;
  /// leave it null and the shared buffer is used instead. Callers never pass
  /// their own read of the file — that is what this class is here to prevent.
  ///
  /// [wanted] is checked when the request reaches the front of the queue, and
  /// is what makes a long document behave. Flick through a 150-page scan and
  /// you leave a hundred requests behind you for pages nobody is looking at
  /// any more; without this the page you actually stopped on would wait for
  /// every one of them. Widgets pass their own mounted state.
  Future<File?> pageImage(
    File pdf,
    int index, {
    required double dpi,
    Uint8List? source,
    bool Function()? wanted,
  }) async {
    try {
      final stat = await pdf.stat();
      final cached = await _cacheFile(
        '${pdf.path}|${stat.modified.millisecondsSinceEpoch}|$index|${dpi.round()}',
      );
      if (await cached.exists()) {
        // Serving from cache counts as use: see [StorageService.touchPreview].
        unawaited(_storage.touchPreview(cached));
        return cached;
      }

      final pending = _rendering[cached.path];
      if (pending != null) {
        final shared = await pending;
        if (shared != null) return shared;
        // The request we joined was abandoned by whoever owned it. Ours is
        // still live, so ask again rather than inheriting someone else's
        // cancellation. The entry is gone by now, so this takes the fresh
        // path, and it can only repeat while [wanted] keeps saying yes.
        if (wanted != null && !wanted()) return null;
        return await pageImage(
          pdf,
          index,
          dpi: dpi,
          source: source,
          wanted: wanted,
        );
      }

      final task = _enqueue(() async {
        // Both re-checked here, not at call time: the wait in the queue is
        // where the page gets cached by someone else, or scrolled away.
        if (await cached.exists()) return cached;
        if (wanted != null && !wanted()) return null;

        final bytes = source ?? await _documentBytes(pdf, stat.modified);
        await for (final page in Printing.raster(
          bytes,
          pages: [index],
          dpi: dpi,
        )) {
          final png = await page.toPng();
          await cached.writeAsBytes(png, flush: true);
          _sweepIfNeeded(png.length);
          return cached;
        }
        return null;
      }).whenComplete(() => _rendering.remove(cached.path));

      _rendering[cached.path] = task;
      return await task;
    } on Object {
      return null;
    }
  }

  /// First-page thumbnail for the archive list.
  ///
  /// Its bytes stay local: the archive scrolls past documents that are not
  /// open, and letting each one evict the shared buffer would turn a scroll
  /// into a string of 45 MB reads.
  Future<File?> thumbnail(File pdf, {double targetPx = 420}) async {
    try {
      final bytes = await pdf.readAsBytes();
      final size = await compute(_firstPageSizeIsolate, bytes);
      return await pageImage(pdf, 0, dpi: dpiFor(size, targetPx), source: bytes);
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
    final stat = await target.stat();
    final source = await _documentBytes(target, stat.modified);
    final bytes = await compute(
      _rewriteIsolate,
      _RewriteRequest(source: source, pages: pages),
    );
    await target.writeAsBytes(bytes, flush: true);
    // The buffer now describes a file that no longer exists. Its key would
    // catch that anyway once the stamp moves, but holding the old bytes for a
    // document this size is a waste nobody benefits from.
    _loadedKey = null;
    _loaded = null;
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

Future<Uint8List> _composeIsolate(List<String> paths) async {
  const longEdge = 842.0; // A4 long side in points.
  final doc = pw.Document(compress: true);

  for (final path in paths) {
    final file = File(path);
    if (!await file.exists()) continue;
    // Embedded exactly as shot: the JPEG is already compressed, and re-encoding
    // it would cost quality for a saving the PDF's own compression cannot make.
    final image = pw.MemoryImage(await file.readAsBytes());
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

Size _firstPageSizeIsolate(Uint8List bytes) => PdfService.firstPageSize(bytes);

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
