import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// The verbs of the archive, in one place so the list, the grid, the viewer
/// and the context sheet all behave identically.
abstract final class DocumentActions {
  /// Hands the files to the system share sheet.
  ///
  /// No `sharePositionOrigin`: it anchors the iPad popover and does nothing on
  /// Android, but getting it meant `context.findRenderObject()` on whatever
  /// context the caller happened to have — a list tile that had since been
  /// recycled, or a sheet already on its way out. That threw
  /// "SingleChildRenderObjectElement unmounted" and painted the red screen
  /// over the document. An anchor no platform we ship on reads is not worth a
  /// single crash.
  ///
  /// The catch matters just as much: Android copies every shared file into the
  /// app's cache before passing the handle on, so a large scan is a large copy
  /// that can fail. Silently, until now — no sheet, no message, nothing, which
  /// is indistinguishable from a dead button.
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
        // An album has no file to share until one is made. This is that
        // moment, and the only one: nothing else in the app writes a PDF.
        final files = [
          for (final document in documents) await repository.exportPdf(document),
        ];
        await SharePlus.instance.share(
          ShareParams(
            files: [
              for (final file in files)
                XFile(file.path, mimeType: 'application/pdf'),
            ],
            subject: documents.length == 1 ? documents.first.title : null,
          ),
        );
      });
    } on Object {
      if (!context.mounted) return;
      showSnack(
        context,
        strings('share_failed'),
        icon: Icons.error_outline_rounded,
      );
    }
  }

  /// Writes the document, as a PDF, wherever the user points the system's own
  /// save dialog.
  ///
  /// This is the one way a document leaves the app as a lasting file. The
  /// library itself stays in private storage — which is why PixelPaper asks for
  /// no storage permission and why a scan never turns up in Google Photos — so
  /// "esporta" is the deliberate act of putting a copy somewhere the user
  /// chooses, that survives uninstalling the app.
  ///
  /// Two ways, and the user picks which in Impostazioni. With a folder set,
  /// the file lands there and the only thing on screen is the confirmation —
  /// which is what you want when you are exporting a stack of documents in a
  /// row. With no folder set, the system save dialog opens and you choose the
  /// place and the name each time.
  ///
  /// The permission on that folder is granted by the user and persisted by
  /// Android, and it can go away: the folder can be deleted, moved, or its
  /// access revoked from the system settings. When the write fails the folder
  /// is forgotten and the dialog takes over, so the export still happens and
  /// the user is told why they were asked.
  static Future<void> export(
    BuildContext context,
    WidgetRef ref,
    ScannedDocument document,
  ) async {
    final strings = ref.read(stringsProvider);
    final store = ref.read(settingsStoreProvider);
    try {
      final file = await withBusy(
        context,
        strings('export_preparing'),
        () => ref.read(documentRepositoryProvider).exportPdf(document),
      );
      final name = '${Fmt.safeFileName(document.title)}.pdf';
      final folder = await store.exportFolder();

      if (folder != null) {
        try {
          await SafStream().writeFileBytes(
            folder.uri,
            name,
            'application/pdf',
            await file.readAsBytes(),
          );
          if (!context.mounted) return;
          showSnack(
            context,
            strings('export_done_in', {'folder': folder.name}),
            icon: Icons.check_circle_outline_rounded,
          );
          return;
        } on Object {
          // The folder is no longer writable. Forget it rather than leaving a
          // setting that fails every time, and fall through to the dialog.
          await store.clearExportFolder();
          ref.invalidate(exportFolderProvider);
        }
      }

      final saved = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          sourceFilePath: file.path,
          fileName: name,
        ),
      );
      if (!context.mounted) return;
      // Null means the user backed out of the dialog, which is not a failure
      // and does not deserve a message.
      if (saved == null) return;
      showSnack(
        context,
        strings('export_done'),
        icon: Icons.check_circle_outline_rounded,
      );
    } on Object {
      if (!context.mounted) return;
      showSnack(
        context,
        strings('export_failed'),
        icon: Icons.error_outline_rounded,
      );
    }
  }

  static Future<void> print(
    BuildContext context,
    WidgetRef ref,
    ScannedDocument document,
  ) async {
    final strings = ref.read(stringsProvider);
    try {
      final file = await withBusy(
        context,
        strings('share_preparing'),
        () => ref.read(documentRepositoryProvider).exportPdf(document),
      );
      if (!context.mounted) return;
      await ref.read(pdfServiceProvider).printDocument(file, document.title);
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
