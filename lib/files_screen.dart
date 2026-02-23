import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'app_state.dart';
import 'settings_modal.dart';
import 'pdf_preview_screen.dart';
import 'pdf_editor_screen.dart';

class FilesScreen extends StatelessWidget {
  const FilesScreen({super.key});

  // --- LOGIC: Rename & Delete ---

  void _showRenameDialog(BuildContext context, AppState app, File file) {
    final colorScheme = Theme.of(context).colorScheme;
    final nameController = TextEditingController(
      text: p.basenameWithoutExtension(file.path),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          app.t('rename') ?? 'Rename File',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            suffixText: '.pdf',
            filled: true,
            fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
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
              if (nameController.text.trim().isNotEmpty) {
                final success = await app.renamePdf(
                  file,
                  nameController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  if (!success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Name already exists!'),
                        backgroundColor: colorScheme.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              }
            },
            child: Text(app.t('save') ?? 'Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, AppState app, {File? file}) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        icon: Icon(
          Icons.warning_amber_rounded,
          color: colorScheme.error,
          size: 32,
        ),
        title: Text(app.t('delete_confirm') ?? 'Delete?'),
        content: Text(app.t('delete_confirm_msg') ?? 'This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(app.t('cancel') ?? 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () {
              HapticFeedback.vibrate();
              if (file != null) app.togglePdfSelection(file.path);
              app.deleteSelectedPdfs();
              Navigator.pop(context);
            },
            child: Text(app.t('delete') ?? 'Delete'),
          ),
        ],
      ),
    );
  }

  void _showFileActionModal(BuildContext context, AppState app, File file) {
    HapticFeedback.mediumImpact();
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
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
              _buildBottomSheetItem(
                context,
                icon: Icons.edit_note_rounded,
                title: app.t('edit'),
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VisualPdfEditorScreen(
                        file: file,
                        onSaved: () => app.loadData(),
                      ),
                    ),
                  );
                },
              ),
              _buildBottomSheetItem(
                context,
                icon: Icons.drive_file_rename_outline_rounded,
                title: app.t('rename'),
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(context, app, file);
                },
              ),
              _buildBottomSheetItem(
                context,
                icon: Icons.ios_share_rounded,
                title: app.t('share'),
                color: colorScheme.primary,
                onTap: () {
                  Navigator.pop(context);
                  Share.shareXFiles([XFile(file.path)]);
                },
              ),
              const Divider(indent: 32, endIndent: 32, height: 32),
              _buildBottomSheetItem(
                context,
                icon: Icons.delete_outline_rounded,
                title: app.t('delete'),
                color: colorScheme.error,
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirm(context, app, file: file);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheetItem(
    BuildContext context, {
    required IconData icon,
    required String? title,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title ?? '',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 32),
    );
  }

  // --- MAIN BUILD ---

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final colorScheme = Theme.of(context).colorScheme;
    final selectedList = app.selectedPdfs.toList();
    final sortedPdfs = List<File>.from(app.pdfs);

    sortedPdfs.sort((a, b) {
      final aPinned = app.pinnedPdfs.contains(a.path) ? 1 : 0;
      final bPinned = app.pinnedPdfs.contains(b.path) ? 1 : 0;
      if (aPinned != bPinned) return bPinned.compareTo(aPinned);
      return b.lastModifiedSync().compareTo(a.lastModifiedSync());
    });

    final bool isAllSelected =
        app.selectedPdfs.length == app.pdfs.length && app.pdfs.isNotEmpty;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: app.isPdfSelectionMode
              ? _buildSelectionAppBar(context, app, isAllSelected, colorScheme)
              : _buildNormalAppBar(context, app, colorScheme),
        ),
      ),
      body: sortedPdfs.isEmpty
          ? _buildEmptyState(context, app, colorScheme)
          : RefreshIndicator(
              onRefresh: () async => await app.loadData(),
              child: app.isFilesGrid
                  ? _buildGridView(context, app, sortedPdfs, selectedList)
                  : _buildListView(context, app, sortedPdfs, selectedList),
            ),
    );
  }

  // --- COMPONENTS ---

  AppBar _buildNormalAppBar(
    BuildContext context,
    AppState app,
    ColorScheme colorScheme,
  ) {
    return AppBar(
      key: const ValueKey('n'),
      title: Text(
        app.t('files') ?? 'Files',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: -0.8,
          fontSize: 24,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            app.isFilesGrid ? Icons.view_list_rounded : Icons.grid_view_rounded,
          ),
          onPressed: () => app.toggleFilesLayout(),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => showSettingsModal(context, app),
        ),
      ],
    );
  }

  AppBar _buildSelectionAppBar(
    BuildContext context,
    AppState app,
    bool isAllSelected,
    ColorScheme colorScheme,
  ) {
    return AppBar(
      key: const ValueKey('s'),
      backgroundColor: colorScheme.primaryContainer,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: () => app.clearPdfSelection(),
      ),
      title: Text(
        "${app.selectedPdfs.length} ${app.t('selected')}",
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      actions: [
        IconButton(
          icon: Icon(
            isAllSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
          ),
          onPressed: () =>
              isAllSelected ? app.clearPdfSelection() : app.selectAllPdfs(),
        ),
        IconButton(
          icon: const Icon(Icons.ios_share_rounded),
          onPressed: () {
            Share.shareXFiles(app.selectedPdfs.map((p) => XFile(p)).toList());
            app.clearPdfSelection();
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () => _showDeleteConfirm(context, app),
        ),
      ],
    );
  }

  Widget _buildListView(
    BuildContext context,
    AppState app,
    List<File> sortedPdfs,
    List<String> selectedList,
  ) {
    return ListView.builder(
      key: const PageStorageKey('pdf_list'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: sortedPdfs.length,
      itemBuilder: (context, index) {
        final file = sortedPdfs[index];
        final selectionIndex = selectedList.indexOf(file.path);
        final isSelected = selectionIndex != -1;
        final isPinned = app.pinnedPdfs.contains(file.path);

        return _buildFileCard(
          context,
          app,
          file,
          isSelected,
          selectionIndex,
          isPinned,
          isGrid: false,
        );
      },
    );
  }

  Widget _buildGridView(
    BuildContext context,
    AppState app,
    List<File> sortedPdfs,
    List<String> selectedList,
  ) {
    return GridView.builder(
      key: const PageStorageKey('pdf_grid'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.9,
      ),
      itemCount: sortedPdfs.length,
      itemBuilder: (context, index) {
        final file = sortedPdfs[index];
        final selectionIndex = selectedList.indexOf(file.path);
        final isSelected = selectionIndex != -1;
        final isPinned = app.pinnedPdfs.contains(file.path);

        return _buildFileCard(
          context,
          app,
          file,
          isSelected,
          selectionIndex,
          isPinned,
          isGrid: true,
        );
      },
    );
  }

  Widget _buildFileCard(
    BuildContext context,
    AppState app,
    File file,
    bool isSelected,
    int selectionIndex,
    bool isPinned, {
    required bool isGrid,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final fileSize = (file.lengthSync() / 1024).toStringAsFixed(1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primaryContainer.withOpacity(0.7)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(isGrid ? 28 : 20),
        border: Border.all(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outline.withOpacity(0.08),
          width: 1.5,
        ),
        boxShadow: [
          if (!isSelected)
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onLongPress: () {
            HapticFeedback.heavyImpact();
            app.togglePdfSelection(file.path);
          },
          onTap: () => app.isPdfSelectionMode
              ? app.togglePdfSelection(file.path)
              : Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PdfPreviewScreen(file: file),
                  ),
                ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: isGrid
                ? _buildGridContent(
                    context,
                    app,
                    file,
                    isSelected,
                    selectionIndex,
                    isPinned,
                    fileSize,
                  )
                : _buildListContent(
                    context,
                    app,
                    file,
                    isSelected,
                    selectionIndex,
                    isPinned,
                    fileSize,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildListContent(
    BuildContext context,
    AppState app,
    File file,
    bool isSelected,
    int selectionIndex,
    bool isPinned,
    String size,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        _buildLeadingIcon(colorScheme, isSelected, selectionIndex),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.basename(file.path),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              _buildMetadataPill(colorScheme, "$size KB"),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            color: isPinned ? Colors.amber : colorScheme.outline,
            size: 20,
          ),
          onPressed: () => app.togglePdfPin(file.path),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () => _showFileActionModal(context, app, file),
        ),
      ],
    );
  }

  Widget _buildGridContent(
    BuildContext context,
    AppState app,
    File file,
    bool isSelected,
    int selectionIndex,
    bool isPinned,
    String size,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLeadingIcon(
                colorScheme,
                isSelected,
                selectionIndex,
                large: true,
              ),
              const SizedBox(height: 12),
              Text(
                p.basename(file.path),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              _buildMetadataPill(colorScheme, "$size KB"),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          child: IconButton(
            icon: Icon(
              isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: isPinned ? Colors.amber : colorScheme.outline,
              size: 18,
            ),
            onPressed: () => app.togglePdfPin(file.path),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            icon: const Icon(Icons.more_horiz_rounded, size: 20),
            onPressed: () => _showFileActionModal(context, app, file),
          ),
        ),
      ],
    );
  }

  Widget _buildLeadingIcon(
    ColorScheme colorScheme,
    bool isSelected,
    int selectionIndex, {
    bool large = false,
  }) {
    final size = large ? 56.0 : 46.0;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: isSelected
          ? Container(
              key: const ValueKey('s'),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${selectionIndex + 1}',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: large ? 20 : 16,
                  ),
                ),
              ),
            )
          : Container(
              key: const ValueKey('u'),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(large ? 18 : 14),
              ),
              child: Icon(
                Icons.picture_as_pdf_rounded,
                color: colorScheme.error,
                size: large ? 28 : 22,
              ),
            ),
    );
  }

  Widget _buildMetadataPill(ColorScheme colorScheme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface.withOpacity(0.5),
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
              color: colorScheme.surfaceVariant.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 64,
              color: colorScheme.outline.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            app.t('empty_files') ?? 'No Documents',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Your scanned PDFs will appear here.',
            style: TextStyle(color: colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
