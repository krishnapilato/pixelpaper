import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../theme/dimens.dart';

/// Coordinates the entrance of one list or grid: a short cascade when the
/// collection appears or is replaced ([epoch] changes), a single entrance for
/// an item added later, nothing for items merely scrolled into view.
class EntranceGroup extends StatefulWidget {
  const EntranceGroup({
    super.key,
    required this.epoch,
    required this.ids,
    required this.child,
  });

  final Object? epoch;
  final Iterable<Object> ids;
  final Widget child;

  static const Duration window = Duration(milliseconds: 450);
  static const int maxStaggered = 14;

  @override
  State<EntranceGroup> createState() => _EntranceGroupState();
}

class _EntranceGroupState extends State<EntranceGroup> {
  final Stopwatch _since = Stopwatch()..start();
  late Set<Object> _known = widget.ids.toSet();
  Set<Object> _added = const {};

  @override
  void didUpdateWidget(EntranceGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.ids.toSet();
    if (oldWidget.epoch != widget.epoch) {
      _since.reset();
      _added = const {};
    } else {
      _added = ids.difference(_known);
    }
    _known = ids;
  }

  /// Null when [id] should simply appear.
  Duration? delayFor(Object id, int index) {
    if (_added.contains(id)) return Duration.zero;
    final elapsed = _since.elapsed;
    if (elapsed > EntranceGroup.window) return null;
    final delay =
        Motion.stagger * index.clamp(0, EntranceGroup.maxStaggered) - elapsed;
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

/// One item of an [EntranceGroup]: fades in and rises a few pixels.
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
  CurvedAnimation? _curve;
  Timer? _start;

  static final Animatable<Offset> _rise = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null || _start != null) return;
    if (Motion.reduced(context)) return;
    final delay = context
        .getInheritedWidgetOfExactType<_EntranceScope>()
        ?.state
        .delayFor(widget.id, widget.index);
    if (delay == null) return;

    final controller = _controller = AnimationController(
      vsync: this,
      duration: Motion.base,
    );
    _curve = CurvedAnimation(parent: controller, curve: Motion.enter);
    if (delay == Duration.zero) {
      controller.forward();
    } else {
      _start = Timer(delay, controller.forward);
    }
  }

  @override
  void dispose() {
    _start?.cancel();
    _curve?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = _curve;
    if (curve == null) return widget.child;
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: _rise.animate(curve),
        child: widget.child,
      ),
    );
  }
}

/// A fixed set of children entering as one cascade; needs an [EntranceGroup]
/// above it.
List<Widget> cascade(List<Widget> children) => [
  for (var i = 0; i < children.length; i++)
    Entrance(id: i, index: i, child: children[i]),
];

/// A short label that is replaced rather than edited, swapped with a small
/// upward slide.
class Swapped extends StatelessWidget {
  const Swapped({super.key, required this.value, required this.child});

  final Object value;
  final Widget child;

  static final Animatable<Offset> _rise = Tween<Offset>(
    begin: const Offset(0, 0.4),
    end: Offset.zero,
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.quick),
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: _rise.animate(animation),
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

/// `Image.frameBuilder` that fades a decoded picture in; cached frames and
/// reduced motion show it at once.
Widget fadeInFrame(
  BuildContext context,
  Widget child,
  int? frame,
  bool wasSynchronouslyLoaded,
) {
  if (wasSynchronouslyLoaded || Motion.reduced(context)) return child;
  return AnimatedOpacity(
    opacity: frame == null ? 0 : 1,
    duration: Motion.base,
    curve: Motion.standard,
    child: child,
  );
}
