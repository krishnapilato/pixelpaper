import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/dimens.dart';
import '../../../data/models/folder.dart';
import '../../documents/application/documents_controller.dart';
import '../../folders/application/drag_state.dart';
import '../../gallery/application/gallery_controller.dart';
import '../../scanner/application/scan_flow.dart';
import '../../trash/presentation/trash_feedback.dart';

/// Two destinations and one action button.
///
/// The button's meaning follows the destination — Archivio creates a document
/// (scan), Galleria adds a photo (camera). One always-visible primary action
/// beats a menu of two.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final index = navigationShell.currentIndex;
    final drag = ref.watch(activeDragProvider);

    final selecting = index == 0
        ? ref.watch(documentSelectionProvider).isNotEmpty
        : ref.watch(gallerySelectionProvider).isNotEmpty;

    // While items are selected the screen shows a contextual bar of its own,
    // and during a drag the bottom of the screen becomes the bin: in both
    // cases a create button under the thumb would be the wrong target.
    final hideFab = selecting || drag != null;

    return Scaffold(
      body: navigationShell,
      floatingActionButton: AnimatedScale(
        duration: Motion.base,
        curve: Motion.emphasized,
        scale: hideFab ? 0 : 1,
        child: FloatingActionButton(
          // No label: the two icons are unambiguous, and a bare circle keeps
          // the thumb zone clear of the content behind it.
          heroTag: 'primary-action',
          tooltip: index == 0 ? strings('action_scan') : strings('camera_title'),
          onPressed: () {
            if (index == 0) {
              ScanFlow.start(context, ref);
            } else {
              context.push(Routes.camera);
            }
          },
          child: AnimatedSwitcher(
            duration: Motion.quick,
            child: Icon(
              index == 0
                  ? Icons.document_scanner_outlined
                  : Icons.photo_camera_outlined,
              key: ValueKey(index),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AnimatedSwitcher(
        duration: Motion.quick,
        switchInCurve: Motion.enter,
        child: drag != null
            ? _TrashDropZone(payload: drag)
            : NavigationBar(
                key: const ValueKey('nav'),
                selectedIndex: index,
                onDestinationSelected: (next) => navigationShell.goBranch(
                  next,
                  // Tapping the active tab again returns it to its root, which
                  // is what every Android user expects from a bottom bar.
                  initialLocation: next == index,
                ),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.folder_outlined),
                    selectedIcon: const Icon(Icons.folder_rounded),
                    label: strings('tab_documents'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.photo_library_outlined),
                    selectedIcon: const Icon(Icons.photo_library_rounded),
                    label: strings('tab_gallery'),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Appears in place of the navigation bar while something is being dragged.
///
/// Putting the bin where the user's thumb already is turns "delete" into a
/// flick, and it can only be hit deliberately because it exists only during
/// a drag.
class _TrashDropZone extends ConsumerWidget {
  const _TrashDropZone({required this.payload});

  final LibraryDragPayload payload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final scheme = Theme.of(context).colorScheme;

    return DragTarget<LibraryDragPayload>(
      key: const ValueKey('trash-zone'),
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) async {
        HapticFeedback.heavyImpact();
        await _trash(context, ref, details.data);
      },
      builder: (context, candidates, rejected) {
        final hovered = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: Motion.quick,
          height: 76 + MediaQuery.paddingOf(context).bottom,
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
          color: hovered ? scheme.errorContainer : scheme.surfaceContainerHigh,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                duration: Motion.quick,
                scale: hovered ? 1.25 : 1,
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: hovered
                      ? scheme.onErrorContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: Space.sm),
              Text(
                strings('trash_drop_here'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: hovered
                          ? scheme.onErrorContainer
                          : scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _trash(
    BuildContext context,
    WidgetRef ref,
    LibraryDragPayload payload,
  ) async {
    switch (payload.kind) {
      case FolderKind.document:
        final documents = (ref.read(documentsControllerProvider).value ??
                const [])
            .where((d) => payload.ids.contains(d.id))
            .toList(growable: false);
        await ref
            .read(documentsControllerProvider.notifier)
            .moveToTrash(documents);
      case FolderKind.capture:
        final captures = (ref.read(galleryControllerProvider).value ?? const [])
            .where((c) => payload.ids.contains(c.id))
            .toList(growable: false);
        await ref.read(galleryControllerProvider.notifier).moveToTrash(captures);
    }

    if (!context.mounted) return;
    showTrashedSnack(context, ref, kind: payload.kind, ids: payload.ids);
  }

}
