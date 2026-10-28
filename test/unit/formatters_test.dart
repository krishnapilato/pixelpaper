import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pixel_paper/core/utils/formatters.dart';

void main() {
  setUpAll(() => initializeDateFormatting('it'));

  group('safeFileName', () {
    const hostile = {
      '../../etc/passwd': 'etcpasswd',
      r'..\..\Windows\system32': 'WindowsSystem32',
      'a/b\\c:d*e?f"g<h>i|j': 'abcdefghij',
      'nul\u0000byte': 'nulbyte',
      'line\nbreak\ttab': 'line break tab',
      '...hidden': 'hidden',
      'trailing. . .': 'trailing',
      '   spaced   out   ': 'spaced out',
    };

    hostile.forEach((input, expected) {
      test('cleans ${jsonEncode(input)}', () {
        final cleaned = Fmt.safeFileName(input);
        expect(cleaned.toLowerCase(), expected.toLowerCase());
        expect(cleaned.contains('/'), isFalse);
        expect(cleaned.contains(r'\'), isFalse);
        expect(cleaned.startsWith('.'), isFalse);
      });
    });

    test('removes bidirectional overrides that disguise extensions', () {
      final cleaned = Fmt.safeFileName(
        'fattura${String.fromCharCode(0x202E)}fdp.exe',
      );
      expect(cleaned.runes.any((r) => r >= 0x202A && r <= 0x202E), isFalse);
      expect(cleaned, 'fatturafdp.exe');
    });

    test('defuses Windows device names', () {
      expect(Fmt.safeFileName('CON'), '_CON');
      expect(Fmt.safeFileName('com1'), '_com1');
      expect(Fmt.safeFileName('Contratto'), 'Contratto');
    });

    test('bounds the name in bytes, never splitting a character', () {
      final cleaned = Fmt.safeFileName('📄' * 200);
      expect(utf8.encode(cleaned).length, lessThanOrEqualTo(Fmt.maxNameBytes));
      expect(cleaned.runes.every((r) => r == '📄'.runes.first), isTrue);
    });

    test('falls back when nothing usable is left', () {
      expect(Fmt.safeFileName('///'), 'Documento');
      expect(Fmt.safeFileName('  ', fallback: 'X'), 'X');
      expect(Fmt.safeFileName('', fallback: ''), '');
    });

    test('keeps ordinary Italian titles as they are', () {
      expect(
        Fmt.safeFileName('Contratto d’affitto – 2026'),
        'Contratto d’affitto – 2026',
      );
    });
  });

  group('bytes', () {
    test('formats with an Italian decimal comma', () {
      expect(Fmt.bytes(0), '0 B');
      expect(Fmt.bytes(-5), '0 B');
      expect(Fmt.bytes(512), '512 B');
      expect(Fmt.bytes(1536), '1,5 KB');
      expect(Fmt.bytes(5 * 1024 * 1024), '5,0 MB');
      expect(Fmt.bytes(1 << 50), endsWith('GB'));
    });
  });

  group('relativeDay', () {
    final now = DateTime(2026, 10, 28, 15);
    String day(DateTime d) =>
        Fmt.relativeDay(d, today: 'Oggi', yesterday: 'Ieri', now: now);

    test('names recent days', () {
      expect(day(DateTime(2026, 10, 28, 1)), 'Oggi');
      expect(day(DateTime(2026, 10, 27, 23)), 'Ieri');
      expect(day(DateTime(2026, 10, 25)), 'Domenica');
    });

    test('falls back to dates', () {
      expect(day(DateTime(2026, 3, 2)), '2 marzo');
      expect(day(DateTime(2024, 3, 2)), '2 marzo 2024');
    });

    test('a date in the future is not called a weekday', () {
      expect(day(DateTime(2026, 10, 30)), '30 ottobre');
    });
  });
}
