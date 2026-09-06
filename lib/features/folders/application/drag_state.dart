import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/folder.dart';

/// What is being dragged: one or more library items of a single kind.
///
/// Dragging always carries the whole selection, so picking three scans and
/// dragging any one of them moves all three — the behaviour every file
/// manager has trained people to expect.
@immutable
class LibraryDragPayload {
  const LibraryDragPayload({required this.kind, required this.ids});

  final FolderKind kind;
  final Set<int> ids;

  int get length => ids.length;
}

/// True while a drag is in flight, so the shell can swap the navigation bar
/// for a drop zone. Kept in a provider rather than passed down: the bar and
/// the dragged tile live in different subtrees.
class DragActivityController extends Notifier<LibraryDragPayload?> {
  @override
  LibraryDragPayload? build() => null;

  void start(LibraryDragPayload payload) => state = payload;
  void end() => state = null;
}

final activeDragProvider =
    NotifierProvider<DragActivityController, LibraryDragPayload?>(
  DragActivityController.new,
);
