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
import 'app_state.dart';

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

  // --- LOGIC: Blank Detection & Loading ---

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
        if (data.getUint8(offset) < 250 ||
            data.getUint8(offset + 1) < 250 ||
            data.getUint8(offset + 2) < 250)
          return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

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

  void _syncThumbnailScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_thumbnailScrollController.hasClients) {
        final double screenWidth = MediaQuery.of(context).size.width;
        const double itemWidth = 88.0;
        double targetOffset =
            (_currentIndex * itemWidth) - (screenWidth / 2) + (itemWidth / 2);
        _thumbnailScrollController.animateTo(
          targetOffset.clamp(
            0.0,
            _thumbnailScrollController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _jumpToCurrentPage() {
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
      );
    }
    _syncThumbnailScroll();
  }

  // --- ACTIONS ---

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
      if (_currentIndex >= _pages.length && _pages.isNotEmpty)
        _currentIndex = _pages.length - 1;
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

  Future<void> _editPageImage(int index) async {
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

  Future<void> _savePdf() async {
    final appState = context.read<AppState>();
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
          newDoc.pageSettings.margins.all = 0;
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
      setState(() => _isSaving = false);
    }
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.7),
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outline.withOpacity(0.1),
                  ),
                ),
              ),
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          appState.t('edit_pdf') ?? 'Editor',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          if (!_isLoading && _pages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: FilledButton.tonal(
                onPressed: _isSaving ? null : _savePdf,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        appState.t('save') ?? 'Save',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Expanded(
                    child: _pages.isEmpty
                        ? _buildEmptyState(colorScheme, appState)
                        : PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() => _currentIndex = index);
                              _syncThumbnailScroll();
                            },
                            itemCount: _pages.length,
                            itemBuilder: (context, index) =>
                                _buildMainCard(index, _pages[index]),
                          ),
                  ),
                  _buildFloatingToolbar(colorScheme, appState),
                  _buildThumbnailStrip(colorScheme),
                ],
              ),
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
            color: colorScheme.outline.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            appState.t('no_pages') ?? 'Empty Document',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard(int index, PdfPageData page) {
    final colorScheme = Theme.of(context).colorScheme;
    final appState = context.read<AppState>();
    final bool isActuallyBlank = page.isBlank;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: colorScheme.outline.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: colorScheme.surfaceVariant.withOpacity(0.2),
              child: isActuallyBlank
                  ? Center(
                      child: Icon(
                        Icons.description_outlined,
                        size: 48,
                        color: colorScheme.outline.withOpacity(0.4),
                      ),
                    )
                  : InteractiveViewer(
                      child: Transform.rotate(
                        angle: page.rotation * math.pi / 180,
                        child: Image.memory(
                          page.displayImage!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(color: colorScheme.outline.withOpacity(0.05)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!isActuallyBlank)
                  _buildContextBtn(
                    Icons.edit_rounded,
                    appState.t('edit'),
                    colorScheme.primary,
                    () => _editPageImage(index),
                  ),
                if (!isActuallyBlank)
                  _buildContextBtn(
                    Icons.rotate_right_rounded,
                    appState.t('rotate'),
                    colorScheme.onSurfaceVariant,
                    () => _rotatePage(index),
                  ),
                _buildContextBtn(
                  Icons.copy_rounded,
                  appState.t('duplicate'),
                  colorScheme.onSurfaceVariant,
                  () => _duplicatePage(index),
                ),
                _buildContextBtn(
                  Icons.delete_outline_rounded,
                  appState.t('delete'),
                  colorScheme.error,
                  () => _deletePage(index),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: onTap,
          icon: Icon(icon, color: color, size: 20),
          style: IconButton.styleFrom(
            padding: const EdgeInsets.all(10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingToolbar(ColorScheme colorScheme, AppState appState) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.onSurface,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToolBtn(
            Icons.camera_alt_rounded,
            appState.t('camera'),
            colorScheme.surface,
            () => _addNewPhoto(ImageSource.camera),
          ),
          _buildToolBtn(
            Icons.photo_library_rounded,
            appState.t('gallery'),
            colorScheme.surface,
            () => _addNewPhoto(ImageSource.gallery),
          ),
          _buildToolBtn(
            Icons.note_add_rounded,
            appState.t('blank'),
            colorScheme.surface,
            _addBlankPage,
          ),
        ],
      ),
    );
  }

  Widget _buildToolBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 18),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  Widget _buildThumbnailStrip(ColorScheme colorScheme) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outline.withOpacity(0.05)),
        ),
      ),
      child: ReorderableListView.builder(
        scrollController: _thumbnailScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: _pages.length,
        onReorder: _onReorder,
        proxyDecorator: (child, index, animation) => AnimatedBuilder(
          animation: animation,
          builder: (context, child) =>
              Transform.scale(scale: 1.1, child: child),
          child: child,
        ),
        itemBuilder: (context, index) =>
            _buildThumbnail(index, _pages[index], colorScheme),
      ),
    );
  }

  Widget _buildThumbnail(int index, PdfPageData page, ColorScheme colorScheme) {
    final isSelected = index == _currentIndex;
    return GestureDetector(
      key: ValueKey(page.id),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentIndex = index);
        _jumpToCurrentPage();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 68,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            page.isBlank
                ? Icon(
                    Icons.description_rounded,
                    color: colorScheme.outline.withOpacity(0.3),
                  )
                : Transform.rotate(
                    angle: page.rotation * math.pi / 180,
                    child: Image.memory(page.displayImage!, fit: BoxFit.cover),
                  ),
            if (!isSelected)
              Container(color: colorScheme.surface.withOpacity(0.3)),
            Positioned(
              bottom: 2,
              right: 2,
              child: CircleAvatar(
                radius: 9,
                backgroundColor: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.6),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 9,
                    color: colorScheme.surface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
