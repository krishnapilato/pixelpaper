import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_paper/data/models/capture.dart';
import 'package:pixel_paper/data/models/document_page.dart';
import 'package:pixel_paper/data/models/folder.dart';
import 'package:pixel_paper/data/models/scanned_document.dart';
import 'package:pixel_paper/features/documents/application/documents_controller.dart';

ScannedDocument doc(
  int id, {
  String title = 'Doc',
  int day = 1,
  int size = 0,
  int? folderId,
}) => ScannedDocument(
  id: id,
  path: '/docs/$id.pdf',
  title: title,
  createdAt: DateTime(2026, 1, day),
  updatedAt: DateTime(2026, 1, day),
  pageCount: 1,
  sizeBytes: size,
  folderId: folderId,
);

void main() {
  group('rows', () {
    test('a document survives a round trip through its row', () {
      final original = doc(
        7,
        title: 'Contratto',
        size: 42,
        folderId: 3,
      ).copyWith(deletedAt: DateTime(2026, 2), thumbnailPath: '/t.png');
      final restored = ScannedDocument.fromRow({...original.toRow(), 'id': 7});
      expect(restored, original);
      expect(restored.hashCode, original.hashCode);
    });

    test('a capture survives a round trip through its row', () {
      final original = Capture(
        id: 3,
        path: '/c/IMG.jpg',
        createdAt: DateTime(2026, 5, 4),
        sizeBytes: 9,
        source: CaptureSource.gallery,
        width: 4,
        height: 3,
        folderId: 1,
      );
      expect(Capture.fromRow({...original.toRow(), 'id': 3}), original);
    });

    test('a corrupt row is reported, not trusted', () {
      expect(
        () => ScannedDocument.fromRow({'id': 'one', 'path': '/x'}),
        throwsFormatException,
      );
      expect(
        () => Capture.fromRow({'id': 1, 'path': null, 'created_at': 0}),
        throwsFormatException,
      );
    });

    test('unknown enum values fall back safely', () {
      final row = {...doc(1).toRow(), 'id': 1, 'kind': 'malware'};
      expect(ScannedDocument.fromRow(row).kind, DocumentKind.pdf);
    });

    test('a page row cannot point outside its album', () {
      Map<String, Object?> row(String name) => {
        'id': 1,
        'document_id': 1,
        'file_name': name,
        'position': 0,
        'created_at': 0,
      };
      expect(
        () => DocumentPage.fromRow(row('../../secret.jpg')),
        throwsFormatException,
      );
      expect(
        () => DocumentPage.fromRow(row('/abs/path.jpg')),
        throwsFormatException,
      );
      expect(() => DocumentPage.fromRow(row('.hidden')), throwsFormatException);
      expect(DocumentPage.fromRow(row('p123.jpg')).fileName, 'p123.jpg');
    });
  });

  group('folder names', () {
    test('are cleaned and bounded', () {
      expect(Folder.cleanName('  Fatture\n2026  '), 'Fatture 2026');
      expect(Folder.cleanName('   '), isNull);
      expect(Folder.cleanName(String.fromCharCodes([0, 0x202E])), isNull);
      expect(Folder.cleanName('x' * 500)!.length, Folder.maxNameLength);
    });

    test('SQL is just text', () {
      const name = "Robert'); DROP TABLE documents;--";
      expect(Folder.cleanName(name), name);
    });
  });

  group('archive view', () {
    final all = [
      doc(1, title: 'banca', day: 3, size: 10, folderId: 1),
      doc(2, title: 'Affitto', size: 30),
      doc(3, title: 'Bollette', day: 2, size: 20, folderId: 1),
      doc(4, title: 'Affitto', size: 30),
    ];

    List<int> ids(List<ScannedDocument> list) => [for (final d in list) d.id];

    test('sorts every way with stable ties', () {
      List<int> sorted(DocumentSort sort) =>
          ids(visibleDocuments(all, sort: sort, query: '', folderId: null));
      expect(sorted(DocumentSort.recent), [1, 3, 2, 4]);
      expect(sorted(DocumentSort.oldest), [2, 4, 3, 1]);
      expect(sorted(DocumentSort.nameAsc), [2, 4, 1, 3]);
      expect(sorted(DocumentSort.nameDesc), [3, 1, 2, 4]);
      expect(sorted(DocumentSort.size), [2, 4, 3, 1]);
    });

    test('scopes to the open folder', () {
      expect(
        ids(
          visibleDocuments(
            all,
            sort: DocumentSort.recent,
            query: '',
            folderId: 1,
          ),
        ),
        [1, 3],
      );
    });

    test('search ignores the folder and the case', () {
      expect(
        ids(
          visibleDocuments(
            all,
            sort: DocumentSort.recent,
            query: ' AFFI ',
            folderId: 1,
          ),
        ),
        [2, 4],
      );
    });

    test('a query full of regex metacharacters is just text', () {
      expect(
        visibleDocuments(
          all,
          sort: DocumentSort.recent,
          query: r'.*(\',
          folderId: null,
        ),
        isEmpty,
      );
    });
  });
}
