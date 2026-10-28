import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pixel_paper/data/services/storage_service.dart';

import '../support/harness.dart';

void main() {
  late Sandbox sandbox;
  late StorageService storage;

  setUp(() async {
    sandbox = await Sandbox.create();
    storage = sandbox.storage();
  });

  tearDown(() => sandbox.dispose());

  group('confinement', () {
    test('owns only what lies inside its two roots', () async {
      expect(
        await storage.owns(p.join(sandbox.documents.path, 'pdf', 'a.pdf')),
        isTrue,
      );
      expect(
        await storage.owns(p.join(sandbox.temporary.path, 'x.jpg')),
        isTrue,
      );
      expect(
        await storage.owns(p.join(sandbox.outside.path, 'x.jpg')),
        isFalse,
      );
      expect(await storage.owns(sandbox.documents.path), isFalse);
    });

    test('sees through traversal', () async {
      final sneaky = p.join(
        sandbox.documents.path,
        'pdf',
        '..',
        '..',
        'outside',
        'x',
      );
      expect(await storage.owns(sneaky), isFalse);
    });

    test(
      'never deletes a file outside its roots, whatever it is asked',
      () async {
        final victim = await sandbox.write(sandbox.outside, 'precious.jpg', [
          1,
          2,
          3,
        ]);
        final sneaky = p.join(
          sandbox.documents.path,
          '..',
          'outside',
          'precious.jpg',
        );

        await storage.deleteFiles([victim.path, sneaky]);
        await storage.deleteTree(sandbox.outside);

        expect(await victim.exists(), isTrue);
      },
    );

    test('deletes its own files', () async {
      final own = await sandbox.write(sandbox.temporary, 'old.jpg', [1]);
      await storage.deleteFiles([own.path, own.path]);
      expect(await own.exists(), isFalse);
    });
  });

  group('atomic writes', () {
    test('replace the content and leave no partial file', () async {
      final dir = await storage.documentsDir();
      final target = File(p.join(dir.path, 'doc.pdf'));
      await target.writeAsString('old');

      await storage.writeAtomic(target, 'new'.codeUnits);

      expect(await target.readAsString(), 'new');
      expect(dir.listSync().where((e) => e.path.endsWith('.part')), isEmpty);
    });

    test('leave the original untouched when the write cannot happen', () async {
      final dir = await storage.documentsDir();
      final target = File(p.join(dir.path, 'doc.pdf'));
      await target.writeAsString('original');
      await Directory('${target.path}.blocker').create();

      await expectLater(
        storage.writeAtomic(File(p.join(dir.path, 'missing', 'x.pdf')), [1]),
        throwsA(isA<FileSystemException>()),
      );
      expect(await target.readAsString(), 'original');
    });
  });

  group('names', () {
    test('never collide', () async {
      final dir = await storage.documentsDir();
      final first = await storage.uniqueFile(dir, 'Fattura', '.pdf');
      await first.writeAsString('1');
      final second = await storage.uniqueFile(dir, 'Fattura', '.pdf');
      expect(p.basename(first.path), 'Fattura.pdf');
      expect(p.basename(second.path), 'Fattura (2).pdf');
    });

    test('cannot be steered out of the folder', () async {
      final dir = await storage.documentsDir();
      final file = await storage.uniqueFile(dir, '../../outside/evil', '.pdf');
      expect(p.isWithin(dir.path, file.path), isTrue);
    });

    test('page files keep only a sane extension', () async {
      final album = await storage.newAlbumDir();
      expect(
        p.extension((await storage.newPageFile(album, '.JPG')).path),
        '.jpg',
      );
      expect(
        p.extension((await storage.newPageFile(album, '.sh/../x')).path),
        '',
      );
      expect(
        p.extension((await storage.newPageFile(album, '.verylongext')).path),
        '',
      );
    });

    test('rename refuses a taken name', () async {
      final dir = await storage.documentsDir();
      final a = await File(p.join(dir.path, 'A.pdf')).writeAsString('a');
      await File(p.join(dir.path, 'B.pdf')).writeAsString('b');
      expect(await storage.rename(a, 'B'), isNull);
      expect((await storage.rename(a, 'C'))!.path, p.join(dir.path, 'C.pdf'));
    });
  });

  group('transient files', () {
    test('exports, plugin copies and partial writes are cleared', () async {
      final export = await storage.exportFile('Fattura', '.pdf');
      await export.writeAsString('x');
      final shared = await sandbox.write(
        sandbox.temporary,
        'share_plus/copy.pdf',
        [1],
      );
      final camera = await sandbox.write(sandbox.temporary, 'camera/shot.jpg', [
        1,
      ]);
      final part = File(
        p.join((await storage.capturesDir()).path, 'IMG.jpg.1.part'),
      );
      await part.writeAsString('half');
      final kept = await sandbox.write(sandbox.temporary, 'other/keep.txt', [
        1,
      ]);

      await storage.clearTransient();

      expect(await export.exists(), isFalse);
      expect(await shared.exists(), isFalse);
      expect(await camera.exists(), isFalse);
      expect(await part.exists(), isFalse);
      expect(await kept.exists(), isTrue);
    });

    test('previews of one document go with it, others stay', () async {
      final mine = await storage.previewFile('/docs/a.pdf', 'thumb|1');
      final other = await storage.previewFile('/docs/b.pdf', 'thumb|1');
      await mine.writeAsString('a');
      await other.writeAsString('b');

      await storage.deletePreviewsOf(['/docs/a.pdf']);

      expect(await mine.exists(), isFalse);
      expect(await other.exists(), isTrue);
    });

    test('the preview cache is trimmed oldest first', () async {
      final dir = await storage.previewsDir();
      final chunk = List.filled(StorageService.previewCacheBudgetBytes ~/ 2, 0);
      final oldest = File(p.join(dir.path, 'old.png'))..writeAsBytesSync(chunk);
      oldest.setLastModifiedSync(DateTime(2020));
      final middle = File(p.join(dir.path, 'mid.png'))..writeAsBytesSync(chunk);
      middle.setLastModifiedSync(DateTime(2021));
      final newest = File(p.join(dir.path, 'new.png'))..writeAsBytesSync([1]);

      await storage.prunePreviewCache();

      expect(oldest.existsSync(), isFalse);
      expect(middle.existsSync(), isTrue);
      expect(newest.existsSync(), isTrue);
    });
  });
}
