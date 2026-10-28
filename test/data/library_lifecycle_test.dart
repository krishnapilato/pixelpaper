import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pixel_paper/data/local/app_database.dart';
import 'package:pixel_paper/data/local/capture_dao.dart';
import 'package:pixel_paper/data/local/document_dao.dart';
import 'package:pixel_paper/data/local/folder_dao.dart';
import 'package:pixel_paper/data/models/capture.dart';
import 'package:pixel_paper/data/models/folder.dart';
import 'package:pixel_paper/data/repositories/capture_repository.dart';
import 'package:pixel_paper/data/repositories/document_repository.dart';
import 'package:pixel_paper/data/repositories/library_repository.dart';
import 'package:pixel_paper/data/services/scanner_service.dart';
import 'package:pixel_paper/data/services/storage_service.dart';

import '../support/harness.dart';

void main() {
  late Sandbox sandbox;
  late AppDatabase db;
  late StorageService storage;
  late CaptureRepository captures;
  late DocumentRepository documents;
  late LibraryRepository library;
  late DateTime now;

  setUp(() async {
    sandbox = await Sandbox.create();
    db = memoryDatabase();
    storage = sandbox.storage();
    now = DateTime(2026, 10, 28);
    captures = CaptureRepository(
      dao: CaptureDao(db),
      storage: storage,
      transcoder: (_) async => jpegWithMetadata(orientation: 1),
    );
    documents = DocumentRepository(
      dao: DocumentDao(db),
      storage: storage,
      pdf: FakePdfService(storage),
      images: captures,
    );
    library = LibraryRepository(
      folders: FolderDao(db),
      documentRows: DocumentDao(db),
      captureRows: CaptureDao(db),
      documents: documents,
      captures: captures,
      clock: () => now,
    );
  });

  tearDown(() async {
    await db.close();
    await sandbox.dispose();
  });

  Future<Capture> shoot([Uint8List? bytes]) async {
    final shot = await sandbox.write(
      sandbox.temporary,
      'camera/${DateTime.now().microsecondsSinceEpoch}.jpg',
      bytes ?? jpegWithMetadata(),
    );
    return captures.adopt(shot, origin: CaptureSource.camera);
  }

  group('photos', () {
    test('a shot is filed privately and its temporary copy removed', () async {
      final shot = await sandbox.write(
        sandbox.temporary,
        'shot.jpg',
        jpegWithMetadata(orientation: 1),
      );
      final capture = await captures.adopt(shot, origin: CaptureSource.camera);

      expect(
        p.isWithin((await storage.capturesDir()).path, capture.path),
        isTrue,
      );
      expect(await shot.exists(), isFalse);
      expect([capture.width, capture.height], [24, 16]);
      expect(await captures.load(), [capture]);
    });

    test(
      'a file from outside the app is copied, never moved or deleted',
      () async {
        final external = await sandbox.write(
          sandbox.outside,
          'mine.png',
          plainPng(),
        );
        final capture = await captures.adopt(
          external,
          origin: CaptureSource.gallery,
        );
        expect(await external.exists(), isTrue);
        expect(capture.path, endsWith('.png'));
      },
    );

    test('non-images are refused, whatever they are called', () async {
      final cases = {
        'empty.jpg': <int>[],
        'script.jpg': '#!/bin/sh\nrm -rf /'.codeUnits,
        'doc.png': '%PDF-1.7'.codeUnits,
        'trunc.jpg': [0xFF, 0xD8],
      };
      for (final entry in cases.entries) {
        final file = await sandbox.write(
          sandbox.temporary,
          entry.key,
          entry.value,
        );
        await expectLater(
          captures.adopt(file, origin: CaptureSource.gallery),
          throwsA(isA<InvalidImageException>()),
          reason: entry.key,
        );
      }
      expect(await captures.load(), isEmpty);
      expect((await storage.capturesDir()).listSync(), isEmpty);
    });

    test('formats the archive does not keep are transcoded to JPEG', () async {
      final webp = await sandbox.write(
        sandbox.temporary,
        'pic.webp',
        Uint8List.fromList('RIFF\x00\x00\x00\x00WEBPVP8 '.codeUnits),
      );
      final capture = await captures.adopt(webp, origin: CaptureSource.gallery);
      expect(capture.path, endsWith('.jpg'));
    });

    test(
      'shared copies carry no metadata and do not outlive the share',
      () async {
        final capture = await shoot();
        late List<File> shared;
        await captures.withShareable([capture], (files) async {
          shared = files;
          final bytes = await files.single.readAsBytes();
          expect(containsAscii(bytes, 'SpyCam'), isFalse);
          expect(p.isWithin(sandbox.temporary.path, files.single.path), isTrue);
        });
        expect(await shared.single.exists(), isFalse);
        expect(
          containsAscii(await capture.file.readAsBytes(), 'SpyCam'),
          isTrue,
        );
      },
    );

    test(
      'an edit that changes format moves the file and keeps the row',
      () async {
        final capture = await shoot();
        final edited = await captures.replaceContent(
          capture,
          plainPng(width: 5, height: 5),
        );
        expect(edited.id, capture.id);
        expect(edited.path, endsWith('.png'));
        expect(await capture.file.exists(), isFalse);
        expect((await captures.load()).single, edited);
      },
    );
  });

  group('albums', () {
    test(
      'are built from byte-exact copies and remember their sources',
      () async {
        final a = await shoot();
        final b = await shoot();
        final album = await documents.createAlbum(
          imagePaths: [a.path, b.path],
          title: '../Contratto',
        );

        expect(album.title, 'Contratto');
        expect(album.pageCount, 2);
        final pages = await documents.pagesOf(album);
        expect(
          await pages.first.fileIn(album.directory).readAsBytes(),
          await a.file.readAsBytes(),
        );
        expect(await documents.pagedCapturePaths(), {a.path, b.path});
      },
    );

    test('leave nothing behind when a page cannot be read', () async {
      final a = await shoot();
      final bogus = await sandbox.write(
        sandbox.temporary,
        'bogus.jpg',
        'not an image'.codeUnits,
      );

      await expectLater(
        documents.createAlbum(imagePaths: [a.path, bogus.path], title: 'X'),
        throwsA(isA<InvalidImageException>()),
      );
      expect((await storage.albumsDir()).listSync(), isEmpty);
      expect(await documents.load(), isEmpty);
    });

    test(
      'saving a new order deletes dropped pages and sweeps orphans',
      () async {
        final a = await shoot();
        final b = await shoot();
        final album = await documents.createAlbum(
          imagePaths: [a.path, b.path],
          title: 'A',
        );
        final pages = await documents.pagesOf(album);
        final unsaved = await documents.addPageFile(album, a.path);

        final saved = await documents.savePages(album, [pages[1]]);

        expect(saved.pageCount, 1);
        expect(await pages[0].fileIn(album.directory).exists(), isFalse);
        expect(await unsaved.fileIn(album.directory).exists(), isFalse);
        expect(await pages[1].fileIn(album.directory).exists(), isTrue);
        expect(saved.thumbnailPath, pages[1].fileIn(album.directory).path);
      },
    );

    test('an album PDF exists only while it is being used', () async {
      final album = await documents.createAlbum(
        imagePaths: [(await shoot()).path],
        title: 'A',
      );
      late File pdf;
      await documents.withPdf(album, (file) async {
        pdf = file;
        final bytes = await file.readAsBytes();
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
        expect(containsAscii(bytes, 'SpyCam'), isFalse);
      });
      expect(await pdf.exists(), isFalse);

      await expectLater(
        documents.withPdf(album, (file) async {
          pdf = file;
          throw StateError('share sheet crashed');
        }),
        throwsStateError,
      );
      expect(await pdf.exists(), isFalse);
    });
  });

  group('scans', () {
    test(
      'importing deletes every file the scanner left in the cache',
      () async {
        final pdf = await sandbox.write(
          sandbox.temporary,
          'mlkit/scan.pdf',
          '%PDF-1.4'.codeUnits,
        );
        final page = await sandbox.write(
          sandbox.temporary,
          'mlkit/p1.jpg',
          jpegWithMetadata(),
        );

        final document = await documents.importScan(
          ScanResult(pdf: pdf, pageCount: 1, pageImages: [page]),
          'Bolletta',
        );

        expect(document.title, 'Bolletta');
        expect(await document.file.exists(), isTrue);
        expect(await pdf.exists(), isFalse);
        expect(await page.exists(), isFalse);
      },
    );

    test('a cancelled scan leaves no trace', () async {
      final pdf = await sandbox.write(sandbox.temporary, 'mlkit/scan.pdf', [1]);
      await documents.discardScan(
        ScanResult(pdf: pdf, pageCount: 1, pageImages: const []),
      );
      expect(await pdf.exists(), isFalse);
    });
  });

  group('bin', () {
    test(
      'emptying it removes album folders, PDFs and photos from disk',
      () async {
        final photo = await shoot();
        final album = await documents.createAlbum(
          imagePaths: [photo.path],
          title: 'A',
        );
        final pdfFile = await sandbox.write(
          sandbox.temporary,
          's.pdf',
          '%PDF'.codeUnits,
        );
        final pdf = await documents.importScan(
          ScanResult(pdf: pdfFile, pageCount: 1, pageImages: const []),
          'P',
        );

        await library.trashDocuments([album.id, pdf.id]);
        await library.trashCaptures([photo.id]);
        expect((await library.trash()).length, 3);
        expect(await documents.load(), isEmpty);

        await library.emptyTrash();

        expect((await library.trash()).isEmpty, isTrue);
        expect(await album.directory.exists(), isFalse);
        expect(await pdf.file.exists(), isFalse);
        expect(await photo.file.exists(), isFalse);
      },
    );

    test('restoring brings everything back untouched', () async {
      final photo = await shoot();
      await library.trashCaptures([photo.id]);
      expect(await captures.load(), isEmpty);
      await library.restoreCaptures([photo.id]);
      expect((await captures.load()).single.path, photo.path);
    });

    test('items expire after thirty days, not before', () async {
      final photo = await shoot();
      await library.trashCaptures([photo.id]);

      now = DateTime.now().add(const Duration(days: 29));
      await library.purgeExpired();
      expect(await photo.file.exists(), isTrue);

      now = DateTime.now().add(const Duration(days: 31));
      await library.purgeExpired();
      expect(await photo.file.exists(), isFalse);
    });

    test('handles selections larger than SQLite’s parameter limit', () async {
      final dao = CaptureDao(db);
      final ids = <int>[];
      for (var i = 0; i < 1500; i++) {
        ids.add(
          await dao.insert(
            Capture(
              id: 0,
              path: '/fake/$i.jpg',
              createdAt: DateTime(2026),
              sizeBytes: 1,
              source: CaptureSource.camera,
            ),
          ),
        );
      }
      await library.trashCaptures(ids);
      expect((await library.trash()).captures.length, 1500);
    });
  });

  group('tampering', () {
    test('a row pointing outside the app cannot delete that file', () async {
      final victim = await sandbox.write(sandbox.outside, 'victim.jpg', [1]);
      final dao = CaptureDao(db);
      final id = await dao.insert(
        Capture(
          id: 0,
          path: victim.path,
          createdAt: DateTime(2026),
          sizeBytes: 1,
          source: CaptureSource.camera,
        ),
      );
      await library.trashCaptures([id]);
      await library.emptyTrash();
      expect(await victim.exists(), isTrue);
    });

    test('a page row with a traversal name is rejected on read', () async {
      final album = await documents.createAlbum(
        imagePaths: [(await shoot()).path],
        title: 'A',
      );
      final raw = await db.instance;
      await raw.update('document_pages', {
        'file_name': '../../../outside/x.jpg',
      });
      await expectLater(documents.pagesOf(album), throwsFormatException);
    });

    test('folder names are data, never SQL', () async {
      const name = "x'); DROP TABLE documents;--";
      final folder = await library.createFolder(name, FolderKind.document);
      expect(folder!.name, name);
      expect(await library.createFolder(name, FolderKind.document), isNull);
      expect(await documents.load(), isEmpty);
      expect((await library.folders(FolderKind.document)).single.name, name);
    });
  });
}
