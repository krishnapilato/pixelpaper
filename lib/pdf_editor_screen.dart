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
            data.getUint8(offset + 2) < 252)
          return false;
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
        // 64 (width) + 16 (margins)
        const double itemWidth = 80.0;
        double targetOffset =
            (_currentIndex * itemWidth) - (screenWidth / 2) + (itemWidth / 2);
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

  void _showAddPageMenu() {
    final app = context.read<AppState>();
    final colorScheme = Theme.of(context).colorScheme;
    HapticFeedback.mediumImpact();

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
            _buildBottomSheetActionRow(
              icon: Icons.camera_alt_rounded,
              label: app.t('take_photo') ?? 'Camera',
              color: colorScheme.primary,
              onTap: () {
                Navigator.pop(context);
                _addNewPhoto(ImageSource.camera);
              },
            ),
            _buildBottomSheetActionRow(
              icon: Icons.photo_library_rounded,
              label: app.t('import_photo') ?? 'Gallery',
              color: colorScheme.secondary,
              onTap: () {
                Navigator.pop(context);
                _addNewPhoto(ImageSource.gallery);
              },
            ),
            Divider(
              indent: 24,
              endIndent: 24,
              height: 32,
              color: colorScheme.outline.withOpacity(0.1),
            ),
            _buildBottomSheetActionRow(
              icon: Icons.note_add_rounded,
              label: app.t('blank_page') ?? 'Blank Page',
              color: colorScheme.tertiary,
              onTap: () {
                Navigator.pop(context);
                _addBlankPage();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheetActionRow({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
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
              child: Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: colorScheme.onSurface.withOpacity(0.2),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addNewPhoto(ImageSource source) async {
    HapticFeedback.lightImpact();
    final pickedFile = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
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

  void _rotatePage(int index) {
    if (_pages[index].isBlank) return;
    HapticFeedback.selectionClick();
    setState(
      () => _pages[index].rotation = (_pages[index].rotation + 90) % 360,
    );
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
          if (oldPage.rotation == s_pdf.PdfPageRotateAngle.rotateAngle90) {
            baseRotation = 90;
          } else if (oldPage.rotation ==
              s_pdf.PdfPageRotateAngle.rotateAngle180) {
            baseRotation = 180;
          } else if (oldPage.rotation ==
              s_pdf.PdfPageRotateAngle.rotateAngle270) {
            baseRotation = 270;
          }

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

        if (finalRotation == 90) {
          newPage.rotation = s_pdf.PdfPageRotateAngle.rotateAngle90;
        } else if (finalRotation == 180) {
          newPage.rotation = s_pdf.PdfPageRotateAngle.rotateAngle180;
        } else if (finalRotation == 270) {
          newPage.rotation = s_pdf.PdfPageRotateAngle.rotateAngle270;
        }
      }
      await widget.file.writeAsBytes(await newDoc.save());
      await widget.file.setLastModified(originalTimestamp);
      originalDoc.dispose();
      newDoc.dispose();
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
    }
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final colorScheme = Theme.of(context).colorScheme;
    final double safeAreaTop = MediaQuery.of(context).padding.top;
    final double safeAreaBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : Stack(
              children: [
                // 1. PAGE VIEWER
                Positioned.fill(
                  child: _pages.isEmpty
                      ? _buildEmptyState(colorScheme, appState)
                      : PageView.builder(
                          controller: _pageController,
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
                  child: _buildHeaderIsland(context, appState, colorScheme),
                ),

                // 3. FLOATING ACTION DOCK (For active page)
                if (_pages.isNotEmpty)
                  Positioned(
                    bottom: safeAreaBottom + 116,
                    left: 40,
                    right: 40,
                    child: _buildPageActionDock(appState, colorScheme),
                  ),

                // 4. THUMBNAIL NAV DOCK
                Positioned(
                  bottom: safeAreaBottom > 0 ? safeAreaBottom : 24,
                  left: 20,
                  right: 20,
                  child: _buildThumbnailDock(colorScheme),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, AppState appState) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_motion_rounded,
              size: 64,
              color: colorScheme.outline.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            appState.t('no_pages') ?? 'Document is Empty',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button below to add pages',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIsland(
    BuildContext context,
    AppState app,
    ColorScheme colorScheme,
  ) {
    final fileName = p.basename(widget.file.path);

    return Container(
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: colorScheme.surface.withOpacity(0.85),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withOpacity(0.5),
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
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        _pages.isEmpty
                            ? 'Empty'
                            : 'Page ${_currentIndex + 1} of ${_pages.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_pages.isNotEmpty)
                  FilledButton.tonal(
                    onPressed: _isSaving ? null : _savePdf,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            app.t('save') ?? 'Save',
                            style: const TextStyle(fontWeight: FontWeight.w800),
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
      // Padding ensures the card sits perfectly between the header and bottom docks
      margin: EdgeInsets.only(
        top: safeAreaTop + 104,
        bottom: safeAreaBottom + 196,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
        border: Border.all(color: colorScheme.outline.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: page.isBlank
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 48,
                    color: colorScheme.outline.withOpacity(0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    appState.t('blank_page') ?? 'Blank Page',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : InteractiveViewer(
              child: Center(
                child: Transform.rotate(
                  angle: page.rotation * math.pi / 180,
                  child: Image.memory(page.displayImage!, fit: BoxFit.contain),
                ),
              ),
            ),
    );
  }

  Widget _buildPageActionDock(AppState app, ColorScheme colorScheme) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            color: colorScheme.surfaceContainerHigh.withOpacity(0.9),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!_pages[_currentIndex].isBlank)
                  _buildIconAction(
                    Icons.edit_rounded,
                    colorScheme.primary,
                    () => _navigateToImageEditor(_currentIndex),
                  ),
                if (!_pages[_currentIndex].isBlank)
                  _buildIconAction(
                    Icons.rotate_right_rounded,
                    colorScheme.secondary,
                    () => _rotatePage(_currentIndex),
                  ),
                _buildIconAction(
                  Icons.copy_rounded,
                  colorScheme.tertiary,
                  () => _duplicatePage(_currentIndex),
                ),
                _buildIconAction(
                  Icons.delete_outline_rounded,
                  colorScheme.error,
                  () => _deletePage(_currentIndex),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconAction(IconData icon, Color color, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 24),
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(12),
        shape: const CircleBorder(),
      ),
    );
  }

  Widget _buildThumbnailDock(ColorScheme colorScheme) {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(42),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 40,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(42),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.85),
            child: Row(
              children: [
                // Fixed Add Button
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 4),
                  child: InkWell(
                    onTap: _showAddPageMenu,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: colorScheme.primary,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: colorScheme.outline.withOpacity(0.2),
                ),
                // Scrollable Thumbnails
                Expanded(
                  child: ReorderableListView.builder(
                    scrollController: _thumbnailScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    itemCount: _pages.length,
                    onReorder: _onReorder,
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, index, animation) =>
                        AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) =>
                              Transform.scale(scale: 1.1, child: child),
                          child: child,
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
        ),
      ),
    );
  }

  Widget _buildThumbnail(int index, PdfPageData page, ColorScheme colorScheme) {
    final isSelected = index == _currentIndex;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentIndex = index);
        _jumpToCurrentPage();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 64,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            page.isBlank
                ? Container(
                    color: colorScheme.surface,
                    child: Icon(
                      Icons.description_rounded,
                      color: colorScheme.outline.withOpacity(0.3),
                    ),
                  )
                : Container(
                    color: colorScheme.surface,
                    child: Transform.rotate(
                      angle: page.rotation * math.pi / 180,
                      child: Image.memory(
                        page.displayImage!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
            if (!isSelected)
              Container(color: colorScheme.surface.withOpacity(0.4)),
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.surface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- IMAGE EDITOR NAVIGATION ---

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
