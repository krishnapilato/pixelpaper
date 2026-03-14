import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

// Assuming these exist in your project:
import 'app_state.dart';
import 'gallery_screen.dart';
import 'files_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      HapticFeedback.selectionClick();
      setState(() => _currentIndex = index);
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastEaseInToSlowEaseOut,
      );
    }
  }

  Future<void> _showAddMenu(BuildContext context, AppState app) async {
    HapticFeedback.mediumImpact();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Theme.of(context).colorScheme.shadow.withOpacity(0.4),
      builder: (context) => _MediaActionSheet(
        app: app,
        onActionSelect: (source) => _handleAction(source, app),
      ),
    );
  }

  Future<void> _handleAction(ImageSource source, AppState app) async {
    Navigator.of(context).pop(); // Close the bottom sheet

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (image != null && mounted) {
      final bytes = await image.readAsBytes();
      await app.saveImage(bytes);

      if (_currentIndex != 0) _onTabTapped(0);
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      extendBody: true, // Allows the PageView to scroll behind the nav bar
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) {
          if (_currentIndex != index) {
            HapticFeedback.selectionClick();
            setState(() => _currentIndex = index);
          }
        },
        children: const [GalleryScreen(), FilesScreen()],
      ),

      // Floating Pill Navigation Dock
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20.0, left: 24, right: 24),
          child: _buildFloatingDock(app, colorScheme),
        ),
      ),
    );
  }

  Widget _buildFloatingDock(AppState app, ColorScheme colorScheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(isDark ? 0.75 : 0.9),
              border: Border.all(
                color: colorScheme.outline.withOpacity(isDark ? 0.15 : 0.05),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(36),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildNavItem(
                    icon: Icons.grid_view_rounded,
                    label: app.t('gallery') ?? 'Gallery',
                    index: 0,
                    colorScheme: colorScheme,
                  ),
                ),
                _buildFab(app, colorScheme, isDark),
                Expanded(
                  child: _buildNavItem(
                    icon: Icons.folder_copy_rounded,
                    label: app.t('files') ?? 'Files',
                    index: 1,
                    colorScheme: colorScheme,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required ColorScheme colorScheme,
  }) {
    final isActive = _currentIndex == index;
    final color = isActive ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isActive ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: isActive ? -0.2 : 0,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab(AppState app, ColorScheme colorScheme, bool isDark) {
    return InteractiveBounce(
      onTap: () => _showAddMenu(context, app),
      child: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
          border: isDark
              ? Border.all(color: Colors.white.withOpacity(0.15), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(isDark ? 0.5 : 0.4),
              blurRadius: isDark ? 24 : 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(Icons.add_rounded, color: colorScheme.onPrimary, size: 32),
      ),
    );
  }
}

/// ---------------------------------------------------------
/// MODERN FROSTED BOTTOM SHEET FOR ACTIONS
/// ---------------------------------------------------------
class _MediaActionSheet extends StatelessWidget {
  final AppState app;
  final Function(ImageSource) onActionSelect;

  const _MediaActionSheet({required this.app, required this.onActionSelect});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(isDark ? 0.85 : 0.95),
            border: Border(
              top: BorderSide(
                color: colorScheme.outline.withOpacity(isDark ? 0.2 : 0.05),
                width: 1.5,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding + 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Drag Handle
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 24),

                // Header
                Text(
                  app.t('add_content') ?? 'Add Media',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  app.t('choose_source') ??
                      'Choose a source to import an image',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                // Bento Grid Actions
                Row(
                  children: [
                    Expanded(
                      child: _BentoActionCard(
                        icon: Icons.camera_alt_rounded,
                        title: app.t('take_photo') ?? 'Camera',
                        subtitle: app.t('Capture now') ?? 'Capture now',
                        isPrimary: true,
                        onTap: () => onActionSelect(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _BentoActionCard(
                        icon: Icons.photo_library_rounded,
                        title: app.t('import_photo') ?? 'Gallery',
                        subtitle: app.t('Browse device') ?? 'Browse device',
                        isPrimary: false,
                        onTap: () => onActionSelect(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BentoActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isPrimary;
  final VoidCallback onTap;

  const _BentoActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isPrimary
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest.withOpacity(isDark ? 0.5 : 1.0);

    final textColor = isPrimary ? colorScheme.onPrimary : colorScheme.onSurface;

    final iconBgColor = isPrimary
        ? Colors.white.withOpacity(0.2)
        : colorScheme.surface;

    return InteractiveBounce(
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(28),
          border: isPrimary
              ? (isDark
                    ? Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1.5,
                      )
                    : null)
              : Border.all(
                  color: colorScheme.outline.withOpacity(isDark ? 0.15 : 0.05),
                  width: 1.5,
                ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(isDark ? 0.4 : 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                  border: !isPrimary && isDark
                      ? Border.all(color: colorScheme.outline.withOpacity(0.2))
                      : null,
                ),
                child: Icon(icon, color: textColor, size: 28),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textColor.withOpacity(isDark ? 0.6 : 0.7),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------
/// MICRO-INTERACTION WRAPPER (Professional iOS-like Bounce)
/// ---------------------------------------------------------
class InteractiveBounce extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const InteractiveBounce({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  State<InteractiveBounce> createState() => _InteractiveBounceState();
}

class _InteractiveBounceState extends State<InteractiveBounce>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) => _controller.forward();

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}
