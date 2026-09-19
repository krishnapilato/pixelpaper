## 0.1.0 + PixelPaper patches

Vendored from pub.dev `manual_camera_pro` 0.1.0 (the latest release, May 2023),
which no longer builds with Flutter 3.29+, Gradle 9 or AGP 8+. Every change is
marked "PixelPaper patch" in the source.

Build compatibility:

- `android/build.gradle`: namespace, compileSdk 36, Java 17; no `buildscript`,
  `jcenter()` or Kotlin plugin (there are no Kotlin sources).
- `AndroidManifest.xml`: no `package` attribute.
- `CameraPlugin`: the removed v1 embedding entry point (`Registrar`) is gone;
  the texture registry comes from the plugin binding.

Fixes:

- The still capture now applies ISO, shutter speed, white balance, focus and the
  torch; 0.1.0 applied them to the preview only, so photos ignored them.
- `focusDistance: 0` really means auto focus; 0.1.0 sent `1 / 0` and locked the
  lens instead.
- `dispose()` works after a failed, pending or missing `initialize()` (it used
  to hang or throw), and re-initialising releases the previous texture.
- Calls on a closed camera return an error instead of crashing the app.
- A permission request already in flight is no longer asked twice.

Additions:

- `CameraController.setManualSettings` changes the manual values on the running
  session, without reopening the camera.
- `CameraDescription` reports what each lens supports: manual sensor, ISO and
  exposure ranges, closest focus, flash, white balance presets.

## 0.1.0

- Updated enabled building with null-safety

## 0.0.3

- Fixed "No podspec found"

## 0.0.2+1

- Updated README

## 0.0.2

- Flash now turns off when camera is disposed

## 0.0.1+1

- Fixed repo link and README table

## 0.0.1

- Initial release
