import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/l10n/strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/providers.dart';

/// The router outlives every rebuild of the app widget.
final routerProvider = Provider<GoRouter>((ref) {
  final router = createRouter();
  ref.onDispose(router.dispose);
  return router;
});

class PixelPaperApp extends ConsumerStatefulWidget {
  const PixelPaperApp({super.key});

  @override
  ConsumerState<PixelPaperApp> createState() => _PixelPaperAppState();
}

class _PixelPaperAppState extends ConsumerState<PixelPaperApp> {
  @override
  void initState() {
    super.initState();
    // Trim the preview cache once the first frame is on screen, never before.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(storageServiceProvider).prunePreviewCache();
      // Anything sitting in the bin past its 30 days goes now, files included.
      ref.read(libraryRepositoryProvider).purgeExpired();
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);

    return MaterialApp.router(
      title: strings('app_name'),
      debugShowCheckedModeBanner: false,
      // Dark only, by product decision: this is a capture tool used on paper
      // under a lamp, and a light UI at night is the complaint that started
      // the redesign. No `theme`, no `themeMode` — nothing can flip it.
      theme: AppTheme.dark(),
      // Italian everywhere, including the parts Flutter draws itself: the
      // text-selection menu, the date pickers, the licence page. Without this
      // they would come up in English inside an all-Italian app.
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        // Respect the system font size, but stop before the layout breaks.
        maxScaleFactor: 1.4,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
