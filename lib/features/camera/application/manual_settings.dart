import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manual_camera_pro/camera.dart';

/// Exposure, white balance and focus as the camera screen holds them, in
/// manual_camera_pro's own units and with its convention: 0 means automatic.
@immutable
class ManualSettings {
  const ManualSettings({
    this.exposure = 0,
    this.iso = 0,
    this.shutter = 0,
    this.whiteBalance = WhiteBalancePreset.auto,
    this.focusMeters = 0,
  });

  /// Exposure compensation in EV, applied while exposure is automatic.
  final double exposure;

  /// Sensor sensitivity; 0 lets the camera choose.
  final int iso;

  /// Denominator of the exposure (125 = 1/125 s); 0 lets the camera choose.
  final int shutter;

  final WhiteBalancePreset whiteBalance;

  /// Focus distance in metres; 0 is autofocus.
  final double focusMeters;

  bool get isAuto =>
      exposure == 0 &&
      iso == 0 &&
      shutter == 0 &&
      whiteBalance == WhiteBalancePreset.auto &&
      focusMeters == 0;

  /// Exposure compensation only steers the automatic exposure: once ISO or
  /// the shutter speed is set by hand there is nothing left for it to move.
  bool get automaticExposure => iso == 0 && shutter == 0;

  Object valueOf(ManualControl control) => switch (control) {
        ManualControl.exposure => exposure,
        ManualControl.iso => iso,
        ManualControl.shutter => shutter,
        ManualControl.whiteBalance => whiteBalance,
        ManualControl.focus => focusMeters,
      };

  ManualSettings withValue(ManualControl control, Object value) =>
      switch (control) {
        ManualControl.exposure => copyWith(exposure: value as double),
        ManualControl.iso => copyWith(iso: value as int),
        ManualControl.shutter => copyWith(shutter: value as int),
        ManualControl.whiteBalance =>
          copyWith(whiteBalance: value as WhiteBalancePreset),
        ManualControl.focus => copyWith(focusMeters: value as double),
      };

  ManualSettings copyWith({
    double? exposure,
    int? iso,
    int? shutter,
    WhiteBalancePreset? whiteBalance,
    double? focusMeters,
  }) {
    return ManualSettings(
      exposure: exposure ?? this.exposure,
      iso: iso ?? this.iso,
      shutter: shutter ?? this.shutter,
      whiteBalance: whiteBalance ?? this.whiteBalance,
      focusMeters: focusMeters ?? this.focusMeters,
    );
  }

  /// The same settings, with every value the lens cannot take put back to
  /// automatic — switching to the front camera must not leave the rear
  /// lens's focus distance applied to a fixed-focus sensor.
  ManualSettings fittedTo(CameraDescription lens) {
    T fit<T>(ManualControl control, T value) {
      final scale = ManualScale.of(control, lens);
      return scale.contains(value) ? value : scale.first as T;
    }

    return ManualSettings(
      exposure: fit(ManualControl.exposure, exposure),
      iso: fit(ManualControl.iso, iso),
      shutter: fit(ManualControl.shutter, shutter),
      whiteBalance: fit(ManualControl.whiteBalance, whiteBalance),
      focusMeters: fit(ManualControl.focus, focusMeters),
    );
  }

  /// [exposure] in the lens's own compensation steps.
  int exposureSteps(CameraDescription lens) {
    final step = lens.exposureCompensationStep;
    return step <= 0 ? 0 : (exposure / step).round();
  }

  @override
  bool operator ==(Object other) =>
      other is ManualSettings &&
      other.exposure == exposure &&
      other.iso == iso &&
      other.shutter == shutter &&
      other.whiteBalance == whiteBalance &&
      other.focusMeters == focusMeters;

  @override
  int get hashCode =>
      Object.hash(exposure, iso, shutter, whiteBalance, focusMeters);
}

/// The dials of the manual mode, in the order they sit on screen.
enum ManualControl { exposure, iso, shutter, whiteBalance, focus }

/// The stops each dial offers, trimmed to what the lens reports it can do.
///
/// Photographic stops rather than a continuous slider: they are the values
/// people know from real cameras, and each one is a visible step.
abstract final class ManualScale {
  static const List<int> _iso = [0, 50, 100, 200, 400, 800, 1600, 3200, 6400];

  static const List<int> _shutter = [
    0, 4000, 2000, 1000, 500, 250, 125, 60, 30, 15, 8, 4, 2, 1, //
  ];

  static const List<WhiteBalancePreset> _whiteBalance = [
    WhiteBalancePreset.auto,
    WhiteBalancePreset.daylight,
    WhiteBalancePreset.cloudy,
    WhiteBalancePreset.shade,
    WhiteBalancePreset.incandescent,
    WhiteBalancePreset.fluorescent,
    WhiteBalancePreset.warmFluorescent,
    WhiteBalancePreset.twilight,
  ];

  /// Near to far; 1000 m reads as infinity.
  static const List<double> _focus = [
    0, 0.08, 0.1, 0.15, 0.2, 0.3, 0.5, 1, 2, 5, 1000, //
  ];

  static const double infinity = 1000;

