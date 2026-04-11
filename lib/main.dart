import 'dart:ui';
import 'dart:math' as math;
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
      title: 'PixelPaper Pro',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: app.seedColor,
        brightness: Brightness.light,
        fontFamily: 'Roboto', // Replace with SF Pro if you have it
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: app.seedColor,
        brightness: Brightness.dark,
      ),
      themeMode: app.themeMode,
      builder: (context, child) {
        final screenSize = MediaQuery.sizeOf(context);
        final isDesktopOrTablet = screenSize.width > 600;

        if (!isDesktopOrTablet) {
          return child!;
        }

        // The Ultra-Real Desktop Presentation
        return Scaffold(
          backgroundColor: Colors.white, // Base canvas
          body: ProCinematicBackground(
            appState: app,
            child: Center(child: UltraRealPhoneFrame(child: child!)),
          ),
        );
      },
      home: const MainScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// PRO CINEMATIC MESH BACKGROUND (Pure Flutter, No Assets)
// Mimics the deep, smooth, slow-moving aura of Apple product pages.
// -----------------------------------------------------------------------------
class ProCinematicBackground extends StatefulWidget {
  final Widget child;
  final AppState appState;

  const ProCinematicBackground({
    super.key,
    required this.child,
    required this.appState,
  });

  @override
  State<ProCinematicBackground> createState() => _ProCinematicBackgroundState();
}

