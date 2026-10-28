import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'core/l10n/strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'features/gallery/application/capture_flow.dart';

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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(runStartupMaintenance(ref)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);

    return MaterialApp.router(
      title: strings('app_name'),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.4,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// Housekeeping after the first frame, each step independent of the others:
/// photos the picker handed over while the app was dead are kept, then every
/// temporary copy of the user's files is removed and the bin is expired.
Future<void> runStartupMaintenance(WidgetRef ref) async {
  Future<void> step(Future<void> Function() run) async {
    try {
      await run();
    } on Object catch (error) {
      if (kDebugMode) debugPrint('Manutenzione: $error');
    }
  }

  await step(() => CaptureFlow.recoverLostPhotos(ref));
  await step(CaptureFlow.clearLeftovers);
  await step(ref.read(storageServiceProvider).clearTransient);
  await step(ref.read(libraryRepositoryProvider).purgeExpired);
  await step(ref.read(storageServiceProvider).prunePreviewCache);
}
