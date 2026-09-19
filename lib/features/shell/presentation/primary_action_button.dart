import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/dimens.dart';

/// The shell's one action button: scan in the Archivio, camera in the
/// Galleria — and, held for [holdDuration] in the Galleria, import.
///
/// A short press is the everyday action, so it must stay instant; importing
/// is the occasional one, so it sits behind a deliberate two-second hold that
/// fills the button from the bottom while it counts, ticks in the hand at
/// each second and can be abandoned by letting go early. Nothing is imported
/// by accident, and nobody has to wait long on purpose.
class PrimaryActionButton extends StatefulWidget {
  const PrimaryActionButton({
    super.key,
    required this.page,
    required this.scanLabel,
    required this.cameraLabel,
    required this.importLabel,
    required this.holdHint,
    required this.onScan,
    required this.onCamera,
    required this.onImport,
    required this.onHoldReleasedEarly,
    required this.onHoldChanged,
  });

  /// Position of the shell's pager: 0 is the Archivio, 1 the Galleria, and
  /// everything in between while the user swipes.
  final Animation<double> page;

  final String scanLabel;
  final String cameraLabel;
  final String importLabel;

  /// Read by screen readers: how to reach import without holding.
  final String holdHint;

  final VoidCallback onScan;
  final VoidCallback onCamera;
  final VoidCallback onImport;

  /// The hold started but was released before it completed.
  final VoidCallback onHoldReleasedEarly;

  /// True while a hold is under way, so the shell can show what it will do.
  final ValueChanged<bool> onHoldChanged;

  static const Duration holdDuration = Duration(seconds: 2);

  @override
  State<PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<PrimaryActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: PrimaryActionButton.holdDuration,
    reverseDuration: Motion.base,
  )..addListener(_onHoldTick);

  bool _fired = false;
  bool _holding = false;
  int _ticks = 0;

  bool get _inGallery => widget.page.value >= 0.5;

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _onHoldTick() {
    // A light tick at each whole second: a count you can feel without
    // looking, ending in a firm one when the import opens.
    final seconds = PrimaryActionButton.holdDuration.inSeconds;
    final second = (_hold.value * seconds).floor();
    if (_hold.status == AnimationStatus.forward &&
        second > _ticks &&
        second < seconds) {
      _ticks = second;
      HapticFeedback.selectionClick();
    }
    final holding = _hold.status == AnimationStatus.forward &&
        _hold.lastElapsedDuration != null &&
        _hold.lastElapsedDuration! >= kLongPressTimeout;
    if (holding != _holding) {
      setState(() => _holding = holding);
      widget.onHoldChanged(holding);
    }
    if (_hold.isCompleted && !_fired) {
      _fired = true;
      HapticFeedback.heavyImpact();
      _hold.reverse();
      widget.onImport();
    }
  }

  void _down(TapDownDetails _) {
    _fired = false;
    _ticks = 0;
    if (_inGallery) _hold.forward(from: 0);
  }

  void _up(TapUpDetails _) {
    if (!_inGallery) {
      widget.onScan();
      return;
    }
    if (_fired) return; // Import already opened at the end of the hold.
    // Measured on the hold's own clock, the one the fill is drawn with, so
    // what the finger saw and what happens can never disagree.
    final held = _hold.lastElapsedDuration ?? Duration.zero;
    _hold.reverse();
    if (held < kLongPressTimeout) {
      widget.onCamera();
    } else {
      widget.onHoldReleasedEarly();
    }
  }

  void _cancel() {
    if (!_fired) _hold.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: widget.page,
      builder: (context, _) {
        final t = widget.page.value.clamp(0.0, 1.0);
        final gallery = t >= 0.5;
        return Semantics(
          button: true,
          label: gallery ? widget.cameraLabel : widget.scanLabel,
          hint: gallery ? widget.holdHint : null,
          onTap: gallery ? widget.onCamera : widget.onScan,
          onLongPress: gallery ? widget.onImport : null,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _down,
            onTapUp: _up,
            onTapCancel: _cancel,
            child: SizedBox.square(
              dimension: 56,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The hold, rising from the bottom like a level.
                  AnimatedBuilder(
                    animation: _hold,
                    builder: (context, _) => Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: Motion.standard.transform(_hold.value),
                        widthFactor: 1,
                        child: ColoredBox(
                          color: scheme.onPrimaryContainer.withValues(
                            alpha: 0.22,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Scan and camera trade places as the pager moves, so the
                  // button tells you what it will do before you let go.
                  Opacity(
                    opacity: 1 - t,
                    child: Transform.rotate(
                      angle: -t * 1.2,
                      child: Icon(
                        Icons.document_scanner_outlined,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: t,
                    child: Transform.rotate(
                      angle: (1 - t) * 1.2,
                      child: AnimatedSwitcher(
                        duration: Motion.quick,
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: Icon(
                          _holding
                              ? Icons.add_photo_alternate_outlined
                              : Icons.photo_camera_outlined,
                          key: ValueKey(_holding),
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// What the hold will do, shown beside the button while it fills.
class HoldHint extends StatelessWidget {
  const HoldHint({super.key, required this.visible, required this.text});

  final bool visible;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedSwitcher(
      duration: Motion.base,
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.15, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: visible
          ? Padding(
              key: const ValueKey('hint'),
              padding: const EdgeInsets.only(right: Space.sm),
              child: Material(
                color: scheme.inverseSurface,
                shape: const StadiumBorder(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.md,
                    vertical: Space.xs,
                  ),
                  child: Text(
                    text,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onInverseSurface,
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey('none')),
    );
  }
}
