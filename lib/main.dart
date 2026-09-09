import 'dart:ui' show PlatformDispatcher;
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

  _installErrorGuards();

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

/// The app must not die, and must not show the user a stack trace.
///
/// Two different failures used to reach the screen. A build that threw put
/// Flutter's red error panel over the document — which is what a reader saw
/// instead of their scan. And an error escaping an async callback with nobody
/// awaiting it took the whole isolate down.
///
/// Neither is recoverable in a useful sense, but both are containable: one
/// broken widget becomes one apologetic box while the rest of the screen keeps
/// working, and an orphaned async error is logged instead of fatal. What this
/// cannot catch is the process being killed for using too much memory — that
/// is not an exception, it is Android ending the app, and the only defence is
/// not allocating that much in the first place.
void _installErrorGuards() {
  final inner = FlutterError.onError;
  FlutterError.onError = (details) {
    inner?.call(details);
  };

  // Anything thrown outside the framework's own zone: a Future nobody awaits,
  // a stream with no error handler. Returning true means "handled".
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Errore non gestito: $error\n$stack');
    return true;
  };

  ErrorWidget.builder = (details) => _ErrorCard(details: details);
}

/// What replaces a widget that failed to build.
///
/// Deliberately quiet and in the app's own colours: the user gets a sentence
/// they can act on, not a red rectangle full of Dart. In debug the details go
/// to the console, where they belong.
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF111318),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFA9ADB8),
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                'Questa parte non si è caricata.\nTorna indietro e riprova.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFE2E2E9), fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Housekeeping that must not delay the first frame.
Future<void> runStartupMaintenance(WidgetRef ref) async {
  await ref.read(storageServiceProvider).prunePreviewCache();
}
