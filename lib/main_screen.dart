import 'dart:io';
import 'dart:ui'; // Required for BackdropFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptics
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
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
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      value: 0,
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.fastOutSlowIn,
    );
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _animationController.forward();
        HapticFeedback.mediumImpact();
      } else {
        _animationController.reverse();
        HapticFeedback.lightImpact();
      }
    });
  }

  Future<void> _processImage(ImageSource source) async {
    _toggleMenu();
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null && mounted) {
        // 1. Read the bytes from the picked image
        final bytes = await image.readAsBytes();

        // 2. Save it directly to your AppState/Storage
        await context.read<AppState>().saveImage(bytes);

        // 3. Switch to Gallery tab to show the new photo
        setState(() => _currentIndex = 0);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Photo saved to gallery')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: true, // Allows content to flow behind the navigation bar
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: const [GalleryScreen(), FilesScreen()],
          ),

          // Blur Overlay
          if (_isMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleMenu,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(color: Colors.black.withOpacity(0.2)),
                ),
              ),
            ),

          // Animated Action Menu
          if (_isMenuOpen) _buildActionMenu(app, colorScheme),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildMainFab(colorScheme),
      bottomNavigationBar: _buildBottomBar(app, colorScheme),
    );
  }

  Widget _buildActionMenu(AppState app, ColorScheme colorScheme) {
    return Positioned(
      bottom: 150,
      left: 0,
      right: 0,
      child: ScaleTransition(
        scale: _expandAnimation,
        child: FadeTransition(
          opacity: _expandAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _menuButton(
                icon: Icons.camera_rounded,
                label: app.t('take_photo'),
                onTap: () => _processImage(ImageSource.camera),
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              _menuButton(
                icon: Icons.photo_library_rounded,
                label: app.t('import_photo'),
                onTap: () => _processImage(ImageSource.gallery),
                color: colorScheme.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        heroTag: label,
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: color,
      ),
    );
  }

  Widget _buildMainFab(ColorScheme colorScheme) {
    return AnimatedRotation(
      duration: const Duration(milliseconds: 300),
      turns: _isMenuOpen ? 0.125 : 0, // 45 degree rotation
      child: FloatingActionButton(
        shape: const CircleBorder(),
        elevation: 4,
        backgroundColor: _isMenuOpen ? Colors.white : colorScheme.primary,
        onPressed: _toggleMenu,
        child: Icon(
          Icons.add,
          size: 32,
          color: _isMenuOpen ? Colors.redAccent : colorScheme.onPrimary,
        ),
      ),
    );
  }

  Widget _buildBottomBar(AppState app, ColorScheme colorScheme) {
    return BottomAppBar(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 70,
      notchMargin: 10,
      shape: const CircularNotchedRectangle(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.grid_view_rounded, app.t('gallery'), 0, app),
          const SizedBox(width: 40), // Space for FAB
          _navItem(Icons.folder_copy_rounded, app.t('files'), 1, app),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index, AppState app) {
    final isActive = _currentIndex == index;
    return InkWell(
      onTap: () {
        app.clearImageSelection();
        app.clearPdfSelection();
        setState(() => _currentIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
              size: 26,
            ),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
