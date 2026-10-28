import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/text_prompt.dart';
import '../../../data/models/folder.dart';
import '../../../data/models/scanned_document.dart';
import '../../../data/providers.dart';
import '../../trash/presentation/trash_feedback.dart';
import 'documents_controller.dart';

/// The verbs of the archive, shared by list, grid, reader and context sheet.
/// Every PDF made for the occasion is deleted as soon as it has been handed
/// over.
abstract final class DocumentActions {
  static Future<void> share(
    BuildContext context,
    WidgetRef ref,
    List<ScannedDocument> documents,
  ) async {
    if (documents.isEmpty) return;
    final strings = ref.read(stringsProvider);
    final repository = ref.read(documentRepositoryProvider);
    try {
      await withBusy(context, strings('share_preparing'), () async {
        Future<void> shareFrom(int index, List<XFile> files) async {
          if (index == documents.length) {
            await SharePlus.instance.share(
              ShareParams(
                files: files,
                subject: documents.length == 1 ? documents.first.title : null,
              ),
            );
            return;
          }
          await repository.withPdf(
            documents[index],
            (pdf) => shareFrom(index + 1, [
              ...files,
              XFile(pdf.path, mimeType: 'application/pdf'),
            ]),
          );
        }

        await shareFrom(0, const []);
      });
    } on Object {
      if (context.mounted) _fail(context, strings('share_failed'));
    }
  }

  /// Saves a PDF copy into the folder chosen in Impostazioni, or wherever the
  /// system save dialog is pointed. A folder that stopped being writable is
  /// forgotten and the dialog takes over.
  static Future<void> export(
    BuildContext context,
    WidgetRef ref,
    ScannedDocument document,
  ) async {
    final strings = ref.read(stringsProvider);
    final store = ref.read(settingsStoreProvider);
    final name = '${Fmt.safeFileName(document.title)}.pdf';
    try {
      final message = await withBusy(
        context,
        strings('export_preparing'),
        () =>
            ref.read(documentRepositoryProvider).withPdf(document, (pdf) async {
              final folder = await store.exportFolder();
              if (folder != null) {
                try {
                  await SafStream().writeFileBytes(
                    folder.uri,
                    name,
                    'application/pdf',
                    await pdf.readAsBytes(),
                  );
                  return strings('export_done_in', {'folder': folder.name});
                } on Object {
                  await store.clearExportFolder();
                  ref.invalidate(exportFolderProvider);
                }
              }
              final saved = await FlutterFileDialog.saveFile(
                params: SaveFileDialogParams(
                  sourceFilePath: pdf.path,
                  fileName: name,
                ),
              );
              return saved == null ? null : strings('export_done');
            }),
      );
      if (message != null && context.mounted) {
        showSnack(context, message, icon: Icons.check_circle_outline_rounded);
      }
    } on Object {
      if (context.mounted) _fail(context, strings('export_failed'));
    }
  }

  static Future<void> print(
    BuildContext context,
    WidgetRef ref,
    ScannedDocument document,
  ) async {
    final strings = ref.read(stringsProvider);
    try {
      final bytes = await withBusy(
        context,
        strings('share_preparing'),
        () => ref
            .read(documentRepositoryProvider)
            .withPdf(document, (file) => file.readAsBytes()),
      );
      if (!context.mounted) return;
      await ref.read(pdfServiceProvider).printBytes(bytes, document.title);
    } on Object {
      if (context.mounted) _fail(context, strings('common_error'));
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

    try {
      final ok = await ref
          .read(documentsControllerProvider.notifier)
          .rename(document, name);
      if (!context.mounted) return;
      showSnack(
        context,
        ok ? strings('doc_renamed') : strings('doc_name_taken'),
        icon: ok ? Icons.check_rounded : Icons.error_outline_rounded,
      );
    } on Object {
      if (context.mounted) _fail(context, strings('common_error'));
    }
  }

  /// Moves documents to the bin with an undo; nothing is erased here.
  static Future<bool> delete(
    BuildContext context,
    WidgetRef ref,
    List<ScannedDocument> documents,
  ) async {
    if (documents.isEmpty) return false;
    final ids = {for (final d in documents) d.id};
    try {
      await ref.read(documentsControllerProvider.notifier).moveToTrash(ids);
    } on Object {
      if (context.mounted) {
        _fail(context, ref.read(stringsProvider)('common_error'));
      }
      return false;
    }
    if (context.mounted) {
      showTrashedSnack(context, ref, kind: FolderKind.document, ids: ids);
    }
    return true;
  }

  static void _fail(BuildContext context, String message) =>
      showSnack(context, message, icon: Icons.error_outline_rounded);
}
