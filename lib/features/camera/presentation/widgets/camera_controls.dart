import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/widgets/motion.dart';
import '../../../../data/models/capture.dart';
import '../../application/camera_settings.dart';

/// The live picture and everything drawn on top of it.
///
/// Tapping sets focus and metering where the page is and brings out the
/// exposure scale beside the ring; sliding up or down from anywhere then
/// lifts or drops the exposure, as on Google's camera — one recogniser for
/// the whole picture instead of a small target to hit. A long press gives
/// the camera back to automatic, two fingers zoom. Nothing here is a menu:
/// the viewfinder is the control surface.
class Viewfinder extends StatelessWidget {
  const Viewfinder({
    super.key,
    required this.controller,
    required this.grid,
    required this.blink,
    required this.countdown,
    required this.focusAt,
    required this.focusId,
    required this.exposure,
    required this.capabilities,
    required this.strings,
    required this.onFocus,
    required this.onResetFocus,
    required this.onExposureNudge,
    required this.onPinchStart,
    required this.onPinch,
  });

  final CameraController controller;
  final bool grid;
  final Animation<double> blink;
  final int? countdown;

  /// Where the user tapped, in the preview's own coordinates.
  final Offset? focusAt;

  /// Changes with every tap, so the ring replays its entrance.
  final int focusId;
  final double exposure;
  final CameraCapabilities capabilities;
  final Strings strings;
  final void Function(Offset local, Size preview) onFocus;
  final VoidCallback onResetFocus;

