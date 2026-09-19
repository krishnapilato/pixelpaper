import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/documents/presentation/documents_screen.dart';
import '../../features/documents/application/documents_controller.dart';
import '../../features/editor/presentation/album_editor_screen.dart';
import '../../features/editor/presentation/document_editor_screen.dart';
import '../../features/gallery/presentation/gallery_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/presentation/home_shell.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/trash/presentation/trash_screen.dart';
import '../../features/tutorial/presentation/tutorial_screen.dart';
import '../../features/viewer/presentation/document_viewer_screen.dart';
import '../theme/dimens.dart';

/// Route names, used instead of raw strings at call sites.
abstract final class Routes {
  static const String splash = '/';
  static const String documents = '/documenti';
  static const String gallery = '/galleria';
  static const String settings = '/impostazioni';
  static const String tutorial = '/guida';
  static const String trash = '/cestino';

  static String viewer(int id) => '/documento/$id';
  static String editor(int id) => '/documento/$id/modifica';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _documentsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'archivio');
final _galleryNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'galleria');

/// go_router 18 decides which `Page` to use by sniffing the app widget, and it
/// now looks for `material_ui`'s MaterialApp. With `flutter/material.dart` every
/// builder-based route silently degrades to no transition at all — so every
/// route here declares its own page and its own motion.
GoRouter createRouter() {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.splash,
    routes: [
      // The opening animation owns the root path: it plays once per launch
      // and replaces itself with the archive, so nothing can navigate back
      // into it.
      GoRoute(
        path: Routes.splash,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: SplashScreen()),
      ),
      // The two tabs are pages of a pager (see HomeShell), so the shell
      // supplies its own container instead of go_router's IndexedStack. It
      // arrives from the splash with a fade through: a top-level change.
      StatefulShellRoute(
        pageBuilder: (context, state, navigationShell) =>
            CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: Motion.slow,
          child: navigationShell,
          transitionsBuilder: (context, animation, secondary, child) =>
              FadeThroughTransition(
            animation: animation,
            secondaryAnimation: secondary,
            fillColor: Theme.of(context).colorScheme.surface,
            child: child,
          ),
        ),
        navigatorContainerBuilder: (context, navigationShell, children) =>
            HomeShell(navigationShell: navigationShell, children: children),
        branches: [
          StatefulShellBranch(
            navigatorKey: _documentsNavigatorKey,
            observers: [ShellModalObserver()],
            routes: [
              GoRoute(
                path: Routes.documents,
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: DocumentsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _galleryNavigatorKey,
            observers: [ShellModalObserver()],
            routes: [
              GoRoute(
                path: Routes.gallery,
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: GalleryScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/documento/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadeThrough(
          state,
          DocumentViewerScreen(documentId: _idOf(state)),
        ),
        routes: [
          GoRoute(
            path: 'modifica',
            parentNavigatorKey: _rootNavigatorKey,
            // Two editors, picked by what the document is made of. An album
            // arranges page images and never rewrites a file; a PDF still has
            // to be redrawn, so it keeps the older, heavier screen.
            pageBuilder: (context, state) =>
                _fadeThrough(state, _EditorForDocument(id: _idOf(state))),
          ),
        ],
      ),
      GoRoute(
        path: Routes.settings,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _slideUp(state, const SettingsScreen()),
      ),
      GoRoute(
        path: Routes.trash,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideUp(state, const TrashScreen()),
      ),
      GoRoute(
        path: Routes.tutorial,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _slideUp(state, const TutorialScreen()),
      ),
    ],
  );
}

int _idOf(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '') ?? -1;

/// Forward navigation (archive → document → editor): Material's shared axis
/// on Z. The page grows in from slightly behind while the one it replaces
/// recedes, and the Hero'd thumbnail flies on top, so the eye follows the
/// document rather than a sliding panel.
CustomTransitionPage<void> _fadeThrough(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: Motion.transition,
    reverseTransitionDuration: Motion.transition,
    child: child,
    transitionsBuilder: (context, animation, secondary, child) =>
        SharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondary,
      transitionType: SharedAxisTransitionType.scaled,
      fillColor: Theme.of(context).colorScheme.surface,
      child: child,
    ),
  );
}

/// Temporary surfaces (settings, guide, bin) rise from below on Material's
/// vertical shared axis: the gesture to dismiss them is "push it back down",
/// which matches the motion.
CustomTransitionPage<void> _slideUp(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: Motion.transition,
    reverseTransitionDuration: Motion.transition,
    child: child,
    transitionsBuilder: (context, animation, secondary, child) =>
        SharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondary,
      transitionType: SharedAxisTransitionType.vertical,
      fillColor: Theme.of(context).colorScheme.surface,
      child: child,
    ),
  );
}

/// Sends the route to the editor that matches the document.
///
/// The choice lives here rather than inside one of the editors so neither has
/// to know the other exists, and so a document whose kind is not known yet
/// shows a spinner instead of the wrong screen.
class _EditorForDocument extends ConsumerWidget {
  const _EditorForDocument({required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final document = ref.watch(documentByIdProvider(id));
    if (document == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return document.isAlbum
        ? AlbumEditorScreen(documentId: id)
        : DocumentEditorScreen(documentId: id);
  }
}
