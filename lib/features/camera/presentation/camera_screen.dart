import 'dart:async';
import 'dart:io';

import 'package:animations/animations.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/dimens.dart';
import '../../../data/models/capture.dart';
import '../../../data/models/folder.dart';
import '../../folders/application/folders_controller.dart';
import '../../gallery/application/gallery_controller.dart';
import '../application/camera_settings.dart';
import 'widgets/camera_controls.dart';
import 'widgets/camera_toast.dart';

/// What a camera session is for.
enum CameraPurpose {
  /// A roll into the Galleria: the camera stays open, every shot is kept and
  /// confirmed on screen.
  gallery,

  /// One page for the editor: the first shot closes the camera and is handed
  /// back to the caller.
  page,
}

/// Module B: the camera, on Flutter's own plugin (CameraX on Android).
///
/// It is built around the one thing that decides whether a page comes out
/// readable: where the camera focuses and meters. Tap the page and it focuses
/// there, meters there, and offers a slider to lift or drop the exposure —
/// the gesture every phone camera has taught people, and the answer to a
/// white sheet under a lamp. Everything else is one tap away: flash, zoom,
/// self-timer, grid, the other lens. Shots are full sensor resolution, with
/// the orientation pinned so pages are never saved sideways.
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key, this.purpose = CameraPurpose.gallery});

  final CameraPurpose purpose;

  /// Opens the camera for a single page and returns the photo, or null when
  /// the user backed out.
  static Future<File?> takePage(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<File>(
      cameraRoute(purpose: CameraPurpose.page),
    );
  }

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

/// The camera as a route, for the entry points that are not the Galleria's
/// action button (which grows into the camera with a container transform).
Route<T> cameraRoute<T>({CameraPurpose purpose = CameraPurpose.gallery}) {
  return PageRouteBuilder<T>(
    transitionDuration: Motion.slow,
    reverseTransitionDuration: Motion.base,
    pageBuilder: (context, animation, secondary) =>
        CameraScreen(purpose: purpose),
    transitionsBuilder: (context, animation, secondary, child) =>
        SharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondary,
      transitionType: SharedAxisTransitionType.scaled,
      fillColor: Colors.black,
      child: child,
    ),
  );
}

