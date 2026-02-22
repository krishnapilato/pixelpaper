import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:share_plus/share_plus.dart';
import 'app_state.dart';
import 'settings_modal.dart';

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  void _showSavePdfDialog(BuildContext context, AppState app) {
    final TextEditingController nameController = TextEditingController(
      text:
          "Document_${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}",
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(app.t('create_pdf')),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: app.t('pdf_name'),
            suffixText: '.pdf',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(app.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);

              final success = await app.generatePDF(name);
              if (context.mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("PDF Created Successfully!"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: Text(app.t('save')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    // Check if all images are currently selected
    final bool isAllSelected =
        app.selectedImages.length == app.images.length && app.images.isNotEmpty;

    return Scaffold(
      appBar: app.isImageSelectionMode
          ? AppBar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => app.clearImageSelection(),
              ),
              title: Text("${app.selectedImages.length}"),
              actions: [
                // NEW: SELECT ALL / DESELECT ALL BUTTON
                IconButton(
                  icon: Icon(isAllSelected ? Icons.deselect : Icons.select_all),
                  tooltip: isAllSelected ? 'Deselect All' : 'Select All',
                  onPressed: () {
                    if (isAllSelected) {
                      app.clearImageSelection();
                    } else {
                      app.selectAllImages();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: app.t('create_pdf'),
                  onPressed: () => _showSavePdfDialog(context, app),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: app.t('delete'),
                  onPressed: () => app.deleteSelectedImages(),
                ),
              ],
            )
          : AppBar(
              title: Text(
                app.t('gallery'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    app.gridColumns == 2 ? Icons.grid_view : Icons.grid_on,
                  ),
                  onPressed: () => app.toggleGalleryGrid(),
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => showSettingsModal(context, app),
                ),
              ],
            ),
      body: app.images.isEmpty
          ? Center(child: Text(app.t('empty_gallery')))
          : RefreshIndicator(
              onRefresh: () async => await app.loadData(),
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
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
                    onLongPress: () => app.toggleImageSelection(file.path),
                    onTap: () {
                      if (app.isImageSelectionMode) {
                        app.toggleImageSelection(file.path);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullScreenImage(file: file),
                          ),
                        );
                      }
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(file, fit: BoxFit.cover),
                        ),
                        if (isSelected)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 3,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class FullScreenImage extends StatefulWidget {
  final File file;
  const FullScreenImage({super.key, required this.file});

  @override
  State<FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> {
  // We use this key to force the screen to redraw the new image
  Key _imageKey = UniqueKey();

  void _openEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProImageEditor.file(
          widget.file,
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (bytes) async {
              // 1. Show instant feedback
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.read<AppState>().t('saving') + '...'),
                ),
              );

              // 2. Close Editor immediately so user doesn't wait
              if (mounted) Navigator.pop(context);

              // 3. Save to disk and clear cache in the background
              await context.read<AppState>().saveImage(
                bytes,
                existingFile: widget.file,
              );

              // 4. Force the UI to refresh and show the new edited image!
              if (mounted) {
                setState(() {
                  _imageKey = UniqueKey();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.read<AppState>().t('Saved!')),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: _openEditor),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Share.shareXFiles([XFile(widget.file.path)]),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          // The key ensures Flutter fetches the fresh file from disk
          child: Image.file(widget.file, key: _imageKey),
        ),
      ),
    );
  }
}
