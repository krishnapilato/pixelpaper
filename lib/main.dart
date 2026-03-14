import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'main_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const DocScannerApp(),
    ),
  );
}

class DocScannerApp extends StatelessWidget {
  const DocScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PixelPaper',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: app.seedColor,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: app.seedColor,
        brightness: Brightness.dark,
      ),
      themeMode: app.themeMode,

      builder: (context, child) {
        final screenSize = MediaQuery.sizeOf(context);
        // If width is < 600, it's a mobile phone.
        final isDesktopOrTablet = screenSize.width > 600;

        // This ensures actual phones get the normal Android full-screen UI!
        if (!isDesktopOrTablet) {
          return child!;
        }

        // Desktop/Tablet users get the premium animated showcase
        return Scaffold(
          body: AnimatedProfessionalBackground(
            child: Center(child: InteractiveGlassPhoneFrame(child: child!)),
          ),
        );
      },

      home: const MainScreen(),
    );
  }
}

/// Creates a smooth, slow-pulsing professional gradient background
class AnimatedProfessionalBackground extends StatefulWidget {
  final Widget child;
  const AnimatedProfessionalBackground({super.key, required this.child});

  @override
  State<AnimatedProfessionalBackground> createState() =>
      _AnimatedProfessionalBackgroundState();
}

class _AnimatedProfessionalBackgroundState
    extends State<AnimatedProfessionalBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Alignment> _topAlignment;
  late Animation<Alignment> _bottomAlignment;

  @override
  void initState() {
    super.initState();
    // 8-second slow, luxurious pulse
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    // Animate the gradient alignment to create a shifting/flowing effect
    _topAlignment = TweenSequence<Alignment>([
      TweenSequenceItem(
        tween: AlignmentTween(
          begin: Alignment.topLeft,
          end: Alignment.topRight,
        ),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: AlignmentTween(
          begin: Alignment.topRight,
          end: Alignment.topLeft,
        ),
        weight: 1,
      ),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _bottomAlignment = TweenSequence<Alignment>([
      TweenSequenceItem(
        tween: AlignmentTween(
          begin: Alignment.bottomRight,
          end: Alignment.bottomLeft,
        ),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: AlignmentTween(
          begin: Alignment.bottomLeft,
          end: Alignment.bottomRight,
        ),
        weight: 1,
      ),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              // Professional corporate colors: Deep Slate, Midnight Blue, Dark Teal
              colors: const [
                Color(0xFF0F2027),
                Color(0xFF203A43),
                Color(0xFF2C5364),
              ],
              begin: _topAlignment.value,
              end: _bottomAlignment.value,
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

class InteractiveGlassPhoneFrame extends StatefulWidget {
  final Widget child;

  const InteractiveGlassPhoneFrame({super.key, required this.child});

  @override
  State<InteractiveGlassPhoneFrame> createState() =>
      _InteractiveGlassPhoneFrameState();
}

class _InteractiveGlassPhoneFrameState
    extends State<InteractiveGlassPhoneFrame> {
  bool _isHovered = false;

  // Massive logical dimensions for the phone
  final double phoneWidth = 540;
  final double phoneHeight = 1160;
  final double bezelThickness = 24.0;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
        child: FittedBox(
          fit: BoxFit.contain,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutExpo, // Super smooth pop animation
            width: phoneWidth,
            height: phoneHeight,
            transform: _isHovered
                ? (Matrix4.identity()
                    ..scale(1.02)
                    ..translate(0.0, -10.0))
                : Matrix4.identity(),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  // Darker, softer drop shadow for realism
                  color: Colors.black.withOpacity(_isHovered ? 0.6 : 0.4),
                  blurRadius: _isHovered ? 80 : 40,
                  spreadRadius: _isHovered ? 15 : 5,
                  offset: Offset(0, _isHovered ? 30 : 15),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(60),
              child: BackdropFilter(
                // Intense blur for premium glassmorphism
                filter: ImageFilter.blur(sigmaX: 40.0, sigmaY: 40.0),
                child: Container(
                  padding: EdgeInsets.all(bezelThickness),
                  decoration: BoxDecoration(
                    // Dark Frosted Glass look
                    color: Colors.white.withOpacity(0.03),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      // Subtle shine on the edges of the glass
                      color: Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        size: Size(
                          phoneWidth - (bezelThickness * 2),
                          phoneHeight - (bezelThickness * 2),
                        ),
                      ),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
