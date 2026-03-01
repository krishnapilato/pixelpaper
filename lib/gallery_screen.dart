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
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // NEW: ML Kit OCR
import 'app_state.dart';
import 'settings_modal.dart';

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  // --- LOGIC: BATCH PDF ---

  void _showSavePdfDialog(BuildContext context, AppState app) {
    final colorScheme = Theme.of(context).colorScheme;
    final nameController = TextEditingController(
      text:
          "SCAN_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                app.t('create_pdf') ?? 'Export PDF',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: app.t('pdf_name') ?? 'Document Name',
                  suffixText: '.pdf',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withOpacity(
                    0.5,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) return;
                        Navigator.pop(context);
                        final success = await app.generatePDF(
                          nameController.text.trim(),
                        );
                        if (context.mounted && success) {
                          HapticFeedback.heavyImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'PDF generated and saved',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            ),
                          );
                        }
                      },
                      child: Text(
                        app.t('save') ?? 'Create',
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

  void _showDeleteConfirm(BuildContext context, AppState app) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
          ),
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
              const SizedBox(height: 16),
              Text(
                app.t('delete_confirm') ?? 'Delete Photos?',
                style: const TextStyle(
                  fontSize: 20,
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
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
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
      backgroundColor: colorScheme.surfaceContainerLowest,
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
                        20,
                        safeAreaTop + 96,
                        20,
                        140,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: app.gridColumns,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: app.images.length,
                      itemBuilder: (context, index) {
                        final file = app.images[index];
                        final selectionIndex = selectedList.indexOf(file.path);
                        final isSelected = selectionIndex != -1;

                        return GestureDetector(
                          onLongPress: () {
                            HapticFeedback.heavyImpact();
                            app.toggleImageSelection(file.path);
                          },
                          onTap: () => isSelection
                              ? app.toggleImageSelection(file.path)
                              : Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FullScreenImage(
                                      images: app.images,
                                      initialIndex: index,
                                    ),
                                  ),
                                ),
                          child: Hero(
                            tag: file.path,
                            child: AnimatedScale(
                              scale: isSelected ? 0.92 : 1.0,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutBack,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : colorScheme.outline.withOpacity(0.08),
                                    width: isSelected ? 3 : 1,
                                  ),
                                  boxShadow: [
                                    if (!isSelected)
                                      BoxShadow(
                                        color: colorScheme.shadow.withOpacity(
                                          0.05,
                                        ),
                                        blurRadius: 15,
                                        offset: const Offset(0, 8),
                                      ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(file, fit: BoxFit.cover),
                                    if (isSelected)
                                      Container(
                                        color: colorScheme.primary.withOpacity(
                                          0.35,
                                        ),
                                      ),
                                    if (isSelected)
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: colorScheme.primary
                                                    .withOpacity(0.4),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            "${selectionIndex + 1}",
                                            style: TextStyle(
                                              color: colorScheme.onPrimary,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 18,
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

          // 2. FLOATING HEADER ISLAND
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            top: safeAreaTop + 12,
            left: 20,
            right: 20,
            child: isSelection
                ? _buildSelectionHeaderIsland(
                    context,
                    app,
                    isAllSelected,
                    colorScheme,
                  )
                : _buildNormalHeaderIsland(context, app, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalHeaderIsland(
    BuildContext context,
    AppState app,
    ColorScheme colorScheme,
  ) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: colorScheme.surface.withOpacity(0.85),
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      fontSize: 20,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    app.gridColumns == 2
                        ? Icons.grid_view_rounded
                        : Icons.grid_on_rounded,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    app.toggleGalleryGrid();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => showSettingsModal(context, app),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionHeaderIsland(
    BuildContext context,
    AppState app,
    bool isAllSelected,
    ColorScheme colorScheme,
  ) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: colorScheme.primaryContainer.withOpacity(0.95),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    app.clearImageSelection();
                  },
                ),
                Expanded(
                  child: Text(
                    "${app.selectedImages.length} Selected",
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w900,
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
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    isAllSelected
                        ? app.clearImageSelection()
                        : app.selectAllImages();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  onPressed: () => _showSavePdfDialog(context, app),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
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
              Icons.photo_library_rounded,
              size: 64,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            app.t('empty_gallery') ?? 'No Photos Yet',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            app.t('tap_to_add') ?? 'Tap the + button to capture documents.',
            style: TextStyle(
              color: colorScheme.outline,
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
// STUNNING FULL SCREEN IMAGE VIEW (WITH MAGIC OCR)
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

class _FullScreenImageState extends State<FullScreenImage> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showUI = true;
  bool _showHint = false;
  bool _isExtractingText = false; // OCR State
  final Map<int, Key> _imageKeys = {};

  double _dragOffset = 0;
  double _dragOpacity = 1.0;
  double _dragScale = 1.0;
  ScrollPhysics _physics = const BouncingScrollPhysics();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    for (int i = 0; i < widget.images.length; i++) {
      _imageKeys[i] = UniqueKey();
    }
    Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showHint = false);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- MAGIC TEXT EXTRACTION (OCR) ---
  Future<void> _extractText() async {
    HapticFeedback.heavyImpact();
    setState(() => _isExtractingText = true);

    final file = widget.images[_currentIndex];
    String extractedText = '';

    try {
      final inputImage = InputImage.fromFile(file);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      extractedText = recognizedText.text;

      await textRecognizer.close();
    } catch (e) {
      // Log the exact error to the console for debugging
      debugPrint('OCR Error: $e');
      extractedText = 'Error analyzing image.\n\nDetails: $e\n\nPlease ensure your minSdk is 21 and the ML Kit meta-data is in your AndroidManifest.xml.';
    }

    setState(() => _isExtractingText = false);

    if (mounted) {
      _showExtractedTextSheet(extractedText);
    }
  }

  void _showExtractedTextSheet(String text) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isEmpty = text.trim().isEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
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
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.document_scanner_rounded,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Extracted Text',
                      style: TextStyle(
                        fontSize: 22,
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
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.text_snippet_rounded,
                                size: 48,
                                color: colorScheme.outline.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No text found in this image.",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        )
                      : SelectableText(
                          text,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              if (!isEmpty)
                SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            foregroundColor: colorScheme.onSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: text));
                            HapticFeedback.lightImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Text copied to clipboard!',
                                ),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.copy_rounded, size: 20),
                          label: const Text(
                            'Copy',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            Share.share(text);
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.ios_share_rounded, size: 20),
                          label: const Text(
                            'Share Text',
                            style: TextStyle(fontWeight: FontWeight.bold),
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

  void _showDeleteCurrentConfirm(BuildContext context) {
    final app = context.read<AppState>();
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
          ),
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
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                app.t('delete') ?? 'Delete Photo?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This photo will be permanently removed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
                      onPressed: () async {
                        final file = widget.images[_currentIndex];
                        if (await file.exists()) await file.delete();
                        await app.loadData();
                        if (mounted) {
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(context); // Close full screen
                        }
                      },
                      child: const Text(
                        'Delete',
                        style: TextStyle(fontWeight: FontWeight.bold),
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

  void _showImageDetails(BuildContext context) {
    final currentFile = widget.images[_currentIndex];
    final app = context.read<AppState>();
    final colorScheme = Theme.of(context).colorScheme;
    HapticFeedback.selectionClick();

    final formattedDate = DateFormat(
      'MMM d, yyyy • h:mm a',
    ).format(currentFile.lastModifiedSync());
    final fileSize = (currentFile.lengthSync() / (1024 * 1024)).toStringAsFixed(2);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              app.t('details') ?? 'Image Details',
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
                    'Size',
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
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
              if (mounted)
                setState(() => _imageKeys[_currentIndex] = UniqueKey());
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double safeAreaTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(_dragOpacity.clamp(0.0, 1.0)),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _showUI = !_showUI);
        },
        onVerticalDragUpdate: (details) {
          if (_isExtractingText) return; // Prevent drag exit during OCR
          setState(() {
            _dragOffset += details.delta.dy;
            _dragOpacity = (1 - (_dragOffset.abs() / 600)).clamp(0.0, 1.0);
            _dragScale = (1 - (_dragOffset.abs() / 2000)).clamp(0.85, 1.0);
            _showUI = false;
            _physics = const NeverScrollableScrollPhysics();
          });
        },
        onVerticalDragEnd: (details) {
          if (_isExtractingText) return;
          if (_dragOffset.abs() > 150) {
            Navigator.pop(context);
          } else {
            setState(() {
              _dragOffset = 0;
              _dragOpacity = 1.0;
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
              child: ClipRect(
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
                            child: Image.file(
                              widget.images[index],
                              key: _imageKeys[index],
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

            // OCR LOADING OVERLAY
            if (_isExtractingText)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              "Analyzing Text...",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // EXIT HINT
            if (_showHint)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 140),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(seconds: 1),
                    builder: (context, val, child) => Opacity(
                      opacity: (1.0 - (val - 0.5).abs() * 2).clamp(0.0, 1.0),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_up_rounded,
                            color: Colors.white60,
                          ),
                          Text(
                            "Swipe down to exit",
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white60,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // FLOATING HEADER PILL (Dark Glass)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.fastOutSlowIn,
              top: _showUI && !_isExtractingText ? safeAreaTop + 16 : -100,
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.1),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            "${_currentIndex + 1} of ${widget.images.length}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.info_outline_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => _showImageDetails(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // FLOATING ACTION DOCK (Dark Glass)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.fastOutSlowIn,
              bottom: _showUI && !_isExtractingText ? 36 : -120,
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDockAction(
                          Icons.ios_share_rounded,
                          'Share',
                          () => Share.shareXFiles([
                            XFile(widget.images[_currentIndex].path),
                          ]),
                        ),
                        _buildDockAction(
                          Icons.document_scanner_rounded, // NEW OCR ACTION
                          'Extract Text',
                          _extractText,
                        ),
                        _buildDockAction(
                          Icons.edit_note_rounded,
                          'Edit',
                          _openEditor,
                        ),
                        _buildDockAction(
                          Icons.delete_outline_rounded,
                          'Delete',
                          () => _showDeleteCurrentConfirm(context),
                          color: Colors.redAccent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
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
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