class _ProCinematicBackgroundState extends State<ProCinematicBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 25-second ultra-smooth orbit
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Pitch Black Base
        Container(color: const Color(0xFF030303)),

        // Moving Mesh Gradients
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value * 2 * math.pi;

            // Complex orbital math for organic movement
            final x1 = math.cos(t) * 0.5;
            final y1 = math.sin(t) * 0.5;

            final x2 = math.cos(t + math.pi) * 0.6;
            final y2 = math.sin(t * 1.5) * 0.4;

            final primaryThemeColor = widget.appState.seedColor;

            return Stack(
              children: [
                // Highlight Orb 1
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(x1, y1),
                      radius: 1.8,
                      colors: [
                        primaryThemeColor.withOpacity(0.12),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
                // Highlight Orb 2 (Slightly shifted hue for depth)
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(x2, y2),
                      radius: 1.5,
                      colors: [
                        primaryThemeColor.withOpacity(0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        // Global Blur to smooth everything into a silky aura
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: Container(color: Colors.transparent),
        ),

        // Foreground Content
        widget.child,
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// ULTRA REAL TITANIUM PHONE FRAME
// Photorealistic simulation of an iPhone 15/16 Pro
// -----------------------------------------------------------------------------
class UltraRealPhoneFrame extends StatefulWidget {
  final Widget child;

  const UltraRealPhoneFrame({super.key, required this.child});

  @override
  State<UltraRealPhoneFrame> createState() => _UltraRealPhoneFrameState();
}

class _UltraRealPhoneFrameState extends State<UltraRealPhoneFrame> {
  bool _isHovered = false;

  // Exact Logical Screen Dimensions (Pro Max)
  final double screenWidth = 430;
  final double screenHeight = 932;

  // Physical device measurements
  final double titaniumBandThickness = 4.0;
  final double innerGlassBezel = 10.0;
  final double outerRadius = 58.0;

  @override
  Widget build(BuildContext context) {
    // Total physical size
    final frameWidth =
        screenWidth + ((titaniumBandThickness + innerGlassBezel) * 2);
    final frameHeight =
        screenHeight + ((titaniumBandThickness + innerGlassBezel) * 2);
    final innerRadius = outerRadius - titaniumBandThickness;
    final screenRadius = innerRadius - innerGlassBezel;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: FittedBox(
          fit: BoxFit.contain,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic, // Heavy, realistic lifting physics
            transform: _isHovered
                ? (Matrix4.identity()
                    ..scale(1.015)
                    ..translate(0.0, -12.0))
                : Matrix4.identity(),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // 1. HARDWARE BUTTONS & ANTENNA BANDS
                _buildHardwareDetails(frameWidth, frameHeight),

                // 2. TITANIUM OUTER BAND
                Container(
                  width: frameWidth,
                  height: frameHeight,
                  padding: EdgeInsets.all(titaniumBandThickness),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(outerRadius),
                    // Multi-stop metallic gradient for photorealism
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: [0.0, 0.2, 0.5, 0.8, 1.0],
                      colors: [
                        Color(0xFFB0B0B5), // Highlight
                        Color(0xFF5A5A5E), // Midtone
                        Color(0xFF333336), // Shadow
                        Color(0xFF6C6C70), // Bounce light
                        Color(0xFFD1D1D6), // Edge highlight
                      ],
                    ),
                    boxShadow: [
                      // Contact Shadow (Sharp, dark)
                      BoxShadow(
                        color: Colors.black.withOpacity(_isHovered ? 0.3 : 0.6),
                        blurRadius: _isHovered ? 30 : 15,
                        spreadRadius: -5,
                        offset: Offset(0, _isHovered ? 20 : 10),
                      ),
                      // Ambient Occlusion Shadow (Huge, soft, colored)
                      BoxShadow(
                        color: Colors.black.withOpacity(_isHovered ? 0.7 : 0.4),
                        blurRadius: _isHovered ? 100 : 60,
                        spreadRadius: _isHovered ? 15 : 5,
                        offset: Offset(0, _isHovered ? 50 : 25),
                      ),
                    ],
                  ),

                  // 3. INNER GLASS BEZEL (True Black)
                  child: Container(
                    padding: EdgeInsets.all(innerGlassBezel),
                    decoration: BoxDecoration(
                      color: Colors.black, // The black screen border
                      borderRadius: BorderRadius.circular(innerRadius),
                      // Faint inner rim light where glass meets metal
                      border: Border.all(
                        color: Colors.white.withOpacity(0.05),
                        width: 0.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // 4. THE ACTUAL APP SCREEN
                        ClipRRect(
                          borderRadius: BorderRadius.circular(screenRadius),
                          child: SizedBox(
                            width: screenWidth,
                            height: screenHeight,
                            child: MediaQuery(
                              // Perfect mobile safe area injection
                              data: MediaQuery.of(context).copyWith(
                                size: Size(screenWidth, screenHeight),
                                padding: const EdgeInsets.only(
                                  top: 59,
                                  bottom: 34,
                                ),
                              ),
                              child: widget.child,
                            ),
                          ),
                        ),

                        // 5. SCREEN GLARE REFLECTION (Diagonal cut)
                        IgnorePointer(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(screenRadius),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  stops: const [0.0, 0.45, 0.45, 1.0],
                                  colors: [
                                    Colors.white.withOpacity(0.06),
                                    Colors.white.withOpacity(0.01),
                                    Colors.transparent,
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 6. PHOTOREALISTIC DYNAMIC ISLAND
                        Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 11.0),
                            child: _buildDynamicIsland(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- PHOTOREALISTIC DYNAMIC ISLAND ---
  Widget _buildDynamicIsland() {
    return Container(
      width: 125,
      height: 37,
      decoration: BoxDecoration(
        color: const Color(0xFF000000), // Pure black
        borderRadius: BorderRadius.circular(18.5),
        // Extremely subtle hardware bevel lighting
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.06),
            blurRadius: 1,
            spreadRadius: 0,
            offset: const Offset(0, 0.5), // Tiny bottom highlight
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 2,
            spreadRadius: 1,
            offset: const Offset(0, -1), // Inner top shadow
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // TrueDepth Camera Sensor Array (Left side faint red/purple tint)
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(
                      0xFF1A1120,
                    ).withOpacity(0.8), // Faint infrared look
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Front Camera Lens (Right side blue/green reflection)
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(
                  0xFF050508,
                ), // Slightly lighter than pure black
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 0.5,
                ),
                boxShadow: [
                  // Internal lens reflection
                  BoxShadow(
                    color: const Color(0xFF2B4C7E).withOpacity(0.4),
                    blurRadius: 3,
                    offset: const Offset(-1, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HARDWARE BUTTONS & ANTENNAS ---
  Widget _buildHardwareDetails(double frameWidth, double frameHeight) {
    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ANTENNA BANDS (Top & Bottom edges)
          Positioned(
            top: -1,
            left: 80,
            child: _buildAntenna(width: 4, height: 2),
          ),
          Positioned(
            top: -1,
            right: 80,
            child: _buildAntenna(width: 4, height: 2),
          ),
          Positioned(
            bottom: -1,
            left: 80,
            child: _buildAntenna(width: 4, height: 2),
          ),
          Positioned(
            bottom: -1,
            right: 80,
            child: _buildAntenna(width: 4, height: 2),
          ),

          // ACTION BUTTON (Left)
          Positioned(left: -3, top: 200, child: _buildButton(height: 32)),

          // VOLUME UP (Left)
          Positioned(left: -3, top: 260, child: _buildButton(height: 65)),

          // VOLUME DOWN (Left)
          Positioned(left: -3, top: 340, child: _buildButton(height: 65)),

          // POWER BUTTON (Right)
          Positioned(right: -3, top: 290, child: _buildButton(height: 100)),
        ],
      ),
    );
  }

  Widget _buildButton({required double height}) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        // Metallic gradient for the buttons
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6C6C70), Color(0xFF8E8E93), Color(0xFF48484A)],
        ),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.black.withOpacity(0.5), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 2,
            offset: const Offset(-1, 0), // Shadow pushing inward
          ),
        ],
      ),
    );
  }

  Widget _buildAntenna({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF3A3A3C), // Dark matte plastic antenna color
    );
  }
}
