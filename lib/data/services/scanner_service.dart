import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

/// Why a scan produced nothing.
enum ScanFailure {
  /// The user backed out of the scanner UI. Not an error: say nothing loud.
  cancelled,

  /// Play services could not start the scanner (missing, outdated, or an
  /// AOSP/de-Googled device).
  unavailable,

  /// Anything else, including the plugin's "Unknown Error" result code.
  failed,
}

class ScanException implements Exception {
  const ScanException(this.reason);
  final ScanFailure reason;

  @override
  String toString() => 'ScanException(${reason.name})';
}

/// Result of a successful scan: the PDF ML Kit generated plus the per-page
/// JPEGs, all as paths into the app's cache.
class ScanResult {
  const ScanResult({
    required this.pdf,
    required this.pageCount,
    required this.pageImages,
  });

  final File pdf;
  final int pageCount;
  final List<File> pageImages;
}

/// Wraps Google's on-device document scanner.
///
/// Play services owns the whole capture UI — edge detection, perspective
/// correction, shadow removal, page reordering — which is why the app needs no
/// camera permission for this flow and why the result is already a clean PDF.
class ScannerService {
  ScannerService();

  /// The plugin keeps a single native `pendingResult`: a second concurrent
  /// scan orphans the first Future forever. One in-flight scan at a time.
  bool _inFlight = false;

  bool get isSupported => Platform.isAndroid;

  Future<ScanResult> scan({int pageLimit = 30}) async {
    if (!isSupported) throw const ScanException(ScanFailure.unavailable);
    if (_inFlight) throw const ScanException(ScanFailure.failed);
    _inFlight = true;

    // Not const: DocumentScannerOptions has no const constructor.
    // - full mode: includes ML cleaning (shadows, stains) — the reason to use
    //   Google's scanner at all rather than a plain camera.
    // - both formats: the PDF is what we store, the JPEG of page 1 becomes the
    //   list thumbnail without rasterising anything.
    // - gallery import: lets the user scan a photo they already took.
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: {DocumentFormat.pdf, DocumentFormat.jpeg},
        mode: ScannerMode.full,
        pageLimit: pageLimit,
        isGalleryImport: true,
      ),
    );

    try {
      final result = await scanner.scanDocument().timeout(
            // The plugin can silently never complete if the host activity is
            // recreated mid-scan; a timeout turns a permanent hang into an
            // error the UI can recover from.
            const Duration(minutes: 10),
            onTimeout: () => throw const ScanException(ScanFailure.failed),
          );

      final pdf = result.pdf;
      if (pdf == null) throw const ScanException(ScanFailure.failed);

      // `uri` is a plain filesystem path despite the name, and it lives in a
      // cache directory ML Kit owns — the caller copies it out immediately.
      return ScanResult(
        pdf: File(pdf.uri),
        pageCount: pdf.pageCount,
        pageImages: [
          for (final path in result.images ?? const <String>[]) File(path),
        ],
      );
    } on PlatformException catch (error) {
      // Every native failure uses the same code ('DocumentScanner'); only the
      // message distinguishes them.
      throw switch (error.message) {
        'Operation cancelled' => const ScanException(ScanFailure.cancelled),
        'Failed to start document scanner' =>
          const ScanException(ScanFailure.unavailable),
        _ => const ScanException(ScanFailure.failed),
      };
    } on MissingPluginException {
      throw const ScanException(ScanFailure.unavailable);
    } finally {
      _inFlight = false;
      // Evicts the native scanner from the plugin's instance cache.
      await scanner.close();
    }
  }
}
