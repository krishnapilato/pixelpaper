import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/text_prompt.dart';
import '../../../data/models/folder.dart';
import '../../../data/models/scanned_document.dart';
import '../../../data/providers.dart';
import '../../trash/presentation/trash_feedback.dart';
import 'documents_controller.dart';

/// The verbs of the archive, in one place so the list, the grid, the viewer
/// and the context sheet all behave identically.
abstract final class DocumentActions {
  static Future<void> share(
    BuildContext context,
    List<ScannedDocument> documents,
  ) async {
    if (documents.isEmpty) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          for (final document in documents)
            XFile(document.path, mimeType: 'application/pdf'),
        ],
        subject: documents.length == 1 ? documents.first.title : null,
        // Anchor for the iPad popover; harmless on Android.
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  static Future<void> print(
    BuildContext context,
    WidgetRef ref,
    ScannedDocument document,
  ) async {
    final strings = ref.read(stringsProvider);
    try {
      await ref
          .read(pdfServiceProvider)
          .printDocument(document.file, document.title);
    } on Object {
      if (!context.mounted) return;
      showSnack(context, strings('common_error'),
          icon: Icons.error_outline_rounded);
    }
  }

  static Future<void> rename(
    BuildContext context,
    WidgetRef ref,
    ScannedDocument document,
  ) async {
    final strings = ref.read(stringsProvider);
    final name = await askForText(
      context,
      title: strings('doc_rename_title'),
      hint: strings('doc_rename_hint'),
      actionLabel: strings('common_save'),
      cancelLabel: strings('common_cancel'),
      initialValue: document.title,
      icon: Icons.drive_file_rename_outline_rounded,
    );
    if (name == null || !context.mounted) return;

    final ok = await ref
        .read(documentsControllerProvider.notifier)
        .rename(document, name);
    if (!context.mounted) return;
    showSnack(
      context,
      ok ? strings('doc_renamed') : strings('doc_name_taken'),
      icon: ok ? Icons.check_rounded : Icons.error_outline_rounded,
    );
  }

  /// Moves documents to the bin. Reversible, so it asks nothing and offers an
  /// undo instead; the irreversible step lives in the Cestino.
  static Future<bool> delete(
    BuildContext context,
    WidgetRef ref,
    List<ScannedDocument> documents,
  ) async {
    if (documents.isEmpty) return false;
    final ids = documents.map((d) => d.id).toSet();

    await ref.read(documentsControllerProvider.notifier).moveToTrash(documents);
    if (!context.mounted) return true;
    showTrashedSnack(context, ref, kind: FolderKind.document, ids: ids);
    return true;
  }
}
