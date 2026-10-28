import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';

import '../../core/state/limits.dart';
import 'image_sanitizer.dart';
import 'storage_service.dart';

/// One page of a rewritten PDF: kept from the source, a new image, or blank.
@immutable
class PageBlueprint {
  const PageBlueprint.fromSource(int this.sourceIndex) : imageBytes = null;
  const PageBlueprint.image(Uint8List this.imageBytes) : sourceIndex = null;
  const PageBlueprint.blank() : sourceIndex = null, imageBytes = null;

  final int? sourceIndex;
  final Uint8List? imageBytes;

  bool get isBlank => sourceIndex == null && imageBytes == null;
}

/// All PDF work, on PDFium through pdfrx (files are opened by path, never
/// read into Dart memory) and on the `pdf` package for new pages.
///
/// A page's size in points is untrusted data, so every raster is bounded.
class PdfService {
  PdfService(this._storage);

  final StorageService _storage;

  static const ui.Size a4 = ui.Size(595, 842);
  static const double _longEdge = 842;
  static const int _maxRasterPx = 2400;

  final Map<String, Future<File?>> _rendering = {};
  Future<void> _queue = Future<void>.value();
  int _serial = 0;

  static double dpiFor(ui.Size page, double targetPx) {
    final longest = math.max(page.width, page.height);
    if (longest <= 0) return 72;
    return (targetPx * 72 / longest).clamp(8.0, 220.0);
  }

  static double dpiForWidth(ui.Size page, double targetPx) {
    if (page.width <= 0) return 72;
    return (targetPx * 72 / page.width).clamp(8.0, 220.0);
  }

  /// One page per image, each shaped like its photo and capped to A4's long
  /// edge. Pixels are embedded as shot, minus their metadata.
  Future<Uint8List> composeFromImages(List<String> imagePaths) =>
      compute(_composeIsolate, imagePaths);

  Future<int> pageCount(File file) async {
    try {
      return await _withDocument(
        file,
        (doc) async => doc.pages.length,
      ).timeout(Limits.wait);
    } on Object {
      return 0;
    }
  }

  /// First-page thumbnail, cached until the file changes.
  Future<File?> thumbnail(File pdf, {double targetPx = 420}) async {
    try {
      final stat = await pdf.stat();
      final cached = await _storage.previewFile(
        pdf.path,
        'thumb|${stat.modified.millisecondsSinceEpoch}|${targetPx.round()}',
      );
      if (await cached.exists()) {
        unawaited(_storage.touchPreview(cached));
        return cached;
      }
      return await (_rendering[cached.path] ??= _enqueue(() async {
        if (await cached.exists()) return cached;
        final png = await renderPagePng(
          pdf,
          0,
          longEdgePx: targetPx,
        ).timeout(Limits.wait);
        if (png == null) return null;
        await _storage.writeAtomic(cached, png);
        unawaited(_storage.prunePreviewCache());
        return cached;
      }).whenComplete(() => _rendering.remove(cached.path)));
    } on Object {
      return null;
    }
  }

  /// Copies an image the scanner already rendered into the preview cache.
  Future<File?> adoptThumbnail(File source, String documentPath) async {
    try {
      final stat = await File(documentPath).stat();
      final target = await _storage.previewFile(
        documentPath,
        'scan|${stat.modified.millisecondsSinceEpoch}',
      );
      return await _storage.copyAtomic(source, target);
    } on Object {
      return null;
    }
  }

  /// Page [index] as a PNG whose long edge is [longEdgePx], white behind.
  Future<Uint8List?> renderPagePng(
    File pdf,
    int index, {
    required double longEdgePx,
  }) => _withDocument(pdf, (doc) async {
    if (index < 0 || index >= doc.pages.length) return null;
    final page = doc.pages[index];
    final longest = math.max(page.width, page.height);
    if (longest <= 0) return null;
    final scale = math.min(longEdgePx, _maxRasterPx) / longest;
    final rendered = await page.render(
      fullWidth: page.width * scale,
      fullHeight: page.height * scale,
      backgroundColor: 0xFFFFFFFF,
    );
    if (rendered == null) return null;
    try {
      final image = await rendered.createImage();
      try {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        return png?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      rendered.dispose();
    }
  });

  /// Rewrites [target] so its pages match [pages]. Kept pages are moved by
  /// PDFium as they are, annotations and vectors included; the file is
  /// replaced atomically.
  Future<void> rewrite({
    required File target,
    required List<PageBlueprint> pages,
  }) async {
    if (pages.isEmpty) throw ArgumentError.value(pages, 'pages', 'empty');
    final source = await PdfDocument.openFile(target.path);
    final added = <PdfDocument>[];
    final Uint8List bytes;
    try {
      final assembled = <PdfPage>[];
      for (final blueprint in pages) {
        final index = blueprint.sourceIndex;
        if (index != null) {
          if (index >= 0 && index < source.pages.length) {
            assembled.add(source.pages[index]);
          }
          continue;
        }
        final single = await compute(_singlePageIsolate, blueprint.imageBytes);
        final doc = await PdfDocument.openData(
          single,
          sourceName: 'pixelpaper-new-${_serial++}',
        );
        added.add(doc);
        assembled.add(doc.pages.first);
      }
      if (assembled.isEmpty) throw StateError('No page left to write');
      source.pages = assembled;
      bytes = await source.encodePdf();
    } finally {
      for (final doc in [...added, source]) {
        await _release(doc);
      }
    }
    await _storage.writeAtomic(target, bytes);
    await _storage.deletePreviewsOf([target.path]);
  }

  Future<void> printBytes(Uint8List bytes, String name) async {
    await Printing.layoutPdf(
      onLayout: (_) => bytes,
      name: name,
      dynamicLayout: false,
    );
  }

  Future<T> _withDocument<T>(
    File file,
    Future<T> Function(PdfDocument doc) use,
  ) async {
    final doc = await PdfDocument.openFile(file.path);
    try {
      return await use(doc);
    } finally {
      await _release(doc);
    }
  }

  /// PDFium closes a document on its worker, behind any render still queued
  /// there by an open reader; the caller must not wait on that.
  static Future<void> _release(PdfDocument doc) =>
      doc.dispose().timeout(const Duration(seconds: 2), onTimeout: () {});

  Future<T> _enqueue<T>(Future<T> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}

pw.Page _imagePage(Uint8List bytes) {
  final image = pw.MemoryImage(_withoutMetadata(bytes));
  final width = (image.width ?? 1240).toDouble();
  final height = (image.height ?? 1754).toDouble();
  final scale = PdfService._longEdge / math.max(width, height);
  return pw.Page(
    pageFormat: PdfPageFormat(width * scale, height * scale),
    margin: pw.EdgeInsets.zero,
    build: (_) => pw.Image(image, fit: pw.BoxFit.fill),
  );
}

Uint8List _withoutMetadata(Uint8List bytes) {
  try {
    return ImageSanitizer.stripMetadata(bytes);
  } on FormatException {
    return bytes;
  }
}

Future<Uint8List> _composeIsolate(List<String> paths) async {
  final doc = pw.Document();
  for (final path in paths) {
    final file = File(path);
    if (!await file.exists()) continue;
    doc.addPage(_imagePage(await file.readAsBytes()));
  }
  return doc.save();
}

Future<Uint8List> _singlePageIsolate(Uint8List? image) {
  final doc = pw.Document()
    ..addPage(
      image == null
          ? pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: pw.EdgeInsets.zero,
              build: (_) => pw.SizedBox(),
            )
          : _imagePage(image),
    );
  return doc.save();
}
