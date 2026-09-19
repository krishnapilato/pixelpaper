import 'dart:async';
import 'dart:io';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manual_camera_pro/camera.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/dimens.dart';
import '../../../data/models/capture.dart';
import '../../../data/models/folder.dart';
import '../../folders/application/folders_controller.dart';
import '../../gallery/application/gallery_controller.dart';
import '../application/manual_settings.dart';
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

/// Module B: a manual camera, on manual_camera_pro.
///
/// Automatic by default, because most pages are shot in a hurry; the dials
/// of a real camera — exposure, ISO, shutter, white balance, focus — are one
/// tap away for the pages automatic gets wrong: glossy paper under a lamp,
/// faded pencil, a spread that needs the focus pinned. Every dial offers only
/// the stops the lens actually reports, so nothing on screen is a lie; a dial
/// the lens cannot turn stays in its place, dimmed, and says why when tapped.
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
  _Phase _phase = _Phase.starting;
  ManualSettings _settings = const ManualSettings();
  ManualControl? _openDial;
  bool _torch = false;

  /// Set while the app is in the background with a camera that was open, so
  /// coming back reopens the same lens.
  CameraDescription? _resumeLens;

  /// Native open and close calls, one at a time: the plugin holds a single
  /// camera, so two overlapping opens would release each other's session.
  Future<void> _operations = Future.value();

  /// Shots already taken, being moved into the gallery one after another.
  Future<void> _saving = Future.value();
  bool _capturing = false;
  Capture? _lastShot;
  int _shots = 0;

  // Zoom: the value on screen moves with the fingers; the native side gets
  // the latest value whenever the previous call has returned, never a queue.
  double _zoom = 1;
  double _pinchFrom = 1;
  double? _zoomPending;
  bool _zoomSending = false;
  late final AnimationController _zoomGlide = AnimationController(
    vsync: this,
    duration: Motion.base,
  );
  Animation<double>? _zoomTween;

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
    _settings = ref.read(cameraPreferencesProvider).settings;
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
    if (mounted) setState(() => _torch = false);
    controller.removeListener(_onControllerChanged);
    await controller.dispose();
  }

  Future<void> _open(CameraDescription lens) async {
    await _close();
    if (!mounted) return;

    final settings = _settings.fittedTo(lens);
    final controller = CameraController(
      lens,
      // The whole point of this screen: the largest frame the sensor gives.
      ResolutionPreset.max,
      enableAudio: false,
      iso: settings.iso,
      shutterSpeed: settings.shutter,
      whiteBalance: settings.whiteBalance,
      focusDistance: settings.focusMeters,
    );

    try {
      await controller.initialize();
      // The constructor has no compensation parameter: set it once open.
      if (settings.exposure != 0) {
        await controller.setManualSettings(
          iso: settings.iso,
          shutterSpeed: settings.shutter,
          whiteBalance: settings.whiteBalance,
          focusDistance: settings.focusMeters,
          exposureCompensation: settings.exposureSteps(lens),
        );
      }
    } on CameraException catch (error) {
      await controller.dispose();
      if (!mounted) return;
      setState(
        () => _phase = error.code == 'cameraPermission'
            ? _Phase.denied
            : _Phase.failed,
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
      _settings = settings;
      // Every lens starts wide: a zoom carried over from the other side of
      // the phone would be a surprise, not a convenience.
      _zoom = 1;
      _phase = _Phase.ready;
      if (_openDial != null &&
          !ManualScale.isAvailable(_openDial!, lens, settings)) {
        _openDial = null;
      }
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

  // --- Manual settings -----------------------------------------------------

  Future<void> _setValue(ManualControl control, Object value) async {
    final next = _settings.withValue(control, value);
    if (next == _settings) return;
    await _applySettings(next);
  }

  Future<void> _applySettings(ManualSettings next) async {
    setState(() {
      _settings = next;
      // Manual ISO or shutter fixes the exposure: its compensation dial has
      // nothing left to move, so it closes.
      if (_openDial == ManualControl.exposure && !next.automaticExposure) {
        _openDial = null;
      }
    });
    ref.read(cameraPreferencesProvider.notifier).setSettings(next);
    final controller = _controller;
    final lens = _lens;
    if (controller == null || lens == null || !controller.value.isInitialized) {
      return;
    }
    try {
      await controller.setManualSettings(
        iso: next.iso,
        shutterSpeed: next.shutter,
        whiteBalance: next.whiteBalance,
        focusDistance: next.focusMeters,
        exposureCompensation: next.exposureSteps(lens),
      );
    } on CameraException {
      // A value the driver refuses leaves the previous one in force; the
      // dials only offer reported stops, so this is rare.
    }
  }

  void _explainUnavailable(ManualControl control) {
    final strings = ref.read(stringsProvider);
    final lens = _lens;
    final locked = control == ManualControl.exposure &&
        lens != null &&
        ManualScale.isAdjustable(control, lens);
    _toast.show(
      strings(locked ? 'camera_exposure_locked' : 'camera_unsupported'),
      kind: CameraToastKind.info,
    );
  }

  // --- Zoom ----------------------------------------------------------------

  void _setZoom(double value) {
    final lens = _lens;
    if (lens == null) return;
    final zoom = value.clamp(1.0, lens.maxZoom);
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
        await _controller?.setZoom(next);
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
      final dir = Directory(
        p.join((await getTemporaryDirectory()).path, 'camera'),
      );
      await dir.create(recursive: true);
      shot = File(
        p.join(dir.path, 'shot_${DateTime.now().microsecondsSinceEpoch}.jpg'),
      );
      await controller.takePicture(shot.path);
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
    final lens = _lens;
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
              padding: EdgeInsets.only(top: padding.top),
              child: Align(
                alignment: Alignment.topCenter,
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
                    _Phase.ready when controller != null => GestureDetector(
                        key: ValueKey(controller),
                        // Two fingers zoom, as in every camera app.
                        onScaleStart: (_) => _pinchFrom = _zoom,
                        onScaleUpdate: (details) {
                          if (details.pointerCount < 2) return;
                          _zoomGlide.stop();
                          _setZoom(_pinchFrom * details.scale);
                        },
                        child: _Viewfinder(
                          controller: controller,
                          grid: preferences.grid,
                          blink: _blink,
                          countdown: _countdown,
                        ),
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
                timer: preferences.timer,
                torch: _torch,
                torchAvailable: lens?.hasFlash == true && controller != null,
                grid: preferences.grid,
                onClose: () => Navigator.of(context).maybePop(),
                onTimer: ref.read(cameraPreferencesProvider.notifier).cycleTimer,
                onTorch: _toggleTorch,
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
                lens: lens,
                settings: _settings,
                openDial: _openDial,
                zoom: _zoom,
                ready: controller != null,
                capturing: _capturing,
                counting: _countdown != null,
                lastShot: widget.purpose == CameraPurpose.gallery
                    ? _lastShot
                    : null,
                shots: _shots,
                canSwitch: _lenses.length > 1,
                bottomInset: padding.bottom,
                onDial: (control) {
                  HapticFeedback.selectionClick();
                  setState(
                    () => _openDial = _openDial == control ? null : control,
                  );
                },
                onUnavailable: _explainUnavailable,
                onValue: _setValue,
                onReset: () {
                  HapticFeedback.selectionClick();
                  _applySettings(const ManualSettings());
                },
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

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null) return;
    final next = !_torch;
    try {
      final applied = await controller.flash(next);
      if (applied && mounted) setState(() => _torch = next);
    } on CameraException {
      // No torch after all: the button simply stays as it was.
    }
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({
    required this.controller,
    required this.grid,
    required this.blink,
    required this.countdown,
  });

  final CameraController controller;
  final bool grid;
  final Animation<double> blink;
  final int? countdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AspectRatio(
      // manual_camera_pro reports height / width of the landscape sensor
      // frame, which is already the portrait ratio of the screen.
      aspectRatio: controller.value.aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // A texture repaints every frame; isolating it keeps the controls
          // above it from being repainted with it.
          RepaintBoundary(child: CameraPreview(controller)),
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: grid ? 1 : 0,
              duration: Motion.base,
              curve: Motion.standard,
              child: const CustomPaint(painter: _ThirdsPainter()),
            ),
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
                    scale: Tween<double>(begin: 1.4, end: 1).animate(animation),
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
                            Shadow(color: Colors.black54, blurRadius: 24),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          IgnorePointer(
            child: FadeTransition(
              opacity: TweenSequence<double>([
                TweenSequenceItem(tween: Tween(begin: 0, end: 0.85), weight: 30),
                TweenSequenceItem(tween: Tween(begin: 0.85, end: 0), weight: 70),
              ]).animate(blink),
              child: const ColoredBox(color: Colors.black),
            ),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(Space.xl, 120, Space.xl, 0),
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
