import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pixel_paper/data/services/settings_store.dart';

import '../support/harness.dart';

void main() {
  late Sandbox sandbox;
  File settingsFile() => File(p.join(sandbox.documents.path, 'settings.json'));

  setUp(() async => sandbox = await Sandbox.create());
  tearDown(() => sandbox.dispose());

  const tree =
      'content://com.android.externalstorage.documents/tree/primary%3ADocuments';

  test('remembers a folder granted by the system picker', () async {
    final store = SettingsStore(sandbox.storage());
    await store.setExportFolder(
      const ExportFolder(uri: tree, name: 'Documents'),
    );

    final reread = SettingsStore(sandbox.storage());
    expect(
      await reread.exportFolder(),
      const ExportFolder(uri: tree, name: 'Documents'),
    );

    await reread.clearExportFolder();
    expect(await SettingsStore(sandbox.storage()).exportFolder(), isNull);
  });

  test('refuses anything that is not a document tree', () async {
    final store = SettingsStore(sandbox.storage());
    for (final uri in [
      'file:///sdcard/Download',
      'https://evil.example/upload',
      'content://com.evil.provider/document/1',
      'content:///tree/x',
      '',
    ]) {
      expect(ExportFolder.isValidUri(uri), isFalse, reason: uri);
      expect(
        () => store.setExportFolder(ExportFolder(uri: uri, name: 'x')),
        throwsArgumentError,
      );
    }
  });

  test('ignores a tampered file pointing exports elsewhere', () async {
    await settingsFile().writeAsString(
      jsonEncode({'export_dir_uri': 'file:///sdcard', 'export_dir_name': 'x'}),
    );
    expect(await SettingsStore(sandbox.storage()).exportFolder(), isNull);
  });

  test('survives a corrupt or oversized file', () async {
    await settingsFile().writeAsString('{not json');
    expect(await SettingsStore(sandbox.storage()).exportFolder(), isNull);

    await settingsFile().writeAsString('x' * (200 * 1024));
    expect(await SettingsStore(sandbox.storage()).exportFolder(), isNull);
  });

  test('concurrent writes are applied in order', () async {
    final store = SettingsStore(sandbox.storage());
    await Future.wait([
      store.setExportFolder(const ExportFolder(uri: tree, name: 'A')),
      store.clearExportFolder(),
      store.setExportFolder(const ExportFolder(uri: tree, name: 'B')),
    ]);
    expect((await SettingsStore(sandbox.storage()).exportFolder())?.name, 'B');
  });
}
