import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the lens turned out to be able to do, read once it is open.
///
/// CameraX answers these at runtime and the answers differ per lens — a front
/// camera with no flash, a sensor with no zoom, a device that refuses
/// exposure points. The screen asks the camera instead of assuming, and hides
/// what would not work.
@immutable
class CameraCapabilities {
  const CameraCapabilities({
    this.minZoom = 1,
    this.maxZoom = 1,
    this.minExposure = 0,
    this.maxExposure = 0,
    this.exposureStep = 0,
    this.focusPoint = false,
    this.exposurePoint = false,
  });

  final double minZoom;
  final double maxZoom;

  /// Exposure compensation range in EV, and the step the device rounds to.
  final double minExposure;
  final double maxExposure;
  final double exposureStep;

  /// Whether tapping can set the focus and the metering point.
  final bool focusPoint;
  final bool exposurePoint;

  bool get canZoom => maxZoom > minZoom + 0.05;
  bool get canCompensate => maxExposure > minExposure;
  bool get canTapToFocus => focusPoint || exposurePoint;

  /// Reads what the camera reports; anything it refuses to answer is simply
  /// treated as unavailable.
  static Future<CameraCapabilities> of(CameraController controller) async {
    Future<double> ask(Future<double> Function() call, double fallback) async {
      try {
        return await call();
      } on CameraException {
        return fallback;
      }
    }

    final minZoom = await ask(controller.getMinZoomLevel, 1);
    final maxZoom = await ask(controller.getMaxZoomLevel, 1);
    final minExposure = await ask(controller.getMinExposureOffset, 0);
    final maxExposure = await ask(controller.getMaxExposureOffset, 0);
    final step = await ask(controller.getExposureOffsetStepSize, 0);

    return CameraCapabilities(
      minZoom: minZoom,
      maxZoom: math.max(minZoom, maxZoom),
      minExposure: minExposure,
      maxExposure: math.max(minExposure, maxExposure),
      exposureStep: step,
      focusPoint: controller.value.focusPointSupported,
      exposurePoint: controller.value.exposurePointSupported,
    );
  }

  /// [ev] rounded to a value the device will accept.
  double snapExposure(double ev) {
    final clamped = ev.clamp(minExposure, maxExposure);
    if (exposureStep <= 0) return clamped;
    return (clamped / exposureStep).round() * exposureStep;
  }

  /// The zoom stops worth offering as buttons, inside what the lens has.
  List<double> get zoomStops => [
        for (final stop in const [1.0, 2.0, 5.0, 10.0])
          if (stop >= minZoom - 0.01 && stop <= maxZoom + 0.01) stop,
      ];
}

/// The exposure dial: where the finger has got to, and the step the camera
/// can actually take.
///
/// The two are deliberately kept apart. A camera takes exposure in steps —
/// half a stop on most phones — while a drag arrives a pixel at a time, each
/// worth a fraction of one. Rounding every fraction and adding it back to an
/// already rounded value rounds it straight back to where it was, so the
/// exposure stays at zero however far the finger travels. Keeping the raw
/// value underneath is what lets small movements add up to a step.
class ExposureDial {
  double _raw = 0;
  double _value = 0;

  /// What the camera is set to.
  double get value => _value;

  /// Where the finger is, somewhere between two steps.
  double get raw => _raw;

  /// Moves the dial by [stops]; true when that lands on a new step, which is
  /// when there is something new to tell the camera.
  bool nudge(double stops, CameraCapabilities capabilities) {
    if (!capabilities.canCompensate) return false;
    final raw = (_raw + stops).clamp(
      capabilities.minExposure,
      capabilities.maxExposure,
    );
    if ((raw - _raw).abs() < 0.0001) return false;
    _raw = raw;

    final stepped = capabilities.snapExposure(raw);
    if ((stepped - _value).abs() < 0.001) return false;
    _value = stepped;
    return true;
  }

  /// Back to neutral, for a new metering point or a new lens.
  void reset() {
    _raw = 0;
    _value = 0;
  }
}

/// Flash, cycled from the top bar in the order a camera app uses: automatic
/// first, because it is the one that is right most of the time.
enum CameraFlash {
  auto(FlashMode.auto),
  on(FlashMode.always),
  off(FlashMode.off),
  torch(FlashMode.torch);

  const CameraFlash(this.mode);

  final FlashMode mode;

  CameraFlash get next => values[(index + 1) % values.length];
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

/// What the camera remembers while the app is open.
///
/// Exposure compensation is deliberately not among them: it belongs to the
/// shot you are framing now, and one left over from yesterday is how a whole
/// roll comes out dark.
class CameraPreferences {
  const CameraPreferences({
    this.flash = CameraFlash.auto,
    this.timer = CameraTimer.off,
    this.grid = false,
    this.lensName,
  });

  final CameraFlash flash;
  final CameraTimer timer;
  final bool grid;

  /// The lens used last, so a roll resumes on the camera it was shot with.
  final String? lensName;

  CameraPreferences copyWith({
    CameraFlash? flash,
    CameraTimer? timer,
    bool? grid,
    String? lensName,
  }) {
    return CameraPreferences(
      flash: flash ?? this.flash,
      timer: timer ?? this.timer,
      grid: grid ?? this.grid,
      lensName: lensName ?? this.lensName,
    );
  }
}

class CameraPreferencesController extends Notifier<CameraPreferences> {
  @override
  CameraPreferences build() => const CameraPreferences();

  void cycleFlash() => state = state.copyWith(flash: state.flash.next);

  void setFlash(CameraFlash flash) => state = state.copyWith(flash: flash);

  void cycleTimer() => state = state.copyWith(timer: state.timer.next);

  void toggleGrid() => state = state.copyWith(grid: !state.grid);

  void useLens(String name) => state = state.copyWith(lensName: name);
}

final cameraPreferencesProvider =
    NotifierProvider<CameraPreferencesController, CameraPreferences>(
      CameraPreferencesController.new,
    );
