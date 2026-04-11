import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as s_pdf;
import 'package:printing/printing.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:path/path.dart' as p;

import 'app_state.dart';

// -----------------------------------------------------------------------------
// PRO FLUID BOUNCE (Apple-style spring physics)
// -----------------------------------------------------------------------------
class ProFluidBounce extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double scaleEnd;

  const ProFluidBounce({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.scaleEnd = 0.92,
  });

  @override
  State<ProFluidBounce> createState() => _ProFluidBounceState();
}

class _ProFluidBounceState extends State<ProFluidBounce>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleEnd).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
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
      onLongPress: widget.onLongPress != null
          ? () {
              HapticFeedback.heavyImpact();
              widget.onLongPress!();
            }
          : null,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

// --- DATA MODEL ---

class PdfPageData {
  final String id;
  final Uint8List? displayImage;
  final int? originalIndex;
  final Uint8List? newRawImage;
  bool isBlank;
  int rotation;

  PdfPageData({
    this.displayImage,
    this.originalIndex,
    this.newRawImage,
    this.isBlank = false,
    this.rotation = 0,
  }) : id = UniqueKey().toString();

  PdfPageData clone() => PdfPageData(
    displayImage: displayImage,
    originalIndex: originalIndex,
    newRawImage: newRawImage,
    isBlank: isBlank,
    rotation: rotation,
  );
}

// --- MAIN SCREEN ---

class VisualPdfEditorScreen extends StatefulWidget {
  final File file;
  final VoidCallback onSaved;

  const VisualPdfEditorScreen({
    super.key,
    required this.file,
    required this.onSaved,
  });

  @override
  State<VisualPdfEditorScreen> createState() => _VisualPdfEditorScreenState();
}

class _VisualPdfEditorScreenState extends State<VisualPdfEditorScreen> {
  List<PdfPageData> _pages = [];
  bool _isLoading = true;
  bool _isSaving = false;
  int _currentIndex = 0;

