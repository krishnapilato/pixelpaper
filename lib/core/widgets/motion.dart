import 'package:flutter/material.dart';

import '../theme/dimens.dart';

/// Coordinates the entrance of the items of one list or grid.
///
/// Items enter in a short cascade when the collection first appears or is
/// swapped for another one (a different folder, a different sort), and an
/// item that is added later — a photo just taken — enters on its own. Items
/// scrolled into view afterwards simply appear: motion on every scroll is
/// noise, not feedback.
class EntranceGroup extends StatefulWidget {
  const EntranceGroup({
    super.key,
    required this.epoch,
    required this.ids,
    required this.child,
  });

  /// Changes when the collection is replaced; the cascade then plays again.
  final Object? epoch;

  /// The ids currently in the collection, to spot the ones just added.
  final Iterable<Object> ids;

  final Widget child;

  /// How long after the collection appears items still join the cascade.
  static const Duration window = Duration(milliseconds: 450);

  /// Items beyond this index appear without waiting for their turn.
  static const int maxStaggered = 14;

  @override
  State<EntranceGroup> createState() => _EntranceGroupState();
}

class _EntranceGroupState extends State<EntranceGroup> {
  late DateTime _since = DateTime.now();
  late Set<Object> _known = widget.ids.toSet();
  Set<Object> _added = const {};

  @override
  void didUpdateWidget(EntranceGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.ids.toSet();
    if (oldWidget.epoch != widget.epoch) {
      _since = DateTime.now();
      _added = const {};
    } else {
      _added = ids.difference(_known);
    }
    _known = ids;
  }

  /// The delay before [id] at [index] enters, or null when it should not
  /// animate at all.
  Duration? _delayFor(Object id, int index) {
    if (_added.contains(id)) return Duration.zero;
    final elapsed = DateTime.now().difference(_since);
    if (elapsed > EntranceGroup.window) return null;
    final slot = index.clamp(0, EntranceGroup.maxStaggered);
    final delay = Motion.stagger * slot - elapsed;
    return delay.isNegative ? Duration.zero : delay;
  }

  @override
  Widget build(BuildContext context) =>
      _EntranceScope(state: this, child: widget.child);
}

class _EntranceScope extends InheritedWidget {
  const _EntranceScope({required this.state, required super.child});

  final _EntranceGroupState state;

  @override
  bool updateShouldNotify(_EntranceScope oldWidget) => false;
}

/// One item of an [EntranceGroup]: fades in and rises a few pixels into
/// place, on the emphasized-decelerate curve.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.id,
    required this.index,
    required this.child,
  });

  final Object id;
  final int index;
  final Widget child;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    final scope = context
        .getInheritedWidgetOfExactType<_EntranceScope>()
        ?.state;
    final delay = scope?._delayFor(widget.id, widget.index);
    if (delay == null) return;

    final controller = _controller = AnimationController(
      vsync: this,
      duration: Motion.base,
    );
    final curved = CurvedAnimation(parent: controller, curve: Motion.enter);
    _opacity = curved;
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(curved);

    if (delay == Duration.zero) {
      controller.forward();
    } else {
      Future<void>.delayed(delay, () {
        if (mounted) controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return widget.child;
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

/// Puts a fixed set of children into one cascade: the sections of a settings
/// page, the rows of a sheet, the actions of a bar. Collections whose items
/// come and go want [EntranceGroup] with their own ids; this is for the ones
/// that are simply there when the screen opens.
///
/// The result still needs an [EntranceGroup] above it, which is what decides
/// whether the cascade plays at all.
List<Widget> cascade(List<Widget> children) => [
  for (var i = 0; i < children.length; i++)
    Entrance(id: i, index: i, child: children[i]),
];

/// A number or a short label that is replaced rather than edited — "3 di 12",
/// a count of selected items — swapped with a small upward slide so the eye
/// catches that it moved.
class Swapped extends StatelessWidget {
  const Swapped({super.key, required this.value, required this.child});

  /// What the child stands for; a new value plays the swap.
  final Object value;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.quick,
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(key: ValueKey(value), child: child),
    );
  }
}

/// `Image.frameBuilder` that fades a picture in once it is decoded, instead
/// of letting it pop into an empty tile. Synchronous frames (already in the
/// image cache) are shown as they are: there is nothing to wait for.
Widget fadeInFrame(
  BuildContext context,
  Widget child,
  int? frame,
  bool wasSynchronouslyLoaded,
) {
  if (wasSynchronouslyLoaded) return child;
  return AnimatedOpacity(
    opacity: frame == null ? 0 : 1,
    duration: Motion.base,
    curve: Motion.standard,
    child: child,
  );
}
