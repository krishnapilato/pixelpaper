import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'app_state.dart';
import 'gallery_screen.dart';
import 'files_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isMenuOpen = false;

  late PageController _pageController;
  late AnimationController _menuController;

  late Animation<double> _menuScale;
  late Animation<double> _contentOpacity;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);

    _menuController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _menuScale = CurvedAnimation(
      parent: _menuController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    );

    _contentOpacity = CurvedAnimation(
      parent: _menuController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _menuController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _toggleMenu() async {
    if (_isMenuOpen) {
      HapticFeedback.lightImpact();
      await _menuController.reverse();
      if (mounted) setState(() => _isMenuOpen = false);
    } else {
      HapticFeedback.mediumImpact();
      setState(() => _isMenuOpen = true);
      _menuController.forward();
    }
  }

  Future<void> _handleAction(ImageSource source) async {
    await _toggleMenu();
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (image != null && mounted) {
      final bytes = await image.readAsBytes();
      await context.read<AppState>().saveImage(bytes);
      if (_currentIndex != 0) _onTabTapped(0);
      HapticFeedback.heavyImpact();
    }
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      HapticFeedback.selectionClick();
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_isMenuOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isMenuOpen) _toggleMenu();
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        extendBody: true,
        body: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // 1. CONTENT LAYER (PAGEVIEW)
            RepaintBoundary(
              child: PageView(
                controller: _pageController,
                physics: _isMenuOpen
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  if (_currentIndex != index) {
                    HapticFeedback.selectionClick();
                    setState(() => _currentIndex = index);
                  }
                },
                children: const [GalleryScreen(), FilesScreen()],
              ),
            ),

            // 2. BLUR OVERLAY
            if (_isMenuOpen)
              Positioned.fill(
                child: FadeTransition(
                  opacity: _menuController,
                  child: GestureDetector(
                    onTap: _toggleMenu,
                    behavior: HitTestBehavior.opaque,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        color: colorScheme.surface.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),

            // 3. MORPHING ACTION ISLAND (UX Bento Grid)
            if (_isMenuOpen) _buildActionIsland(app, colorScheme),

            // 4. FLOATING NAV DOCK
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: IgnorePointer(
                ignoring: _isMenuOpen,
                child: _buildFloatingDock(app, colorScheme),
              ),
            ),

            // 5. FAB ORB
            Positioned(bottom: 30, child: _buildOrbFab(colorScheme)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIsland(AppState app, ColorScheme colorScheme) {
    return Positioned(
      bottom: 124, // Positioned right above the FAB
      child: ScaleTransition(
        scale: _menuScale,
        alignment: Alignment.bottomCenter,
        child: FadeTransition(
          opacity: _contentOpacity,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // PRIMARY ACTION: High Contrast, Solid Color
              _buildBentoAction(
                icon: Icons.camera_alt_rounded,
                label: app.t('take_photo') ?? 'Camera',
                bgColor: colorScheme.primary,
                iconColor: colorScheme.onPrimary,
                textColor: colorScheme.onPrimary,
                isPrimary: true,
                onTap: () => _handleAction(ImageSource.camera),
              ),
              const SizedBox(width: 16),
              // SECONDARY ACTION: Low Contrast, Glass/Surface
              _buildBentoAction(
                icon: Icons.photo_library_rounded,
                label: app.t('import_photo') ?? 'Gallery',
                bgColor: colorScheme.surface,
                iconColor: colorScheme.secondary,
                textColor: colorScheme.onSurface,
                isPrimary: false,
                onTap: () => _handleAction(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBentoAction({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color iconColor,
    required Color textColor,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 140,
        height: 120,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: isPrimary
                  ? bgColor.withOpacity(0.4)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
          border: isPrimary
              ? null
              : Border.all(color: colorScheme.outline.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isPrimary
                    ? Colors.white.withOpacity(0.2)
                    : iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrbFab(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _menuController,
      builder: (context, child) {
        final val = _menuController.value;
        final bgColor = Color.lerp(colorScheme.primary, colorScheme.error, val);
        final iconColor = Color.lerp(
          colorScheme.onPrimary,
          colorScheme.onError,
          val,
        );
        final shadowColor = Color.lerp(
          colorScheme.primary.withOpacity(0.3),
          colorScheme.error.withOpacity(0.3),
          val,
        );

        return Container(
          height: 72,
          width: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: shadowColor ?? Colors.transparent,
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton.large(
            elevation: 0,
            focusElevation: 0,
            hoverElevation: 0,
            highlightElevation: 0,
            shape: const CircleBorder(),
            backgroundColor: bgColor,
            foregroundColor: iconColor,
            onPressed: _toggleMenu,
            child: Transform.rotate(
              angle: val * (math.pi / 4),
              child: const Icon(Icons.add_rounded, size: 40),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingDock(AppState app, ColorScheme colorScheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double barWidth = constraints.maxWidth;
        final double tabAreaWidth = (barWidth - 80) / 2;

        final double actualBulbWidth = math.min(100.0, tabAreaWidth - 16);
        const double bulbHeight = 58;

        final double tabCenter = _currentIndex == 0
            ? tabAreaWidth / 2
            : tabAreaWidth + 80 + (tabAreaWidth / 2);

        final double bulbLeftOffset = math.max(
          0,
          tabCenter - (actualBulbWidth / 2),
        );

        return AnimatedBuilder(
          animation: _menuController,
          builder: (context, child) {
            final double dockOpacity = 1.0 - (_menuController.value * 0.8);
            return Opacity(opacity: dockOpacity, child: child);
          },
          child: Container(
            height: 84,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withOpacity(0.95),
              borderRadius: BorderRadius.circular(42),
              border: Border.all(color: colorScheme.outline.withOpacity(0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 25,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  left: bulbLeftOffset,
                  top: (84 - bulbHeight) / 2,
                  child: Container(
                    width: actualBulbWidth,
                    height: bulbHeight,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildNavItem(
                        Icons.grid_view_rounded,
                        app.t('gallery'),
                        0,
                        colorScheme,
                      ),
                    ),
                    const SizedBox(width: 80), // FAB Space Hole
                    Expanded(
                      child: _buildNavItem(
                        Icons.folder_copy_rounded,
                        app.t('files'),
                        1,
                        colorScheme,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String? label,
    int index,
    ColorScheme colorScheme,
  ) {
    final isActive = _currentIndex == index;
    final color = isActive
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant.withOpacity(0.5);

    return InkWell(
      onTap: () => _onTabTapped(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: isActive ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              letterSpacing: isActive ? -0.3 : 0,
            ),
            child: Text(label ?? ''),
          ),
        ],
      ),
    );
  }
}
