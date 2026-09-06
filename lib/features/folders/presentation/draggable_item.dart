import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/selection_controller.dart';
import '../../../core/theme/dimens.dart';
import '../../../data/models/folder.dart';
import '../application/drag_state.dart';

/// Makes a library tile draggable onto a folder chip or the bin.
///
/// One gesture, two outcomes, matching Files and Photos: a long press marks
/// the item and arms the drag. Lift without moving and you are simply in
/// selection mode; keep moving and you are carrying everything selected.
///
/// The child must NOT handle `onLongPress` itself. Two long-press recognisers
/// on the same pointer both claim the arena at 500 ms and the innermost one
/// wins, so a tile that keeps its own handler swallows the gesture and nothing
/// can ever be dragged. Selection is therefore done here, in [onDragStarted].
class LibraryDraggable extends ConsumerWidget {
  const LibraryDraggable({
    super.key,
    required this.kind,
    required this.id,
    required this.selectionProvider,
    required this.child,
    required this.preview,
  });

  final FolderKind kind;
  final int id;
  final NotifierProvider<SelectionController, Set<int>> selectionProvider;
  final Widget child;

  /// A small representation of the item that follows the finger.
  final Widget preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LongPressDraggable<LibraryDragPayload>(
      // The payload is resolved at drag start, so it always reflects the
      // selection as it is at that moment.
      data: LibraryDragPayload(kind: kind, ids: _resolveSelection(ref)),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: () {
        HapticFeedback.selectionClick();
        final selection = ref.read(selectionProvider);
        if (!selection.contains(id)) {
          ref.read(selectionProvider.notifier).toggle(id);
        }
        ref
            .read(activeDragProvider.notifier)
            .start(LibraryDragPayload(kind: kind, ids: _resolveSelection(ref)));
      },
      onDragEnd: (_) => ref.read(activeDragProvider.notifier).end(),
      onDraggableCanceled: (velocity, offset) =>
          ref.read(activeDragProvider.notifier).end(),
      feedback: _DragFeedback(
        preview: preview,
        count: _resolveSelection(ref).length,
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: child),
      child: child,
    );
  }

  Set<int> _resolveSelection(WidgetRef ref) {
    final selection = ref.read(selectionProvider);
    return selection.contains(id) ? selection : {id, ...selection};
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.preview, required this.count});

  final Widget preview;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Transform.translate(
      // Sits above the fingertip so the drop target stays visible.
      offset: const Offset(-38, -46),
      child: Material(
        color: Colors.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 76,
              height: 92,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(Radii.sm),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: preview,
            ),
            if (count > 1)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(Radii.full),
                  ),
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