enum _Phase { starting, ready, denied, blocked, unavailable, failed }

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _lenses = const [];
  CameraDescription? _lens;
  CameraCapabilities _caps = const CameraCapabilities();
  _Phase _phase = _Phase.starting;

  /// Set while the app is in the background with a camera that was open, so
  /// coming back reopens the same lens.
  CameraDescription? _resumeLens;

  /// Native open and close calls, one at a time: two overlapping opens would
  /// release each other's session.
  Future<void> _operations = Future.value();

  /// Shots already taken, being moved into the gallery one after another.
  Future<void> _saving = Future.value();
  bool _capturing = false;
  Capture? _lastShot;
  int _shots = 0;

  // Zoom: the value on screen moves with the fingers; the camera gets the
  // latest value whenever the previous call has returned, never a queue.
  double _zoom = 1;
  double _pinchFrom = 1;
  double? _zoomPending;
  bool _zoomSending = false;
  late final AnimationController _zoomGlide = AnimationController(
    vsync: this,
    duration: Motion.base,
  );
  Animation<double>? _zoomTween;

  // Where the user last tapped, in the preview's own coordinates, and the
  // exposure compensation that goes with it.
  Offset? _focusAt;
  int _focusId = 0;
  Timer? _focusFade;

  /// What the camera is set to, with the finger's own position kept
  /// underneath it so that small movements add up.
  final _exposure = ExposureDial();
  double? _exposurePending;
  bool _exposureSending = false;

  // Self-timer.
  Timer? _countdownTimer;
  int? _countdown;

  final _toast = CameraToastController();

  /// The black "blink" of a shutter: the viewfinder dips for an instant so a
  /// silent capture still reads as a capture.
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  // Read once, up front: the last save can finish after the screen is gone,
  // when `ref` may no longer be used, and the roll belongs to the folder that
  // was open when the camera started.
  late final GalleryController _gallery;
  late final int? _folderId;
  late final String? _folderName;

  @override
  void initState() {
    super.initState();
    _gallery = ref.read(galleryControllerProvider.notifier);
    _folderId = ref.read(currentFolderProvider(FolderKind.capture));
    _folderName = ref
        .read(currentFolderDetailProvider(FolderKind.capture))
        ?.name;
    _zoomGlide.addListener(() {
      final tween = _zoomTween;
      if (tween != null) _setZoom(tween.value);
    });
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _focusFade?.cancel();
    final controller = _controller;
    _controller = null;
    // Released even while a save is still running: the sensor must go the
    // moment the screen does.
    _operations = _operations.then((_) => controller?.dispose());
    _zoomGlide.dispose();
    _blink.dispose();
    _toast.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // Free the sensor for whatever the user switched to; keeping it
        // would block other camera apps and drain the battery.
        _cancelCountdown();
        final lens = _lens;
        if (_controller != null && lens != null) {
          _resumeLens = lens;
          _serial(_close);
        }
      case AppLifecycleState.resumed:
        final lens = _resumeLens;
        if (lens != null) {
          _resumeLens = null;
          _serial(() => _open(lens));
        } else if (_phase == _Phase.denied || _phase == _Phase.blocked) {
          // Back from Android's settings, perhaps with access granted.
          _start();
        }
      case AppLifecycleState.detached:
        break;
    }
  }

  void _serial(Future<void> Function() operation) {
    _operations = _operations.then((_) => operation()).catchError((_) {});
  }

  Future<void> _start() async {
    if (mounted) setState(() => _phase = _Phase.starting);

    var status = await Permission.camera.status;
    if (!status.isGranted) status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(
        () => _phase =
            status.isPermanentlyDenied ? _Phase.blocked : _Phase.denied,
      );
      return;
    }

    try {
      _lenses = await availableCameras();
    } on CameraException {
      _lenses = const [];
    }
    if (!mounted) return;
    if (_lenses.isEmpty) {
      setState(() => _phase = _Phase.unavailable);
      return;
    }

    final remembered = ref.read(cameraPreferencesProvider).lensName;
    final lens = _lenses.firstWhere(
      (l) => l.name == remembered,
      orElse: () => _lenses.firstWhere(
        (l) => l.lensDirection == CameraLensDirection.back,
        orElse: () => _lenses.first,
      ),
    );
    _serial(() => _open(lens));
  }

  Future<void> _close() async {
    final controller = _controller;
    if (controller == null) return;
    _controller = null;
    controller.removeListener(_onControllerChanged);
    await controller.dispose();
  }

  Future<void> _open(CameraDescription lens) async {
    await _close();
    if (!mounted) return;

    final controller = CameraController(
      lens,
      // The whole point of this screen: the largest frame the sensor gives.
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    final CameraCapabilities caps;
    try {
      await controller.initialize();
      // The app is portrait-locked, so pinning the capture orientation keeps
      // every saved page upright instead of trusting EXIF downstream.
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      caps = await CameraCapabilities.of(controller);
      await _applyFlash(
        controller,
        ref.read(cameraPreferencesProvider).flash,
        silent: true,
      );
    } on CameraException catch (error) {
      await controller.dispose();
      if (!mounted) return;
      setState(
        () => _phase = switch (error.code) {
          'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' =>
            _Phase.denied,
          'CameraAccessRestricted' => _Phase.blocked,
          _ => _Phase.failed,
        },
      );
      return;
    }

    if (!mounted) {
      await controller.dispose();
      return;
    }
    controller.addListener(_onControllerChanged);
    ref.read(cameraPreferencesProvider.notifier).useLens(lens.name);
    setState(() {
      _controller = controller;
      _lens = lens;
      _caps = caps;
      // Every lens starts wide and neutral: a zoom or an exposure carried
      // over from the other side of the phone would be a surprise.
      _zoom = caps.minZoom;
      _exposure.reset();
      _focusAt = null;
      _phase = _Phase.ready;
    });
  }

  void _onControllerChanged() {
    final controller = _controller;
    if (controller == null || !controller.value.hasError) return;
    // The camera went away underneath us (another app took it, the service
    // restarted): say so and offer to try again, instead of a frozen frame.
    _serial(_close);
    if (mounted) setState(() => _phase = _Phase.failed);
  }

  Future<void> _switchLens() async {
    final current = _lens;
    if (current == null || _lenses.length < 2) return;
    HapticFeedback.selectionClick();
    // Front and back alternate first; extra lenses follow in the list order.
    final other = _lenses.firstWhere(
      (l) => l.lensDirection != current.lensDirection,
      orElse: () => _lenses[(_lenses.indexOf(current) + 1) % _lenses.length],
    );
    _serial(() => _open(other));
  }

  // --- Flash ---------------------------------------------------------------

  Future<void> _applyFlash(
    CameraController controller,
    CameraFlash flash, {
    bool silent = false,
  }) async {
    try {
      await controller.setFlashMode(flash.mode);
    } on CameraException {
      // A lens with no flash: say so once, and fall back to off.
      if (!silent && mounted) {
        _toast.show(
          ref.read(stringsProvider)('camera_flash_unsupported'),
          kind: CameraToastKind.info,
        );
        ref.read(cameraPreferencesProvider.notifier).setFlash(CameraFlash.off);
      }
    }
  }

  Future<void> _cycleFlash() async {
    final controller = _controller;
    if (controller == null) return;
    ref.read(cameraPreferencesProvider.notifier).cycleFlash();
    await _applyFlash(controller, ref.read(cameraPreferencesProvider).flash);
  }

  // --- Focus, metering and exposure ---------------------------------------

  Future<void> _focusOn(Offset local, Size preview) async {
    final controller = _controller;
    if (controller == null || !_caps.canTapToFocus || preview.isEmpty) return;

    final point = Offset(
      (local.dx / preview.width).clamp(0.0, 1.0),
      (local.dy / preview.height).clamp(0.0, 1.0),
    );
    HapticFeedback.selectionClick();
    setState(() {
      _focusAt = local;
      _focusId++;
      // Metering starts again from the point: the slider goes back to
      // neutral rather than stacking on top of a new reading.
      _exposure.reset();
    });
    _armFocusFade();

    try {
      if (_caps.focusPoint) {
        await controller.setFocusMode(FocusMode.auto);
        await controller.setFocusPoint(point);
      }
      if (_caps.exposurePoint) {
        await controller.setExposureMode(ExposureMode.auto);
        await controller.setExposurePoint(point);
        await controller.setExposureOffset(0);
      }
    } on CameraException {
      if (mounted) setState(() => _focusAt = null);
    }
  }

  /// The ring and its slider fade out on their own, like every camera app;
  /// touching them again puts the clock back.
  void _armFocusFade() {
    _focusFade?.cancel();
    _focusFade = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _focusAt = null);
    });
  }

  Future<void> _resetFocus() async {
    final controller = _controller;
    if (controller == null || _focusAt == null) return;
    HapticFeedback.mediumImpact();
    _focusFade?.cancel();
    setState(() {
      _focusAt = null;
      _exposure.reset();
    });
    try {
      if (_caps.focusPoint) await controller.setFocusPoint(null);
      if (_caps.exposurePoint) await controller.setExposurePoint(null);
      if (_caps.canCompensate) await controller.setExposureOffset(0);
    } on CameraException {
      // Back to whatever the camera was doing before: nothing to report.
    }
  }

  void _nudgeExposure(double stops) {
    if (_controller == null) return;
    // Any movement counts as touching the controls, so the ring stays put.
    _armFocusFade();
    if (!_exposure.nudge(stops, _caps)) return;
    // One tick per step: the scale feels like a dial with detents.
    HapticFeedback.selectionClick();
    setState(() {});
    _exposurePending = _exposure.value;
    if (!_exposureSending) _sendExposure();
  }

  /// Steps arrive faster than the camera can take them, so only the newest
  /// one is ever in flight and the rest are dropped.
  Future<void> _sendExposure() async {
    _exposureSending = true;
    while (_exposurePending != null) {
      final next = _exposurePending!;
      _exposurePending = null;
      try {
        await _controller?.setExposureOffset(next);
      } on CameraException {
        break;
      }
    }
    _exposureSending = false;
  }

  // --- Zoom ----------------------------------------------------------------

  void _setZoom(double value) {
    final zoom = value.clamp(_caps.minZoom, _caps.maxZoom);
    if ((zoom - _zoom).abs() < 0.005) return;
    setState(() => _zoom = zoom);
    _zoomPending = zoom;
    if (!_zoomSending) _sendZoom();
  }

  Future<void> _sendZoom() async {
    _zoomSending = true;
    while (_zoomPending != null) {
      final next = _zoomPending!;
      _zoomPending = null;
      try {
        await _controller?.setZoomLevel(next);
      } on CameraException {
        break;
      }
    }
    _zoomSending = false;
  }

  /// Glides to a zoom stop instead of jumping, like turning a lens.
  void _glideZoomTo(double target) {
    _zoomTween = Tween<double>(begin: _zoom, end: target).animate(
      CurvedAnimation(parent: _zoomGlide, curve: Motion.emphasized),
    );
    _zoomGlide.forward(from: 0);
  }

  // --- Shooting ------------------------------------------------------------

  void _onShutter() {
    if (_countdown != null) {
      _cancelCountdown();
      return;
    }
    final timer = ref.read(cameraPreferencesProvider).timer;
    if (timer == CameraTimer.off) {
      _shoot();
      return;
    }
    var remaining = timer.delay.inSeconds;
    HapticFeedback.selectionClick();
    setState(() => _countdown = remaining);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (tick) {
      if (!mounted) {
        tick.cancel();
        return;
      }
      remaining--;
      if (remaining <= 0) {
        tick.cancel();
        _countdownTimer = null;
        setState(() => _countdown = null);
        _shoot();
      } else {
        HapticFeedback.selectionClick();
        setState(() => _countdown = remaining);
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (mounted && _countdown != null) setState(() => _countdown = null);
  }

  Future<void> _shoot() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _capturing ||
        controller.value.isTakingPicture) {
      return;
    }
    setState(() => _capturing = true);
    HapticFeedback.lightImpact();
    _blink.forward(from: 0);
    final strings = ref.read(stringsProvider);

    final File shot;
    try {
      final taken = await controller.takePicture();
      shot = File(taken.path);
    } on Object {
      if (!mounted) return;
      setState(() => _capturing = false);
      _toast.show(
        strings('camera_shot_failed'),
        kind: CameraToastKind.failure,
      );
      return;
    }
    if (!mounted) return;
    setState(() => _capturing = false);

    if (widget.purpose == CameraPurpose.page) {
      Navigator.of(context).pop(shot);
      return;
    }
    // The next shot does not wait for this one to be filed.
    _saving = _saving.then((_) => _keep(shot, strings));
  }

  Future<void> _keep(File shot, Strings strings) async {
    try {
      final capture = await _gallery.adopt(
        shot,
        origin: CaptureSource.camera,
        folderId: _folderId,
      );
      if (!mounted) return;
      setState(() {
        _lastShot = capture;
        _shots++;
      });
      final name = _folderName;
      _toast.show(
        name == null
            ? strings('camera_saved')
            : strings('camera_saved_in', {'name': name}),
        kind: CameraToastKind.success,
      );
    } on Object {
      if (!mounted) return;
      _toast.show(
        strings('camera_save_failed'),
        kind: CameraToastKind.failure,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final preferences = ref.watch(cameraPreferencesProvider);
    final controller = _controller;
    final padding = MediaQuery.paddingOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // The viewfinder, letterboxed rather than cropped: the frame you
            // see is the frame that gets saved, which matters when lining up
            // the edge of a page.
            Padding(
              padding: EdgeInsets.only(
                top: padding.top + 56,
                bottom: padding.bottom + 150,
              ),
              child: Center(
                child: PageTransitionSwitcher(
                  duration: Motion.slow,
                  transitionBuilder: (child, primary, secondary) =>
                      FadeThroughTransition(
                    animation: primary,
                    secondaryAnimation: secondary,
                    fillColor: Colors.black,
                    child: child,
                  ),
                  child: switch (_phase) {
                    _Phase.ready when controller != null => Viewfinder(
                        key: ValueKey(controller),
                        controller: controller,
                        grid: preferences.grid,
                        blink: _blink,
                        countdown: _countdown,
                        focusAt: _focusAt,
                        focusId: _focusId,
                        exposure: _exposure.value,
                        capabilities: _caps,
                        strings: strings,
                        onFocus: _focusOn,
                        onResetFocus: _resetFocus,
                        onExposureNudge: _nudgeExposure,
                        onPinchStart: () => _pinchFrom = _zoom,
                        onPinch: (scale) {
                          _zoomGlide.stop();
                          _setZoom(_pinchFrom * scale);
                        },
                      ),
                    _Phase.starting || _Phase.ready => const SizedBox(
                        key: ValueKey('starting'),
                        height: 240,
                        child: Center(
                          child: SizedBox.square(
                            dimension: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    final phase => _CameraMessage(
                        key: ValueKey(phase),
                        phase: phase,
                        strings: strings,
                        onRetry: _start,
                      ),
                  },
                ),
              ),
            ),
            Positioned(
              top: padding.top,
              left: 0,
              right: 0,
              child: CameraTopBar(
                strings: strings,
                flash: preferences.flash,
                timer: preferences.timer,
                grid: preferences.grid,
                ready: controller != null,
                onClose: () => Navigator.of(context).maybePop(),
                onFlash: _cycleFlash,
                onTimer: ref.read(cameraPreferencesProvider.notifier).cycleTimer,
                onGrid: ref.read(cameraPreferencesProvider.notifier).toggleGrid,
              ),
            ),
            Positioned(
              top: padding.top + 64,
              left: Space.lg,
              right: Space.lg,
              child: CameraToast(controller: _toast),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CameraBottomPanel(
                strings: strings,
                zoom: _zoom,
                stops: _caps.zoomStops,
                canZoom: _caps.canZoom,
                ready: controller != null,
                capturing: _capturing,
                counting: _countdown != null,
                lastShot: widget.purpose == CameraPurpose.gallery
                    ? _lastShot
                    : null,
                shots: _shots,
                canSwitch: _lenses.length > 1,
                bottomInset: padding.bottom,
                onZoom: _glideZoomTo,
                onShoot: _onShutter,
                onSwitch: _switchLens,
                onLastShot: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraMessage extends StatelessWidget {
  const _CameraMessage({
    super.key,
    required this.phase,
    required this.strings,
    required this.onRetry,
  });

  final _Phase phase;
  final Strings strings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, title, body) = switch (phase) {
      _Phase.denied => (
          Icons.no_photography_outlined,
          strings('camera_permission_title'),
          strings('camera_permission_body'),
        ),
      _Phase.blocked => (
          Icons.no_photography_outlined,
          strings('camera_permission_title'),
          strings('camera_permission_blocked'),
        ),
      _Phase.unavailable => (
          Icons.no_photography_outlined,
          strings('camera_unavailable'),
          strings('camera_unavailable_body'),
        ),
      _ => (
          Icons.error_outline_rounded,
          strings('camera_failed'),
          strings('camera_failed_body'),
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 76,
            width: 76,
            decoration: const BoxDecoration(
              color: Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: Colors.white70),
          ),
          const SizedBox(height: Space.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: Space.xs),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          if (phase != _Phase.unavailable) ...[
            const SizedBox(height: Space.lg),
            FilledButton.tonal(
              onPressed: phase == _Phase.blocked ? openAppSettings : onRetry,
              child: Text(
                strings(switch (phase) {
                  _Phase.blocked => 'camera_open_settings',
                  _Phase.denied => 'camera_permission_allow',
                  _ => 'camera_retry',
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
