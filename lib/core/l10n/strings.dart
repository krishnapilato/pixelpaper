import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Italian copy, loaded once from `assets/lang.json`.
///
/// The app ships a single locale on purpose, so this stays a flat key → string
/// map with `{placeholder}` interpolation instead of a full l10n pipeline.
class Strings {
  const Strings(this._values);

  final Map<String, String> _values;

  static const Strings empty = Strings({});

  /// Looks up [key]; falls back to the key itself so a missing string is
  /// visible in the UI instead of silently blank.
  String call(String key, [Map<String, Object?>? params]) {
    var value = _values[key] ?? key;
    if (params != null) {
      params.forEach((name, replacement) {
        value = value.replaceAll('{$name}', '$replacement');
      });
    }
    return value;
  }

  /// Chooses between `<base>_one` and `<base>_other`, filling `{n}`.
  String plural(String base, int count) {
    final key = count == 1 ? '${base}_one' : '${base}_other';
    return call(_values.containsKey(key) ? key : base, {'n': count});
  }

  static Future<Strings> load() async {
    try {
      final raw = await rootBundle.loadString('assets/lang.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return Strings({
        for (final entry in decoded.entries) entry.key: '${entry.value}',
      });
    } on Object {
      return empty;
    }
  }
}

/// Resolved before the first frame in `main()`, then overridden in the scope,
/// so screens can read strings synchronously.
final stringsProvider = Provider<Strings>(
  (ref) => throw UnimplementedError('stringsProvider must be overridden'),
);

extension StringsRef on WidgetRef {
  Strings get s => read(stringsProvider);
}

extension StringsRefBase on Ref {
  Strings get s => read(stringsProvider);
}
