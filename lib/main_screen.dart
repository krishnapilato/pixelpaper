import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

// Assuming these exist in your project:
import 'app_state.dart';
import 'gallery_screen.dart';
import 'files_screen.dart';
import 'widgets/fluid_bounce.dart';

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
      HapticFeedback.lightImpact();
      setState(() => _currentIndex = index);
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  Future<void> _showAddMenu(BuildContext context, AppState app) async {
    HapticFeedback.mediumImpact();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: false,
      elevation: 0,
      barrierColor: colorScheme.shadow.withValues(alpha: isDark ? 0.4 : 0.2),
      builder: (sheetContext) => _ProActionSheet(
        app: app,
        onActionSelect: (selectedSource) {
          if (sheetContext.mounted) {
            Navigator.of(sheetContext).pop(selectedSource);
          }
        },
      ),
    );

    if (source != null && mounted) {
      await _handleAction(source, app);
    }
  }

  Future<void> _handleAction(ImageSource source, AppState app) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 100,
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

    if (app.isInitialLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        statusBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        extendBody: true,
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
        bottomNavigationBar: _GlassDock(
          currentIndex: _currentIndex,
          onTabTapped: _onTabTapped,
          onFabTapped: () => _showAddMenu(context, app),
          app: app,
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------
/// APPLE PRO STYLE GLASS DOCK
/// ---------------------------------------------------------
class _GlassDock extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabTapped;
  final VoidCallback onFabTapped;
  final AppState app;

  const _GlassDock({
    required this.currentIndex,
    required this.onTabTapped,
    required this.onFabTapped,
    required this.app,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomPadding == 0 ? 24.0 : bottomPadding + 8.0,
        left: 32,
        right: 32,
      ),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: isDark ? 0.5 : 0.7),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: colorScheme.onSurface.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _DockItem(
                      icon: Icons.collections_rounded,
                      label: app.t('gallery'),
                      isActive: currentIndex == 0,
                      onTap: () => onTabTapped(0),
                    ),
                  ),
                  _DockFab(onTap: onFabTapped),
                  Expanded(
                    child: _DockItem(
                      icon: Icons.folder_copy_rounded,
                      label: app.t('files'),
                      isActive: currentIndex == 1,
                      onTap: () => onTabTapped(1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _DockItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isActive ? colorScheme.onSurface : colorScheme.onSurface.withValues(alpha: 0.4);

    return Semantics(
      button: true,
      label: label,
      selected: isActive,
      child: ProFluidBounce(
        onTap: onTap,
        child: Container(
          color: Colors.transparent, // Ensures hit testing
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<Color?>(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                tween: ColorTween(end: color),
                builder: (context, animatedColor, child) {
                  return Icon(icon, color: animatedColor, size: 26);
                },
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: -0.2,
                ),
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockFab extends StatelessWidget {
  final VoidCallback onTap;

  const _DockFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'Add Media',
      child: ProFluidBounce(
        onTap: onTap,
        child: Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            color: colorScheme.onSurface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colorScheme.onSurface.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(Icons.add_rounded, color: colorScheme.surface, size: 28),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------
/// APPLE PRO LEVEL BENTO ACTION SHEET
/// ---------------------------------------------------------
class _ProActionSheet extends StatelessWidget {
  final AppState app;
  final Function(ImageSource) onActionSelect;

  const _ProActionSheet({required this.app, required this.onActionSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      bottom: false, // Handled manually below
      child: Container(
        margin: const EdgeInsets.all(16).copyWith(bottom: bottomPadding + 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 40,
              spreadRadius: -10,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              color: colorScheme.surface.withValues(alpha: isDark ? 0.6 : 0.8),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Minimal Drag Indicator
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    app.t('add_content'),
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    app.t('choose_source'),
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 32),

                  // Pro Bento Grid
                  Row(
                    children: [
                      Expanded(
                        child: _ProBentoCard(
                          icon: Icons.camera_rounded,
                          title: app.t('take_photo'),
                          isPrimary: true,
                          onTap: () => onActionSelect(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _ProBentoCard(
                          icon: Icons.photo_library_rounded,
                          title: app.t('import_photo'),
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
      ),
    );
  }
}

class _ProBentoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ProBentoCard({
    required this.icon,
    required this.title,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isPrimary
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: isDark ? 0.1 : 0.05);
    final fgColor = isPrimary ? colorScheme.surface : colorScheme.onSurface;

    return Semantics(
      button: true,
      label: title,
      child: ProFluidBounce(
        onTap: onTap,
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colorScheme.onSurface.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? colorScheme.surface.withValues(alpha: 0.2)
                        : colorScheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: fgColor, size: 28),
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: fgColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
