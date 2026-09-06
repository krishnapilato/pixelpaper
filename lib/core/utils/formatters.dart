import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

/// Formatting helpers. Everything user-facing is Italian; date symbols are
/// initialised for `it` in `main()`.
abstract final class Fmt {
  static const String locale = 'it';

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

  /// "Oggi", "Ieri", a weekday, then a date — used for list subtitles.
  static String relativeDay(DateTime d, {required String today, required String yesterday}) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = startOfToday.difference(that).inDays;

    if (diff == 0) return today;
    if (diff == 1) return yesterday;
    if (diff < 7) return _capitalise(DateFormat('EEEE', locale).format(d));
    if (d.year == now.year) return DateFormat('d MMMM', locale).format(d);
    return DateFormat('d MMMM y', locale).format(d);
  }

  static String stem(String path) => p.basenameWithoutExtension(path);

  static String extension(String path) =>
      p.extension(path).replaceFirst('.', '').toUpperCase();

  /// Strips characters that are illegal in a file name on any platform.
  static String safeFileName(String input, {String fallback = 'Documento'}) {
    final cleaned = input
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? fallback : cleaned;
  }

  /// Default name for a freshly scanned document, e.g. "Scansione 5 set 2026".
  static String defaultDocumentName(DateTime now) =>
      'Scansione ${DateFormat('d MMM y', locale).format(now)}';

  static String _capitalise(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}
