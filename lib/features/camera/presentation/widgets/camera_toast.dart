import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/dimens.dart';

/// What a message on the viewfinder is about.
enum CameraToastKind { success, failure, info }

/// One confirmation on the viewfinder.
@immutable
class CameraToastMessage {
  const CameraToastMessage(this.text, {required this.kind, required this.id});

  final String text;
  final CameraToastKind kind;

  /// Distinguishes two identical texts, so a second "saved" replays the
  /// entrance instead of looking like nothing happened.
  final int id;
}

/// Drives [CameraToast]: shows a message for a moment, then clears it.
class CameraToastController extends ChangeNotifier {
  CameraToastMessage? _current;
  Timer? _timer;
  int _count = 0;

  CameraToastMessage? get current => _current;

  static const Duration visibleFor = Duration(milliseconds: 1800);

  void show(String text, {required CameraToastKind kind}) {
    _timer?.cancel();
    _current = CameraToastMessage(text, kind: kind, id: _count++);
    notifyListeners();
    _timer = Timer(visibleFor, () {
      _current = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// The confirmation after a shot, over the top of the viewfinder.
///
/// A toast instead of a snack bar: the bottom of the screen belongs to the
/// shutter, and a message that pushed the controls up after every shot would
/// move the target under the thumb.
class CameraToast extends StatelessWidget {
  const CameraToast({super.key, required this.controller});

  final CameraToastController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final message = controller.current;
        return AnimatedSwitcher(
          duration: Motion.base,
          reverseDuration: Motion.quick,
          switchInCurve: Motion.enter,
          switchOutCurve: Motion.exit,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.4),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: message == null
              ? const SizedBox.shrink()
              : Center(
                  key: ValueKey(message.id),
                  child: _Pill(message: message),
                ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.message});

  final CameraToastMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      liveRegion: true,
      child: Material(
        color: scheme.inverseSurface,
        shape: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.sm - 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                switch (message.kind) {
                  CameraToastKind.success => Icons.check_circle_rounded,
                  CameraToastKind.failure => Icons.error_rounded,
                  CameraToastKind.info => Icons.info_rounded,
                },
                size: 18,
                color: switch (message.kind) {
                  CameraToastKind.failure => scheme.error,
                  _ => scheme.inversePrimary,
                },
              ),
              const SizedBox(width: Space.xs),
              Flexible(
                child: Text(
                  message.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onInverseSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
