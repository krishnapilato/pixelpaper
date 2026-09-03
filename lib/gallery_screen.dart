import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'app_state.dart';
import 'settings_modal.dart';
import 'widgets/fluid_bounce.dart';

// -----------------------------------------------------------------------------
// GALLERY SCREEN
// -----------------------------------------------------------------------------
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  void _showSavePdfSheet(BuildContext context, AppState app) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(
      text: "Doc_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}",
    );

    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: colorScheme.shadow.withOpacity(isDark ? 0.5 : 0.3),
      builder: (context) {
        final viewInsets = MediaQuery.viewInsetsOf(context);
        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface.withOpacity(isDark ? 0.7 : 0.9),
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.onSurface.withOpacity(0.08),
                      width: 0.5,
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Icon(
                        Icons.picture_as_pdf_rounded,
                        color: colorScheme.onSurface,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        app.t('create_pdf'),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colorScheme.onSurface.withOpacity(0.08),
                          ),
                        ),
                        child: TextField(
                          controller: nameController,
                          autofocus: true,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            suffixText: '.pdf',
                            suffixStyle: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.4),
                              fontWeight: FontWeight.w600,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: ProFluidBounce(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: colorScheme.onSurface.withOpacity(
                                    0.05,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  app.t('cancel') ?? 'Cancel',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ProFluidBounce(
                              onTap: () async {
                                if (nameController.text.trim().isEmpty) return;
                                Navigator.pop(context);
                                final success = await app.generatePDF(
                                  nameController.text.trim(),
                                );
                                if (context.mounted && success) {
                                  HapticFeedback.heavyImpact();
                                  _showProToast(
                                    context,
                                    app.t('pdf_generated_success') ??
                                        'PDF created successfully',
                                    Icons.check_circle_rounded,
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: colorScheme.onSurface,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  app.t('save') ?? 'Export',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.surface,
                                  ),
                                ),
                              ),
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
      },
    );
  }

  void _showDeleteConfirm(
    BuildContext context,
    AppState app, {
    bool isSingle = false,
    VoidCallback? onConfirm,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: colorScheme.shadow.withOpacity(isDark ? 0.5 : 0.3),
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            color: colorScheme.surface.withOpacity(isDark ? 0.7 : 0.9),
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              MediaQuery.paddingOf(context).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  app.t('delete_confirm') ??
                      (isSingle ? 'Delete Photo?' : 'Delete Photos?'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  app.t('delete_confirm_msg'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: ProFluidBounce(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            app.t('cancel') ?? 'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ProFluidBounce(
                        onTap: () {
                          HapticFeedback.heavyImpact();
                          if (onConfirm != null) {
                            onConfirm();
                          } else {
                            app.deleteSelectedImages();
                            Navigator.pop(context);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            app.t('delete') ?? 'Delete',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
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

  void _showProToast(BuildContext context, String message, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Safely capture messenger
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          bottom: 100,
          left: 24,
          right: 24,
        ), // Avoid docks
        padding: EdgeInsets.zero,
        content: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(isDark ? 0.9 : 0.85),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: colorScheme.surface, size: 20),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: colorScheme.surface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final colorScheme = Theme.of(context).colorScheme;
    final double safeAreaTop = MediaQuery.paddingOf(context).top;

    final selectedList = app.selectedImages.toList();
    final bool isSelection = app.isImageSelectionMode;
    final bool isAllSelected =
        app.selectedImages.length == app.images.length && app.images.isNotEmpty;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. MAIN GRID
          Positioned.fill(
            child: app.images.isEmpty
                ? _buildEmptyState(context, app, colorScheme)
                : RefreshIndicator(
                    onRefresh: () async => await app.loadData(),
                    edgeOffset: safeAreaTop + 90,
                    child: GridView.builder(
                      key: const PageStorageKey('gallery_grid'),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        safeAreaTop + 104,
                        16,
                        140,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: app.gridColumns,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: app.images.length,
                      itemBuilder: (context, index) {
                        final file = app.images[index];
                        final selectionIndex = selectedList.indexOf(file.path);
                        final isSelected = selectionIndex != -1;

                        return ProFluidBounce(
                          onLongPress: () {
                            HapticFeedback.heavyImpact();
                            app.toggleImageSelection(file.path);
                          },
                          onTap: () {
                            if (isSelection) {
                              HapticFeedback.selectionClick();
                              app.toggleImageSelection(file.path);
                            } else {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  transitionDuration: const Duration(
                                    milliseconds: 350,
                                  ),
                                  reverseTransitionDuration: const Duration(
                                    milliseconds: 350,
                                  ),
                                  pageBuilder: (context, anim, secAnim) {
                                    return FadeTransition(
                                      opacity: anim,
                                      child: FullScreenImage(
                                        images: app.images,
                                        initialIndex: index,
                                      ),
                                    );
                                  },
                                ),
                              );
                            }
                          },
                          child: Hero(
                            tag: file.path,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              transform: Matrix4.identity()
                                ..scaleByDouble(isSelected ? 0.92 : 1.0),
                              transformAlignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(file, fit: BoxFit.cover),
                                    // Dimmer overlay for selected
                                    AnimatedOpacity(
                                      opacity: isSelected ? 0.4 : 0.0,
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      child: Container(color: Colors.black),
                                    ),
                                    // Pro Selection Badge
                                    if (isSelection)
                                      Positioned(
                                        top: 10,
                                        right: 10,
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          transitionBuilder: (child, anim) =>
                                              ScaleTransition(
                                                scale: anim,
                                                child: child,
                                              ),
                                          child: isSelected
                                              ? Container(
                                                  key: const ValueKey(
                                                    'selected',
                                                  ),
                                                  width: 26,
                                                  height: 26,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        colorScheme.onSurface,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color:
                                                          colorScheme.surface,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      '${selectionIndex + 1}',
                                                      style: TextStyle(
                                                        color:
                                                            colorScheme.surface,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : Container(
                                                  key: const ValueKey(
                                                    'unselected',
                                                  ),
                                                  width: 26,
                                                  height: 26,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.2),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Colors.white,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),

          // 2. DYNAMIC ISLAND HEADER
          Positioned(
            top: safeAreaTop > 0 ? safeAreaTop + 12 : 24,
            left: 20,
            right: 20,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.5),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: isSelection
                  ? _buildSelectionHeader(
                      context,
                      app,
                      isAllSelected,
                      colorScheme,
                    )
                  : _buildNormalHeader(context, app, colorScheme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalHeader(
    BuildContext context,
    AppState app,
    ColorScheme colorScheme,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      key: const ValueKey('normal_header'),
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: colorScheme.surface.withOpacity(isDark ? 0.6 : 0.8),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    app.t('gallery'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      fontSize: 18,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                ProFluidBounce(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    app.toggleGalleryGrid();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      app.gridColumns == 2
                          ? Icons.grid_view_rounded
                          : Icons.grid_on_rounded,
                      size: 20,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ProFluidBounce(
                  onTap: () => showSettingsModal(
                    context,
                    app,
                  ), // Using the cohesive settings modal
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: colorScheme.onSurface,
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

  Widget _buildSelectionHeader(
    BuildContext context,
    AppState app,
    bool isAllSelected,
    ColorScheme colorScheme,
  ) {
    return Container(
      key: const ValueKey('selection_header'),
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.onSurface.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: colorScheme.onSurface.withOpacity(
              0.95,
            ), // Stark contrast for active state
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.close_rounded, color: colorScheme.surface),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    app.clearImageSelection();
                  },
                ),
                Expanded(
                  child: Text(
                    "${app.selectedImages.length} ${app.t('selected_count')}",
                    style: TextStyle(
                      color: colorScheme.surface,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isAllSelected
                        ? Icons.deselect_rounded
                        : Icons.select_all_rounded,
                    color: colorScheme.surface,
                    size: 22,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    isAllSelected
                        ? app.clearImageSelection()
                        : app.selectAllImages();
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.picture_as_pdf_rounded,
                    color: colorScheme.surface,
                    size: 22,
                  ),
                  onPressed: () => _showSavePdfSheet(context, app),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    size: 22,
                  ),
                  onPressed: () => _showDeleteConfirm(context, app),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppState app,
    ColorScheme colorScheme,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withOpacity(0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.photo_library_rounded,
              size: 48,
              color: colorScheme.onSurface.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            app.t('empty_gallery'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            app.t('tap_to_add'),
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.5),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// STUNNING FULL SCREEN IMAGE VIEW (WITH PRO DRAG & OCR)
// -----------------------------------------------------------------------------
class FullScreenImage extends StatefulWidget {
  final List<File> images;
  final int initialIndex;

  const FullScreenImage({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  bool _showUI = true;
  bool _isExtractingText = false;

  // Custom Apple-like Drag Physics
  double _dragOffset = 0;
  double _dragScale = 1.0;
  ScrollPhysics _physics = const BouncingScrollPhysics();

  // OCR Scanner Animation
  late AnimationController _scannerController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    _scannerController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..addStatusListener((status) {
    if (status == AnimationStatus.completed) {
      _scannerController.reverse();
    } else if (status == AnimationStatus.dismissed) {
      _scannerController.forward();
    }
          });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _extractText() async {
    final app = context.read<AppState>();
    HapticFeedback.heavyImpact();
    setState(() => _isExtractingText = true);
    _scannerController.forward();

    final file = widget.images[_currentIndex];
    String extractedText = '';

    try {
      final inputImage = InputImage.fromFile(file);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      extractedText = recognizedText.text;
      await textRecognizer.close();
      await Future.delayed(
        const Duration(milliseconds: 800),
      ); // Ensure user sees the cool animation
    } catch (e) {
      extractedText = 'Error analyzing image.\n\nDetails: $e';
    }

    if (mounted) {
      setState(() => _isExtractingText = false);
      _scannerController.stop();
      _scannerController.reset();
      _showExtractedTextSheet(extractedText, app);
    }
  }

  void _showExtractedTextSheet(String text, AppState app) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isEmpty = text.trim().isEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: colorScheme.shadow.withOpacity(isDark ? 0.5 : 0.3),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(isDark ? 0.7 : 0.9),
                border: Border(
                  top: BorderSide(
                    color: colorScheme.onSurface.withOpacity(0.08),
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 20),
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Icon(
                          Icons.document_scanner_rounded,
                          color: colorScheme.onSurface,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            app.t('extracted_text'),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: colorScheme.onSurface.withOpacity(0.08),
                        ),
                      ),
                      child: isEmpty
                          ? Center(
                              child: Text(
                                app.t('no_text_found'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              controller: controller,
                              physics: const BouncingScrollPhysics(),
                              child: SelectableText(
                                text,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.6,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!isEmpty)
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ProFluidBounce(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: text));
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: colorScheme.onSurface.withOpacity(
                                      0.05,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 18,
                                        color: colorScheme.onSurface,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        app.t('copy'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ProFluidBounce(
                                onTap: () {
                                  Share.share(text);
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: colorScheme.onSurface,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.ios_share_rounded,
                                        size: 18,
                                        color: colorScheme.surface,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        app.t('share'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.surface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showImageDetails(BuildContext context) {
    final currentFile = widget.images[_currentIndex];
    final app = context.read<AppState>();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    HapticFeedback.selectionClick();

    final formattedDate = DateFormat(
      'MMM d, yyyy • h:mm a',
    ).format(currentFile.lastModifiedSync());
    final fileSize = (currentFile.lengthSync() / (1024 * 1024)).toStringAsFixed(
      2,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: colorScheme.shadow.withOpacity(isDark ? 0.5 : 0.3),
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            color: colorScheme.surface.withOpacity(isDark ? 0.7 : 0.9),
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              MediaQuery.paddingOf(context).bottom + 32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  app.t('image_details'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                _buildBentoDetailCard(
                  Icons.insert_drive_file_rounded,
                  app.t('name'),
                  p.basename(currentFile.path),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildBentoDetailCard(
                        Icons.sd_storage_rounded,
                        app.t('size'),
                        '$fileSize MB',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBentoDetailCard(
                        Icons.access_time_rounded,
                        app.t('modified'),
                        formattedDate,
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

  Widget _buildBentoDetailCard(IconData icon, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: colorScheme.onSurface.withOpacity(0.5),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface.withOpacity(0.5),
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _openEditor() {
    final currentFile = widget.images[_currentIndex];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProImageEditor.file(
          currentFile,
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (bytes) async {
              Navigator.pop(context);
              await context.read<AppState>().saveImage(
                bytes,
                existingFile: currentFile,
              );
              if (mounted) setState(() {});
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double safeAreaTop = MediaQuery.paddingOf(context).top;
    final double safeAreaBottom = MediaQuery.paddingOf(context).bottom;
    final app = context.watch<AppState>();

    // Seamless Apple Photos drag fade
    final bgOpacity = (1 - (_dragOffset.abs() / 400)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(bgOpacity),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: () {
          if (_isExtractingText) return;
          HapticFeedback.selectionClick();
          setState(() => _showUI = !_showUI);
        },
        onVerticalDragUpdate: (details) {
          if (_isExtractingText) return;
          setState(() {
            _dragOffset += details.delta.dy;
            _dragScale = (1 - (_dragOffset.abs() / 1500)).clamp(0.5, 1.0);
            _showUI = false;
            _physics = const NeverScrollableScrollPhysics();
          });
        },
        onVerticalDragEnd: (details) {
          if (_isExtractingText) return;
          if (_dragOffset.abs() > 150 ||
              details.velocity.pixelsPerSecond.dy.abs() > 800) {
            Navigator.pop(context);
          } else {
            setState(() {
              _dragOffset = 0;
              _dragScale = 1.0;
              _showUI = true;
              _physics = const BouncingScrollPhysics();
            });
          }
        },
        child: Stack(
          children: [
            // IMAGE VIEWER
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(0, _dragOffset),
                child: Transform.scale(
                  scale: _dragScale,
                  child: PageView.builder(
                    controller: _pageController,
                    physics: _physics,
                    itemCount: widget.images.length,
                    onPageChanged: (index) =>
                        setState(() => _currentIndex = index),
                    itemBuilder: (context, index) => Hero(
                      tag: widget.images[index].path,
                      child: InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              _dragOffset.abs() > 10 ? 32 : 0,
                            ),
                            child: Image.file(
                              widget.images[index],
                              key: UniqueKey(),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // LIVE OCR SCANNER (Apple Vision Style)
            if (_isExtractingText)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _scannerController,
                  builder: (context, child) {
                    final scanPos = _scannerController.value;
                    return Stack(
                      children: [
                        Container(color: Colors.black.withOpacity(0.6)),
                        Positioned(
                          top: MediaQuery.sizeOf(context).height * scanPos,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blueAccent.withOpacity(0.0),
                                  Colors.blueAccent,
                                  Colors.white,
                                  Colors.blueAccent,
                                  Colors.blueAccent.withOpacity(0.0),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blueAccent.withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                ),
                                child: Text(
                                  app.t('analyzing_ai'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            // FLOATING HEADER
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              top: _showUI && !_isExtractingText ? safeAreaTop + 12 : -100,
              left: 20,
              right: 20,
              child: _buildGlassIsland(
                height: 52,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        "${_currentIndex + 1} of ${widget.images.length}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.info_outline_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: () => _showImageDetails(context),
                    ),
                  ],
                ),
              ),
            ),

            // FLOATING BOTTOM DOCK
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              bottom: _showUI && !_isExtractingText
                  ? safeAreaBottom + 20
                  : -120,
              left: 32,
              right: 32,
              child: _buildGlassIsland(
                height: 64,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDockAction(
                      Icons.ios_share_rounded,
                      app.t('share'),
                      () => SharePlus.instance.share(ShareParams(files: [XFile(widget.images[_currentIndex].path)])),
                    ),
                    _buildDockAction(
                      Icons.document_scanner_rounded,
                      app.t('extracted_text'),
                      _extractText,
                    ),
                    _buildDockAction(
                      Icons.tune_rounded,
                      app.t('edit'),
                      _openEditor,
                    ),
                    _buildDockAction(
                      Icons.delete_outline_rounded,
                      app.t('delete'),
                      () {
                        // Reusing our beautiful Delete Modal from Gallery for coherence
                        final galleryState = context.read<AppState>();
                        _showDeleteConfirm(
                          context,
                          galleryState,
                          isSingle: true,
                          onConfirm: () async {
                            final file = widget.images[_currentIndex];
                            if (await file.exists()) await file.delete();
                            await galleryState.loadData();
                            if (context.mounted) {
                              Navigator.pop(context); // close sheet
                              Navigator.pop(context); // close full screen
                            }
                          },
                        );
                      },
                      color: Colors.redAccent,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Same component used for Deletion in Gallery for absolute consistency
  void _showDeleteConfirm(
    BuildContext context,
    AppState app, {
    bool isSingle = false,
    VoidCallback? onConfirm,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: colorScheme.shadow.withOpacity(isDark ? 0.5 : 0.3),
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            color: colorScheme.surface.withOpacity(isDark ? 0.7 : 0.9),
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              MediaQuery.paddingOf(context).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  app.t('delete_confirm') ??
                      (isSingle ? 'Delete Photo?' : 'Delete Photos?'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  app.t('delete_confirm_msg'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: ProFluidBounce(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            app.t('cancel') ?? 'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ProFluidBounce(
                        onTap: () {
                          HapticFeedback.heavyImpact();
                          if (onConfirm != null) {
                            onConfirm();
                          } else {
                            app.deleteSelectedImages();
                            Navigator.pop(context);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            app.t('delete') ?? 'Delete',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
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

  Widget _buildGlassIsland({required double height, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildDockAction(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color color = Colors.white,
  }) {
    return ProFluidBounce(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        color: Colors.transparent, // Required for hit testing
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.8),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
