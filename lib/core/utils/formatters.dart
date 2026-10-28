import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

abstract final class Fmt {
  static const String locale = 'it';

  /// Bytes, not characters: ext4 and FAT both cap a name at 255 bytes, and the
  /// extension plus a " (99)" suffix must still fit.
  static const int maxNameBytes = 120;

  static final RegExp _illegal = RegExp(r'[\\/:*?"<>|\x00-\x1F\x7F]');
  static final RegExp _invisible = RegExp(
    r'[\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]',
  );
  static final RegExp _spaces = RegExp(r'\s+');
  static final RegExp _edges = RegExp(r'^[\s.]+|[\s.]+$');
  static final RegExp _reserved = RegExp(
    r'^(con|prn|aux|nul|com[0-9]|lpt[0-9])$',
    caseSensitive: false,
  );

  static String bytes(int size) {
    if (size <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    final i = math.min((math.log(size) / math.log(1024)).floor(), 3);
    final value = size / math.pow(1024, i);
    return '${value.toStringAsFixed(i == 0 ? 0 : 1).replaceAll('.', ',')} '
        '${units[i]}';
  }

  static String date(DateTime d) => DateFormat('d MMM y', locale).format(d);

  static String dateTime(DateTime d) =>
      DateFormat('d MMMM y · HH:mm', locale).format(d);

  static String relativeDay(
    DateTime d, {
    required String today,
    required String yesterday,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final startOfToday = DateTime(
      reference.year,
      reference.month,
      reference.day,
    );
    final diff = startOfToday
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;

    if (diff == 0) return today;
    if (diff == 1) return yesterday;
    if (diff > 1 && diff < 7) {
      return _capitalise(DateFormat('EEEE', locale).format(d));
    }
    if (d.year == reference.year) return DateFormat('d MMMM', locale).format(d);
    return DateFormat('d MMMM y', locale).format(d);
  }

  static String stem(String path) => p.basenameWithoutExtension(path);

  static String extension(String path) =>
      p.extension(path).replaceFirst('.', '').toUpperCase();

  /// A name that is safe as a single path segment on any file system: no
  /// separators, control or bidi-override characters, no leading dots, no
  /// device names, bounded in bytes.
  static String safeFileName(String input, {String fallback = 'Documento'}) {
    var cleaned = input
        .replaceAll(_spaces, ' ')
        .replaceAll(_illegal, '')
        .replaceAll(_invisible, '')
        .replaceAll(_edges, '');
    if (_reserved.hasMatch(cleaned)) cleaned = '_$cleaned';
    cleaned = _truncateUtf8(cleaned, maxNameBytes).replaceAll(_edges, '');
    return cleaned.isEmpty ? fallback : cleaned;
  }

  static String defaultDocumentName(DateTime now) =>
      'Scansione ${DateFormat('d MMM y', locale).format(now)}';

  static String _truncateUtf8(String value, int maxBytes) {
    var bytes = 0;
    final out = StringBuffer();
    for (final rune in value.runes) {
      final size = rune < 0x80
          ? 1
          : rune < 0x800
          ? 2
          : rune < 0x10000
          ? 3
          : 4;
      if (bytes + size > maxBytes) break;
      bytes += size;
      out.writeCharCode(rune);
    }
    return out.toString();
  }

  static String _capitalise(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}
