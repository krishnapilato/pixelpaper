import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/scanned_document.dart';
import 'document_thumbnail.dart';

/// Shared metadata line: "12 pagine · 2,4 MB · Oggi".
String documentSubtitle(Strings strings, ScannedDocument document) {
  final parts = <String>[
    if (document.pageCount > 0) strings.plural('doc_pages', document.pageCount),
    Fmt.bytes(document.sizeBytes),
    Fmt.relativeDay(
      document.updatedAt,
      today: strings('common_today'),
      yesterday: strings('common_yesterday'),
    ),
  ];
  return parts.join(' · ');
}

/// Archive row.
///
/// Tap opens, long-press starts selection, the trailing button opens actions.
/// Long-press is the Android convention for "select"; putting selection behind
/// an explicit mode switch would cost a tap on the common path.
class DocumentTile extends ConsumerWidget {
  const DocumentTile({
    super.key,
    required this.document,
    required this.selected,
    required this.selectionActive,
    required this.onTap,
    this.onLongPress,
    required this.onMore,
  });

  final ScannedDocument document;
  final bool selected;
  final bool selectionActive;
  final VoidCallback onTap;

  /// Left null wherever the tile sits inside a LibraryDraggable: two
  /// long-press recognisers on one pointer cancel the drag.
  final VoidCallback? onLongPress;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strings = ref.watch(stringsProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Material(
        color: selected
            ? scheme.secondaryContainer
            : scheme.surfaceContainerLow,
        borderRadius: Radii.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(Space.sm),
            child: Row(
              children: [
                _Leading(
                  document: document,
                  selected: selected,
                  selectionActive: selectionActive,
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        documentSubtitle(strings, document),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: selectionActive ? null : onMore,
                  icon: const Icon(Icons.more_vert_rounded),
                  tooltip: strings('common_details'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({
    required this.document,
    required this.selected,
    required this.selectionActive,
  });

  final ScannedDocument document;
  final bool selected;
  final bool selectionActive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 52,
      height: 66,
      child: AnimatedSwitcher(
        duration: Motion.quick,
        child: selected
            ? Container(
                key: const ValueKey('check'),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Icon(Icons.check_rounded, color: scheme.onPrimary),
              )
            // No Hero: its counterpart in the reader is gone, and a Hero with
            // nothing to fly to is just a trap for whoever adds one back.
            : DocumentThumbnail(
                key: const ValueKey('thumb'),
                document: document,
                width: 52,
                height: 66,
              ),
      ),
    );
  }
}

/// Archive card for the grid layout: the page itself is the affordance.
class DocumentCard extends ConsumerWidget {
  const DocumentCard({
    super.key,
    required this.document,
    required this.width,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    required this.onMore,
  });

  final ScannedDocument document;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  /// Left null wherever the tile sits inside a LibraryDraggable: two
  /// long-press recognisers on one pointer cancel the drag.
  final VoidCallback? onLongPress;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strings = ref.watch(stringsProvider);

    return Material(
      color: selected ? scheme.secondaryContainer : scheme.surfaceContainerLow,
      borderRadius: Radii.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DocumentThumbnail(
                    document: document,
                    width: width,
                    height: width * 1.3,
                    radius: 0,
                  ),
                  if (selected)
                    ColoredBox(
                      color: scheme.primary.withValues(alpha: 0.28),
                      child: Center(
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: scheme.onPrimary,
                          size: 34,
                        ),
                      ),
                    ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.surface.withValues(alpha: 0.72),
                        minimumSize: const Size(34, 34),
                      ),
                      iconSize: 18,
                      onPressed: onMore,
                      icon: const Icon(Icons.more_vert_rounded),
                      tooltip: strings('common_details'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.sm,
                Space.xs,
                Space.sm,
                Space.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    documentSubtitle(strings, document),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
