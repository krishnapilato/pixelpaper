import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../data/models/folder.dart';
import '../../../data/providers.dart';
import '../application/trash_controller.dart';

/// Confirmation for a move to the bin, with one-tap undo.
///
/// Deleting to a bin is reversible, so it does not get a modal question first:
/// interrupting the common case to ask about the rare one is the thing that
/// makes an app feel slow. The undo lives right where the eye already is.
void showTrashedSnack(
  BuildContext context,
  WidgetRef ref, {
  required FolderKind kind,
  required Set<int> ids,
}) {
  final strings = ref.read(stringsProvider);

  // The snack outlives the widget that showed it: deleting from the reader
  // pops that screen immediately, and a WidgetRef read after disposal throws,
  // which used to swallow the undo. The container lives as long as the app.
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(strings('trash_moved')),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: strings('trash_undo'),
          onPressed: () async {
            await restoreFromTrash(container, kind: kind, ids: ids);
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(strings('trash_restored')),
                  duration: const Duration(milliseconds: 2400),
                ),
              );
          },
        ),
      ),
    );
}

/// Pulls a set of ids back out of the bin.
Future<void> restoreFromTrash(
  ProviderContainer container, {
  required FolderKind kind,
  required Set<int> ids,
}) async {
  final trashed = await container.read(libraryRepositoryProvider).trash();
  final controller = container.read(trashControllerProvider.notifier);

  switch (kind) {
    case FolderKind.document:
      await controller.restore(
        documents: trashed.documents
            .where((d) => ids.contains(d.id))
            .toList(growable: false),
      );
    case FolderKind.capture:
      await controller.restore(
        captures: trashed.captures
            .where((c) => ids.contains(c.id))
            .toList(growable: false),
      );
  }
}
