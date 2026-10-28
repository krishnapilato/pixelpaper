import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'storage_service.dart';

@immutable
class ExportFolder {
  const ExportFolder({required this.uri, required this.name});

  /// A Storage Access Framework tree URI granted by the user.
  final String uri;
  final String name;

  /// Only tree URIs from the system document provider are accepted back from
  /// disk, so a tampered file cannot point exports anywhere else.
  static bool isValidUri(String uri) {
    final parsed = Uri.tryParse(uri);
    return parsed != null &&
        parsed.scheme == 'content' &&
        parsed.host.isNotEmpty &&
        parsed.pathSegments.isNotEmpty &&
        parsed.pathSegments.first == 'tree';
  }

  @override
  bool operator ==(Object other) =>
      other is ExportFolder && other.uri == uri && other.name == name;

  @override
  int get hashCode => Object.hash(uri, name);
}

/// The few choices remembered between launches, in a small JSON file.
class SettingsStore {
  SettingsStore(this._storage);

  final StorageService _storage;
  Map<String, Object?>? _cache;
  Future<void> _writes = Future<void>.value();

  static const String _exportUri = 'export_dir_uri';
  static const String _exportName = 'export_dir_name';
  static const int _maxBytes = 64 * 1024;

  Future<File> _file() async =>
      File(p.join((await _storage.roots).documents.path, 'settings.json'));

  Future<Map<String, Object?>> _read() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final file = await _file();
      if (await file.exists() && await file.length() <= _maxBytes) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, Object?>) return _cache = decoded;
      }
    } on Object {
      // A corrupt file holds nothing that cannot be chosen again.
    }
    return _cache = <String, Object?>{};
  }

  Future<void> _update(void Function(Map<String, Object?> values) change) {
    final next = _writes.then((_) async {
      final values = {...await _read()};
      change(values);
      _cache = values;
      await _storage.writeAtomic(
        await _file(),
        utf8.encode(jsonEncode(values)),
      );
    });
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<ExportFolder?> exportFolder() async {
    final values = await _read();
    final uri = values[_exportUri];
    final name = values[_exportName];
    if (uri is! String || !ExportFolder.isValidUri(uri)) return null;
    return ExportFolder(
      uri: uri,
      name: name is String && name.isNotEmpty ? name : uri,
    );
  }

  Future<void> setExportFolder(ExportFolder folder) {
    if (!ExportFolder.isValidUri(folder.uri)) {
      throw ArgumentError.value(folder.uri, 'uri', 'not a tree URI');
    }
    return _update((v) {
      v[_exportUri] = folder.uri;
      v[_exportName] = folder.name;
    });
  }

  Future<void> clearExportFolder() => _update((v) {
    v
      ..remove(_exportUri)
      ..remove(_exportName);
  });
}
