import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manual_camera_pro/camera.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/widgets/motion.dart';
import '../../../../data/models/capture.dart';
import '../../application/manual_settings.dart';

/// Close on the left, the viewfinder aids on the right.
///
/// An aid that is on shows in the accent colour; one that is off stays
/// white. No filled circles: on a camera the picture is the loudest thing on
/// screen, and the chrome around it should whisper.
class CameraTopBar extends StatelessWidget {
  const CameraTopBar({
    super.key,
    required this.strings,
    required this.timer,
    required this.torch,
    required this.torchAvailable,
    required this.grid,
    required this.onClose,
    required this.onTimer,
    required this.onTorch,
    required this.onGrid,
  });

  final Strings strings;
  final CameraTimer timer;
  final bool torch;
  final bool torchAvailable;
  final bool grid;
  final VoidCallback onClose;
  final VoidCallback onTimer;
  final VoidCallback onTorch;
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
            AnimatedSwitcher(
              duration: Motion.quick,
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: torchAvailable
                  ? _BarButton(
                      key: const ValueKey('torch'),
                      icon: torch
                          ? Icons.flashlight_on_rounded
                          : Icons.flashlight_off_rounded,
                      tooltip: strings(
                        torch ? 'camera_torch_on' : 'camera_torch_off',
                      ),
                      active: torch,
                      onPressed: onTorch,
                    )
                  : const SizedBox.shrink(),
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
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        onPressed();
      },
      tooltip: tooltip,
      isSelected: active,
      color: active ? scheme.primary : Colors.white,
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

/// Everything under the thumb: zoom, the manual dials and the shutter row.
class CameraBottomPanel extends StatelessWidget {
  const CameraBottomPanel({
    super.key,
    required this.strings,
    required this.lens,
    required this.settings,
    required this.openDial,
    required this.zoom,
    required this.ready,
    required this.capturing,
    required this.counting,
    required this.lastShot,
    required this.shots,
    required this.canSwitch,
    required this.bottomInset,
    required this.onDial,
    required this.onUnavailable,
    required this.onValue,
    required this.onReset,
    required this.onZoom,
    required this.onShoot,
    required this.onSwitch,
    required this.onLastShot,
  });

  final Strings strings;
  final CameraDescription? lens;
  final ManualSettings settings;
  final ManualControl? openDial;
  final double zoom;
  final bool ready;
  final bool capturing;

  /// A self-timer is running: the shutter becomes its stop button.
  final bool counting;
  final Capture? lastShot;
  final int shots;
  final bool canSwitch;
  final double bottomInset;
  final ValueChanged<ManualControl> onDial;
  final ValueChanged<ManualControl> onUnavailable;
  final void Function(ManualControl control, Object value) onValue;
  final VoidCallback onReset;
  final ValueChanged<double> onZoom;
  final VoidCallback onShoot;
  final VoidCallback onSwitch;
  final VoidCallback onLastShot;

