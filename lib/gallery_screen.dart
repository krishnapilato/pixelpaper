import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'app_state.dart';
import 'settings_modal.dart';

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  void _showSavePdfDialog(BuildContext context, AppState app) {
    final colorScheme = Theme.of(context).colorScheme;
    final TextEditingController nameController = TextEditingController(
      text:
          "Document_${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}",
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Icon(Icons.picture_as_pdf_rounded, color: colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              app.t('create_pdf') ?? 'Create PDF',
              style: const TextStyle(fontSize: 20),
            ),
          ],
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: app.t('pdf_name') ?? 'Document Name',
            suffixText: '.pdf',
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(app.t('cancel') ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              final success = await app.generatePDF(name);
              if (context.mounted && success) {
                HapticFeedback.heavyImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("PDF Created Successfully!"),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.all(24),
                  ),
                );
              }
            },
            child: Text(app.t('save') ?? 'Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, AppState app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.red,
          size: 32,
        ),
        title: Text(app.t('delete_confirm') ?? 'Delete Photos?'),
        content: Text(
          app.t('delete_confirm_msg') ?? 'Are you sure?',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(app.t('cancel') ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              HapticFeedback.vibrate();
              app.deleteSelectedImages();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(app.t('delete') ?? 'Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final colorScheme = Theme.of(context).colorScheme;
    final selectedList = app.selectedImages.toList();
    final bool isAllSelected =
        app.selectedImages.length == app.images.length && app.images.isNotEmpty;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: app.isImageSelectionMode
              ? AppBar(
                  key: const ValueKey('selection'),
                  backgroundColor: colorScheme.primaryContainer,
                  leading: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => app.clearImageSelection(),
                  ),
                  title: Text(
                    "${app.selectedImages.length} Selected",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        isAllSelected
                            ? Icons.deselect_rounded
                            : Icons.select_all_rounded,
                      ),
                      onPressed: () => isAllSelected
                          ? app.clearImageSelection()
                          : app.selectAllImages(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      onPressed: () => _showSavePdfDialog(context, app),
                    ),
                    IconButton(
                      icon: const Icon(Icons.ios_share_rounded),
                      onPressed: () => Share.shareXFiles(
                        app.selectedImages.map((p) => XFile(p)).toList(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                      ),
                      onPressed: () => _showDeleteConfirm(context, app),
                    ),
                  ],
                )
              : AppBar(
                  key: const ValueKey('normal'),
                  title: Text(
                    app.t('gallery') ?? 'Gallery',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        app.gridColumns == 2
                            ? Icons.grid_view_rounded
                            : Icons.grid_on_rounded,
                      ),
                      onPressed: () => app.toggleGalleryGrid(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => showSettingsModal(context, app),
                    ),
                  ],
                ),
        ),
      ),
      body: app.images.isEmpty
          ? Center(
              child: Icon(
                Icons.photo_library_outlined,
                size: 64,
                color: colorScheme.outline.withOpacity(0.3),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => await app.loadData(),
              child: GridView.builder(
                key: const PageStorageKey('gallery'),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: app.gridColumns,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: app.images.length,
                itemBuilder: (context, index) {
                  final file = app.images[index];
                  final isSelected = app.selectedImages.contains(file.path);
                  return GestureDetector(
                    onLongPress: () {
                      HapticFeedback.heavyImpact();
                      app.toggleImageSelection(file.path);
                    },
                    onTap: () => app.isImageSelectionMode
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
                        scale: isSelected ? 0.94 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: isSelected
                                ? Border.all(
                                    color: colorScheme.primary,
                                    width: 3,
                                  )
                                : null,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.file(file, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

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

  // --- ACTIONS ---
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

  void _showImageDetails(BuildContext context) async {
    final currentFile = widget.images[_currentIndex];
    final app = context.read<AppState>();
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
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
              app.t('details') ?? 'Details',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildDetailItem(
              Icons.insert_drive_file_outlined,
              app.t('name'),
              p.basename(currentFile.path),
            ),
            _buildDetailItem(
              Icons.folder_open_outlined,
              app.t('path'),
              currentFile.path,
            ),
            _buildDetailItem(
              Icons.access_time_rounded,
              app.t('modified'),
              currentFile.lastModifiedSync().toString(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String? title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title ?? '',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(_dragOpacity.clamp(0.0, 1.0)),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: () => setState(() => _showUI = !_showUI),
        // --- FIX: V-DRAG LOGIC ---
        onVerticalDragUpdate: (details) {
          setState(() {
            _dragOffset += details.delta.dy;
            _dragOpacity = (1 - (_dragOffset.abs() / 600)).clamp(0.0, 1.0);
            _dragScale = (1 - (_dragOffset.abs() / 2000)).clamp(0.85, 1.0);
            _showUI = false;
            _showHint = false;
            _physics = const NeverScrollableScrollPhysics(); // LOCK HORIZONTAL
          });
        },
        onVerticalDragEnd: (details) {
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
            // --- FIX: CLIP RECT + TRANSFORM ---
            Positioned.fill(
              child: ClipRect(
                // HIDES NEIGHBORING IMAGES DURING SCALE
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
                      itemBuilder: (context, index) {
                        return Hero(
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
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // Pulsating Hint
            if (_showHint)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(seconds: 3),
                    builder: (context, val, child) => Opacity(
                      opacity: (1.0 - (val - 0.5).abs() * 2).clamp(0.0, 1.0),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_up_rounded,
                            color: Colors.white70,
                          ),
                          Text(
                            "Swipe to exit",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Top Bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              top: _showUI ? 0 : -120,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 10,
                  bottom: 20,
                  left: 10,
                  right: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        "${_currentIndex + 1} / ${widget.images.length}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),

            // Bottom Bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              bottom: _showUI ? 30 : -100,
              left: 24,
              right: 24,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.ios_share_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => Share.shareXFiles([
                            XFile(widget.images[_currentIndex].path),
                          ]),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                          ),
                          onPressed: _openEditor,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.info_outline_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => _showImageDetails(context),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            context
                                .read<AppState>()
                                .deleteSelectedImages(); // Simple logic for brevity
                            Navigator.pop(context);
                          },
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
}
