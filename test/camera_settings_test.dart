import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_paper/features/camera/application/camera_settings.dart';
import 'package:pixel_paper/features/camera/presentation/widgets/camera_controls.dart';

void main() {
  group('CameraCapabilities', () {
    test('exposure snaps to the step the device accepts', () {
      const caps = CameraCapabilities(
        minExposure: -2,
        maxExposure: 2,
        exposureStep: 1 / 6,
      );
      expect(caps.snapExposure(0.3), closeTo(1 / 3, 0.001));
      expect(caps.snapExposure(0.12), closeTo(1 / 6, 0.001));
      expect(caps.snapExposure(0.08), 0);
      expect(caps.snapExposure(0), 0);
    });

    test('exposure never leaves the reported range', () {
      const caps = CameraCapabilities(
        minExposure: -1,
        maxExposure: 1,
        exposureStep: 0.5,
      );
      expect(caps.snapExposure(9), 1);
      expect(caps.snapExposure(-9), -1);
    });

    test('a device without compensation keeps the value it is given', () {
      const caps = CameraCapabilities();
      expect(caps.canCompensate, isFalse);
      expect(caps.snapExposure(0.7), 0);
    });

    test('zoom stops stay inside what the lens has', () {
      const wide = CameraCapabilities(minZoom: 1, maxZoom: 8);
      expect(wide.zoomStops, [1, 2, 5]);
      expect(wide.canZoom, isTrue);

      const fixed = CameraCapabilities(minZoom: 1, maxZoom: 1);
      expect(fixed.zoomStops, [1]);
      expect(fixed.canZoom, isFalse);
    });

    test('tapping to focus needs focus or metering points', () {
      expect(const CameraCapabilities().canTapToFocus, isFalse);
      expect(
        const CameraCapabilities(exposurePoint: true).canTapToFocus,
        isTrue,
      );
      expect(const CameraCapabilities(focusPoint: true).canTapToFocus, isTrue);
    });
  });

  group('ExposureDial', () {
    const caps = CameraCapabilities(
      minExposure: -3,
      maxExposure: 3,
      exposureStep: 0.5,
    );

    test('small movements add up instead of rounding away', () {
      final dial = ExposureDial();
      // A drag arrives a pixel at a time and not one of these movements is
      // worth half a stop on its own. Rounding each one before adding it is
      // what used to pin the exposure at zero however far the finger went.
      var steps = 0;
      for (var i = 0; i < 20; i++) {
        if (dial.nudge(0.04, caps)) steps++;
      }
      expect(dial.raw, closeTo(0.8, 0.001));
      expect(dial.value, 1);
      expect(steps, 2, reason: 'the camera is only told when a step changes');
    });

    test('the dial stops at the ends of the range', () {
      final dial = ExposureDial();
      for (var i = 0; i < 20; i++) {
        dial.nudge(0.5, caps);
      }
      expect(dial.value, 3);
      expect(dial.raw, 3);
      expect(dial.nudge(0.5, caps), isFalse);
    });

    test('a camera without compensation never moves', () {
      final dial = ExposureDial();
      expect(dial.nudge(2, const CameraCapabilities()), isFalse);
      expect(dial.value, 0);
    });

    test('a new metering point puts the dial back to neutral', () {
      final dial = ExposureDial();
      expect(dial.nudge(1.2, caps), isTrue);
      expect(dial.value, 1);
      dial.reset();
      expect(dial.value, 0);
      expect(dial.raw, 0);
    });
  });

  group('cycles', () {
    test('flash goes automatic → on → off → torch → automatic', () {
      expect(CameraFlash.auto.next, CameraFlash.on);
      expect(CameraFlash.on.next, CameraFlash.off);
      expect(CameraFlash.off.next, CameraFlash.torch);
      expect(CameraFlash.torch.next, CameraFlash.auto);
    });

    test('each flash carries the plugin mode it stands for', () {
      expect(CameraFlash.auto.mode, FlashMode.auto);
      expect(CameraFlash.on.mode, FlashMode.always);
      expect(CameraFlash.off.mode, FlashMode.off);
      expect(CameraFlash.torch.mode, FlashMode.torch);
    });

    test('the self-timer cycles off → 3 s → 10 s → off', () {
      expect(CameraTimer.off.next, CameraTimer.three);
      expect(CameraTimer.three.next, CameraTimer.ten);
      expect(CameraTimer.ten.next, CameraTimer.off);
      expect(CameraTimer.three.delay, const Duration(seconds: 3));
    });
  });

  group('labels', () {
    test('exposure uses Italian decimals and a real minus sign', () {
      expect(evLabel(0), '±0');
      expect(evLabel(0.7), '+0,7');
      expect(evLabel(-1), '−1');
      expect(evLabel(2), '+2');
    });

    test('zoom', () {
      expect(zoomLabel(1), '1×');
      expect(zoomLabel(1.5), '1,5×');
      expect(zoomLabel(2.04), '2×');
    });
  });
}
