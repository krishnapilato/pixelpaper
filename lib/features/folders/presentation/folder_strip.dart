import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/dimens.dart';
import '../../../data/models/folder.dart';
import '../application/drag_state.dart';
import '../application/folders_controller.dart';
import 'folder_sheets.dart';

/// The folder rail: "Tutti", one chip per folder, and a create button.
///
/// Chips rather than a folder grid, for three reasons: the content stays on
/// screen, the targets are always visible while dragging, and a scanner
/// archive is a short list of contexts ("Fatture", "Università"), not a tree.
class FolderStrip extends ConsumerWidget {
  const FolderStrip({super.key, required this.kind, required this.onMove});

  final FolderKind kind;

  /// Called when items are dropped on a folder (null = back to the root).
  final void Function(Set<int> ids, int? folderId) onMove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final folders = ref.watch(foldersProvider(kind)).value ?? const <Folder>[];
    final current = ref.watch(currentFolderProvider(kind));

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
        children: [
          // With no folders yet the rail is a single quiet invitation — an
          // "Tutti" chip that filters nothing would just be furniture.
          if (folders.isNotEmpty)
            _FolderChip(
              label: strings('folders_all'),
              icon: Icons.inbox_outlined,
              selected: current == null,
              onTap: () =>
                  ref.read(currentFolderProvider(kind).notifier).clear(),
              onAccept: (payload) => onMove(payload.ids, null),
              accepts: (payload) => payload.kind == kind,
            ),
          for (final folder in folders)
            _FolderChip(
              label: folder.name,
              icon: Icons.folder_outlined,
              count: folder.itemCount,
              selected: current == folder.id,
              onTap: () => ref
                  .read(currentFolderProvider(kind).notifier)
                  .open(folder.id),
              onLongPress: () => showFolderActions(context, ref, folder),
              onAccept: (payload) => onMove(payload.ids, folder.id),
              accepts: (payload) => payload.kind == kind,
            ),
          _FolderChip(
            label: strings('folders_new'),
            icon: Icons.create_new_folder_outlined,
            dashed: true,
            onTap: () => createFolderFlow(context, ref, kind),
          ),
        ],
      ),
    );
  }
}

class _FolderChip extends ConsumerWidget {
  const _FolderChip({
    required this.label,
    required this.icon,
    this.count,
    this.selected = false,
    this.dashed = false,
    this.onTap,
    this.onLongPress,
    this.onAccept,
    this.accepts,
  });

  final String label;
  final IconData icon;
  final int? count;
  final bool selected;
  final bool dashed;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(LibraryDragPayload payload)? onAccept;
  final bool Function(LibraryDragPayload payload)? accepts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DragTarget<LibraryDragPayload>(
      onWillAcceptWithDetails: (details) =>
          onAccept != null && (accepts?.call(details.data) ?? false),
      onAcceptWithDetails: (details) {
        // A confirmation you feel, before the list even redraws.
        HapticFeedback.mediumImpact();
        onAccept!(details.data);
      },
      builder: (context, candidates, rejected) {
        final hovered = candidates.isNotEmpty;
        final background = hovered
            ? scheme.primary
            : selected
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHigh;
        final foreground = hovered
            ? scheme.onPrimary
            : selected
            ? scheme.onSecondaryContainer
            : scheme.onSurfaceVariant;

        return Padding(
          padding: const EdgeInsets.only(right: Space.xs),
          child: Material(
            color: dashed ? Colors.transparent : background,
            shape: StadiumBorder(
              side: dashed
                  ? BorderSide(color: scheme.outlineVariant)
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              child: AnimatedContainer(
                duration: Motion.quick,
                curve: Motion.enter,
                padding: EdgeInsets.symmetric(
                  horizontal: hovered ? Space.lg : Space.md,
                  vertical: Space.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: dashed ? scheme.onSurfaceVariant : foreground,
                    ),
                    const SizedBox(width: Space.xs),
                    Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: dashed ? scheme.onSurfaceVariant : foreground,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    if (count != null && count! > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '$count',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: foreground.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The folder rail as a pinned sliver.
///
/// Folders are a filter, and a filter you cannot see while you scroll is a
/// filter you forget you turned on — so the rail stays under the app bar
/// instead of scrolling away with the first row. It doubles as a drop target:
/// dragging a document to a folder no longer means scrolling back to the top.
class PinnedFolderStrip extends StatelessWidget {
  const PinnedFolderStrip({
    super.key,
    required this.kind,
    required this.onMove,
  });

  final FolderKind kind;
  final void Function(Set<int> ids, int? folderId) onMove;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _FolderStripHeader(kind: kind, onMove: onMove),
    );
  }
}

class _FolderStripHeader extends SliverPersistentHeaderDelegate {
  const _FolderStripHeader({required this.kind, required this.onMove});

  final FolderKind kind;
  final void Function(Set<int> ids, int? folderId) onMove;

  /// 44 for the chips, plus air above and below.
  static const double _height = 44 + Space.sm;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      // A tonal step instead of a shadow once content runs underneath: the
      // rail reads as the layer above without darkening anything.
      color: overlaps ? scheme.surfaceContainer : scheme.surface,
      child: Column(
        children: [
          const SizedBox(height: Space.xxs),
          FolderStrip(kind: kind, onMove: onMove),
          const Spacer(),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_FolderStripHeader oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.onMove != onMove;
}