  /// How many stops to move the exposure by, positive for brighter.
  final ValueChanged<double> onExposureNudge;
  final VoidCallback onPinchStart;
  final ValueChanged<double> onPinch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AspectRatio(
      // The plugin reports the sensor frame in landscape; on a portrait
      // screen the preview is its reciprocal.
      aspectRatio: 1 / controller.value.aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return Semantics(
            label: capabilities.canTapToFocus
                ? strings('camera_tap_to_focus')
                : null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => onFocus(details.localPosition, size),
              onLongPress: onResetFocus,
              onScaleStart: (_) => onPinchStart(),
              onScaleUpdate: (details) {
                if (details.pointerCount < 2) return;
                onPinch(details.scale);
              },
              // Exposure, once a point has been metered: up is brighter.
              // The whole frame is the track, so the value can be changed
              // with the thumb that is already on the screen.
              // Exposure, once a point has been metered: up is brighter, and
              // the whole frame is the track so the thumb already on the
              // screen can change it. What goes out is how far the finger
              // moved, never where it should land: the camera only takes
              // whole steps, and adding a fraction of a step to a value that
              // has already been rounded rounds straight back to it, which
              // left the exposure pinned at zero however far the finger went.
              onVerticalDragUpdate:
                  focusAt == null || !capabilities.canCompensate
                      ? null
                      : (details) {
                          final span = capabilities.maxExposure -
                              capabilities.minExposure;
                          final track = size.height * 0.7;
                          onExposureNudge(-details.delta.dy / track * span);
                        },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // A texture repaints every frame; isolating it keeps what
                  // is drawn above from repainting with it.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.lg),
                    child: RepaintBoundary(child: CameraPreview(controller)),
                  ),
                  IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: grid ? 1 : 0,
                      duration: Motion.base,
                      curve: Motion.standard,
                      child: const CustomPaint(painter: _ThirdsPainter()),
                    ),
                  ),
                  if (focusAt != null)
                    FocusRing(
                      key: ValueKey(focusId),
                      at: focusAt!,
                      bounds: size,
                      exposure: exposure,
                      capabilities: capabilities,
                      strings: strings,
                    ),
                  // The self-timer, counting down where the eye already is.
                  IgnorePointer(
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: Motion.base,
                        switchInCurve: Motion.enter,
                        switchOutCurve: Motion.exit,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(
                              begin: 1.4,
                              end: 1,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: countdown == null
                            ? const SizedBox.shrink()
                            : Text(
                                '$countdown',
                                key: ValueKey(countdown),
                                style: theme.textTheme.displayLarge?.copyWith(
                                  color: Colors.white,
                                  fontSize: 96,
                                  fontWeight: FontWeight.w300,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 24,
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: FadeTransition(
                      opacity: TweenSequence<double>([
                        TweenSequenceItem(
                          tween: Tween(begin: 0, end: 0.85),
                          weight: 30,
                        ),
                        TweenSequenceItem(
                          tween: Tween(begin: 0.85, end: 0),
                          weight: 70,
                        ),
                      ]).animate(blink),
                      child: const ColoredBox(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The square that says "focused here", with the exposure slider beside it.
///
/// It arrives a little larger and settles, the way a camera confirms the
/// point it locked onto, and the slider next to it lifts or drops the
/// exposure for that subject — the page under the lamp that comes out white.
class FocusRing extends StatelessWidget {
  const FocusRing({
    super.key,
    required this.at,
    required this.bounds,
    required this.exposure,
    required this.capabilities,
    required this.strings,
  });

  final Offset at;
  final Size bounds;
  final double exposure;
  final CameraCapabilities capabilities;
  final Strings strings;

  static const double size = 78;
  static const double sliderHeight = 170;
  static const double sliderWidth = 44;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // The ring and the slider are placed separately inside the viewfinder,
    // not nested one inside the other: a child drawn outside its parent's
    // box is painted but never hit, and the slider was undraggable for it.
    final ringLeft = (at.dx - size / 2).clamp(4.0, bounds.width - size - 4);
    final ringTop = (at.dy - size / 2).clamp(4.0, bounds.height - size - 4);
    // The slider goes on the side with room for it.
    final onLeft = ringLeft + size + sliderWidth + 8 > bounds.width;
    final sliderLeft = (onLeft ? ringLeft - sliderWidth - 8 : ringLeft + size + 8)
        .clamp(4.0, bounds.width - sliderWidth - 4);
    final sliderTop = (at.dy - sliderHeight / 2)
        .clamp(4.0, bounds.height - sliderHeight - 4);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.base,
      curve: Motion.enter,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: ringLeft,
            top: ringTop,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.4, end: 1),
              duration: Motion.base,
              curve: Motion.enter,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              // The ring: a thin square, the shape every camera uses for
              // "this is what I am looking at". It does not take the touch:
              // tapping it again focuses there.
              child: SizedBox.square(
                dimension: size,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.primary, width: 1.6),
                    borderRadius: BorderRadius.circular(Radii.xs),
                  ),
                ),
              ),
            ),
          ),
          if (capabilities.canCompensate)
            Positioned(
              left: sliderLeft,
              top: sliderTop,
              // Shown, not touched: the drag lives on the whole viewfinder.
              child: IgnorePointer(
                child: _ExposureScale(
                  value: exposure,
                  min: capabilities.minExposure,
                  max: capabilities.maxExposure,
                  label: strings('camera_exposure'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The exposure read-out: a track with the sun at the value in force.
class _ExposureScale extends StatelessWidget {
  const _ExposureScale({
    required this.value,
    required this.min,
    required this.max,
    required this.label,
  });

  final double value;
  final double min;
  final double max;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final span = (max - min).abs() < 0.001 ? 1 : max - min;
    // Top is brighter: dragging up lifts the exposure.
    final position = ((max - value) / span).clamp(0.0, 1.0);

    return Semantics(
      label: label,
      value: evLabel(value),
      child: SizedBox(
        width: FocusRing.sliderWidth,
        height: FocusRing.sliderHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 2,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            Align(
              alignment: Alignment(0, position * 2 - 1),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.light_mode_rounded,
                  size: 16,
                  color: scheme.onPrimary,
                ),
              ),
            ),
            if (value.abs() > 0.001)
              Align(
                alignment: Alignment.topCenter,
                child: Text(
                  evLabel(value),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    letterSpacing: 0,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 6),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Rule-of-thirds lines: enough to square a page against, faint enough not
/// to be mistaken for part of the photo.
class _ThirdsPainter extends CustomPainter {
  const _ThirdsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas
        ..drawLine(Offset(x, 0), Offset(x, size.height), paint)
        ..drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ThirdsPainter oldDelegate) => false;
}

/// Close on the left, the shooting aids on the right.
///
/// An aid that is on shows in the accent colour; one that is off stays
/// white. No filled circles: on a camera the picture is the loudest thing on
/// screen, and the chrome around it should whisper.
class CameraTopBar extends StatelessWidget {
  const CameraTopBar({
    super.key,
    required this.strings,
    required this.flash,
    required this.timer,
    required this.grid,
    required this.ready,
    required this.onClose,
    required this.onFlash,
    required this.onTimer,
    required this.onGrid,
  });

  final Strings strings;
  final CameraFlash flash;
  final CameraTimer timer;
  final bool grid;
  final bool ready;
  final VoidCallback onClose;
  final VoidCallback onFlash;
  final VoidCallback onTimer;
  final VoidCallback onGrid;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.xs,
          vertical: Space.xxs,
        ),
        child: Row(
          children: [
            _BarButton(
              icon: Icons.close_rounded,
              tooltip: strings('camera_close'),
              onPressed: onClose,
            ),
            const Spacer(),
            _BarButton(
              icon: switch (flash) {
                CameraFlash.auto => Icons.flash_auto_rounded,
                CameraFlash.on => Icons.flash_on_rounded,
                CameraFlash.off => Icons.flash_off_rounded,
                CameraFlash.torch => Icons.flashlight_on_rounded,
              },
              tooltip: strings(switch (flash) {
                CameraFlash.auto => 'camera_flash_auto',
                CameraFlash.on => 'camera_flash_on',
                CameraFlash.off => 'camera_flash_off',
                CameraFlash.torch => 'camera_flash_torch',
              }),
              active: flash == CameraFlash.on || flash == CameraFlash.torch,
              onPressed: ready ? onFlash : null,
            ),
            _BarButton(
              icon: switch (timer) {
                CameraTimer.off => Icons.timer_off_outlined,
                CameraTimer.three => Icons.timer_3_outlined,
                CameraTimer.ten => Icons.timer_10_outlined,
              },
              tooltip: strings(switch (timer) {
                CameraTimer.off => 'camera_timer_off',
                CameraTimer.three => 'camera_timer_3',
                CameraTimer.ten => 'camera_timer_10',
              }),
              active: timer != CameraTimer.off,
              onPressed: onTimer,
            ),
            _BarButton(
              icon: grid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
              tooltip: strings('camera_grid'),
              active: grid,
              onPressed: onGrid,
            ),
          ],
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onPressed!();
            },
      tooltip: tooltip,
      isSelected: active,
      color: active ? scheme.primary : Colors.white,
      disabledColor: Colors.white38,
      icon: AnimatedSwitcher(
        duration: Motion.quick,
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(icon, key: ValueKey(icon)),
      ),
    );
  }
}

/// Everything under the thumb: zoom and the shutter row.
class CameraBottomPanel extends StatelessWidget {
  const CameraBottomPanel({
    super.key,
    required this.strings,
    required this.zoom,
    required this.stops,
    required this.canZoom,
    required this.ready,
    required this.capturing,
    required this.counting,
    required this.lastShot,
    required this.shots,
    required this.canSwitch,
    required this.bottomInset,
    required this.onZoom,
    required this.onShoot,
    required this.onSwitch,
    required this.onLastShot,
  });

  final Strings strings;
  final double zoom;
  final List<double> stops;
  final bool canZoom;
  final bool ready;
  final bool capturing;

  /// A self-timer is running: the shutter becomes its stop button.
  final bool counting;
  final Capture? lastShot;
  final int shots;
  final bool canSwitch;
  final double bottomInset;
  final ValueChanged<double> onZoom;
  final VoidCallback onShoot;
  final VoidCallback onSwitch;
  final VoidCallback onLastShot;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87, Colors.black],
          stops: [0, 0.35, 1],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: Space.xl, bottom: bottomInset + Space.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canZoom && stops.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: ZoomPills(
                  zoom: zoom,
                  stops: stops,
                  label: (value) =>
                      strings('camera_zoom', {'x': zoomLabel(value)}),
                  onSelected: ready ? onZoom : null,
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _LastShot(
                  capture: lastShot,
                  shots: shots,
                  strings: strings,
                  onTap: onLastShot,
                ),
                ShutterButton(
                  enabled: ready,
                  busy: capturing,
                  counting: counting,
                  label: strings(
                    counting ? 'camera_timer_cancel' : 'camera_shutter',
                  ),
                  onPressed: onShoot,
                ),
                _SwitchLensButton(
                  visible: canSwitch,
                  enabled: ready && !counting,
                  tooltip: strings('camera_switch'),
                  onPressed: onSwitch,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "1,5×" — Italian decimals, and no decimals where there are none.
String zoomLabel(double zoom) {
  final rounded = (zoom * 10).round() / 10;
  final text = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1).replaceAll('.', ',');
  return '$text×';
}

/// "±0", "+0,7", "−1": the typographic minus and Italian decimals.
String evLabel(double ev) {
  if (ev.abs() < 0.05) return '±0';
  final magnitude = ev.abs();
  final text = (magnitude - magnitude.round()).abs() < 0.05
      ? magnitude.round().toString()
      : magnitude.toStringAsFixed(1).replaceAll('.', ',');
  return '${ev > 0 ? '+' : '−'}$text';
}

/// The zoom stops, as on a Pixel: small circles, the active one larger and
/// showing the exact ratio while you pinch.
class ZoomPills extends StatelessWidget {
  const ZoomPills({
    super.key,
    required this.zoom,
    required this.stops,
    required this.label,
    required this.onSelected,
  });

  final double zoom;
  final List<double> stops;
  final String Function(double zoom) label;
  final ValueChanged<double>? onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // The stop that owns the current zoom: the largest one not above it.
    final active = stops.lastWhere(
      (stop) => zoom >= stop - 0.05,
      orElse: () => stops.first,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.xxs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final stop in stops)
              Semantics(
                button: true,
                selected: stop == active,
                label: label(stop == active ? zoom : stop),
                child: GestureDetector(
                  onTap: onSelected == null
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          onSelected!(stop);
                        },
                  child: AnimatedContainer(
                    duration: Motion.quick,
                    curve: Motion.standard,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: stop == active ? 40 : 32,
                    constraints: BoxConstraints(
                      minWidth: stop == active ? 40 : 32,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: stop == active ? Colors.white24 : Colors.white10,
                      borderRadius: BorderRadius.circular(Radii.full),
                    ),
                    alignment: Alignment.center,
                    child: ExcludeSemantics(
                      child: Text(
                        stop == active
                            ? zoomLabel(zoom)
                            : zoomLabel(stop).replaceAll('×', ''),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: stop == active ? scheme.primary : Colors.white,
                          fontWeight: stop == active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
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

/// The one control that must never be missed: big, centred, and it answers
/// the press before the photo is even taken.
class ShutterButton extends StatefulWidget {
  const ShutterButton({
    super.key,
    required this.enabled,
    required this.busy,
    required this.counting,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final bool busy;
  final bool counting;
  final String label;
  final VoidCallback onPressed;

  @override
  State<ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<ShutterButton> {
  bool _pressed = false;

  void _press(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => _press(true),
        onTapCancel: () => _press(false),
        onTapUp: (_) => _press(false),
        onTap: widget.enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1,
          duration: Motion.quick,
          curve: Motion.standard,
          child: SizedBox.square(
            dimension: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.standard,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.enabled ? Colors.white : Colors.white38,
                      width: 4,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.emphasized,
                  height: widget.busy ? 46 : (widget.counting ? 30 : 62),
                  width: widget.busy ? 46 : (widget.counting ? 30 : 62),
                  decoration: BoxDecoration(
                    // While the self-timer runs the shutter turns into a
                    // stop square: the same place cancels it.
                    borderRadius: BorderRadius.circular(
                      widget.counting ? Radii.xs : 40,
                    ),
                    color: widget.busy || widget.counting
                        ? scheme.primary
                        : widget.enabled
                            ? Colors.white
                            : Colors.white38,
                  ),
                ),
                if (widget.busy)
                  const SizedBox.square(
                    dimension: 80,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LastShot extends StatelessWidget {
  const _LastShot({
    required this.capture,
    required this.shots,
    required this.strings,
    required this.onTap,
  });

  final Capture? capture;
  final int shots;
  final Strings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final capture = this.capture;
    final pixels = (56 * MediaQuery.devicePixelRatioOf(context)).round();

    return SizedBox.square(
      dimension: 56,
      child: AnimatedSwitcher(
        duration: Motion.base,
        switchInCurve: Motion.enter,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: Tween<double>(begin: 0.6, end: 1).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: capture == null
            ? const SizedBox.shrink()
            : Semantics(
                key: ValueKey(capture.id),
                button: true,
                label:
                    '${strings('camera_last_shot')}, ${strings.plural('camera_shots', shots)}',
                child: GestureDetector(
                  onTap: onTap,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Radii.sm),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.file(
                          capture.file,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          cacheWidth: pixels,
                          gaplessPlayback: true,
                          frameBuilder: fadeInFrame,
                        ),
                      ),
                      Positioned(
                        right: -4,
                        top: -4,
                        child: AnimatedSwitcher(
                          duration: Motion.quick,
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Container(
                            key: ValueKey(shots),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(Radii.full),
                            ),
                            child: Text(
                              '$shots',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: scheme.onPrimary,
                                    letterSpacing: 0,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _SwitchLensButton extends StatefulWidget {
  const _SwitchLensButton({
    required this.visible,
    required this.enabled,
    required this.tooltip,
    required this.onPressed,
  });

  final bool visible;
  final bool enabled;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_SwitchLensButton> createState() => _SwitchLensButtonState();
}

class _SwitchLensButtonState extends State<_SwitchLensButton> {
  double _turns = 0;

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.square(dimension: 56);
    return SizedBox.square(
      dimension: 56,
      child: IconButton(
        onPressed: widget.enabled
            ? () {
                setState(() => _turns += 0.5);
                widget.onPressed();
              }
            : null,
        tooltip: widget.tooltip,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white12,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white38,
        ),
        icon: AnimatedRotation(
          turns: _turns,
          duration: Motion.slow,
          curve: Motion.emphasized,
          child: const Icon(Icons.cameraswitch_rounded),
        ),
      ),
    );
  }
}
