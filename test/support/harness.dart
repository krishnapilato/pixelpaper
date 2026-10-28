import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pixel_paper/core/l10n/strings.dart';
import 'package:pixel_paper/data/local/app_database.dart';
import 'package:pixel_paper/data/providers.dart';
import 'package:pixel_paper/data/services/pdf_service.dart';
import 'package:pixel_paper/data/services/storage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A private documents root and cache root per test, plus a folder outside
/// both that stands for "the rest of the phone".
class Sandbox {
  Sandbox._(this.base);

  final Directory base;

  Directory get documents => Directory(p.join(base.path, 'documents'));
  Directory get temporary => Directory(p.join(base.path, 'cache'));
  Directory get outside => Directory(p.join(base.path, 'outside'));

  static Future<Sandbox> create() async {
    final sandbox = Sandbox._(
      await Directory.systemTemp.createTemp('pixelpaper_test_'),
    );
    for (final dir in [sandbox.documents, sandbox.temporary, sandbox.outside]) {
      await dir.create(recursive: true);
    }
    return sandbox;
  }

  StorageService storage() => StorageService(
    roots: () async => StorageRoots(documents: documents, temporary: temporary),
  );

  Future<File> write(Directory dir, String name, List<int> bytes) async {
    final file = File(p.join(dir.path, name));
    await file.parent.create(recursive: true);
    return file.writeAsBytes(bytes, flush: true);
  }

  Future<void> dispose() async {
    if (await base.exists()) await base.delete(recursive: true);
  }
}

AppDatabase memoryDatabase() {
  sqfliteFfiInit();
  return AppDatabase(
    factory: databaseFactoryFfiNoIsolate,
    path: inMemoryDatabasePath,
  );
}

/// PDF work that needs PDFium is not exercised here; composing is pure Dart
/// and stays real.
class FakePdfService extends PdfService {
  FakePdfService(super.storage);

  @override
  Future<int> pageCount(File file) async => 1;

  @override
  Future<File?> thumbnail(File pdf, {double targetPx = 420}) async => null;
}

Strings loadStrings() {
  final raw = File('assets/lang.json').readAsStringSync();
  final decoded = jsonDecode(raw) as Map<String, Object?>;
  return Strings({for (final e in decoded.entries) e.key: '${e.value}'});
}

ProviderContainer containerFor(Sandbox sandbox, {AppDatabase? database}) {
  final db = database ?? memoryDatabase();
  final storage = sandbox.storage();
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      storageServiceProvider.overrideWithValue(storage),
      pdfServiceProvider.overrideWithValue(FakePdfService(storage)),
      stringsProvider.overrideWithValue(loadStrings()),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await db.close();
  });
  return container;
}

/// A real JPEG carrying GPS coordinates, a camera model and an orientation.
Uint8List jpegWithMetadata({
  int orientation = 6,
  int width = 24,
  int height = 16,
}) {
  final image = img.Image(width: width, height: height)
    ..clear(img.ColorRgb8(200, 30, 30));
  image.exif.imageIfd
    ..make = 'SpyCam'
    ..model = 'Serial-0042'
    ..orientation = orientation;
  image.exif.gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');
  image.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(45, 1);
  return img.encodeJpg(image);
}

Uint8List plainPng({int width = 8, int height = 8}) {
  final image = img.Image(width: width, height: height)
    ..clear(img.ColorRgb8(10, 120, 200));
  return img.encodePng(image);
}

/// [needle] as ASCII inside [haystack].
bool containsAscii(Uint8List haystack, String needle) {
  final pattern = ascii.encode(needle);
  outer:
  for (var i = 0; i <= haystack.length - pattern.length; i++) {
    for (var j = 0; j < pattern.length; j++) {
      if (haystack[i + j] != pattern[j]) continue outer;
    }
    return true;
  }
  return false;
}
