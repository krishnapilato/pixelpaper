import 'dart:io';
import 'dart:ui';
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

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isMenuOpen = false;

  // PageController for smooth tab transitions
  late PageController _pageController;

  late AnimationController _animationController;
  late Animation<double> _backdropAnimation;
  late Animation<double> _button1Animation;
  late Animation<double> _button2Animation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _backdropAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _button1Animation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
    );

    _button2Animation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.9, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _toggleMenu() async {
    if (_isMenuOpen) {
      HapticFeedback.lightImpact();
      await _animationController.reverse();
      if (mounted) setState(() => _isMenuOpen = false);
    } else {
      HapticFeedback.mediumImpact();
      setState(() => _isMenuOpen = true);
      _animationController.forward();
    }
  }

  Future<void> _processImage(ImageSource source) async {
    await _toggleMenu();
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null && mounted) {
        final bytes = await image.readAsBytes();
        await context.read<AppState>().saveImage(bytes);

        // Smoothly slide back to gallery if not already there
        if (_currentIndex != 0) {
          _onTabTapped(0, context.read<AppState>());
        }

        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: colorScheme.onInverseSurface,
                ),
                const SizedBox(width: 12),
                const Text('Photo saved to gallery'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(24),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Extracted tab tapping logic to handle PageView animation
  void _onTabTapped(int index, AppState app) {
    if (_currentIndex != index) {
      HapticFeedback.selectionClick();
      app.clearImageSelection();
      app.clearPdfSelection();
      setState(() => _currentIndex = index);

      // Animate the page transition!
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final colorScheme = Theme.of(context).colorScheme;

    // PopScope intercepts the Android Back Button
    return PopScope(
      canPop: !_isMenuOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isMenuOpen) {
          // If the menu is open, close the menu instead of exiting the app
          _toggleMenu();
        }
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            // PageView instead of IndexedStack for buttery smooth swiping
            PageView(
              controller: _pageController,
              physics:
                  const NeverScrollableScrollPhysics(), // Disables manual swiping
              children: const [GalleryScreen(), FilesScreen()],
            ),

            // Animated Blur Overlay
            if (_isMenuOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggleMenu,
                  child: AnimatedBuilder(
                    animation: _backdropAnimation,
                    builder: (context, child) {
                      return BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 8 * _backdropAnimation.value,
                          sigmaY: 8 * _backdropAnimation.value,
                        ),
                        child: Container(
                          color: colorScheme.shadow.withOpacity(
                            0.3 * _backdropAnimation.value,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // Floating Action Menu
            if (_isMenuOpen) _buildActionMenu(app, colorScheme),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: _buildMainFab(colorScheme),
        bottomNavigationBar: _buildBottomBar(app, colorScheme),
      ),
    );
  }

  Widget _buildActionMenu(AppState app, ColorScheme colorScheme) {
    return Positioned(
      bottom: 150,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: Tween<double>(
              begin: 0.8,
              end: 1.0,
            ).animate(_button2Animation),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.4),
                end: Offset.zero,
              ).animate(_button2Animation),
              child: FadeTransition(
                opacity: _button2Animation,
                child: _menuButton(
                  icon: Icons.photo_library_rounded,
                  label: app.t('import_photo') ?? 'Import Photo',
                  onTap: () => _processImage(ImageSource.gallery),
                  colorScheme: colorScheme,
                  primaryColor: colorScheme.secondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ScaleTransition(
            scale: Tween<double>(
              begin: 0.8,
              end: 1.0,
            ).animate(_button1Animation),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.4),
                end: Offset.zero,
              ).animate(_button1Animation),
              child: FadeTransition(
                opacity: _button1Animation,
                child: _menuButton(
                  icon: Icons.camera_rounded,
                  label: app.t('take_photo') ?? 'Take Photo',
                  onTap: () => _processImage(ImageSource.camera),
                  colorScheme: colorScheme,
                  primaryColor: colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    required Color primaryColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 60),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(30),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: primaryColor.withOpacity(0.1),
          highlightColor: primaryColor.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center, // Now works perfectly
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: primaryColor, size: 22),
                ),
                const SizedBox(width: 16),
                Flexible(
                  // Replaced Expanded with Flexible
                  child: Text(
                    label,
                    textAlign: TextAlign.center, // Centered text alignment
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 0.3,
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

  Widget _buildMainFab(ColorScheme colorScheme) {
    final isMenuFullyOpen =
        _animationController.status == AnimationStatus.forward ||
        _animationController.status == AnimationStatus.completed;

    return AnimatedScale(
      scale: isMenuFullyOpen ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Tooltip(
        message: isMenuFullyOpen ? 'Close Menu' : 'Add Document',
        child: FloatingActionButton(
          shape: const CircleBorder(),
          elevation: isMenuFullyOpen ? 0 : 6,
          backgroundColor: isMenuFullyOpen
              ? colorScheme.errorContainer
              : colorScheme.primary,
          foregroundColor: isMenuFullyOpen
              ? colorScheme.onErrorContainer
              : colorScheme.onPrimary,
          onPressed: _toggleMenu,
          child: AnimatedRotation(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutBack,
            turns: isMenuFullyOpen ? 0.125 : 0,
            child: const Icon(Icons.add_rounded, size: 30),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(AppState app, ColorScheme colorScheme) {
    return BottomAppBar(
      height: 80,
      notchMargin: 12,
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      elevation: 10,
      shadowColor: colorScheme.shadow.withOpacity(0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: const CircularNotchedRectangle(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: _navItem(
              Icons.grid_view_rounded,
              app.t('gallery') ?? 'Gallery',
              0,
              app,
              colorScheme,
            ),
          ),
          const SizedBox(width: 80),
          Expanded(
            child: _navItem(
              Icons.folder_copy_rounded,
              app.t('files') ?? 'Files',
              1,
              app,
              colorScheme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label,
    int index,
    AppState app,
    ColorScheme colorScheme,
  ) {
    final isActive = _currentIndex == index;
    final activeColor = colorScheme.primary;
    final inactiveColor = colorScheme.onSurfaceVariant.withOpacity(0.6);

    return InkWell(
      onTap: () => _onTabTapped(index, app),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isActive ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: Icon(
                icon,
                color: isActive ? activeColor : inactiveColor,
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : inactiveColor,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
