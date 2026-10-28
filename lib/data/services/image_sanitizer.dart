import 'dart:typed_data';

enum ImageFormat {
  jpeg('.jpg', 'image/jpeg'),
  png('.png', 'image/png'),
  webp('.webp', 'image/webp'),
  heif('.heic', 'image/heic'),
  gif('.gif', 'image/gif');

  const ImageFormat(this.extension, this.mimeType);

  final String extension;
  final String mimeType;

  /// What the gallery stores as is; anything else is transcoded on import.
  bool get isArchival => this == jpeg || this == png;
}

/// Reads image bytes as untrusted input: every offset is bounds-checked and a
/// malformed structure is reported, never trusted.
abstract final class ImageSanitizer {
  static ImageFormat? sniff(Uint8List bytes) {
    bool at(int offset, List<int> magic) {
      if (bytes.length < offset + magic.length) return false;
      for (var i = 0; i < magic.length; i++) {
        if (bytes[offset + i] != magic[i]) return false;
      }
      return true;
    }

    if (at(0, const [0xFF, 0xD8, 0xFF])) return ImageFormat.jpeg;
    if (at(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return ImageFormat.png;
    }
    if (at(0, 'RIFF'.codeUnits) && at(8, 'WEBP'.codeUnits)) {
      return ImageFormat.webp;
    }
    if (at(0, 'GIF8'.codeUnits)) return ImageFormat.gif;
    if (at(4, 'ftyp'.codeUnits)) {
      for (final brand in const [
        'heic',
        'heix',
        'hevc',
        'heim',
        'heis',
        'mif1',
        'msf1',
        'avif',
      ]) {
        if (at(8, brand.codeUnits)) return ImageFormat.heif;
      }
    }
    return null;
  }

  /// Location, camera serials, thumbnails, XMP, comments and anything
  /// appended after the image are removed. EXIF orientation is the one tag
  /// kept, rewritten on its own, so the picture does not turn sideways.
  ///
  /// Formats other than JPEG and PNG are returned unchanged.
  static Uint8List stripMetadata(Uint8List bytes) => switch (sniff(bytes)) {
    ImageFormat.jpeg => _stripJpeg(bytes),
    ImageFormat.png => _stripPng(bytes),
    _ => bytes,
  };

  /// EXIF orientation (1–8), 1 when absent or unreadable.
  static int jpegOrientation(Uint8List bytes) {
    try {
      for (final segment in _jpegSegments(bytes)) {
        if (segment.marker == 0xE1) {
          final value = _exifOrientation(bytes, segment.start, segment.end);
          if (value != null) return value;
        }
        if (segment.marker == 0xDA) break;
      }
    } on FormatException {
      return 1;
    }
    return 1;
  }

  static Uint8List _stripJpeg(Uint8List bytes) {
    final out = BytesBuilder(copy: false)..add(const [0xFF, 0xD8]);
    final orientation = jpegOrientation(bytes);
    var wroteOrientation = false;

    for (final segment in _jpegSegments(bytes)) {
      final m = segment.marker;
      if (m == 0xE1 || _isDroppedApp(bytes, m, segment.start, segment.end)) {
        continue;
      }
      if (!wroteOrientation && m != 0xE0) {
        if (orientation != 1) out.add(_orientationSegment(orientation));
        wroteOrientation = true;
      }
      out.add(
        Uint8List.sublistView(bytes, segment.headerStart, segment.dataEnd),
      );
      if (m == 0xD9) break;
    }
    return out.takeBytes();
  }

  static bool _isDroppedApp(Uint8List bytes, int marker, int start, int end) {
    if (marker == 0xFE || marker == 0xED) return true;
    if (marker < 0xE2 || marker > 0xEF) return false;
    bool tagged(String tag) {
      if (end - start < tag.length) return false;
      for (var i = 0; i < tag.length; i++) {
        if (bytes[start + i] != tag.codeUnitAt(i)) return false;
      }
      return true;
    }

    if (marker == 0xE2 && tagged('ICC_PROFILE\u0000')) return false;
    if (marker == 0xEE && tagged('Adobe')) return false;
    return true;
  }

  /// Segments after SOI. For SOS, [dataEnd] includes the entropy-coded scan.
  static Iterable<_Segment> _jpegSegments(Uint8List bytes) sync* {
    if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
      throw const FormatException('Not a JPEG');
    }
    var i = 2;
    while (i < bytes.length) {
      if (bytes[i] != 0xFF) throw FormatException('Marker expected', bytes, i);
      while (i < bytes.length && bytes[i] == 0xFF) {
        i++;
      }
      if (i >= bytes.length) throw const FormatException('Truncated marker');
      final marker = bytes[i];
      final headerStart = i - 1;
      i++;

      if (marker == 0xD9) {
        yield _Segment(marker, headerStart, i, i, i);
        return;
      }
      if ((marker >= 0xD0 && marker <= 0xD7) || marker == 0x01) {
        yield _Segment(marker, headerStart, i, i, i);
        continue;
      }
      if (i + 2 > bytes.length) throw const FormatException('Truncated length');
      final length = (bytes[i] << 8) | bytes[i + 1];
      if (length < 2 || i + length > bytes.length) {
        throw FormatException('Segment out of bounds', bytes, i);
      }
      final start = i + 2;
      final end = i + length;
      i = end;

      if (marker == 0xDA) {
        while (i + 1 < bytes.length) {
          if (bytes[i] == 0xFF) {
            final next = bytes[i + 1];
            if (next != 0x00 && (next < 0xD0 || next > 0xD7)) break;
          }
          i++;
        }
        if (i + 1 >= bytes.length) i = bytes.length;
      }
      yield _Segment(marker, headerStart, start, end, i);
    }
  }

