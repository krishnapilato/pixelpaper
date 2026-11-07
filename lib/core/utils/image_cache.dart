import 'dart:io';

import 'package:flutter/painting.dart';

/// Edited images receive a fresh path. Old resized cache entries age out under
/// Flutter's normal budget; unrelated gallery thumbnails stay warm.
Future<void> forgetCachedImage(File file) async {
  await FileImage(file).evict();
}
