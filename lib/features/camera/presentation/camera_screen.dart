import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/widgets/feedback.dart';
import '../../../data/models/capture.dart';
import '../../gallery/application/gallery_controller.dart';

/// Module B: manual capture at full sensor resolution.
///
/// This screen exists next to the ML Kit scanner for the cases the scanner is
/// wrong for — a fragile page, faded ink, an old Latin text — where automatic
/// cropping and "cleaning" destroy the very detail worth keeping.
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  FlashMode _flash = FlashMode.auto;
  bool _busy = true;
  bool _capturing = false;
  String? _errorKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // The controller holds a native camera session: releasing it here is the
    // difference between leaving the screen and leaving the camera on.
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Drop the reference before disposing so no rebuild can touch a dead
      // controller, and free the sensor for whatever the user switched to.
      setState(() => _controller = null);
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _boot();
    }
  }

  Future<void> _boot() async {
    setState(() {
      _busy = true;
      _errorKey = null;
    });
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _busy = false;
            _errorKey = 'camera_unavailable';
          });
        }
        return;
      }
      await _select(_cameraIndex.clamp(0, _cameras.length - 1));
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorKey = error.code == 'CameraAccessDenied'
            ? 'camera_permission_title'
            : 'camera_unavailable';
      });
    }
  }

  Future<void> _select(int index) async {
    final previous = _controller;
    _controller = null;
    await previous?.dispose();

    final controller = CameraController(
      _cameras[index],
      // The whole point of this screen: no downscaling of the sensor frame.
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
      // The app is portrait-locked, so pinning capture orientation keeps every
      // saved file upright instead of relying on EXIF metadata downstream.
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await controller.setFlashMode(_flash);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _cameraIndex = index;
        _busy = false;
      });
    } on CameraException catch (error) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorKey = error.code == 'CameraAccessDenied'
            ? 'camera_permission_title'
            : 'camera_failed';
      });
    }
  }

  Future<void> _cycleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final next = switch (_flash) {
      FlashMode.auto => FlashMode.always,
      FlashMode.always => FlashMode.off,
      _ => FlashMode.auto,
    };
    try {
      await controller.setFlashMode(next);
      if (mounted) setState(() => _flash = next);
    } on CameraException {
      // Some devices refuse a mode: keep the previous one rather than lying
      // about the state in the UI.
    }
  }

  /// Brings existing photos into the app's own gallery.
  ///
  /// Uses the system photo picker, so it needs no storage permission and the
  /// user only ever exposes the images they choose.
  Future<void> _importFromGallery() async {
    final strings = ref.read(stringsProvider);
    try {
      final picked = await ImagePicker().pickMultiImage();
      if (picked.isEmpty) return;
      for (final file in picked) {
        await ref
            .read(galleryControllerProvider.notifier)
            .adopt(File(file.path), origin: CaptureSource.gallery);
      }
      if (!mounted) return;
      showSnack(
        context,
        strings.plural('camera_imported', picked.length),
        icon: Icons.check_circle_outline_rounded,
      );
    } on Object {
      if (!mounted) return;
      showSnack(context, strings('common_error'),
          icon: Icons.error_outline_rounded);
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    final strings = ref.read(stringsProvider);

    try {
      final shot = await controller.takePicture();
      await ref
          .read(galleryControllerProvider.notifier)
          .adopt(File(shot.path), origin: CaptureSource.camera);
      // A click you can feel: confirmation without covering the viewfinder.
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      showSnack(context, strings('camera_saved'),
          icon: Icons.check_circle_outline_rounded);
    } on Object {
      if (!mounted) return;
      showSnack(context, strings('camera_failed'),
          icon: Icons.error_outline_rounded);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(strings('camera_title')),
        actions: [
          if (controller != null)
            IconButton(
              onPressed: _cycleFlash,
              tooltip: strings(switch (_flash) {
                FlashMode.always => 'camera_flash_on',
                FlashMode.off => 'camera_flash_off',
                _ => 'camera_flash_auto',
              }),
              icon: Icon(switch (_flash) {
                FlashMode.always => Icons.flash_on_rounded,
                FlashMode.off => Icons.flash_off_rounded,
                _ => Icons.flash_auto_rounded,
              }),
            ),
          IconButton(
            onPressed: _importFromGallery,
            tooltip: strings('camera_import'),
            icon: const Icon(Icons.add_photo_alternate_outlined),
          ),
          if (_cameras.length > 1 && controller != null)
            IconButton(
              onPressed: () => _select((_cameraIndex + 1) % _cameras.length),
              tooltip: strings('camera_switch'),
              icon: const Icon(Icons.cameraswitch_outlined),
            ),
          const SizedBox(width: Space.xxs),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: switch ((controller, _errorKey, _busy)) {
                (_, final String key, _) => _CameraMessage(
                    title: strings(key),
                    body: strings(
                      key == 'camera_permission_title'
                          ? 'camera_permission_body'
                          : 'camera_hint',
                    ),
                  ),
                (final CameraController c, _, _) when c.value.isInitialized =>
                  // Letterboxed, not cropped: the frame you see is the frame
                  // that gets saved, which matters when you are lining up a
                  // page edge.
                  AspectRatio(
                    aspectRatio: 1 / c.value.aspectRatio,
                    child: CameraPreview(c),
                  ),
                _ => const CircularProgressIndicator(),
              },
            ),
          ),
          Container(
            color: Colors.black,
            padding: EdgeInsets.fromLTRB(
              Space.lg,
              Space.md,
              Space.lg,
              MediaQuery.paddingOf(context).bottom + Space.lg,
            ),
            child: Column(
              children: [
                Text(
                  strings('camera_hint'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: Space.md),
                _ShutterButton(
                  enabled: controller != null && !_capturing,
                  busy: _capturing,
                  color: scheme.primary,
                  onPressed: _capture,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraMessage extends StatelessWidget {
  const _CameraMessage({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_outlined,
              size: 40, color: Colors.white54),
          const SizedBox(height: Space.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: Space.xs),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

/// A big, centred target: the one control that must never be missed.
class _ShutterButton extends StatelessWidget {
  const _ShutterButton({
    required this.enabled,
    required this.busy,
    required this.color,
    required this.onPressed,
  });

  final bool enabled;
  final bool busy;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: AnimatedContainer(
          duration: Motion.quick,
          height: 74,
          width: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? Colors.white : Colors.white38,
            border: Border.all(color: color, width: busy ? 6 : 3),
          ),
          child: busy
              ? Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              : null,
        ),
      ),
    );
  }
}
