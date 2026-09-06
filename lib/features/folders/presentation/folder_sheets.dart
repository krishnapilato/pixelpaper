import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/text_prompt.dart';
import '../../../data/models/folder.dart';
import '../application/folders_controller.dart';

/// Create a folder, then open it: making a folder is only ever the first half
/// of an intention.
Future<void> createFolderFlow(
  BuildContext context,
  WidgetRef ref,
  FolderKind kind,
) async {
  final strings = ref.read(stringsProvider);

  final name = await askForText(
    context,
    title: strings('folders_new_title'),
    subtitle: strings('folders_new_body'),
    hint: strings('folders_name_hint'),
    actionLabel: strings('common_save'),
    cancelLabel: strings('common_cancel'),
    icon: Icons.create_new_folder_outlined,
  );
  if (name == null || !context.mounted) return;

  final folder = await ref.read(foldersProvider(kind).notifier).create(name);
  if (!context.mounted) return;

  if (folder == null) {
    showSnack(context, strings('folders_name_taken'),
        icon: Icons.error_outline_rounded);
    return;
  }
  ref.read(currentFolderProvider(kind).notifier).open(folder.id);
}

/// Rename or delete one folder (long-press on its chip).
Future<void> showFolderActions(
  BuildContext context,
  WidgetRef ref,
  Folder folder,
) {
  final strings = ref.read(stringsProvider);

  return showAppSheet<void>(
    context: context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: folder.name,
          subtitle: strings.plural('folders_items', folder.itemCount),
        ),
        SheetAction(
          icon: Icons.drive_file_rename_outline_rounded,
          label: strings('common_rename'),
          onTap: () async {
            Navigator.pop(context);
            final name = await askForText(
              context,
              title: strings('folders_rename_title'),
              hint: strings('folders_name_hint'),
              actionLabel: strings('common_save'),
              cancelLabel: strings('common_cancel'),
              initialValue: folder.name,
            );
            if (name == null || !context.mounted) return;
            final ok = await ref
                .read(foldersProvider(folder.kind).notifier)
                .rename(folder, name);
            if (!context.mounted) return;
            if (!ok) {
              showSnack(context, strings('folders_name_taken'),
                  icon: Icons.error_outline_rounded);
            }
          },
        ),
        SheetAction(
          icon: Icons.folder_delete_outlined,
          label: strings('folders_delete'),
          detail: strings('folders_delete_detail'),
          destructive: true,
          onTap: () async {
            Navigator.pop(context);
            final confirmed = await confirmAction(
              context,
              title: strings('folders_delete_title', {'name': folder.name}),
              message: strings('folders_delete_body'),
              confirmLabel: strings('common_delete'),
              cancelLabel: strings('common_cancel'),
            );
            if (!confirmed || !context.mounted) return;
            await ref
                .read(foldersProvider(folder.kind).notifier)
                .delete(folder);
            if (!context.mounted) return;
            showSnack(context, strings('folders_deleted'),
                icon: Icons.check_rounded);
          },
        ),
        const SheetFooterSpace(),
      ],
    ),
  );
}

/// "Sposta in…" for a selection — the keyboard-and-thumb alternative to
/// dragging, because a precise drag is hard one-handed on a tall phone.
Future<void> showMoveToFolderSheet(
  BuildContext context,
  WidgetRef ref, {
  required FolderKind kind,
  required Set<int> ids,
  required void Function(Set<int> ids, int? folderId) onMove,
}) {
  final strings = ref.read(stringsProvider);
  final folders = ref.read(foldersProvider(kind)).value ?? const <Folder>[];

  return showAppSheet<void>(
    context: context,
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(
            title: strings('folders_move_title'),
            subtitle: strings.plural('folders_move_body', ids.length),
          ),
          SheetAction(
            icon: Icons.inbox_outlined,
            label: strings('folders_move_root'),
            onTap: () {
              Navigator.pop(context);
              onMove(ids, null);
            },
          ),
          for (final folder in folders)
            SheetAction(
              icon: Icons.folder_outlined,
              label: folder.name,
              detail: strings.plural('folders_items', folder.itemCount),
              onTap: () {
                Navigator.pop(context);
                onMove(ids, folder.id);
              },
            ),
          SheetAction(
            icon: Icons.create_new_folder_outlined,
            label: strings('folders_new'),
            onTap: () async {
              Navigator.pop(context);
              final name = await askForText(
                context,
                title: strings('folders_new_title'),
                hint: strings('folders_name_hint'),
                actionLabel: strings('common_save'),
                cancelLabel: strings('common_cancel'),
                icon: Icons.create_new_folder_outlined,
              );
              if (name == null || !context.mounted) return;
              final folder =
                  await ref.read(foldersProvider(kind).notifier).create(name);
              if (folder == null) {
                if (context.mounted) {
                  showSnack(context, strings('folders_name_taken'),
                      icon: Icons.error_outline_rounded);
                }
                return;
              }
              onMove(ids, folder.id);
            },
          ),
          const SheetFooterSpace(),
        ],
      ),
    ),
  );
}
