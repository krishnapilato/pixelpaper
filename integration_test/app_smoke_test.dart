import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:pixel_paper/app.dart';
import 'package:pixel_paper/core/router/app_router.dart';
import 'package:pixel_paper/data/models/scanned_document.dart';
import 'package:pixel_paper/data/providers.dart';
import 'package:pixel_paper/features/documents/application/documents_controller.dart';
import 'package:pixel_paper/features/editor/application/editor_controller.dart';
import 'package:pixel_paper/features/editor/presentation/document_editor_screen.dart';
import 'package:pixel_paper/features/settings/presentation/settings_screen.dart';
import 'package:pixel_paper/features/viewer/presentation/document_viewer_screen.dart';
import 'package:pixel_paper/main.dart' as application;
import 'package:pro_image_editor/pro_image_editor.dart';

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final limit = DateTime.now().add(const Duration(seconds: 30));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(limit)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(find.byType(application.ErrorCard), findsNothing);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('launch, gallery, settings, generated PDF, editor and save', (
    tester,
  ) async {
    final errorHandler = FlutterError.onError;
    final errorBuilder = ErrorWidget.builder;
    await application.main();
    // Keep the test binding's error collection; production guards must not
    // accidentally turn a failed smoke test into a successful one.
    FlutterError.onError = errorHandler;
    ErrorWidget.builder = errorBuilder;
    await waitFor(tester, find.text('Archivio'));
    await tester.tap(find.text('Galleria').last);
    await waitFor(tester, find.text('Galleria'));
    await tester.tap(find.byIcon(Icons.settings_outlined).last);
    await waitFor(tester, find.byType(SettingsScreen));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PixelPaperApp)),
    );
    final storage = container.read(storageServiceProvider);
    final router = container.read(routerProvider);
    ScannedDocument? created;
    File? fixture;
    try {
      fixture = await storage.exportFile('smoke-fixture', '.jpg');
      final image = img.Image(width: 320, height: 480)
        ..clear(img.ColorRgb8(245, 238, 215));
      await fixture.writeAsBytes(img.encodeJpg(image));
      created = await container
          .read(documentsControllerProvider.notifier)
          .createPdf(
            imagePaths: [fixture.path, fixture.path],
            title: 'Smoke ${DateTime.now().microsecondsSinceEpoch}',
          );
      expect(await created.file.exists(), isTrue);
      expect(created.pageCount, 2);
      unawaited(router.push<void>(Routes.viewer(created.id)));
      await waitFor(tester, find.byType(DocumentViewerScreen));
      await waitFor(tester, find.byType(PdfPageView));
      unawaited(router.push<void>(Routes.editor(created.id)));
      await waitFor(tester, find.byType(DocumentEditorScreen));
      await waitFor(tester, find.byType(PdfPageView));
      await tester.tap(find.byIcon(Icons.brush_outlined));
      await waitFor(tester, find.byType(ProImageEditor));
      Navigator.of(tester.element(find.byType(ProImageEditor))).pop();
      await tester.pumpAndSettle();
      final editor = container.read(
        editorControllerProvider(created.id).notifier,
      );
      editor
        ..addBlank()
        ..reorder(2, 0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();
      final updated = container
          .read(editorControllerProvider(created.id))
          .requireValue;
      created = updated.document;
      expect(updated.dirty, isFalse);
      expect(updated.pages.length, 3);
      expect(
        await container.read(pdfServiceProvider).pageCount(created.file),
        3,
      );
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(application.ErrorCard), findsNothing);
    } finally {
      if (created != null) {
        await container.read(documentRepositoryProvider).deleteForever([
          created,
        ]);
      }
      if (fixture != null) await storage.deleteFiles([fixture.path]);
    }
  });
}
