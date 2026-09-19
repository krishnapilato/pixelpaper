import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/dimens.dart';
import '../../documents/application/documents_controller.dart';
import '../../gallery/application/gallery_controller.dart';

/// The opening: the launcher mark is scanned, turns into pixels, and the name
/// is written under it.
///
/// It starts exactly where Android's own splash leaves off — the same mark,
/// the same size, the same place — so the hand-over from the system is
/// invisible and the animation reads as the icon coming to life. The whole
/// thing takes a little over three seconds — each movement keeps its natural
/// speed, and the finished mark rests on screen long enough to be read — the
/// archive and the gallery load underneath it, a tap skips it, and with
/// Android's animations turned off it is not shown at all.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );

  bool _left = false;

  // The acts, as fractions of the 3.4 s: the mark settles and is scanned
  // (0.1–1.25 s), its pixels come away (0.9–1.65 s), the name is written
  // (1.1–2.3 s), the motto arrives (2–2.6 s), everything rests, and the
  // whole dissolves into the archive (3.05–3.4 s).
  static const Interval _settle = Interval(0.03, 0.28, curve: Motion.emphasized);
  static const Interval _scan = Interval(0.07, 0.37, curve: Curves.easeInOut);
  static const Interval _firstPixel = Interval(0.26, 0.44);
  static const Interval _secondPixel = Interval(0.31, 0.49);
  static const Interval _word = Interval(0.32, 0.68, curve: Curves.easeInOut);
  static const Interval _rule = Interval(0.41, 0.65, curve: Motion.enter);
  static const Interval _caption = Interval(0.59, 0.76, curve: Motion.enter);
  static const Interval _outro = Interval(0.90, 1, curve: Motion.exit);

  /// Android 12+ draws the launcher foreground at 288 dp on its splash.
  static const double _systemIconSize = 288;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _enter();
    });

    // Kick off the first reads now: by the time the name is written, the
    // archive is already in memory and the first screen paints with content.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
        ..read(documentsControllerProvider)
        ..read(galleryControllerProvider);
      if (MediaQuery.disableAnimationsOf(context)) {
        _enter();
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A tap runs the ending instead of cutting to the app.
  void _skip() {
    if (_left || _controller.value >= _outro.begin) return;
    _controller.animateTo(1, duration: Motion.base, curve: Motion.exit);
  }

  void _enter() {
    if (_left || !mounted) return;
    _left = true;
    context.go(Routes.documents);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skip,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final settle = _settle.transform(t);
            final outro = _outro.transform(t);

            return Opacity(
              // Dissolve into the app instead of cutting: the archive fades
              // through from the same dark surface.
              opacity: 1 - outro,
              child: Transform.scale(
                scale: 1 - outro * 0.04,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // The mark: from the system splash's size and place to
                    // a smaller one above the name.
                    Center(
                      child: Transform.translate(
                        offset: Offset(0, lerpDouble(0, -72, settle)!),
                        child: Transform.scale(
                          scale: lerpDouble(1, 0.46, settle)!,
                          child: SizedBox.square(
                            dimension: _systemIconSize,
                            child: CustomPaint(
                              painter: _MarkPainter(
                                scan: _scan.transform(t),
                                firstPixel: _pop(_firstPixel.transform(t)),
                                secondPixel: _pop(_secondPixel.transform(t)),
                                tint: settle,
                                paper: Colors.white,
                                accent: scheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Transform.translate(
                        offset: const Offset(0, 44),
                        child: Opacity(
                          opacity: (_word.transform(t) * 4).clamp(0.0, 1.0),
                          child: IntrinsicWidth(
                            // The rule and the caption take the width of the
                            // word, so the three lines read as one mark.
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _Wordmark(
                                  text: strings('app_name'),
                                  progress: _word.transform(t),
                                  style: theme.textTheme.displaySmall!.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                    color: scheme.onSurface,
                                  ),
                                  dim: scheme.onSurface.withValues(alpha: 0.12),
                                  beam: scheme.primary,
                                ),
                                const SizedBox(height: Space.md),
                                // The sheet edge: a rule that draws itself.
                                FractionallySizedBox(
                                  widthFactor: _rule.transform(t),
                                  child: Container(
                                    height: 2,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(1),
                                      gradient: LinearGradient(
                                        colors: [
                                          scheme.primary.withValues(alpha: 0),
                                          scheme.primary,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: Space.sm),
                                Opacity(
                                  opacity: _caption.transform(t),
                                  child: Transform.translate(
                                    offset: Offset(
                                      0,
                                      (1 - _caption.transform(t)) * 8,
                                    ),
                                    child: Text(
                                      strings('app_motto'),
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// A small lift and settle: up past full size, then back, decelerating.
  static double _pop(double t) {
    if (t <= 0) return 1;
    if (t >= 1) return 1;
    return t < 0.4
        ? 1 + 0.35 * Motion.enter.transform(t / 0.4)
        : 1.35 - 0.35 * Motion.standard.transform((t - 0.4) / 0.6);
  }
}

/// The launcher mark — an A4 sheet whose corner comes away in pixels —
/// drawn from the same geometry as `ic_launcher_foreground.xml`, in its
/// 108-unit viewport, so the first frame matches the system splash exactly.
class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.scan,
    required this.firstPixel,
    required this.secondPixel,
    required this.tint,
    required this.paper,
    required this.accent,
  });

  /// 0 → 1: the scan line's travel down the sheet.
  final double scan;

  /// Scale of each pixel square (1 at rest).
  final double firstPixel;
  final double secondPixel;

  /// 0 → 1: how far the pixels have turned from paper white to the accent.
  final double tint;

  final Color paper;
  final Color accent;

  static const Rect _sheet = Rect.fromLTRB(31, 32, 59, 72);
  static const Rect _pixelA = Rect.fromLTRB(62, 52, 72, 62);
  static const Rect _pixelB = Rect.fromLTRB(74, 66, 81, 73);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 108);

    final sheet = RRect.fromRectAndRadius(_sheet, const Radius.circular(3));
    canvas.drawRRect(sheet, Paint()..color = paper);

    // The scan: a band of light travelling down the page, with a short
    // trail above it, clipped to the paper.
    if (scan > 0 && scan < 1) {
      canvas.save();
      canvas.clipRRect(sheet);
      final y = _sheet.top + _sheet.height * scan;
      final trail = Rect.fromLTRB(_sheet.left, y - 9, _sheet.right, y);
      canvas.drawRect(
        trail,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [accent.withValues(alpha: 0), accent.withValues(alpha: 0.35)],
          ).createShader(trail),
      );
      canvas.drawRect(
        Rect.fromLTRB(_sheet.left, y - 0.6, _sheet.right, y + 0.6),
        Paint()..color = accent,
      );
      canvas.restore();
    }

    final pixel = Paint()..color = Color.lerp(paper, accent, tint)!;
    _drawPixel(canvas, _pixelA, 1.5, firstPixel, pixel);
    _drawPixel(canvas, _pixelB, 1, secondPixel, pixel);
    canvas.restore();
  }

  void _drawPixel(Canvas canvas, Rect rect, double radius, double scale, Paint paint) {
    final scaled = Rect.fromCenter(
      center: rect.center,
      width: rect.width * scale,
      height: rect.height * scale,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(scaled, Radius.circular(radius * scale)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      oldDelegate.scan != scan ||
      oldDelegate.firstPixel != firstPixel ||
      oldDelegate.secondPixel != secondPixel ||
      oldDelegate.tint != tint ||
      oldDelegate.accent != accent;
}

/// The name, dim until the beam has passed over it.
class _Wordmark extends StatelessWidget {
  const _Wordmark({
    required this.text,
    required this.progress,
    required this.style,
    required this.dim,
    required this.beam,
  });

  final String text;
  final double progress;
  final TextStyle style;
  final Color dim;
  final Color beam;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // The unlit page: the word is already there, waiting for the light.
        Text(text, style: style.copyWith(color: dim)),
        // Everything the beam has crossed, lit.
        ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [
              Colors.white,
              Colors.white,
              Colors.transparent,
              Colors.transparent,
            ],
            stops: [0, progress, (progress + 0.04).clamp(0, 1), 1],
          ).createShader(rect),
          child: Text(text, style: style),
        ),
        // The beam itself, a soft vertical band riding the edge.
        Positioned.fill(
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0001, 1),
            child: Align(
              alignment: Alignment.centerRight,
              child: Opacity(
                // Fades out as it leaves the last letter.
                opacity: progress >= 1 ? 0 : 1,
                child: Container(
                  width: 18,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: beam, width: 2)),
                    gradient: LinearGradient(
                      colors: [
                        beam.withValues(alpha: 0),
                        beam.withValues(alpha: 0.30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
