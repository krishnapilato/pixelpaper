import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/feedback.dart';
import '../../../data/models/capture.dart';
import '../../../data/models/scanned_document.dart';
import '../../../data/repositories/library_repository.dart';
import '../application/trash_controller.dart';

/// The bin.
///
/// Restoring is one tap; erasing asks first and says plainly that the file
/// leaves the device — the two outcomes are not symmetric and the UI should
/// not pretend they are.
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final trash = ref.watch(trashControllerProvider);
    final contents = trash.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings('trash_title')),
        actions: [
          if (contents != null && !contents.isEmpty)
            TextButton.icon(
              onPressed: () => _emptyAll(context, ref),
              icon: const Icon(Icons.delete_sweep_outlined),
              label: Text(strings('trash_empty_action')),
            ),
          const SizedBox(width: Space.xs),
        ],
      ),
      body: switch (trash) {
        AsyncData(:final value) when value.isEmpty => EmptyState(
            icon: Icons.delete_outline_rounded,
            title: strings('trash_empty_title'),
            body: strings('trash_empty_body'),
          ),
        AsyncData(:final value) => ListView(
            padding: EdgeInsets.fromLTRB(
              Space.md,
              Space.xs,
              Space.md,
              MediaQuery.paddingOf(context).bottom + Space.xl,
            ),
            children: [
              _Notice(text: strings('trash_empty_body')),
              if (value.documents.isNotEmpty) ...[
                _SectionLabel(label: strings('trash_section_documents')),
                for (final document in value.documents)
                  _TrashRow(
                    key: ValueKey('doc-${document.id}'),
                    icon: Icons.picture_as_pdf_outlined,
                    title: document.title,
                    subtitle: _subtitle(
                      strings,
                      document.deletedAt,
                      Fmt.bytes(document.sizeBytes),
                    ),
                    restoreLabel: strings('trash_restore'),
                    deleteLabel: strings('trash_delete_forever'),
                    onRestore: () => _restore(context, ref, documents: [document]),
                    onDelete: () => _purge(context, ref, documents: [document]),
                  ),
              ],
              if (value.captures.isNotEmpty) ...[
                _SectionLabel(label: strings('trash_section_images')),
                for (final capture in value.captures)
                  _TrashRow(
                    key: ValueKey('img-${capture.id}'),
                    icon: Icons.image_outlined,
                    title: Fmt.stem(capture.path),
                    subtitle: _subtitle(
                      strings,
                      capture.deletedAt,
                      Fmt.bytes(capture.sizeBytes),
                    ),
                    restoreLabel: strings('trash_restore'),
                    deleteLabel: strings('trash_delete_forever'),
                    onRestore: () => _restore(context, ref, captures: [capture]),
                    onDelete: () => _purge(context, ref, captures: [capture]),
                  ),
              ],
            ],
          ),
        AsyncError() => EmptyState(
            icon: Icons.error_outline_rounded,
            title: strings('common_error'),
            body: strings('trash_empty_body'),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  String _subtitle(Strings strings, DateTime? deletedAt, String size) {
    if (deletedAt == null) return size;
    final left = LibraryRepository.retention.inDays -
        DateTime.now().difference(deletedAt).inDays;
    return '$size · ${strings.plural('trash_days_left', left.clamp(0, 30))}';
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref, {
    List<ScannedDocument> documents = const [],
    List<Capture> captures = const [],
  }) async {
    final strings = ref.read(stringsProvider);
    await ref
        .read(trashControllerProvider.notifier)
        .restore(documents: documents, captures: captures);
    if (!context.mounted) return;
    showSnack(context, strings('trash_restored'), icon: Icons.undo_rounded);
  }

  Future<void> _purge(
    BuildContext context,
    WidgetRef ref, {
    List<ScannedDocument> documents = const [],
    List<Capture> captures = const [],
  }) async {
    final strings = ref.read(stringsProvider);
    final confirmed = await confirmAction(
      context,
      title: strings('trash_delete_forever_title'),
      message: strings('trash_delete_forever_body'),
      confirmLabel: strings('trash_delete_forever'),
      cancelLabel: strings('common_cancel'),
    );
    if (!confirmed || !context.mounted) return;

    await ref
        .read(trashControllerProvider.notifier)
        .purge(documents: documents, captures: captures);
    if (!context.mounted) return;
    showSnack(context, strings('trash_deleted_forever'),
        icon: Icons.delete_forever_outlined);
  }

  Future<void> _emptyAll(BuildContext context, WidgetRef ref) async {
    final strings = ref.read(stringsProvider);
    final confirmed = await confirmAction(
      context,
      title: strings('trash_empty_confirm_title'),
      message: strings('trash_empty_confirm_body'),
      confirmLabel: strings('trash_empty_action'),
      cancelLabel: strings('common_cancel'),
    );
    if (!confirmed || !context.mounted) return;

    await ref.read(trashControllerProvider.notifier).emptyAll();
    if (!context.mounted) return;
    showSnack(context, strings('trash_emptied'),
        icon: Icons.delete_sweep_outlined);
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Card(
        color: scheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Row(
            children: [
              Icon(Icons.schedule_rounded,
                  size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(text, style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xs, Space.lg, Space.xs, Space.xs),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _TrashRow extends StatelessWidget {
  const _TrashRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.restoreLabel,
    required this.deleteLabel,
    required this.onRestore,
    required this.onDelete,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String restoreLabel;
  final String deleteLabel;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(subtitle),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onRestore,
                icon: const Icon(Icons.restore_rounded),
                tooltip: restoreLabel,
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_forever_outlined, color: scheme.error),
                tooltip: deleteLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
