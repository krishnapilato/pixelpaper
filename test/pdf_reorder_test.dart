import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_paper/data/services/pdf_service.dart';
import 'package:pixel_paper/data/services/storage_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// Guards the one thing the editor promises: the order you leave the filmstrip
/// in is the order the file is written in.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('pixelpaper_test');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  List<String> textOf(List<int> bytes) {
    final doc = sf.PdfDocument(inputBytes: bytes);
    final out = <String>[];
    for (var i = 0; i < doc.pages.count; i++) {
      out.add(
        sf.PdfTextExtractor(doc)
            .extractText(startPageIndex: i, endPageIndex: i)
            .trim(),
      );
    }
    doc.dispose();
    return out;
  }

  test('rewrite writes pages in the requested order', () async {
    final source = sf.PdfDocument();
    for (final label in ['ALPHA', 'BETA', 'GAMMA']) {
      final page = source.pages.add();
      page.graphics.drawString(
        label,
        sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 48),
      );
    }
    final file = File('${tmp.path}/doc.pdf');
    await file.writeAsBytes(await source.save(), flush: true);
    source.dispose();

    expect(textOf(await file.readAsBytes()), ['ALPHA', 'BETA', 'GAMMA']);

    await PdfService(StorageService()).rewrite(
      target: file,
      pages: const [
        PageBlueprint.fromSource(2),
        PageBlueprint.fromSource(0),
        PageBlueprint.fromSource(1),
      ],
    );

    expect(textOf(await file.readAsBytes()), ['GAMMA', 'ALPHA', 'BETA']);
  });

  test('rewrite drops a deleted page and keeps the rest in order', () async {
    final source = sf.PdfDocument();
    for (final label in ['ALPHA', 'BETA', 'GAMMA']) {
      final page = source.pages.add();
      page.graphics.drawString(
        label,
        sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 48),
      );
    }
    final file = File('${tmp.path}/doc2.pdf');
    await file.writeAsBytes(await source.save(), flush: true);
    source.dispose();

    await PdfService(StorageService()).rewrite(
      target: file,
      pages: const [PageBlueprint.fromSource(0), PageBlueprint.fromSource(2)],
    );

    expect(textOf(await file.readAsBytes()), ['ALPHA', 'GAMMA']);
  });
}
