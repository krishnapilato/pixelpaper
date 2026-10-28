import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';

import 'app.dart';
import 'core/l10n/strings.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installErrorGuards();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(AppTheme.overlay);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Bounded so a large gallery cannot push the process past Android's heap.
  PaintingBinding.instance.imageCache
    ..maximumSizeBytes = 80 << 20
    ..maximumSize = 160;

  await initializeDateFormatting('it');
  await pdfrxFlutterInitialize();
  final strings = await Strings.load();

  runApp(
    ProviderScope(
      overrides: [stringsProvider.overrideWithValue(strings)],
      child: const PixelPaperApp(),
    ),
  );
}

/// A failed build shows a quiet card instead of a stack trace, and an
/// unawaited error is contained instead of fatal. Details are logged only in
/// debug builds: release logs must not carry titles or paths.
@visibleForTesting
void installErrorGuards() {
  FlutterError.onError = (details) {
    if (kDebugMode) FlutterError.dumpErrorToConsole(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) debugPrint('Errore non gestito: $error\n$stack');
    return true;
  };
  ErrorWidget.builder = (details) => ErrorCard(details: details);
}

/// Fits any slot it replaces: a full screen gets the sentence, a toolbar or a
/// tile gets the icon alone, and nothing can overflow.
class ErrorCard extends StatelessWidget {
  const ErrorCard({super.key, required this.details});

  final FlutterErrorDetails details;

  static const String message =
      'Questa parte non si è caricata.\nTorna indietro e riprova.';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: message,
      child: ColoredBox(
        color: const Color(0xFF111318),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final roomy =
                constraints.maxHeight >= 160 && constraints.maxWidth >= 200;
            return Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: EdgeInsets.all(roomy ? 24 : 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFA9ADB8),
                        size: 40,
                      ),
                      if (roomy) ...const [
                        SizedBox(height: 12),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            color: Color(0xFFE2E2E9),
                            fontSize: 15,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
