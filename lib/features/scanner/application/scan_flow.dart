import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/text_prompt.dart';
import '../../../data/providers.dart';
import '../../../data/services/scanner_service.dart';
import '../../documents/application/documents_controller.dart';

/// Module A end to end: launch Google's scanner, name the result, store it.
///
/// The naming step comes *after* the scan on purpose — asking for a file name
/// before there is anything to name is the classic scanner-app annoyance, and
/// after scanning the user knows what they just captured.
abstract final class ScanFlow {
  static Future<void> start(BuildContext context, WidgetRef ref) async {
    final strings = ref.read(stringsProvider);
    final messenger = ScaffoldMessenger.of(context);

    final ScanResult result;
    try {
      result = await ref.read(scannerServiceProvider).scan();
    } on ScanException catch (error) {
      if (!context.mounted) return;
      switch (error.reason) {
        case ScanFailure.cancelled:
          // Backing out is a normal outcome, not an error worth a banner.
          return;
        case ScanFailure.unavailable:
          await _showUnavailable(context, strings);
        case ScanFailure.failed:
          showSnack(context, strings('scan_failed'),
              icon: Icons.error_outline_rounded);
      }
      return;
    }

    if (!context.mounted) return;

    final suggestion = Fmt.defaultDocumentName(DateTime.now());
    final name = await askForText(
      context,
      title: strings('scan_naming_title'),
      subtitle: result.pageCount == 1
          ? strings('scan_naming_body_one')
          : strings('scan_naming_body', {'n': result.pageCount}),
      hint: strings('scan_naming_hint'),
      actionLabel: strings('scan_create_pdf'),
      cancelLabel: strings('common_cancel'),
      initialValue: suggestion,
      icon: Icons.description_outlined,
    );
    if (name == null || !context.mounted) return;

    try {
      final document =
          await ref.read(documentsControllerProvider.notifier).importScan(
                pdfSource: result.pdf,
                title: name,
                pageCount: result.pageCount,
                thumbnailSource:
                    result.pageImages.isEmpty ? null : result.pageImages.first,
              );

      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      showSnack(context, strings('scan_created'),
          icon: Icons.check_circle_outline_rounded);
      // Straight into the document: the user's next question is always
      // "did it come out right?".
      context.push(Routes.viewer(document.id));
    } on Object {
      if (!context.mounted) return;
      showSnack(context, strings('common_error'),
          icon: Icons.error_outline_rounded);
    }
  }

  static Future<void> _showUnavailable(
    BuildContext context,
    Strings strings,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.document_scanner_outlined),
        title: Text(strings('scan_unavailable_title')),
        content: Text(strings('scan_unavailable_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings('common_close')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ctx.push(Routes.camera);
            },
            child: Text(strings('camera_title')),
          ),
        ],
      ),
    );
  }
}
