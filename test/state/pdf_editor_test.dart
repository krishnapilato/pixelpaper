import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_paper/data/providers.dart';
import 'package:pixel_paper/data/services/pdf_service.dart';
import 'package:pixel_paper/features/documents/application/documents_controller.dart';
import 'package:pixel_paper/features/editor/application/editor_controller.dart';

import '../support/harness.dart';

class DelayedPdfService extends FakePdfService {
  DelayedPdfService(super.storage);

  final started = Completer<void>();
  final finish = Completer<void>();

  @override
  Future<void> rewrite({
    required File target,
    required List<PageBlueprint> pages,
  }) async {
    started.complete();
    await finish.future;
    await target.writeAsString('rewritten ${pages.length} pages');
  }
}

void main() {
  test(
    'PDF mutations and another save are blocked until the commit completes',
    () async {
      final sandbox = await Sandbox.create();
      addTearDown(sandbox.dispose);
      final pdf = DelayedPdfService(sandbox.storage());
      final container = containerFor(sandbox, pdfService: pdf);
      final source = await sandbox.write(
        sandbox.documents,
        'page.jpg',
        jpegWithMetadata(),
      );
      final document = await container
          .read(documentRepositoryProvider)
          .createPdf(imagePaths: [source.path], title: 'Volume');
      await container.read(documentsControllerProvider.future);
      final provider = editorControllerProvider(document.id);
      final subscription = container.listen(provider, (_, next) {});
      addTearDown(subscription.close);
      await container.read(provider.future);
      final editor = container.read(provider.notifier)..addBlank();
      final saving = editor.save();
      await pdf.started.future;
      final pages = container.read(provider).requireValue.pages;
      editor
        ..addBlank()
        ..remove(0)
        ..duplicate(0)
        ..reorder(0, 1);
      expect(container.read(provider).requireValue.pages, same(pages));
      expect(await editor.save(), isFalse);
      expect(await document.file.exists(), isTrue);
      pdf.finish.complete();
      expect(await saving, isTrue);
      final saved = container.read(provider).requireValue;
      expect(saved.saving, isFalse);
      expect(saved.dirty, isFalse);
      expect(saved.pages.length, 2);
      expect(saved.document.path, isNot(document.path));
      expect(await saved.document.file.exists(), isTrue);
    },
  );
}
