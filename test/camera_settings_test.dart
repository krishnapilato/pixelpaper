import 'package:flutter_test/flutter_test.dart';
import 'package:manual_camera_pro/camera.dart';
import 'package:pixel_paper/core/l10n/strings.dart';
import 'package:pixel_paper/features/camera/application/manual_settings.dart';
import 'package:pixel_paper/features/camera/presentation/widgets/camera_controls.dart';

CameraDescription _lens({
  bool manualSensor = true,
  ({int min, int max})? iso = (min: 100, max: 1000),
  ({int min, int max})? exposureNs = (min: 100000, max: 1000000000),
  double minFocusDiopters = 10,
  List<WhiteBalancePreset> whiteBalance = const [
    WhiteBalancePreset.off,
    WhiteBalancePreset.auto,
    WhiteBalancePreset.daylight,
    WhiteBalancePreset.cloudy,
  ],
  ({int min, int max})? compensation = (min: -6, max: 6),
  double compensationStep = 1 / 3,
}) {
  return CameraDescription(
    name: '0',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90,
    manualSensor: manualSensor,
    isoRange: iso,
    exposureRangeNs: exposureNs,
    minFocusDiopters: minFocusDiopters,
    whiteBalancePresets: whiteBalance,
    exposureCompensationRange: compensation,
    exposureCompensationStep: compensationStep,
  );
}

const _strings = Strings({
  'camera_auto': 'Auto',
  'camera_wb_daylight': 'Sole',
});

void main() {
  group('ManualScale', () {
    test('exposure offers thirds of a stop up to two stops either way', () {
      final stops = ManualScale.exposure(_lens());
      expect(stops, hasLength(13));
      expect(stops.first, -2);
      expect(stops.last, 2);
      expect(stops, contains(0.0));
      expect(stops, contains(0.33));
    });

    test('a finer lens step still gives thirds, not twelfths', () {
      final stops = ManualScale.exposure(
        _lens(compensation: (min: -24, max: 24), compensationStep: 1 / 12),
      );
      expect(stops, hasLength(13));
      expect(stops, contains(-0.33));
    });

    test('no compensation range means a single neutral stop', () {
      expect(ManualScale.exposure(_lens(compensation: null)), [0]);
    });

    test('ISO stops stay inside the sensor range, auto first', () {
      expect(ManualScale.iso(_lens()), [0, 100, 200, 400, 800]);
    });

    test('a lens without manual sensor offers only auto', () {
      final lens = _lens(manualSensor: false);
      expect(ManualScale.iso(lens), [0]);
      expect(ManualScale.shutter(lens), [0]);
      expect(ManualScale.focus(lens), [0]);
      expect(ManualScale.isAdjustable(ManualControl.iso, lens), isFalse);
      // White balance and compensation do not need the manual sensor.
      expect(ManualScale.isAdjustable(ManualControl.whiteBalance, lens), isTrue);
      expect(ManualScale.isAdjustable(ManualControl.exposure, lens), isTrue);
    });

    test('shutter stops respect the exposure time range', () {
      // The plugin exposes for 90% of the frame. With 0.5 ms to 1 s:
      // 1/4000 (0.225 ms) is too short, 1/1000 (0.9 ms) and 1 s (0.9 s) fit.
      final stops = ManualScale.shutter(
        _lens(exposureNs: (min: 500000, max: 1000000000)),
      );
      expect(stops, isNot(contains(4000)));
      expect(stops, contains(1000));
      expect(stops, contains(1));
    });

    test('white balance keeps only the presets the lens supports', () {
      expect(ManualScale.whiteBalance(_lens()), [
        WhiteBalancePreset.auto,
        WhiteBalancePreset.daylight,
        WhiteBalancePreset.cloudy,
      ]);
    });

    test('focus starts at the closest distance the lens can reach', () {
      final stops = ManualScale.focus(_lens(minFocusDiopters: 10));
      expect(stops.first, 0);
      expect(stops, isNot(contains(0.08)));
      expect(stops, contains(0.1));
      expect(stops.last, ManualScale.infinity);
    });

    test('a fixed-focus lens has nothing to turn', () {
      expect(ManualScale.focus(_lens(minFocusDiopters: 0)), [0]);
    });

    test('compensation is locked once ISO or shutter is manual', () {
      final lens = _lens();
      const manual = ManualSettings(iso: 400);
      expect(
        ManualScale.isAvailable(ManualControl.exposure, lens, manual),
        isFalse,
      );
      expect(
        ManualScale.isAvailable(
          ManualControl.exposure,
          lens,
          const ManualSettings(),
        ),
        isTrue,
      );
    });
  });

  group('ManualSettings', () {
    test('fittedTo puts back to auto what the new lens cannot do', () {
      const settings = ManualSettings(
        exposure: 1,
        iso: 3200,
        shutter: 125,
        whiteBalance: WhiteBalancePreset.shade,
        focusMeters: 0.3,
      );
      final fitted = settings.fittedTo(_lens(manualSensor: false));
      expect(fitted.iso, 0);
      expect(fitted.shutter, 0);
      expect(fitted.focusMeters, 0);
      expect(fitted.whiteBalance, WhiteBalancePreset.auto);
      expect(fitted.exposure, 1);
    });

    test('exposure is converted into the lens steps', () {
      const settings = ManualSettings(exposure: 0.33);
      expect(settings.exposureSteps(_lens()), 1);
      expect(
        settings.exposureSteps(
          _lens(compensation: (min: -24, max: 24), compensationStep: 1 / 12),
        ),
        4,
      );
    });

    test('isAuto only when every dial is neutral', () {
      expect(const ManualSettings().isAuto, isTrue);
      expect(const ManualSettings(exposure: -0.33).isAuto, isFalse);
    });
  });

  group('labels', () {
    test('exposure uses Italian decimals and a real minus sign', () {
      String ev(double value) =>
          manualValueLabel(_strings, ManualControl.exposure, value);
      expect(ev(0), '±0');
      expect(ev(0.33), '+0,3');
      expect(ev(-1), '−1');
      expect(ev(1.67), '+1,7');
    });

    test('shutter, ISO, focus and white balance', () {
      expect(manualValueLabel(_strings, ManualControl.shutter, 0), 'Auto');
      expect(manualValueLabel(_strings, ManualControl.shutter, 125), '1/125');
      expect(manualValueLabel(_strings, ManualControl.shutter, 1), '1 s');
      expect(manualValueLabel(_strings, ManualControl.iso, 400), '400');
      expect(manualValueLabel(_strings, ManualControl.focus, 0.1), '10 cm');
      expect(manualValueLabel(_strings, ManualControl.focus, 2.0), '2 m');
      expect(
        manualValueLabel(_strings, ManualControl.focus, ManualScale.infinity),
        '∞',
      );
      expect(
        manualValueLabel(
          _strings,
          ManualControl.whiteBalance,
          WhiteBalancePreset.daylight,
        ),
        'Sole',
      );
    });

    test('zoom', () {
      expect(zoomLabel(1), '1×');
      expect(zoomLabel(1.5), '1,5×');
      expect(zoomLabel(2.04), '2×');
    });
  });

  test('the self-timer cycles off → 3 s → 10 s → off', () {
    expect(CameraTimer.off.next, CameraTimer.three);
    expect(CameraTimer.three.next, CameraTimer.ten);
    expect(CameraTimer.ten.next, CameraTimer.off);
  });
}
