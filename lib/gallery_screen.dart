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

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  // --- PREMIUM MODALS ---

  void _showSavePdfDialog(BuildContext context, AppState app) {
    final colorScheme = Theme.of(context).colorScheme;
    final nameController = TextEditingController(
      text:
      "SCAN_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
    );

    HapticFeedback.mediumImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: colorScheme.shadow.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(36),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.picture_as_pdf_rounded,
                            color: colorScheme.primary,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          app.t('create_pdf') ?? 'Export PDF',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: colorScheme.outline.withOpacity(0.1),
                            ),
                          ),
                          child: TextField(
                            controller: nameController,
                            autofocus: true,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              labelText: app.t('pdf_name') ?? 'Document Name',
                              labelStyle: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              suffixText: '.pdf',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: _InteractiveBounce(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest
                                        .withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    app.t('cancel') ?? 'Cancel',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _InteractiveBounce(
                                onTap: () async {
                                  if (nameController.text.trim().isEmpty)
                                    return;
                                  Navigator.pop(context);
                                  final success = await app.generatePDF(
                                    nameController.text.trim(),
                                  );
                                  if (context.mounted && success) {
                                    HapticFeedback.heavyImpact();
                                    _showSuccessToast(
                                      context,
                                      app.t('pdf_generated_success') ?? 'PDF generated successfully!',
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colorScheme.primary.withOpacity(
                                          0.4,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    app.t('save') ?? 'Create',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: colorScheme.onPrimary,
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
          ),
        );
      },
    );
  }

  void _showDeleteConfirm(BuildContext context, AppState app) {
    final colorScheme = Theme.of(context).colorScheme;
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_sweep_rounded,
                  color: Colors.red,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                app.t('delete_confirm') ?? 'Delete Photos?',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                app.t('delete_confirm_msg') ??
                    'Selected items will be permanently removed. This cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        app.t('cancel') ?? 'Cancel',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        app.deleteSelectedImages();
                        Navigator.pop(context);
                      },
                      child: Text(
                        app.t('delete') ?? 'Delete',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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

  void _showSuccessToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 24, right: 24),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.green.shade600,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final colorScheme = Theme.of(context).colorScheme;
    final double safeAreaTop = MediaQuery.of(context).padding.top;

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
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: app.images.length,
                itemBuilder: (context, index) {
                  final file = app.images[index];
                  final selectionIndex = selectedList.indexOf(file.path);
                  final isSelected = selectionIndex != -1;

                  return _InteractiveBounce(
                    onTap: () {
                      if (isSelection) {
                        HapticFeedback.selectionClick();
                        app.toggleImageSelection(file.path);
                      } else {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            transitionDuration: const Duration(
                              milliseconds: 400,
                            ),
                            reverseTransitionDuration: const Duration(
                              milliseconds: 400,
                            ),
                            pageBuilder:
                                (context, animation, secondaryAnimation) {
                              return FadeTransition(
                                opacity: animation,
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
                    child: GestureDetector(
                      onLongPress: () {
                        HapticFeedback.heavyImpact();
                        app.toggleImageSelection(file.path);
                      },
                      child: Hero(
                        tag: file.path,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.all(isSelected ? 6 : 0),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primary.withOpacity(0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              isSelected ? 18 : 24,
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(file, fit: BoxFit.cover),

                                AnimatedOpacity(
                                  opacity: isSelected ? 0.3 : 0.0,
                                  duration: const Duration(
                                    milliseconds: 200,
                                  ),
                                  child: Container(color: Colors.black),
                                ),

                                // UPDATED: Sleek Numbered Selection Indicator
                                if (isSelection)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      transitionBuilder: (child, anim) => FadeTransition(
                                        opacity: anim,
                                        child: ScaleTransition(scale: anim, child: child),
                                      ),
                                      child: isSelected
                                          ? Container(
                                        key: const ValueKey('selected'),
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: colorScheme.primary, width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: colorScheme.primary.withOpacity(0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${selectionIndex + 1}',
                                            style: TextStyle(
                                              color: colorScheme.onPrimary,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      )
                                          : Container(
                                        key: const ValueKey('unselected'),
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
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
                  );
                },
              ),
            ),
          ),

          // 2. SMART HEADER ISLAND
          Positioned(
            top: safeAreaTop + 16,
            left: 20,
            right: 20,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
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
    return Container(
      key: const ValueKey('normal_header'),
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: colorScheme.surface.withOpacity(0.85),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
                  Icons.photo_library_rounded,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    app.t('gallery') ?? 'Gallery',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      fontSize: 20,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                _InteractiveBounce(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    app.toggleGalleryGrid();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(
                        0.5,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      app.gridColumns == 2
                          ? Icons.grid_view_rounded
                          : Icons.grid_on_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _InteractiveBounce(
                  onTap: () => showSettingsModal(context, app),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(
                        0.5,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
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
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: colorScheme.primary.withOpacity(0.95),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.close_rounded, color: colorScheme.onPrimary),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    app.clearImageSelection();
                  },
                ),
                Expanded(
                  child: Text(
                    "${app.selectedImages.length} ${app.t('selected_count') ?? 'Selected'}",
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isAllSelected
                        ? Icons.deselect_rounded
                        : Icons.select_all_rounded,
                    color: colorScheme.onPrimary,
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
                    color: colorScheme.onPrimary,
                  ),
                  onPressed: () => _showSavePdfDialog(context, app),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: colorScheme.onPrimary,
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
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.image_search_rounded,
              size: 64,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            app.t('empty_gallery') ?? 'No Photos Yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            app.t('tap_to_add') ?? 'Capture or import documents to begin.',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
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
// STUNNING FULL SCREEN IMAGE VIEW (WITH LIVE OCR SCANNER AND RESTORED FUNCTIONS)
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

  // Custom Drag Physics
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
        if (status == AnimationStatus.completed)
          _scannerController.reverse();
        else if (status == AnimationStatus.dismissed)
          _scannerController.forward();
      });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  // --- MAGIC TEXT EXTRACTION (OCR) ---
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

      await Future.delayed(const Duration(milliseconds: 800));
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
    final bool isEmpty = text.trim().isEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 40,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          padding: const EdgeInsets.only(top: 20, left: 24, right: 24),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 5,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.document_scanner_rounded,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      app.t('extracted_text') ?? 'Extracted Text',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.1),
                    ),
                  ),
                  child: isEmpty
                      ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.text_snippet_rounded,
                          size: 48,
                          color: colorScheme.onSurfaceVariant.withOpacity(
                            0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          app.t('no_text_found') ?? "No text found in this image.",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                      : SingleChildScrollView(
                    controller: controller,
                    physics: const BouncingScrollPhysics(),
                    child: SelectableText(
                      text,
                      style: TextStyle(
                        fontSize: 16,
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
                  child: Row(
                    children: [
                      Expanded(
                        child: _InteractiveBounce(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: text));
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  app.t('copied_to_clipboard') ?? 'Text copied to clipboard!',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  size: 20,
                                  color: colorScheme.onSurface,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  app.t('copy') ?? 'Copy',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
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
                        child: _InteractiveBounce(
                          onTap: () {
                            Share.share(text);
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.ios_share_rounded,
                                  size: 20,
                                  color: colorScheme.onPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  app.t('share') ?? 'Share',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.onPrimary,
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- RESTORED: IMAGE DETAILS ---
  void _showImageDetails(BuildContext context) {
    final currentFile = widget.images[_currentIndex];
    final app = context.read<AppState>();
    final colorScheme = Theme.of(context).colorScheme;
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
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Text(
                app.t('image_details') ?? 'Image Details',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildDetailCard(
                      Icons.insert_drive_file_rounded,
                      Colors.blue,
                      app.t('name') ?? 'Name',
                      p.basename(currentFile.path),
                    ),
                    _buildDetailCard(
                      Icons.sd_storage_rounded,
                      Colors.orange,
                      app.t('size') ?? 'Size',
                      '$fileSize MB',
                    ),
                    _buildDetailCard(
                      Icons.access_time_rounded,
                      Colors.purple,
                      app.t('modified') ?? 'Date Modified',
                      formattedDate,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(
      IconData icon,
      Color color,
      String label,
      String value,
      ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface.withOpacity(0.5),
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- RESTORED: OPEN PRO IMAGE EDITOR ---
  void _openEditor() {
    final currentFile = widget.images[_currentIndex];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProImageEditor.file(
          currentFile,
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (bytes) async {
              Navigator.pop(context); // Close editor
              await context.read<AppState>().saveImage(
                bytes,
                existingFile: currentFile,
              );
              if (mounted) setState(() {}); // Trigger rebuild to show new image
            },
          ),
        ),
      ),
    );
  }

  // --- RESTORED: DELETE SINGLE IMAGE MODAL ---
  void _showDeleteCurrentConfirm(BuildContext context) {
    final app = context.read<AppState>();
    final colorScheme = Theme.of(context).colorScheme;
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    app.t('delete_photo') ?? 'Delete Photo?',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    app.t('delete_photo_msg') ?? 'This photo will be permanently removed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: _InteractiveBounce(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              app.t('cancel') ?? 'Cancel',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InteractiveBounce(
                          onTap: () async {
                            final file = widget.images[_currentIndex];
                            if (await file.exists()) await file.delete();
                            await app.loadData();
                            if (mounted) {
                              Navigator.pop(context); // Close dialog
                              Navigator.pop(context); // Close full screen
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              app.t('delete') ?? 'Delete',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double safeAreaTop = MediaQuery.of(context).padding.top;
    final colorScheme = Theme.of(context).colorScheme;
    final app = context.watch<AppState>();

    // Background darkness based on drag
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
            _dragScale = (1 - (_dragOffset.abs() / 1500)).clamp(0.8, 1.0);
            _showUI = false;
            _physics = const NeverScrollableScrollPhysics();
          });
        },
        onVerticalDragEnd: (details) {
          if (_isExtractingText) return;
          if (_dragOffset.abs() > 120 ||
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
                              _dragOffset.abs() > 10 ? 24 : 0,
                            ),
                            // Key forces rebuild on edit finish
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

            // LIVE OCR SCANNER EFFECT
            if (_isExtractingText)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _scannerController,
                  builder: (context, child) {
                    final scanPosition = _scannerController.value;
                    return Stack(
                      children: [
                        // Dimmed background
                        Container(color: Colors.black.withOpacity(0.4)),
                        // Laser line
                        Positioned(
                          top:
                          MediaQuery.of(context).size.height * scanPosition,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary,
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Processing Text
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: Text(
                              app.t('analyzing_ai') ?? "Analyzing AI Text...",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
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
              curve: Curves.fastOutSlowIn,
              top: _showUI && !_isExtractingText ? safeAreaTop + 16 : -100,
              left: 20,
              right: 20,
              child: _buildGlassIsland(
                height: 56,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        "${_currentIndex + 1} / ${widget.images.length}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.info_outline_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () =>
                          _showImageDetails(context), // <--- RESTORED!
                    ),
                  ],
                ),
              ),
            ),

            // FLOATING BOTTOM DOCK
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.fastOutSlowIn,
              bottom: _showUI && !_isExtractingText ? 36 : -120,
              left: 24,
              right: 24,
              child: _buildGlassIsland(
                height: 72,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDockAction(
                      Icons.ios_share_rounded,
                      app.t('share') ?? 'Share',
                          () => Share.shareXFiles([
                        XFile(widget.images[_currentIndex].path),
                      ]),
                    ),
                    _buildDockAction(
                      Icons.document_scanner_rounded,
                      app.t('extracted_text') ?? 'Text',
                      _extractText,
                    ),
                    _buildDockAction(
                      Icons.tune_rounded,
                      app.t('edit') ?? 'Edit',
                      _openEditor,
                    ), // <--- RESTORED!
                    _buildDockAction(
                      Icons.delete_outline_rounded,
                      app.t('delete') ?? 'Delete',
                          () => _showDeleteCurrentConfirm(context),
                      color: Colors.redAccent,
                    ), // <--- RESTORED!
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassIsland({required double height, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
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
    return _InteractiveBounce(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        color: Colors.transparent, // Expands hit area
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- MICRO-INTERACTION WRAPPER ---
class _InteractiveBounce extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _InteractiveBounce({required this.child, required this.onTap});

  @override
  State<_InteractiveBounce> createState() => _InteractiveBounceState();
}

class _InteractiveBounceState extends State<_InteractiveBounce>
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
      end: 0.92,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}