import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The handful of choices the app has to remember between launches.
///
/// A small JSON file rather than a preferences plugin or a table: there is one
/// setting so far, it is two strings long, and a file is something you can
/// open and read when something goes wrong. If this grows past a screenful it
/// belongs in the database with the rest of the state.
class SettingsStore {
  SettingsStore();

  Map<String, Object?>? _cache;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'settings.json'));
  }

  Future<Map<String, Object?>> _read() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final file = await _file();
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, Object?>) return _cache = decoded;
      }
    } on Object {
      // A corrupt settings file is not worth a crash, and there is nothing in
      // it that cannot be chosen again.
    }
    return _cache = <String, Object?>{};
  }

  Future<void> _write(Map<String, Object?> values) async {
    _cache = values;
    final file = await _file();
    await file.writeAsString(jsonEncode(values), flush: true);
  }

  // --- Export folder -------------------------------------------------------

  static const String _exportUri = 'export_dir_uri';
  static const String _exportName = 'export_dir_name';

  /// The folder "Esporta" writes into, or null while it should ask each time.
  ///
  /// Stored as the SAF tree URI plus the name to show in Impostazioni — the
  /// URI is unreadable to a human and the name alone cannot be written to.
  Future<({String uri, String name})?> exportFolder() async {
    final values = await _read();
    final uri = values[_exportUri];
    final name = values[_exportName];
    if (uri is! String || uri.isEmpty) return null;
    return (uri: uri, name: name is String && name.isNotEmpty ? name : uri);
  }

  Future<void> setExportFolder({required String uri, required String name}) =>
      _read().then((v) => _write({...v, _exportUri: uri, _exportName: name}));

  Future<void> clearExportFolder() =>
      _read().then((v) => _write({...v}..remove(_exportUri)
        ..remove(_exportName)));
}
