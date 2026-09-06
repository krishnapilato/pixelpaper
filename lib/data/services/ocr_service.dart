import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device text recognition.
///
/// One recogniser is kept for the whole session: ML Kit loads its model on
/// first use, and constructing a new recogniser per scan pays that cost every
/// single time. It is closed when the provider is disposed.
///
/// [TextRecognitionScript.latin] recognises a *script*, not a language: it
/// reads anything set in the Latin alphabet — Italian, English, Latin itself —
/// but not Greek, Cyrillic, Hebrew or Arabic, for which ML Kit has no model at
/// all (it ships latin, chinese, devanagari, japanese and korean). Old printing
/// is the real limit rather than the language: blackletter, long-s and scribal
/// abbreviations come back wrong, which is why `ocr_empty` says so plainly
/// instead of leaving the user to guess.
class OcrService {
  TextRecognizer? _recognizer;

  TextRecognizer get _instance =>
      _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> read(File image) async {
    final result = await _instance.processImage(InputImage.fromFile(image));
    return result.text.trim();
  }

  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}