  late PageController _pageController;
  late ScrollController _thumbnailScrollController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _thumbnailScrollController = ScrollController();
    _loadVisualThumbnails();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    super.dispose();
  }

  // --- LOGIC & HELPERS ---

  Future<void> _loadVisualThumbnails() async {
    final bytes = await widget.file.readAsBytes();
    List<PdfPageData> tempPages = [];
    int index = 0;

    await for (final page in Printing.raster(bytes, dpi: 100)) {
      final pngBytes = await page.toPng();
      final isBlank = await _detectIfImageIsBlank(pngBytes);
      tempPages.add(
        PdfPageData(
          displayImage: pngBytes,
          originalIndex: index,
          isBlank: isBlank,
        ),
      );
      index++;
    }

    if (mounted) {
      setState(() {
        _pages = tempPages;
        _isLoading = false;
      });
      _syncThumbnailScroll();
    }
  }

  Future<bool> _detectIfImageIsBlank(Uint8List bytes) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 50,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image image = frame.image;
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (data == null) return false;
      final List<int> samples = [
        0,
        data.lengthInBytes ~/ 2,
        data.lengthInBytes - 4,
      ];
      for (int offset in samples) {
        if (data.getUint8(offset) < 252 ||
            data.getUint8(offset + 1) < 252 ||
            data.getUint8(offset + 2) < 252) {
          return false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  void _syncThumbnailScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_thumbnailScrollController.hasClients) {
        final double screenWidth = MediaQuery.of(context).size.width;
        const double itemWidth = 76.0;
        double targetOffset =
            (_currentIndex * itemWidth) -
            (screenWidth / 2) +
            (itemWidth / 2) +
            80;

        _thumbnailScrollController.animateTo(
          targetOffset.clamp(
            0.0,
            _thumbnailScrollController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _jumpToCurrentPage() {
    if (_pageController.hasClients && _pages.isNotEmpty) {
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
      );
    }
    _syncThumbnailScroll();
  }

  // --- ACTIONS ---

  void _showProAddMenu() {
    final app = context.read<AppState>();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) => Container(
        margin: const EdgeInsets.all(
          16,
        ).copyWith(bottom: MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
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
              color: colorScheme.surface.withOpacity(isDark ? 0.6 : 0.85),
              padding: const EdgeInsets.all(24),
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
                  Text(
                    app.t('add_page') ?? 'Insert Page',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Pro Bento Layout
                  Row(
                    children: [
                      Expanded(
                        child: _BentoAction(
                          icon: Icons.camera_rounded,
                          label: app.t('take_photo') ?? 'Camera',
                          isPrimary: true,
                          onTap: () {
                            Navigator.pop(context);
                            _addNewPhoto(ImageSource.camera);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _BentoAction(
                          icon: Icons.photo_library_rounded,
                          label: app.t('import_photo') ?? 'Gallery',
                          isPrimary: false,
                          onTap: () {
                            Navigator.pop(context);
                            _addNewPhoto(ImageSource.gallery);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _BentoAction(
                    icon: Icons.note_add_rounded,
                    label: app.t('blank_page') ?? 'Insert Blank Page',
                    isPrimary: false,
                    isWide: true,
                    onTap: () {
                      Navigator.pop(context);
                      _addBlankPage();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addNewPhoto(ImageSource source) async {
    HapticFeedback.lightImpact();
    final pickedFile = await ImagePicker().pickImage(
      source: source,
      imageQuality: 100,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _pages.add(
          PdfPageData(displayImage: bytes, newRawImage: bytes, isBlank: false),
        );
        _currentIndex = _pages.length - 1;
      });
      _jumpToCurrentPage();
    }
  }

  void _addBlankPage() {
    HapticFeedback.lightImpact();
    setState(() {
      _pages.add(PdfPageData(isBlank: true));
      _currentIndex = _pages.length - 1;
    });
    _jumpToCurrentPage();
  }

  void _duplicatePage(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      _pages.insert(index + 1, _pages[index].clone());
      _currentIndex = index + 1;
    });
    _jumpToCurrentPage();
  }

  void _deletePage(int index) {
    HapticFeedback.heavyImpact();
    setState(() {
      _pages.removeAt(index);
      if (_currentIndex >= _pages.length && _pages.isNotEmpty) {
        _currentIndex = _pages.length - 1;
      }
    });
    if (_pages.isNotEmpty) _jumpToCurrentPage();
  }

  void _onReorder(int oldIndex, int newIndex) {
    HapticFeedback.lightImpact();
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, item);
      _currentIndex = newIndex;
    });
    _jumpToCurrentPage();
  }

  Future<void> _savePdf() async {
    if (_pages.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      final DateTime originalTimestamp = await widget.file.lastModified();
      final originalDoc = s_pdf.PdfDocument(
        inputBytes: await widget.file.readAsBytes(),
      );
      final newDoc = s_pdf.PdfDocument();

      for (var pageData in _pages) {
        s_pdf.PdfPage newPage;
        int finalRotation = pageData.rotation;
        if (pageData.isBlank) {
          newDoc.pageSettings.size = const Size(595, 842);
          newPage = newDoc.pages.add();
        } else if (pageData.originalIndex != null) {
          s_pdf.PdfPage oldPage = originalDoc.pages[pageData.originalIndex!];
          int baseRotation = 0;
          if (oldPage.rotation == s_pdf.PdfPageRotateAngle.rotateAngle90)
            baseRotation = 90;
          else if (oldPage.rotation == s_pdf.PdfPageRotateAngle.rotateAngle180)
            baseRotation = 180;
          else if (oldPage.rotation == s_pdf.PdfPageRotateAngle.rotateAngle270)
            baseRotation = 270;

          newDoc.pageSettings.size = (baseRotation == 90 || baseRotation == 270)
              ? Size(oldPage.size.height, oldPage.size.width)
              : oldPage.size;
          newDoc.pageSettings.margins.all = 0;
          newPage = newDoc.pages.add();
          newPage.graphics.drawPdfTemplate(
            oldPage.createTemplate(),
            const Offset(0, 0),
          );
          finalRotation = (baseRotation + pageData.rotation) % 360;
        } else if (pageData.newRawImage != null) {
          final bitmap = s_pdf.PdfBitmap(pageData.newRawImage!);
          newDoc.pageSettings.size = Size(
            bitmap.width.toDouble(),
            bitmap.height.toDouble(),
          );
          newDoc.pageSettings.margins.all = 0;
          newPage = newDoc.pages.add();
          newPage.graphics.drawImage(
            bitmap,
            Rect.fromLTWH(
              0,
              0,
              newDoc.pageSettings.size.width,
              newDoc.pageSettings.size.height,
            ),
          );
        } else {
          continue;
        }

        if (finalRotation == 90)
          newPage.rotation = s_pdf.PdfPageRotateAngle.rotateAngle90;
        else if (finalRotation == 180)
          newPage.rotation = s_pdf.PdfPageRotateAngle.rotateAngle180;
        else if (finalRotation == 270)
          newPage.rotation = s_pdf.PdfPageRotateAngle.rotateAngle270;
      }

      await widget.file.writeAsBytes(await newDoc.save());
      await widget.file.setLastModified(originalTimestamp);
      originalDoc.dispose();
      newDoc.dispose();
      widget.onSaved();

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double safeAreaTop = MediaQuery.of(context).padding.top;
    final double safeAreaBottom = MediaQuery.of(context).padding.bottom;

    // By giving the scaffold a deep background, the white PDF pages pop dynamically
    final bgColor = isDark ? Colors.black : colorScheme.surfaceContainerHighest;

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        children: [
          // 1. MAIN PAGE VIEWER
          Positioned.fill(
            child: _pages.isEmpty
                ? _buildEmptyState(colorScheme, appState)
                : PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                      _syncThumbnailScroll();
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _buildPageCard(
                        _pages[index],
                        colorScheme,
                        appState,
                        safeAreaTop,
                        safeAreaBottom,
                      );
                    },
                  ),
          ),

          // 2. HEADER ISLAND
          Positioned(
            top: safeAreaTop + 16,
            left: 20,
            right: 20,
            child: _buildProHeader(context, appState, colorScheme),
          ),

          // 3. UNIFIED BOTTOM CONSOLE
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildProBottomConsole(colorScheme, safeAreaBottom),
          ),

          // 4. LOADING / SAVING OVERLAY (Apple HUD Style)
          if (_isLoading || _isSaving) _buildProLoadingOverlay(colorScheme),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, AppState appState) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_motion_rounded,
            size: 64,
            color: colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 24),
          Text(
            appState.t('no_pages') ?? 'Empty Document',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to insert a new page.',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProHeader(
    BuildContext context,
    AppState app,
    ColorScheme colorScheme,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fileName = p.basename(widget.file.path);

    return Container(
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(isDark ? 0.5 : 0.7),
              border: Border.all(
                color: colorScheme.onSurface.withOpacity(0.08),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                ProFluidBounce(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        _pages.isEmpty
                            ? 'Empty'
                            : 'Page ${_currentIndex + 1} of ${_pages.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_pages.isNotEmpty)
                  ProFluidBounce(
                    onTap: _isSaving ? () {} : _savePdf,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        app.t('save') ?? 'Save',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.surface,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageCard(
    PdfPageData page,
    ColorScheme colorScheme,
    AppState appState,
    double safeAreaTop,
    double safeAreaBottom,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.only(
        top: safeAreaTop + 90,
        // 160 is roughly the height of the bottom console
        bottom: safeAreaBottom + 160,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: page.isBlank
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.insert_page_break_rounded,
                    size: 64,
                    color: colorScheme.onSurface.withOpacity(0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    appState.t('blank_page') ?? 'Blank Page',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Center(
                child: Transform.rotate(
                  angle: page.rotation * math.pi / 180,
                  child: Image.memory(page.displayImage!, fit: BoxFit.contain),
                ),
              ),
            ),
    );
  }

  // --- UNIFIED BOTTOM CONSOLE ---
  Widget _buildProBottomConsole(
    ColorScheme colorScheme,
    double safeAreaBottom,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: 20,
            bottom: safeAreaBottom > 0 ? safeAreaBottom : 20,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(isDark ? 0.6 : 0.85),
            border: Border(
              top: BorderSide(
                color: colorScheme.onSurface.withOpacity(0.08),
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Page Actions (Edit, Duplicate, Delete)
              if (_pages.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!_pages[_currentIndex].isBlank)
                        _buildConsoleAction(
                          Icons.tune_rounded,
                          'Edit',
                          colorScheme.onSurface,
                          () => _navigateToImageEditor(_currentIndex),
                        ),
                      if (!_pages[_currentIndex].isBlank)
                        const SizedBox(width: 16),
                      _buildConsoleAction(
                        Icons.copy_rounded,
                        'Duplicate',
                        colorScheme.onSurface,
                        () => _duplicatePage(_currentIndex),
                      ),
                      const SizedBox(width: 16),
                      _buildConsoleAction(
                        Icons.delete_outline_rounded,
                        'Delete',
                        Colors.redAccent,
                        () => _deletePage(_currentIndex),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Horizontal Thumbnails Strip
              SizedBox(
                height: 72,
                child: Row(
                  children: [
                    // Pinned Add Button
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 12),
                      child: ProFluidBounce(
                        onTap: _showProAddMenu,
                        child: Container(
                          height: 72,
                          width: 56,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colorScheme.onSurface.withOpacity(0.1),
                            ),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: colorScheme.onSurface,
                            size: 28,
                          ),
                        ),
                      ),
                    ),

                    Container(
                      width: 1,
                      height: 40,
                      color: colorScheme.onSurface.withOpacity(0.1),
                    ),
                    const SizedBox(width: 12),

                    // Reorderable Thumbnails
                    Expanded(
                      child: ReorderableListView.builder(
                        scrollController: _thumbnailScrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(right: 24),
                        itemCount: _pages.length,
                        onReorder: _onReorder,
                        buildDefaultDragHandles: false,
                        proxyDecorator: (child, index, animation) =>
                            AnimatedBuilder(
                              animation: animation,
                              builder: (context, child) =>
                                  Transform.scale(scale: 1.05, child: child),
                              child: Material(
                                color: Colors.transparent,
                                elevation: 20,
                                shadowColor: Colors.black54,
                                borderRadius: BorderRadius.circular(16),
                                child: child,
                              ),
                            ),
                        itemBuilder: (context, index) =>
                            ReorderableDragStartListener(
                              key: ValueKey(_pages[index].id),
                              index: index,
                              child: _buildThumbnail(
                                index,
                                _pages[index],
                                colorScheme,
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsoleAction(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return ProFluidBounce(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.onSurface.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(int index, PdfPageData page, ColorScheme colorScheme) {
    final isSelected = index == _currentIndex;
    return ProFluidBounce(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentIndex = index);
        _jumpToCurrentPage();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colorScheme.onSurface
                : colorScheme.onSurface.withOpacity(0.1),
            width: isSelected ? 2.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            page.isBlank
                ? Container(
                    color: colorScheme.onSurface.withOpacity(0.05),
                    child: Icon(
                      Icons.description_rounded,
                      color: colorScheme.onSurface.withOpacity(0.2),
                    ),
                  )
                : Transform.rotate(
                    angle: page.rotation * math.pi / 180,
                    child: Image.memory(page.displayImage!, fit: BoxFit.cover),
                  ),
            if (!isSelected) Container(color: Colors.black.withOpacity(0.15)),

            // Subtle page number indicator
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.onSurface
                      : colorScheme.surface.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 9,
                    color: isSelected
                        ? colorScheme.surface
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- APPLE iOS STYLE HUD OVERLAY ---
  Widget _buildProLoadingOverlay(ColorScheme colorScheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.2),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withOpacity(isDark ? 0.6 : 0.8),
                  border: Border.all(
                    color: colorScheme.onSurface.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: colorScheme.onSurface,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isSaving ? "Saving..." : "Loading...",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- BENTO ACTIONS (For Add Menu) ---
  Future<void> _navigateToImageEditor(int index) async {
    HapticFeedback.selectionClick();
    final page = _pages[index];
    if (page.isBlank || page.displayImage == null) return;
    final Uint8List imageToEdit = page.newRawImage ?? page.displayImage!;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProImageEditor.memory(
          imageToEdit,
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (Uint8List editedBytes) async {
              Navigator.pop(context);
              setState(() {
                _pages[index] = PdfPageData(
                  displayImage: editedBytes,
                  newRawImage: editedBytes,
                  rotation: 0,
                  isBlank: false,
                );
              });
            },
          ),
        ),
      ),
    );
  }
}

class _BentoAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final bool isWide;
  final VoidCallback onTap;

  const _BentoAction({
    required this.icon,
    required this.label,
    required this.isPrimary,
    this.isWide = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = isPrimary
        ? colorScheme.onSurface
        : colorScheme.onSurface.withOpacity(0.05);
    final fgColor = isPrimary ? colorScheme.surface : colorScheme.onSurface;

    return ProFluidBounce(
      onTap: onTap,
      child: Container(
        height: isWide ? 80 : 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: isPrimary
              ? null
              : Border.all(color: colorScheme.onSurface.withOpacity(0.08)),
        ),
        child: isWide
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: fgColor, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: fgColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: fgColor, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: fgColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
