import 'dart:io';

import 'package:flutter/painting.dart';

/// Forgets every decoded copy of [file].
///
/// Widgets decode at the size they draw them (`cacheWidth`), so one photo can
/// sit in the image cache under several keys at once — a private `ResizeImage`
/// key per width, none of which `FileImage(file).evict()` can reach. When the
/// editor overwrites a photo in place the path stays the same, so anything
/// still cached is the *previous* picture and would be shown again on the next
/// resolve. Flushing is the only way to guarantee the next frame reads disk.
///
/// Cheap in practice: this runs only after an explicit edit, and what is on
/// screen keeps its decoded image until it is replaced.
Future<void> forgetCachedImage(File file) async {
  await FileImage(file).evict();
  PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages();
}
