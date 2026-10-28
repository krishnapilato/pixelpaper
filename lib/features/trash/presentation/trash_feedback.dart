import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/widgets/feedback.dart';
import '../../../data/models/folder.dart';
import '../application/trash_controller.dart';

/// Confirms a move to the bin and offers a one-tap undo. The container is
/// captured up front: the snack outlives the screen that showed it.
void showTrashedSnack(
  BuildContext context,
  WidgetRef ref, {
  required FolderKind kind,
  required Set<int> ids,
}) {
  final strings = ref.read(stringsProvider);
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
            final trash = container.read(trashControllerProvider.notifier);
            await switch (kind) {
              FolderKind.document => trash.undoTrash(documentIds: ids),
              FolderKind.capture => trash.undoTrash(captureIds: ids),
            };
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(strings('trash_restored')),
                  duration: snackDuration,
                ),
              );
          },
        ),
      ),
    );
}
