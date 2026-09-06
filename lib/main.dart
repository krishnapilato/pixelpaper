import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/l10n/strings.dart';
import 'core/theme/app_theme.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android 15 draws behind the system bars by default; opting in explicitly
  // keeps the behaviour identical on 14 and below.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(AppTheme.overlay);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // A gallery of several hundred full-resolution photos would otherwise let
  // Flutter's default cache (1000 entries / 100 MB) fill with decoded frames
  // faster than they are evicted. Bounding it explicitly keeps the app inside
  // Android's per-process heap no matter how big the library gets.
  PaintingBinding.instance.imageCache
    ..maximumSizeBytes = 80 << 20
    ..maximumSize = 160;

  // Italian month and weekday names for `intl`.
  await initializeDateFormatting('it');

  // Strings are resolved before the first frame so screens can read them
  // synchronously — no loading state for text that is baked into the bundle.
  final strings = await Strings.load();

  runApp(
    ProviderScope(
      overrides: [stringsProvider.overrideWithValue(strings)],
      child: const PixelPaperApp(),
    ),
  );
}

/// Housekeeping that must not delay the first frame.
Future<void> runStartupMaintenance(WidgetRef ref) async {
  await ref.read(storageServiceProvider).prunePreviewCache();
}
