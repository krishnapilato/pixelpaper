import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_paper/data/local/document_dao.dart';
import 'package:pixel_paper/data/models/scanned_document.dart';
import 'package:pixel_paper/data/providers.dart';
import 'package:pixel_paper/data/repositories/capture_repository.dart';
import 'package:pixel_paper/data/repositories/document_repository.dart';
import 'package:pixel_paper/data/services/pdf_service.dart';

import '../support/harness.dart';

class RejectUpdates extends DocumentDao {
  RejectUpdates(super.database);

  @override
  Future<void> replaceFile(
    ScannedDocument expected,
    ScannedDocument replacement,
  ) async => throw StateError('Database unavailable');
}

class RewrittenPdf extends FakePdfService {
  RewrittenPdf(super.storage);

  @override
  Future<void> rewrite({
    required File target,
    required List<PageBlueprint> pages,
  }) async {
    await target.writeAsString('new PDF contents');
  }
}

void main() {
  late Sandbox sandbox;
  setUp(() async => sandbox = await Sandbox.create());
  tearDown(() => sandbox.dispose());

  test('gallery selection creates a persistent two-page PDF without consuming photos', () async {
    final container = containerFor(sandbox);
    final a = await sandbox.write(
      sandbox.documents,
      'a.jpg',
      jpegWithMetadata(),
    );
    final b = await sandbox.write(sandbox.documents, 'b.png', plainPng());
    final document = await container
        .read(documentRepositoryProvider)
        .createPdf(imagePaths: [a.path, b.path], title: 'Libro storico');
    expect(document.isAlbum, isFalse);
    expect(document.pageCount, 2);
    final bytes = await document.file.readAsBytes();
    expect(containsAscii(bytes, '%PDF-'), isTrue);
    expect(containsAscii(bytes, '/Count 2'), isTrue);
    expect(containsAscii(bytes, 'SpyCam'), isFalse);
    expect(await a.exists(), isTrue);
    expect(await b.exists(), isTrue);
    expect(
      (await container.read(documentRepositoryProvider).byId(document.id))
          ?.path,
      document.path,
    );
    await container.read(documentRepositoryProvider).withPdf(document, (
      file,
    ) async {
      expect(file.path, document.path);
    });
    expect(await document.file.exists(), isTrue);
  });

  test('compact PDF does not upscale small images', () async {
    final file = await sandbox.write(
      sandbox.documents,
      'small.jpg',
      jpegWithMetadata(),
    );
    final target = File('${sandbox.documents.path}/compact.pdf');
    await PdfService(sandbox.storage())
        .composeToFile([file.path], target, quality: PdfImageQuality.compact);
    final bytes = await target.readAsBytes();
    expect(containsAscii(bytes, '/Width 16'), isTrue);
    expect(containsAscii(bytes, '/Height 24'), isTrue);
  });

  test('over-budget selection fails before creating an output', () async {
    final source = File('${sandbox.documents.path}/large.jpg');
    final handle = await source.open(mode: FileMode.write);
    await handle.truncate(97 * 1024 * 1024);
    await handle.close();
    final target = File('${sandbox.documents.path}/large.pdf');
    await expectLater(
      PdfService(sandbox.storage()).composeToFile([source.path], target),
      throwsA(isA<PdfMemoryLimitException>()),
    );
    expect(await target.exists(), isFalse);
    expect(await source.exists(), isTrue);
  });

  test(
    'database failure after PDF encoding keeps the previous document intact',
    () async {
      final db = memoryDatabase();
      addTearDown(db.close);
      final storage = sandbox.storage();
      final dao = RejectUpdates(db);
      final source = await sandbox.write(
        await storage.documentsDir(),
        'original.pdf',
        [1, 2, 3],
      );
      final draft = ScannedDocument(
        id: 0,
        path: source.path,
        title: 'Originale',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        pageCount: 1,
        sizeBytes: 3,
      );
      final document = draft.copyWith(id: await dao.insert(draft));
      final repository = DocumentRepository(
        dao: dao,
        storage: storage,
        pdf: RewrittenPdf(storage),
        images: CaptureRepository(
          dao: containerFor(sandbox, database: db).read(captureDaoProvider),
          storage: storage,
        ),
      );
      await expectLater(
        repository.rewritePdf(document, [const PageBlueprint.blank()]),
        throwsStateError,
      );
      expect(await source.readAsBytes(), [1, 2, 3]);
      expect((await dao.byId(document.id))?.path, source.path);
      expect(
        (await storage.listFiles(await storage.documentsDir(), {
          '.pdf',
        })).length,
        1,
      );
    },
  );
}
