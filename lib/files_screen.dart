import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

import 'app_state.dart';
import 'settings_modal.dart';
import 'pdf_preview_screen.dart';
import 'pdf_editor_screen.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchActive = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSearchActive = !_isSearchActive;
      if (!_isSearchActive) {
        _searchController.clear();
        _searchFocusNode.unfocus();
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }

  // --- PREMIUM MODALS ---

  void _showRenameDialog(BuildContext context, AppState app, File file) {
    final colorScheme = Theme.of(context).colorScheme;
    final nameController = TextEditingController(
      text: p.basenameWithoutExtension(file.path),
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
                            color: Colors.orange.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.drive_file_rename_outline_rounded,
                            color: Colors.orange,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          app.t('rename') ?? 'Rename File',
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
                                  if (nameController.text.trim().isNotEmpty) {
                                    final success = await app.renamePdf(
                                      file,
                                      nameController.text.trim(),
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      if (!success)
                                        _showErrorToast(
                                          context,
                                          colorScheme,
                                          'Name already exists!',
                                        );
                                    }
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orange.withOpacity(0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    app.t('save') ?? 'Save',
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
          ),
        );
      },
    );
  }

  void _showDeleteConfirm(BuildContext context, AppState app, {File? file}) {
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
                app.t('delete_confirm') ?? 'Delete PDF?',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                app.t('delete_confirm_msg') ??
                    'This document will be removed permanently. This cannot be undone.',
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
                        if (file != null) app.togglePdfSelection(file.path);
                        app.deleteSelectedPdfs();
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

  void _showFileActionModal(BuildContext context, AppState app, File file) {
    HapticFeedback.mediumImpact();
    final colorScheme = Theme.of(context).colorScheme;
    final fileName = p.basename(file.path);
    final fileSize = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(2);
    final formattedDate = DateFormat(
      'MMM d, yyyy',
    ).format(file.lastModifiedSync());

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Colors.red,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$fileSize MB • $formattedDate',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(
                indent: 24,
                endIndent: 24,
                height: 32,
                color: colorScheme.outline.withOpacity(0.1),
              ),
              _buildBottomSheetItem(
                context,
                icon: Icons.edit_note_rounded,
                title: app.t('edit') ?? 'Edit Pages',
                color: Colors.blueAccent,
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
                title: app.t('rename') ?? 'Rename',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(context, app, file);
                },
              ),
              _buildBottomSheetItem(
                context,
                icon: Icons.ios_share_rounded,
                title: app.t('share') ?? 'Share',
                color: colorScheme.primary,
                onTap: () {
                  Navigator.pop(context);
                  Share.shareXFiles([XFile(file.path)]);
                },
              ),
              Divider(
                indent: 24,
                endIndent: 24,
                height: 32,
                color: colorScheme.outline.withOpacity(0.1),
              ),
              _buildBottomSheetItem(
                context,
                icon: Icons.delete_outline_rounded,
                title: app.t('delete') ?? 'Delete',
                color: Colors.red,
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirm(context, app, file: file);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheetItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return _InteractiveBounce(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDestructive ? Colors.red : colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorToast(
    BuildContext context,
    ColorScheme colorScheme,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 24, right: 24),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: colorScheme.error,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colorScheme.error.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: colorScheme.onError),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: colorScheme.onError,
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

  // --- MAIN BUILD ---

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final colorScheme = Theme.of(context).colorScheme;
    final double safeAreaTop = MediaQuery.of(context).padding.top;
    final selectedList = app.selectedPdfs.toList();

    List<File> sortedPdfs = List<File>.from(app.pdfs);
    sortedPdfs.sort((a, b) {
      final aPinned = app.pinnedPdfs.contains(a.path) ? 1 : 0;
      final bPinned = app.pinnedPdfs.contains(b.path) ? 1 : 0;
      if (aPinned != bPinned) return bPinned.compareTo(aPinned);
      return b.lastModifiedSync().compareTo(a.lastModifiedSync());
    });

    if (_searchQuery.isNotEmpty) {
      sortedPdfs = sortedPdfs
          .where(
            (file) =>
                p.basename(file.path).toLowerCase().contains(_searchQuery),
          )
          .toList();
    }

    final bool isAllSelected =
        app.selectedPdfs.length == app.pdfs.length && app.pdfs.isNotEmpty;
    final bool isSelection = app.isPdfSelectionMode;

    return Scaffold(
      // FIXED: Matched Gallery background exactly
      backgroundColor: colorScheme.surface,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. MAIN LIST / GRID
          Positioned.fill(
            child: sortedPdfs.isEmpty
                ? _buildEmptyState(context, app, colorScheme)
                : RefreshIndicator(
                    onRefresh: () async => await app.loadData(),
                    edgeOffset: safeAreaTop + 90,
                    child: app.isFilesGrid
                        ? _buildGridView(
                            context,
                            app,
                            sortedPdfs,
                            selectedList,
                            safeAreaTop,
                          )
                        : _buildListView(
                            context,
                            app,
                            sortedPdfs,
                            selectedList,
                            safeAreaTop,
                          ),
                  ),
          ),

          // 2. DYNAMIC MORPHING HEADER ISLAND
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            top: safeAreaTop + 16,
            left: 20,
            right: 20,
            child: _buildDynamicHeaderIsland(
              context,
              app,
              isSelection,
              isAllSelected,
              colorScheme,
            ),
          ),
        ],
      ),
    );
  }

  // --- MORPHING HEADER ---

  Widget _buildDynamicHeaderIsland(
    BuildContext context,
    AppState app,
    bool isSelection,
    bool isAllSelected,
    ColorScheme colorScheme,
  ) {
    // FIXED: Matched Gallery selection background exactly
    final bgColor = isSelection
        ? colorScheme.primary.withOpacity(0.95)
        : colorScheme.surface.withOpacity(0.85);
    final shadowColor = isSelection
        ? colorScheme.primary.withOpacity(0.2)
        : colorScheme.shadow.withOpacity(0.08);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.fastOutSlowIn,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            color: bgColor,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.2),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: isSelection
                  ? _buildSelectionHeaderContent(
                      app,
                      isAllSelected,
                      colorScheme,
                    )
                  : _isSearchActive
                  ? _buildSearchHeaderContent(colorScheme)
                  : _buildNormalHeaderContent(context, app, colorScheme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNormalHeaderContent(
    BuildContext context,
    AppState app,
    ColorScheme colorScheme,
  ) {
    return Padding(
      key: const ValueKey('normal_mode'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(Icons.folder_copy_rounded, color: colorScheme.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              app.t('files') ?? 'Files',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                fontSize: 20,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          _InteractiveBounce(
            onTap: _toggleSearch,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _InteractiveBounce(
            onTap: () {
              HapticFeedback.lightImpact();
              app.toggleFilesLayout();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                app.isFilesGrid
                    ? Icons.view_list_rounded
                    : Icons.grid_view_rounded,
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
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
    );
  }

  Widget _buildSearchHeaderContent(ColorScheme colorScheme) {
    return Padding(
      key: const ValueKey('search_mode'),
      padding: const EdgeInsets.only(left: 20, right: 8),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: colorScheme.primary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Search files...',
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.cancel_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                _searchController.clear();
              },
            ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            onPressed: _toggleSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionHeaderContent(
    AppState app,
    bool isAllSelected,
    ColorScheme colorScheme,
  ) {
    return Padding(
      key: const ValueKey('selection_mode'),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // FIXED: Use onPrimary to perfectly match Gallery Screen
          IconButton(
            icon: Icon(Icons.close_rounded, color: colorScheme.onPrimary),
            onPressed: () {
              HapticFeedback.lightImpact();
              app.clearPdfSelection();
            },
          ),
          Expanded(
            child: Text(
              "${app.selectedPdfs.length} Selected",
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
              isAllSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
              color: colorScheme.onPrimary,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              isAllSelected ? app.clearPdfSelection() : app.selectAllPdfs();
            },
          ),
          IconButton(
            icon: Icon(Icons.ios_share_rounded, color: colorScheme.onPrimary),
            onPressed: () {
              Share.shareXFiles(app.selectedPdfs.map((p) => XFile(p)).toList());
              app.clearPdfSelection();
            },
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
    );
  }

  // --- REUSABLE FILE CARD ---

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
    final fileSize = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(2);
    final formattedDate = DateFormat(
      'MMM d, yyyy',
    ).format(file.lastModifiedSync());

    return _InteractiveBounce(
      onTap: () {
        if (app.isPdfSelectionMode) {
          HapticFeedback.selectionClick();
          app.togglePdfSelection(file.path);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PdfPreviewScreen(file: file)),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.15)
              : colorScheme.surfaceContainerHighest.withOpacity(
                  0.3,
                ), // Matches Gallery better
          borderRadius: BorderRadius.circular(isGrid ? 28 : 24),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.08),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? []
              : [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: GestureDetector(
          onLongPress: () {
            HapticFeedback.heavyImpact();
            app.togglePdfSelection(file.path);
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.all(isGrid ? 20 : 16),
            child: isGrid
                ? _buildGridContent(
                    context,
                    app,
                    file,
                    isSelected,
                    selectionIndex,
                    isPinned,
                    fileSize,
                    formattedDate,
                  )
                : _buildListContent(
                    context,
                    app,
                    file,
                    isSelected,
                    selectionIndex,
                    isPinned,
                    fileSize,
                    formattedDate,
                  ),
          ),
        ),
      ),
    );
  }

  // --- CONTENT LAYOUTS ---

  Widget _buildListContent(
    BuildContext context,
    AppState app,
    File file,
    bool isSelected,
    int selectionIndex,
    bool isPinned,
    String size,
    String date,
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
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildMetadataPill(
                    colorScheme,
                    Icons.sd_storage_rounded,
                    "$size MB",
                  ),
                  const SizedBox(width: 8),
                  _buildMetadataPill(
                    colorScheme,
                    Icons.calendar_month_rounded,
                    date,
                  ),
                ],
              ),
            ],
          ),
        ),
        _InteractiveBounce(
          onTap: () {
            HapticFeedback.lightImpact();
            app.togglePdfPin(file.path);
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: isPinned ? Colors.amber : colorScheme.onSurfaceVariant,
              size: 22,
            ),
          ),
        ),
        _InteractiveBounce(
          onTap: () => _showFileActionModal(context, app, file),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              Icons.more_vert_rounded,
              color: colorScheme.onSurfaceVariant,
              size: 22,
            ),
          ),
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
    String date,
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
              const SizedBox(height: 16),
              Text(
                p.basename(file.path),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              _buildMetadataPill(
                colorScheme,
                null,
                "$size MB • $date",
                small: true,
              ),
            ],
          ),
        ),
        Positioned(
          top: -12,
          left: -12,
          child: _InteractiveBounce(
            onTap: () {
              HapticFeedback.lightImpact();
              app.togglePdfPin(file.path);
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                color: isPinned ? Colors.amber : colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
          ),
        ),
        Positioned(
          top: -12,
          right: -12,
          child: _InteractiveBounce(
            onTap: () => _showFileActionModal(context, app, file),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                Icons.more_horiz_rounded,
                color: colorScheme.onSurfaceVariant,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- ATOMS ---

  Widget _buildLeadingIcon(
    ColorScheme colorScheme,
    bool isSelected,
    int selectionIndex, {
    bool large = false,
  }) {
    final size = large ? 64.0 : 52.0;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: anim, child: child),
      ),
      child: isSelected
          ? Container(
              key: const ValueKey('s'),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${selectionIndex + 1}',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: large ? 22 : 18,
                  ),
                ),
              ),
            )
          : Container(
              key: const ValueKey('u'),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(large ? 20 : 16),
              ),
              child: Icon(
                Icons.picture_as_pdf_rounded,
                color: Colors.red,
                size: large ? 32 : 26,
              ),
            ),
    );
  }

  Widget _buildMetadataPill(
    ColorScheme colorScheme,
    IconData? icon,
    String text, {
    bool small = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: small ? 9 : 10,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
              _searchQuery.isNotEmpty
                  ? Icons.search_off_rounded
                  : Icons.folder_open_rounded,
              size: 64,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty
                ? 'No matches found'
                : (app.t('empty_files') ?? 'No Scanned PDFs'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term.'
                : (app.t('tap_gallery_to_create') ??
                      'Create PDFs from the gallery tab.'),
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

  // --- WRAPPERS ---

  Widget _buildListView(
    BuildContext context,
    AppState app,
    List<File> sortedPdfs,
    List<String> selectedList,
    double safeAreaTop,
  ) {
    return ListView.builder(
      key: const PageStorageKey('pdf_list'),
      padding: EdgeInsets.fromLTRB(16, safeAreaTop + 104, 16, 140),
      physics: const BouncingScrollPhysics(),
      itemCount: sortedPdfs.length,
      itemBuilder: (context, index) {
        final file = sortedPdfs[index];
        final selectionIndex = selectedList.indexOf(file.path);
        return _buildFileCard(
          context,
          app,
          file,
          selectionIndex != -1,
          selectionIndex,
          app.pinnedPdfs.contains(file.path),
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
    double safeAreaTop,
  ) {
    return GridView.builder(
      key: const PageStorageKey('pdf_grid'),
      padding: EdgeInsets.fromLTRB(16, safeAreaTop + 104, 16, 140),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: sortedPdfs.length,
      itemBuilder: (context, index) {
        final file = sortedPdfs[index];
        final selectionIndex = selectedList.indexOf(file.path);
        return _buildFileCard(
          context,
          app,
          file,
          selectionIndex != -1,
          selectionIndex,
          app.pinnedPdfs.contains(file.path),
          isGrid: true,
        );
      },
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
      end: 0.94,
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