  /// At most this much compensation either way: past two stops a page is
  /// better served by ISO and shutter.
  static const double _maxExposure = 2;

  /// The stops in order; for every dial but exposure, automatic comes first.
  static List<Object> of(ManualControl control, CameraDescription lens) =>
      switch (control) {
        ManualControl.exposure => exposure(lens),
        ManualControl.iso => iso(lens),
        ManualControl.shutter => shutter(lens),
        ManualControl.whiteBalance => whiteBalance(lens),
        ManualControl.focus => focus(lens),
      };

  /// Compensation in EV, from darker to brighter, in thirds where the lens
  /// allows them; 0 (no compensation) is always there.
  static List<double> exposure(CameraDescription lens) {
    final range = lens.exposureCompensationRange;
    final step = lens.exposureCompensationStep;
    if (range == null || step <= 0 || range.max <= range.min) return const [0];
    // Thirds of a stop, or the lens's own step when it is coarser.
    final stride = math.max(1, (1 / 3 / step).round());
    final values = <double>[];
    for (var n = range.min; n <= range.max; n++) {
      if (n % stride != 0) continue;
      final ev = n * step;
      if (ev.abs() <= _maxExposure + 1e-6) {
        values.add(double.parse(ev.toStringAsFixed(2)));
      }
    }
    return values.contains(0.0) ? values : const [0];
  }

  static List<int> iso(CameraDescription lens) {
    final range = lens.isoRange;
    if (!lens.manualSensor) return const [0];
    return [
      for (final value in _iso)
        if (value == 0 ||
            range == null ||
            (value >= range.min && value <= range.max))
          value,
    ];
  }

  static List<int> shutter(CameraDescription lens) {
    final range = lens.exposureRangeNs;
    if (!lens.manualSensor) return const [0];
    return [
      for (final value in _shutter)
        if (value == 0 || range == null || _fits(value, range)) value,
    ];
  }

  static bool _fits(int shutter, ({int min, int max}) range) {
    // The plugin exposes for 90% of the frame.
    final exposure = 1e9 / shutter * 0.9;
    return exposure >= range.min && exposure <= range.max;
  }

  static List<WhiteBalancePreset> whiteBalance(CameraDescription lens) {
    final supported = lens.whiteBalancePresets;
    if (supported.isEmpty) return const [WhiteBalancePreset.auto];
    return [
      for (final preset in _whiteBalance)
        if (preset == WhiteBalancePreset.auto || supported.contains(preset))
          preset,
    ];
  }

  static List<double> focus(CameraDescription lens) {
    // Fixed-focus lenses report 0 dioptres: there is nothing to turn.
    if (!lens.manualSensor || lens.minFocusDiopters <= 0) return const [0];
    final closest = 1 / lens.minFocusDiopters;
    return [
      for (final value in _focus)
        if (value == 0 || value >= closest) value,
    ];
  }

  /// Whether the lens offers anything but the neutral value for [control].
  static bool isAdjustable(ManualControl control, CameraDescription lens) =>
      of(control, lens).length > 1;

  /// Whether [control] can be turned right now: the lens has it, and — for
  /// exposure compensation — exposure is still automatic.
  static bool isAvailable(
    ManualControl control,
    CameraDescription lens,
    ManualSettings settings,
  ) =>
      isAdjustable(control, lens) &&
      (control != ManualControl.exposure || settings.automaticExposure);
}

/// Self-timer choices, cycled from the top bar.
enum CameraTimer {
  off(Duration.zero),
  three(Duration(seconds: 3)),
  ten(Duration(seconds: 10));

  const CameraTimer(this.delay);

  final Duration delay;

  CameraTimer get next => values[(index + 1) % values.length];
}

/// What the camera remembers while the app is open: the manual values and
/// the viewfinder aids. Reset on the next launch on purpose — a manual
/// exposure left over from last week is how a whole roll comes out black.
class CameraPreferences {
  const CameraPreferences({
    this.settings = const ManualSettings(),
    this.grid = false,
    this.timer = CameraTimer.off,
    this.lensName,
  });

  final ManualSettings settings;
  final bool grid;
  final CameraTimer timer;

  /// The lens used last, so a roll resumes on the camera it was shot with.
  final String? lensName;

  CameraPreferences copyWith({
    ManualSettings? settings,
    bool? grid,
    CameraTimer? timer,
    String? lensName,
  }) {
    return CameraPreferences(
      settings: settings ?? this.settings,
      grid: grid ?? this.grid,
      timer: timer ?? this.timer,
      lensName: lensName ?? this.lensName,
    );
  }
}

class CameraPreferencesController extends Notifier<CameraPreferences> {
  @override
  CameraPreferences build() => const CameraPreferences();

  void setSettings(ManualSettings settings) =>
      state = state.copyWith(settings: settings);

  void toggleGrid() => state = state.copyWith(grid: !state.grid);

  void cycleTimer() => state = state.copyWith(timer: state.timer.next);

  void useLens(String name) => state = state.copyWith(lensName: name);
}

final cameraPreferencesProvider =
    NotifierProvider<CameraPreferencesController, CameraPreferences>(
      CameraPreferencesController.new,
    );
