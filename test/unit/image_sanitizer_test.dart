import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pixel_paper/data/services/image_sanitizer.dart';

import '../support/harness.dart';

void main() {
  group('sniff', () {
    test('recognises formats from their bytes, not their name', () {
      expect(ImageSanitizer.sniff(jpegWithMetadata()), ImageFormat.jpeg);
      expect(ImageSanitizer.sniff(plainPng()), ImageFormat.png);
      expect(
        ImageSanitizer.sniff(
          Uint8List.fromList('RIFF\x00\x00\x00\x00WEBPVP8 '.codeUnits),
        ),
        ImageFormat.webp,
      );
      expect(
        ImageSanitizer.sniff(
          Uint8List.fromList('\x00\x00\x00\x18ftypheic'.codeUnits),
        ),
        ImageFormat.heif,
      );
      expect(
        ImageSanitizer.sniff(Uint8List.fromList('GIF89a'.codeUnits)),
        ImageFormat.gif,
      );
    });

    test('refuses what is not an image', () {
      expect(ImageSanitizer.sniff(Uint8List(0)), isNull);
      expect(
        ImageSanitizer.sniff(Uint8List.fromList('%PDF-1.7'.codeUnits)),
        isNull,
      );
      expect(
        ImageSanitizer.sniff(Uint8List.fromList('MZ\x90\x00'.codeUnits)),
        isNull,
      );
      expect(ImageSanitizer.sniff(Uint8List.fromList([0xFF, 0xD8])), isNull);
    });
  });

  group('JPEG', () {
    test('drops GPS and camera identity but keeps the orientation', () {
      final source = jpegWithMetadata();
      expect(containsAscii(source, 'SpyCam'), isTrue);
      expect(ImageSanitizer.jpegOrientation(source), 6);

      final clean = ImageSanitizer.stripMetadata(source);

      expect(containsAscii(clean, 'SpyCam'), isFalse);
      expect(containsAscii(clean, 'Serial-0042'), isFalse);
      expect(ImageSanitizer.jpegOrientation(clean), 6);
      final decoded = img.decodeJpg(clean)!;
      expect(decoded.exif.gpsIfd.isEmpty, isTrue);
      expect(decoded.exif.imageIfd.make, isNull);
    });

    test('adds no EXIF block when the orientation is upright', () {
      final clean = ImageSanitizer.stripMetadata(
        jpegWithMetadata(orientation: 1),
      );
      expect(containsAscii(clean, 'Exif'), isFalse);
      expect(img.decodeJpg(clean), isNotNull);
    });

    test('removes data hidden after the end of the image', () {
      final source = jpegWithMetadata();
      final smuggled = Uint8List.fromList([
        ...source,
        ...'secret-payload'.codeUnits,
      ]);
      final clean = ImageSanitizer.stripMetadata(smuggled);
      expect(containsAscii(clean, 'secret-payload'), isFalse);
      expect(clean.sublist(clean.length - 2), [0xFF, 0xD9]);
    });

    test('keeps the pixels intact', () {
      final source = jpegWithMetadata(orientation: 1, width: 40, height: 30);
      final before = img.decodeJpg(source)!;
      final after = img.decodeJpg(ImageSanitizer.stripMetadata(source))!;
      expect([after.width, after.height], [before.width, before.height]);
      expect(after.getPixel(5, 5), before.getPixel(5, 5));
    });

    test('reports a truncated file instead of reading past its end', () {
      final source = jpegWithMetadata();
      expect(
        () =>
            ImageSanitizer.stripMetadata(Uint8List.sublistView(source, 0, 30)),
        throwsFormatException,
      );
    });

    test('survives thousands of corrupted inputs without crashing', () {
      final source = jpegWithMetadata();
      final random = Random(1337);
      for (var round = 0; round < 3000; round++) {
        final bytes = Uint8List.fromList(source);
        final flips = 1 + random.nextInt(8);
        for (var i = 0; i < flips; i++) {
          bytes[2 + random.nextInt(bytes.length - 2)] = random.nextInt(256);
        }
        final cut = random.nextBool()
            ? bytes
            : Uint8List.sublistView(bytes, 0, random.nextInt(bytes.length));
        try {
          ImageSanitizer.stripMetadata(cut);
          ImageSanitizer.jpegOrientation(cut);
        } on FormatException {
          // Rejected cleanly: the only acceptable failure.
        }
      }
    });
  });

  group('PNG', () {
    test('drops text, EXIF and time chunks, keeps the image', () {
      final image = img.Image(width: 4, height: 4)
        ..clear(img.ColorRgb8(1, 2, 3));
      image.textData = {'Author': 'Mario Rossi', 'Location': '45.46N 9.19E'};
      final source = img.encodePng(image);
      expect(containsAscii(source, 'Mario Rossi'), isTrue);

      final clean = ImageSanitizer.stripMetadata(source);

      expect(containsAscii(clean, 'Mario Rossi'), isFalse);
      expect(containsAscii(clean, 'tEXt'), isFalse);
      expect(img.decodePng(clean)!.getPixel(1, 1), image.getPixel(1, 1));
    });

    test('rejects a chunk that claims more bytes than the file has', () {
      final source = plainPng();
      final broken = Uint8List.fromList(source)
        ..setRange(8, 12, [0x7F, 0xFF, 0xFF, 0xFF]);
      expect(() => ImageSanitizer.stripMetadata(broken), throwsFormatException);
    });

    test('survives corrupted inputs without crashing', () {
      final source = plainPng();
      final random = Random(7);
      for (var round = 0; round < 2000; round++) {
        final bytes = Uint8List.fromList(source);
        bytes[8 + random.nextInt(bytes.length - 8)] = random.nextInt(256);
        try {
          ImageSanitizer.stripMetadata(bytes);
        } on FormatException {
          // Rejected cleanly.
        }
      }
    });
  });

  test('other formats pass through untouched', () {
    final gif = Uint8List.fromList('GIF89a....'.codeUnits);
    expect(ImageSanitizer.stripMetadata(gif), same(gif));
  });
}
