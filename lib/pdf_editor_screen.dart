import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as s_pdf;
import 'package:printing/printing.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'app_state.dart';

// ----------------------------------------------------
// ENHANCED PDF PAGE DATA MODEL
// ----------------------------------------------------
class PdfPageData {
  final String id;
  final Uint8List? displayImage;
  final int? originalIndex;
  final Uint8List? newRawImage;
  final bool isBlank;
  int rotation;

  PdfPageData({
    this.displayImage,
    this.originalIndex,
    this.newRawImage,
    this.isBlank = false,
    this.rotation = 0,
  }) : id = UniqueKey().toString();

  PdfPageData clone() {
    return PdfPageData(
      displayImage: displayImage,
      originalIndex: originalIndex,
      newRawImage: newRawImage,
      isBlank: isBlank,
      rotation: rotation,
    );
  }
}

// ----------------------------------------------------
// VISUAL PDF EDITOR SCREEN
// ----------------------------------------------------
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

  Future<void> _loadVisualThumbnails() async {
    final bytes = await widget.file.readAsBytes();
    List<PdfPageData> tempPages = [];
    int index = 0;

    await for (final page in Printing.raster(bytes, dpi: 150)) {
      tempPages.add(
        PdfPageData(displayImage: await page.toPng(), originalIndex: index),
      );
      index++;
    }

    setState(() {
      _pages = tempPages;
      _isLoading = false;
      if (_pages.isNotEmpty) _currentIndex = 0;
    });

    // Auto-center the first thumbnail after loading
    _syncThumbnailScroll();
  }

  /// Calculates and animates the thumbnail list so the selected index is centered
  void _syncThumbnailScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_thumbnailScrollController.hasClients) {
        final double screenWidth = MediaQuery.of(context).size.width;
        // Thumbnail width is 80 + margin of 6 on each side = 92 total width
        const double itemWidth = 92.0;
        double targetOffset =
            (_currentIndex * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

        if (targetOffset < 0) {
          targetOffset = 0;
        } else if (targetOffset >
            _thumbnailScrollController.position.maxScrollExtent) {
          targetOffset = _thumbnailScrollController.position.maxScrollExtent;
        }

        _thumbnailScrollController.animateTo(
          targetOffset,
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
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    _syncThumbnailScroll();
  }

  Future<void> _addNewPhoto(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _pages.add(PdfPageData(displayImage: bytes, newRawImage: bytes));
        _currentIndex = _pages.length - 1;
      });
      _jumpToCurrentPage();
    }
  }

  void _addBlankPage() {
    setState(() {
      _pages.add(PdfPageData(isBlank: true));
      _currentIndex = _pages.length - 1;
    });
    _jumpToCurrentPage();
  }

  void _duplicatePage(int index) {
    setState(() {
      _pages.insert(index + 1, _pages[index].clone());
      _currentIndex = index + 1;
    });
    _jumpToCurrentPage();
  }

  void _rotatePage(int index) {
    setState(() {
      _pages[index].rotation = (_pages[index].rotation + 90) % 360;
    });
  }

  void _deletePage(int index) {
    setState(() {
      _pages.removeAt(index);
      if (_currentIndex >= _pages.length && _pages.isNotEmpty) {
        _currentIndex = _pages.length - 1;
      } else if (_pages.isEmpty) {
        _currentIndex = 0;
      }
    });
    if (_pages.isNotEmpty) {
      _jumpToCurrentPage();
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, item);

      if (_currentIndex == oldIndex) {
        _currentIndex = newIndex;
      } else if (_currentIndex > oldIndex && _currentIndex <= newIndex) {
        _currentIndex--;
      } else if (_currentIndex < oldIndex && _currentIndex >= newIndex) {
        _currentIndex++;
      }
    });
    _jumpToCurrentPage();
  }

  Future<void> _editPageImage(int index) async {
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
              if (mounted) Navigator.pop(context);

              setState(() {
                _pages[index] = PdfPageData(
                  displayImage: editedBytes,
                  newRawImage: editedBytes,
                  originalIndex: null,
                  isBlank: false,
                  rotation: 0,
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
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appState.t('error_empty_pdf')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

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

        // Syncfusion creates a template stripped of its rotation.
        // We must extract its original rotation first.
        int baseRotation = 0;
        if (oldPage.rotation == s_pdf.PdfPageRotateAngle.rotateAngle90)
          baseRotation = 90;
        else if (oldPage.rotation == s_pdf.PdfPageRotateAngle.rotateAngle180)
          baseRotation = 180;
        else if (oldPage.rotation == s_pdf.PdfPageRotateAngle.rotateAngle270)
          baseRotation = 270;

        // Un-rotate the size so when we apply the rotation, it's not double-swapped.
        Size unrotatedSize = oldPage.size;
        if (baseRotation == 90 || baseRotation == 270) {
          unrotatedSize = Size(oldPage.size.height, oldPage.size.width);
        }

        newDoc.pageSettings.size = unrotatedSize;
        newDoc.pageSettings.margins.all = 0;
        newPage = newDoc.pages.add();
        newPage.graphics.drawPdfTemplate(
          oldPage.createTemplate(),
          const Offset(0, 0),
        );

        // Combine the original rotation + the user's new rotation
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

      // Apply the final calculated rotation to the whole page container
      if (finalRotation == 90)
        newPage.rotation = s_pdf.PdfPageRotateAngle.rotateAngle90;
      else if (finalRotation == 180)
        newPage.rotation = s_pdf.PdfPageRotateAngle.rotateAngle180;
      else if (finalRotation == 270)
        newPage.rotation = s_pdf.PdfPageRotateAngle.rotateAngle270;
      else
        newPage.rotation = s_pdf.PdfPageRotateAngle.rotateAngle0;
    }

    await widget.file.writeAsBytes(await newDoc.save());
    originalDoc.dispose();
    newDoc.dispose();
    widget.onSaved();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appState.t('pdf_saved')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildActionBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI BUILDERS ---

  Widget _buildMainCard(int index, PdfPageData page) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final appState = context.read<AppState>();

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.grey.shade200,
              child: page.isBlank
                  ? Center(
                      child: Text(
                        appState.t('blank_page') ?? 'Blank Page',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 24,
                        ),
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
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!page.isBlank)
                  _buildActionBtn(
                    Icons.edit,
                    appState.t('edit') ?? 'Edit',
                    Colors.blue,
                    () => _editPageImage(index),
                  ),
                if (!page.isBlank)
                  _buildActionBtn(
                    Icons.rotate_right,
                    appState.t('rotate') ?? 'Rotate',
                    textColor,
                    () => _rotatePage(index),
                  ),
                _buildActionBtn(
                  Icons.copy,
                  appState.t('duplicate') ?? 'Duplicate',
                  textColor,
                  () => _duplicatePage(index),
                ),
                _buildActionBtn(
                  Icons.delete,
                  appState.t('delete') ?? 'Delete',
                  Colors.red,
                  () => _deletePage(index),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(int index, PdfPageData page) {
    final isSelected = index == _currentIndex;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      key: ValueKey(page.id),
      onTap: () {
        setState(() => _currentIndex = index);
        _jumpToCurrentPage();
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 8)
            else
              const BoxShadow(
                color: Colors.black12,
                blurRadius: 2,
                offset: Offset(0, 2),
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: page.isBlank
                  ? const Center(
                      child: Icon(Icons.insert_drive_file, color: Colors.grey),
                    )
                  : Transform.rotate(
                      angle: page.rotation * math.pi / 180,
                      child: Image.memory(
                        page.displayImage!,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              child: CircleAvatar(
                radius: 10,
                backgroundColor: isSelected ? primaryColor : Colors.black87,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
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

  /// Scale down to 0.5 for a "very small" effect during thumbnail drag
  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double scale = ui.lerpDouble(1, 0.5, animValue)!;
        final double elevation = ui.lerpDouble(0, 8, animValue)!;
        return Transform.scale(
          scale: scale,
          child: Material(
            elevation: elevation,
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildAddToolbar() {
    final appState = context.read<AppState>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: () => _addNewPhoto(ImageSource.camera),
            icon: const Icon(Icons.camera_alt, size: 18),
            label: Text(appState.t('camera') ?? 'Camera'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _addNewPhoto(ImageSource.gallery),
            icon: const Icon(Icons.photo_library, size: 18),
            label: Text(appState.t('gallery') ?? 'Gallery'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _addBlankPage,
            icon: const Icon(Icons.insert_drive_file_outlined, size: 18),
            label: Text(appState.t('blank') ?? 'Blank'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      appBar: AppBar(
        title: Text(appState.t('edit_pdf') ?? 'Edit PDF'),
        actions: [
          if (!_isLoading && _pages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _savePdf,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(appState.t('save') ?? 'Save'),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. MAIN PAGE PREVIEW (Swipable)
                Expanded(
                  child: _pages.isEmpty
                      ? Center(
                          child: Text(
                            appState.t('no_pages') ??
                                'No pages available.\nAdd some below!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() => _currentIndex = index);
                            _syncThumbnailScroll(); // Shift thumbnails on swipe
                          },
                          itemCount: _pages.length,
                          itemBuilder: (context, index) {
                            return _buildMainCard(index, _pages[index]);
                          },
                        ),
                ),

                // 2. ACTION BAR (Add Buttons)
                _buildAddToolbar(),

                // 3. THUMBNAIL STRIP (Drag & Drop Reordering)
                if (_pages.isNotEmpty)
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: ReorderableListView.builder(
                      scrollController: _thumbnailScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _pages.length,
                      onReorder: _onReorder,
                      proxyDecorator: _proxyDecorator,
                      itemBuilder: (context, index) {
                        return _buildThumbnail(index, _pages[index]);
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
