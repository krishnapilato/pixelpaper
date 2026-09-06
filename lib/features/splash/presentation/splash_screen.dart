import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/dimens.dart';
import '../../documents/application/documents_controller.dart';
import '../../gallery/application/gallery_controller.dart';

/// The opening: a scanner beam sweeps the screen and writes the app's name.
///
/// The animation is the product in one gesture — paper on the left, the light
/// passes, pixels on the right. It runs for four seconds, and the archive and
/// the gallery load underneath while it plays, so the wait buys something
/// instead of only costing time. A tap skips it: a launch screen that cannot
/// be dismissed is the part of a splash people come to resent.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  bool _left = false;

  // The four acts, as fractions of the four seconds.
  static const Interval _rule = Interval(0.02, 0.30, curve: Curves.easeOut);
  static const Interval _sweep = Interval(0.12, 0.72, curve: Curves.easeInOut);
  static const Interval _caption = Interval(0.62, 0.82, curve: Curves.easeOut);
  static const Interval _outro = Interval(0.90, 1, curve: Curves.easeIn);

  @override
  void initState() {
    super.initState();
    _controller
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _enter();
      })
      ..forward();

    // Kick off the first reads now: by the time the beam finishes, the archive
    // is already in memory and the first screen paints with content.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
        ..read(documentsControllerProvider)
        ..read(galleryControllerProvider);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        onTap: _enter,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final sweep = _sweep.transform(t);
              final rule = _rule.transform(t);

              return Opacity(
                // Dissolve into the app instead of cutting: both surfaces are
                // the same dark, so the word simply fades off the first screen.
                opacity: 1 - _outro.transform(t),
                child: IntrinsicWidth(
                  // The rule and the caption take the width of the word, so
                  // the three lines read as one mark instead of three
                  // elements that happen to be stacked.
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Wordmark(
                        text: strings('app_name'),
                        progress: sweep,
                        style: theme.textTheme.displaySmall!.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: scheme.onSurface,
                        ),
                        dim: scheme.onSurface.withValues(alpha: 0.12),
                        beam: scheme.primary,
                      ),
                      const SizedBox(height: Space.md),
                      // The sheet edge: a rule that draws itself under the word.
                      FractionallySizedBox(
                        widthFactor: rule,
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
                        child: Text(
                          strings('app_motto'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            letterSpacing: 1.2,
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
      ),
    );
  }
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
                    // A bright edge with a short trail behind it: the edge is
                    // the light, the trail is where it has just been.
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
