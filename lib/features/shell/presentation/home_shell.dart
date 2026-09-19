import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/widgets/feedback.dart';
import '../../../data/models/folder.dart';
import '../../camera/presentation/camera_screen.dart';
import '../../documents/application/documents_controller.dart';
import '../../folders/application/drag_state.dart';
import '../../gallery/application/capture_flow.dart';
import '../../gallery/application/gallery_controller.dart';
import '../../scanner/application/scan_flow.dart';
import '../../trash/presentation/trash_feedback.dart';
import 'primary_action_button.dart';

/// How many modal routes (bottom sheets, dialogs pushed inside a tab) are
/// open in the tabs' own navigators.
///
/// Those sit under the shell's action button, which belongs to the scaffold
/// around both tabs: without this the button floated on top of a document's
/// menu. The button steps aside while one is up.
final ValueNotifier<int> _openModals = ValueNotifier<int>(0);

/// Counts [PopupRoute]s on one tab navigator into [_openModals]. One instance
/// per navigator: an observer can only be attached to one at a time.
class ShellModalObserver extends NavigatorObserver {
  void _change(Route<dynamic>? added, Route<dynamic>? removed) {
    var open = _openModals.value;
    if (added is PopupRoute) open++;
    if (removed is PopupRoute) open--;
    _openModals.value = open < 0 ? 0 : open;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, null);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(null, route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(null, route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _change(newRoute, oldRoute);
}

/// Two destinations side by side, and one action button.
///
/// The destinations are pages of a pager, so moving between them is a swipe
/// as well as a tap on the bar — the lateral navigation Android users expect
/// between peers. The button follows the finger: its icon turns from scan to
/// camera as the Galleria slides in, and it acts for the page it lands on.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({
    super.key,
    required this.navigationShell,
    required this.children,
  });

  final StatefulNavigationShell navigationShell;

  /// One navigator per branch, from go_router.
  final List<Widget> children;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  late final PageController _pager = PageController(
    initialPage: widget.navigationShell.currentIndex,
  );

  /// The pager's position as an animation, for the button: 0 Archivio, 1
  /// Galleria, fractional in between.
  late final _PagePosition _page = _PagePosition(
    _pager,
    widget.navigationShell.currentIndex.toDouble(),
  );

  bool _holding = false;

  @override
  void didUpdateWidget(HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A branch change that did not come from a swipe — the bar, a
    // context.go() elsewhere: slide the pager there, so both always agree.
    final index = widget.navigationShell.currentIndex;
    if (_pager.hasClients && _pager.page?.round() != index) {
      _pager.animateToPage(
        index,
        duration: Motion.slow,
        curve: Motion.emphasized,
      );
    }
  }

  @override
  void dispose() {
    _page.dispose();
    _pager.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (index == widget.navigationShell.currentIndex) return;
    HapticFeedback.selectionClick();
    widget.navigationShell.goBranch(index);
  }

  void _onDestinationSelected(int next) {
    final index = widget.navigationShell.currentIndex;
    widget.navigationShell.goBranch(
      next,
      // Tapping the active tab again returns it to its root, which is what
      // every Android user expects from a bottom bar.
      initialLocation: next == index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final index = widget.navigationShell.currentIndex;
    final drag = ref.watch(activeDragProvider);
    final scheme = Theme.of(context).colorScheme;

    final selecting = index == 0
        ? ref.watch(documentSelectionProvider.select((s) => s.isNotEmpty))
        : ref.watch(gallerySelectionProvider.select((s) => s.isNotEmpty));

    // While items are selected the screen shows a contextual bar of its own,
    // and during a drag the bottom of the screen becomes the bin: in both
    // cases a create button under the thumb — or a swipe that carries the
    // selection off screen — would be the wrong thing.
    final busy = selecting || drag != null;

    return Scaffold(
      body: PageView(
        controller: _pager,
        onPageChanged: _onPageChanged,
        physics: busy
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        children: [
          for (final child in widget.children) _KeepAlive(child: child),
        ],
      ),
      floatingActionButton: ValueListenableBuilder<int>(
        valueListenable: _openModals,
        builder: (context, modals, child) => AnimatedScale(
          duration: Motion.base,
          curve: Motion.emphasized,
          scale: busy || modals > 0 ? 0 : 1,
          child: child,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HoldHint(visible: _holding, text: strings('action_import_holding')),
            OpenContainer<void>(
              // Material's container transform: the button grows into the
              // camera and the camera shrinks back into it.
              useRootNavigator: true,
              tappable: false,
              transitionDuration: Motion.expand,
              transitionType: ContainerTransitionType.fadeThrough,
              closedElevation: 0,
              openElevation: 0,
              closedColor: scheme.primaryContainer,
              middleColor: Colors.black,
              openColor: Colors.black,
              closedShape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(Radii.md)),
              ),
              openBuilder: (context, _) => const CameraScreen(),
              closedBuilder: (context, openCamera) => PrimaryActionButton(
                page: _page,
                scanLabel: strings('action_scan'),
                cameraLabel: strings('camera_title'),
                importLabel: strings('camera_import'),
                holdHint: strings('action_import_hint'),
                onScan: () => ScanFlow.start(context, ref),
                onCamera: openCamera,
                onImport: () => CaptureFlow.importPhotos(context, ref),
                onHoldReleasedEarly: () => showSnack(
                  context,
                  strings('action_import_hold'),
                  icon: Icons.touch_app_outlined,
                ),
                onHoldChanged: (holding) => setState(() => _holding = holding),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedSwitcher(
        duration: Motion.base,
        switchInCurve: Motion.enter,
        switchOutCurve: Motion.exit,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
        child: drag != null
            ? _TrashDropZone(payload: drag)
            : NavigationBar(
                key: const ValueKey('nav'),
                selectedIndex: index,
                onDestinationSelected: _onDestinationSelected,
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

/// Exposes a [PageController]'s position as an [Animation], starting from
/// [initial] until the pager is laid out.
class _PagePosition extends Animation<double>
    with AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin {
  _PagePosition(this._controller, this._initial) {
    _controller.addListener(notifyListeners);
  }

  final PageController _controller;
  final double _initial;

  @override
  double get value {
    if (!_controller.hasClients ||
        !_controller.position.hasContentDimensions) {
      return _initial;
    }
    return _controller.page ?? _initial;
  }

  @override
  AnimationStatus get status => AnimationStatus.forward;

  @override
  void didRegisterListener() {}

  @override
  void didUnregisterListener() {}

  void dispose() => _controller.removeListener(notifyListeners);
}

/// Keeps a branch alive while it is off screen: each branch is a navigator
/// with its own stack, scroll position and selection, and rebuilding it on
/// every swipe would lose all three.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
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
          curve: Motion.standard,
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
                curve: Motion.standard,
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
