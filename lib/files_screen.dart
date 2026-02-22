import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'app_state.dart';
import 'settings_modal.dart';
import 'pdf_preview_screen.dart';
import 'pdf_editor_screen.dart';

class FilesScreen extends StatelessWidget {
  const FilesScreen({super.key});

  void _showRenameDialog(BuildContext context, AppState app, File file) {
    final String currentName = file.path.split('/').last.replaceAll('.pdf', '');
    final TextEditingController nameController = TextEditingController(
      text: currentName,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(app.t('rename')),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            suffixText: '.pdf',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(app.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                final success = await app.renamePdf(
                  file,
                  nameController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  if (!success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Name exists!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: Text(app.t('save')),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, AppState app, {File? file}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(app.t('delete_confirm')),
        content: Text(app.t('delete_confirm_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(app.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              if (file != null) {
                app.togglePdfSelection(file.path);
              }
              app.deleteSelectedPdfs();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              app.t('delete'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _openPdfMenu(
    BuildContext context,
    AppState app,
    File file,
    String action,
  ) {
    if (action == 'share') Share.shareXFiles([XFile(file.path)]);
    if (action == 'delete') {
      _showDeleteConfirm(context, app, file: file);
    }
    if (action == 'rename') _showRenameDialog(context, app, file);
    if (action == 'edit') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              VisualPdfEditorScreen(file: file, onSaved: () => app.loadData()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final sortedPdfs = List<File>.from(app.pdfs);
    sortedPdfs.sort((a, b) {
      final aPinned = app.pinnedPdfs.contains(a.path) ? 1 : 0;
      final bPinned = app.pinnedPdfs.contains(b.path) ? 1 : 0;
      return bPinned.compareTo(aPinned);
    });

    // Check if all items are currently selected
    final bool isAllSelected =
        app.selectedPdfs.length == app.pdfs.length && app.pdfs.isNotEmpty;

    return Scaffold(
      appBar: app.isPdfSelectionMode
          ? AppBar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => app.clearPdfSelection(),
              ),
              title: Text("${app.selectedPdfs.length}"),
              actions: [
                // NEW: SELECT ALL / DESELECT ALL BUTTON
                IconButton(
                  icon: Icon(isAllSelected ? Icons.deselect : Icons.select_all),
                  tooltip: isAllSelected ? 'Deselect All' : 'Select All',
                  onPressed: () {
                    if (isAllSelected) {
                      app.clearPdfSelection();
                    } else {
                      app.selectAllPdfs();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: app.t('share'),
                  onPressed: () {
                    Share.shareXFiles(
                      app.selectedPdfs.map((p) => XFile(p)).toList(),
                    );
                    app.clearPdfSelection();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: app.t('delete'),
                  onPressed: () => _showDeleteConfirm(context, app),
                ),
              ],
            )
          : AppBar(
              title: Text(
                app.t('files'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    app.isFilesGrid ? Icons.view_list : Icons.grid_view,
                  ),
                  onPressed: () => app.toggleFilesLayout(),
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => showSettingsModal(context, app),
                ),
              ],
            ),
      body: sortedPdfs.isEmpty
          ? Center(child: Text(app.t('empty_files')))
          : RefreshIndicator(
              onRefresh: () async => await app.loadData(),
              child: app.isFilesGrid
                  ? _buildGridView(context, app, sortedPdfs)
                  : _buildListView(context, app, sortedPdfs),
            ),
    );
  }

  Widget _buildListView(
    BuildContext context,
    AppState app,
    List<File> sortedPdfs,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: sortedPdfs.length,
      itemBuilder: (context, index) {
        final file = sortedPdfs[index];
        final isSelected = app.selectedPdfs.contains(file.path);
        final isPinned = app.pinnedPdfs.contains(file.path);

        return Card(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onLongPress: () => app.togglePdfSelection(file.path),
            onTap: () {
              if (app.isPdfSelectionMode) {
                app.togglePdfSelection(file.path);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PdfPreviewScreen(file: file),
                  ),
                );
              }
            },
            leading: Icon(
              isSelected ? Icons.check_circle : Icons.picture_as_pdf,
              color: isSelected ? Colors.white : Colors.red,
              size: 40,
            ),
            title: Text(
              file.path.split('/').last,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "${(file.lengthSync() / 1024).toStringAsFixed(1)} KB",
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    isPinned ? Icons.star : Icons.star_border,
                    color: isPinned ? Colors.amber : null,
                  ),
                  onPressed: () => app.togglePdfPin(file.path),
                ),
                PopupMenuButton<String>(
                  onSelected: (val) => _openPdfMenu(context, app, file, val),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(
                        app.t('edit'),
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'rename',
                      child: Text(app.t('rename')),
                    ),
                    PopupMenuItem(value: 'share', child: Text(app.t('share'))),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        app.t('delete'),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridView(
    BuildContext context,
    AppState app,
    List<File> sortedPdfs,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: sortedPdfs.length,
      itemBuilder: (context, index) {
        final file = sortedPdfs[index];
        final isSelected = app.selectedPdfs.contains(file.path);
        final isPinned = app.pinnedPdfs.contains(file.path);

        return GestureDetector(
          onLongPress: () => app.togglePdfSelection(file.path),
          onTap: () {
            if (app.isPdfSelectionMode) {
              app.togglePdfSelection(file.path);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PdfPreviewScreen(file: file)),
              );
            }
          },
          child: Card(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle : Icons.picture_as_pdf,
                        color: isSelected ? Colors.white : Colors.red,
                        size: 50,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: Text(
                          file.path.split('/').last,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "${(file.lengthSync() / 1024).toStringAsFixed(1)} KB",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  child: IconButton(
                    icon: Icon(
                      isPinned ? Icons.star : Icons.star_border,
                      color: isPinned ? Colors.amber : Colors.grey,
                    ),
                    onPressed: () => app.togglePdfPin(file.path),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: PopupMenuButton<String>(
                    onSelected: (val) => _openPdfMenu(context, app, file, val),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(
                          app.t('edit'),
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'rename',
                        child: Text(app.t('rename')),
                      ),
                      PopupMenuItem(
                        value: 'share',
                        child: Text(app.t('share')),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          app.t('delete'),
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