  static int? _exifOrientation(Uint8List bytes, int start, int end) {
    const header = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00];
    if (end - start < header.length + 8) return null;
    for (var k = 0; k < header.length; k++) {
      if (bytes[start + k] != header[k]) return null;
    }
    final tiff = start + header.length;
    final view = ByteData.sublistView(bytes, tiff, end);
    final Endian order;
    if (view.getUint16(0) == 0x4949) {
      order = Endian.little;
    } else if (view.getUint16(0) == 0x4D4D) {
      order = Endian.big;
    } else {
      return null;
    }
    final ifd = view.getUint32(4, order);
    if (ifd + 2 > view.lengthInBytes) return null;
    final count = view.getUint16(ifd, order);
    for (var n = 0; n < count; n++) {
      final entry = ifd + 2 + n * 12;
      if (entry + 12 > view.lengthInBytes) return null;
      if (view.getUint16(entry, order) != 0x0112) continue;
      final value = view.getUint16(entry + 8, order);
      return value >= 1 && value <= 8 ? value : null;
    }
    return null;
  }

  static Uint8List _orientationSegment(int orientation) => Uint8List.fromList([
    0xFF, 0xE1, 0x00, 0x22, // APP1, length 34
    0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // "Exif\0\0"
    0x4D,
    0x4D,
    0x00,
    0x2A,
    0x00,
    0x00,
    0x00,
    0x08, // big-endian TIFF, IFD0 at 8
    0x00, 0x01, // one entry
    0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, // Orientation, SHORT, 1
    0x00, orientation, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, // no next IFD
  ]);

  static const Set<String> _pngMetadata = {
    'tEXt',
    'zTXt',
    'iTXt',
    'eXIf',
    'tIME',
  };

  static Uint8List _stripPng(Uint8List bytes) {
    final out = BytesBuilder(copy: false)
      ..add(Uint8List.sublistView(bytes, 0, 8));
    final view = ByteData.sublistView(bytes);
    var i = 8;
    while (i + 12 <= bytes.length) {
      final length = view.getUint32(i);
      final next = i + 12 + length;
      if (length > bytes.length || next > bytes.length) {
        throw FormatException('Chunk out of bounds', bytes, i);
      }
      final type = String.fromCharCodes(bytes, i + 4, i + 8);
      if (!_pngMetadata.contains(type)) {
        out.add(Uint8List.sublistView(bytes, i, next));
      }
      i = next;
      if (type == 'IEND') return out.takeBytes();
    }
    throw const FormatException('PNG without IEND');
  }
}

class _Segment {
  const _Segment(
    this.marker,
    this.headerStart,
    this.start,
    this.end,
    this.dataEnd,
  );

  final int marker;
  final int headerStart;
  final int start;
  final int end;
  final int dataEnd;
}