  @override
  Widget build(BuildContext context) {
    final lens = this.lens;
    final dial = openDial;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87, Colors.black],
          stops: [0, 0.3, 1],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: Space.xl, bottom: bottomInset + Space.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lens != null && lens.maxZoom > 1.05)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: ZoomPills(
                  zoom: zoom,
                  maxZoom: lens.maxZoom,
                  label: (value) => strings('camera_zoom', {'x': zoomLabel(value)}),
                  onSelected: ready ? onZoom : null,
                ),
              ),
            AnimatedSize(
              duration: Motion.base,
              curve: Motion.emphasized,
              child: AnimatedSwitcher(
                duration: Motion.base,
                switchInCurve: Motion.enter,
                switchOutCurve: Motion.exit,
                child: dial != null && lens != null && ready
                    ? Padding(
                        key: ValueKey(dial),
                        padding: const EdgeInsets.only(bottom: Space.sm),
                        child: ManualDial(
                          values: ManualScale.of(dial, lens),
                          value: settings.valueOf(dial),
                          label: (value) =>
                              manualValueLabel(strings, dial, value),
                          onChanged: (value) => onValue(dial, value),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ),
            _ManualChips(
              strings: strings,
              lens: lens,
              settings: settings,
              openDial: dial,
              enabled: ready,
              onDial: onDial,
              onUnavailable: onUnavailable,
              onReset: onReset,
            ),
            const SizedBox(height: Space.lg),
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

/// A short label for one dial stop.
String manualValueLabel(Strings strings, ManualControl control, Object value) {
  return switch ((control, value)) {
    (ManualControl.exposure, final double ev) => _evLabel(ev),
    (ManualControl.iso, 0) ||
    (ManualControl.shutter, 0) ||
    (ManualControl.focus, 0.0) =>
      strings('camera_auto'),
    (ManualControl.iso, final int iso) => '$iso',
    (ManualControl.shutter, 1) => '1 s',
    (ManualControl.shutter, final int shutter) => '1/$shutter',
    (ManualControl.focus, final double metres)
        when metres >= ManualScale.infinity =>
      '∞',
    (ManualControl.focus, final double metres) when metres < 1 =>
      '${(metres * 100).round()} cm',
    (ManualControl.focus, final double metres) =>
      '${metres.toStringAsFixed(metres == metres.roundToDouble() ? 0 : 1)} m',
    (ManualControl.whiteBalance, final WhiteBalancePreset preset) =>
      strings(switch (preset) {
        WhiteBalancePreset.auto || WhiteBalancePreset.off => 'camera_auto',
        WhiteBalancePreset.daylight => 'camera_wb_daylight',
        WhiteBalancePreset.cloudy => 'camera_wb_cloudy',
        WhiteBalancePreset.shade => 'camera_wb_shade',
        WhiteBalancePreset.incandescent => 'camera_wb_incandescent',
        WhiteBalancePreset.fluorescent => 'camera_wb_fluorescent',
        WhiteBalancePreset.warmFluorescent => 'camera_wb_warm',
        WhiteBalancePreset.twilight => 'camera_wb_twilight',
      }),
    _ => '$value',
  };
}

/// "±0", "+0,3", "−1,7": the typographic minus, Italian decimals, and whole
/// stops without a trailing zero.
String _evLabel(double ev) {
  if (ev.abs() < 0.01) return '±0';
  final magnitude = ev.abs();
  final text = (magnitude - magnitude.round()).abs() < 0.01
      ? magnitude.round().toString()
      : magnitude.toStringAsFixed(1).replaceAll('.', ',');
  return '${ev > 0 ? '+' : '−'}$text';
}

class _ManualChips extends StatelessWidget {
  const _ManualChips({
    required this.strings,
    required this.lens,
    required this.settings,
    required this.openDial,
    required this.enabled,
    required this.onDial,
    required this.onUnavailable,
    required this.onReset,
  });

  final Strings strings;
  final CameraDescription? lens;
  final ManualSettings settings;
  final ManualControl? openDial;
  final bool enabled;
  final ValueChanged<ManualControl> onDial;
  final ValueChanged<ManualControl> onUnavailable;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final lens = this.lens;

    // All five dials, always, in the same places: a lens that cannot turn
    // one shows it dimmed rather than making the row jump when you switch
    // cameras.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: Row(
        children: [
          for (final control in ManualControl.values)
            Padding(
              padding: const EdgeInsets.only(right: Space.xs),
              child: _DialChip(
                title: strings(switch (control) {
                  ManualControl.exposure => 'camera_exposure',
                  ManualControl.iso => 'camera_iso',
                  ManualControl.shutter => 'camera_shutter_speed',
                  ManualControl.whiteBalance => 'camera_white_balance',
                  ManualControl.focus => 'camera_focus',
                }),
                value: manualValueLabel(
                  strings,
                  control,
                  settings.valueOf(control),
                ),
                manual: settings.valueOf(control) !=
                    const ManualSettings().valueOf(control),
                open: openDial == control,
                available: lens != null &&
                    ManualScale.isAvailable(control, lens, settings),
                onTap: !enabled
                    ? null
                    : lens != null &&
                            ManualScale.isAvailable(control, lens, settings)
                        ? () => onDial(control)
                        : () => onUnavailable(control),
              ),
            ),
          AnimatedSwitcher(
            duration: Motion.quick,
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: settings.isAuto
                ? const SizedBox.shrink()
                : IconButton(
                    key: const ValueKey('reset'),
                    onPressed: enabled ? onReset : null,
                    tooltip: strings('camera_reset'),
                    color: Colors.white,
                    icon: const Icon(Icons.restart_alt_rounded),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DialChip extends StatelessWidget {
  const _DialChip({
    required this.title,
    required this.value,
    required this.manual,
    required this.open,
    required this.available,
    required this.onTap,
  });

  final String title;
  final String value;
  final bool manual;
  final bool open;
  final bool available;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = manual ? scheme.primary : Colors.white;

    return Semantics(
      button: true,
      selected: open,
      enabled: available,
      label: '$title $value',
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          // Material's disabled emphasis: present, legible, clearly off.
          opacity: available ? 1 : 0.38,
          duration: Motion.base,
          child: Material(
            color: open ? Colors.white24 : Colors.white10,
            shape: StadiumBorder(
              side: BorderSide(
                color: open ? accent : Colors.white24,
                width: open ? 1.5 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.md,
                  vertical: Space.xs - 2,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white60,
                        letterSpacing: 1,
                        fontSize: 9.5,
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: Motion.quick,
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
                      child: Text(
                        value,
                        key: ValueKey(value),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The zoom stops, as on a Pixel: small circles, the active one larger and
/// showing the exact ratio while you pinch.
class ZoomPills extends StatelessWidget {
  const ZoomPills({
    super.key,
    required this.zoom,
    required this.maxZoom,
    required this.label,
    required this.onSelected,
  });

  final double zoom;
  final double maxZoom;
  final String Function(double zoom) label;
  final ValueChanged<double>? onSelected;

  static const List<double> _stops = [1, 2, 5, 10];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stops = [
      for (final stop in _stops)
        if (stop <= maxZoom + 0.01) stop,
    ];
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
                      shape: BoxShape.rectangle,
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

/// A horizontal wheel of stops, like the dial on a camera body.
///
/// The value under the notch is the one in force; every stop you pass is a
/// light tick in the hand, so the dial can be turned without looking at it.
class ManualDial extends StatefulWidget {
  const ManualDial({
    super.key,
    required this.values,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final List<Object> values;
  final Object value;
  final String Function(Object value) label;
  final ValueChanged<Object> onChanged;

  @override
  State<ManualDial> createState() => _ManualDialState();
}

class _ManualDialState extends State<ManualDial> {
  late final PageController _controller = PageController(
    viewportFraction: 0.2,
    initialPage: _indexOf(widget.value),
  );

  int _indexOf(Object value) {
    final index = widget.values.indexOf(value);
    return index < 0 ? 0 : index;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The notch the values turn under.
          Positioned(
            top: 0,
            child: Icon(Icons.arrow_drop_down_rounded, color: scheme.primary),
          ),
          PageView.builder(
            controller: _controller,
            itemCount: widget.values.length,
            onPageChanged: (index) {
              HapticFeedback.selectionClick();
              widget.onChanged(widget.values[index]);
            },
            itemBuilder: (context, index) => AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final page = _controller.hasClients &&
                        _controller.position.hasContentDimensions
                    ? _controller.page ?? _indexOf(widget.value).toDouble()
                    : _indexOf(widget.value).toDouble();
                final distance = (page - index).abs().clamp(0.0, 2.0);
                return Opacity(
                  opacity: 1 - distance * 0.35,
                  child: Transform.scale(
                    scale: 1.1 - distance * 0.15,
                    child: child,
                  ),
                );
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _controller.animateToPage(
                  index,
                  duration: Motion.base,
                  curve: Motion.emphasized,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: Space.sm),
                    child: Text(
                      widget.label(widget.values[index]),
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: widget.values[index] == widget.value
                            ? scheme.primary
                            : Colors.white,
                        fontWeight: widget.values[index] == widget.value
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: ClipOval(
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
