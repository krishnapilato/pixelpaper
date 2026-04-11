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
    this.scaleEnd = 0.95,
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

// -----------------------------------------------------------------------------
// FILES SCREEN
// -----------------------------------------------------------------------------
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

  // --- PREMIUM APPLE-STYLE MODALS ---

  void _showRenameDialog(BuildContext context, AppState app, File file) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(
      text: p.basenameWithoutExtension(file.path),
    );

    HapticFeedback.mediumImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 350),
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
                borderRadius: BorderRadius.circular(40),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withOpacity(
                        isDark ? 0.6 : 0.8,
                      ),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: colorScheme.onSurface.withOpacity(0.08),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.drive_file_rename_outline_rounded,
                          color: colorScheme.onSurface,
                          size: 48,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          app.t('rename') ?? 'Rename File',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colorScheme.onSurface.withOpacity(0.1),
                            ),
                          ),
                          child: TextField(
                            controller: nameController,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
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
                              child: ProFluidBounce(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: colorScheme.onSurface.withOpacity(
                                      0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    app.t('cancel') ?? 'Cancel',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ProFluidBounce(
                                onTap: () async {
                                  if (nameController.text.trim().isNotEmpty) {
                                    final success = await app.renamePdf(
                                      file,
                                      nameController.text.trim(),
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      if (!success) {
                                        _showProToast(
                                          context,
                                          'Name already exists!',
                                          Icons.error_outline_rounded,
                                          isError: true,
                                        );
                                      }
                                    }
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: colorScheme.onSurface,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    app.t('save') ?? 'Save',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.surface,
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
              color: colorScheme.surface.withOpacity(isDark ? 0.6 : 0.8),
              padding: const EdgeInsets.all(24),
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
                  const SizedBox(height: 20),
                  Text(
                    app.t('delete_confirm') ?? 'Delete PDF?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    app.t('delete_confirm_msg') ??
                        'This document will be removed permanently.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: ProFluidBounce(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colorScheme.onSurface.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              app.t('cancel') ?? 'Cancel',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ProFluidBounce(
                          onTap: () {
                            HapticFeedback.heavyImpact();
                            if (file != null) app.togglePdfSelection(file.path);
                            app.deleteSelectedPdfs();
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              app.t('delete') ?? 'Delete',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
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
    );
  }

  void _showFileActionModal(BuildContext context, AppState app, File file) {
    HapticFeedback.mediumImpact();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fileName = p.basename(file.path);
    final fileSize = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(2);
    final formattedDate = DateFormat(
      'MMM d, yyyy',
    ).format(file.lastModifiedSync());

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
              color: colorScheme.surface.withOpacity(isDark ? 0.6 : 0.8),
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
                  Row(
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
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fileName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$fileSize MB • $formattedDate',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action Group 1 (iOS Style Grouping)
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        _buildBottomSheetItem(
                          context,
                          icon: Icons.edit_note_rounded,
                          title: app.t('edit') ?? 'Edit Pages',
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
                        Divider(
                          height: 1,
                          indent: 56,
                          color: colorScheme.onSurface.withOpacity(0.05),
                        ),
                        _buildBottomSheetItem(
                          context,
                          icon: Icons.drive_file_rename_outline_rounded,
                          title: app.t('rename') ?? 'Rename',
                          onTap: () {
                            Navigator.pop(context);
                            _showRenameDialog(context, app, file);
                          },
                        ),
                        Divider(
                          height: 1,
                          indent: 56,
                          color: colorScheme.onSurface.withOpacity(0.05),
                        ),
                        _buildBottomSheetItem(
                          context,
                          icon: Icons.ios_share_rounded,
                          title: app.t('share') ?? 'Share',
                          onTap: () {
                            Navigator.pop(context);
                            Share.shareXFiles([XFile(file.path)]);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Action Group 2 (Destructive)
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _buildBottomSheetItem(
                      context,
                      icon: Icons.delete_outline_rounded,
                      title: app.t('delete') ?? 'Delete',
                      isDestructive: true,
                      onTap: () {
                        Navigator.pop(context);
                        _showDeleteConfirm(context, app, file: file);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheetItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isDestructive ? Colors.redAccent : colorScheme.onSurface;

    return ProFluidBounce(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colorScheme.onSurface.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  void _showProToast(
    BuildContext context,
    String message,
    IconData icon, {
    bool isError = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(top: 50, left: 24, right: 24),
        padding: EdgeInsets.zero,
        content: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isError
                    ? Colors.redAccent.withOpacity(0.9)
                    : colorScheme.onSurface.withOpacity(isDark ? 0.9 : 0.8),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: colorScheme.surface, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    message,
                    style: TextStyle(
                      color: colorScheme.surface,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
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
      backgroundColor: colorScheme.surface,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
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

          // DYNAMIC MORPHING HEADER ISLAND
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            top: safeAreaTop + 16,
            left: 24,
            right: 24,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isSelection
        ? colorScheme.onSurface.withOpacity(0.9)
        : colorScheme.surface.withOpacity(isDark ? 0.5 : 0.7);

    final shadowColor = isSelection
        ? colorScheme.onSurface.withOpacity(0.3)
        : colorScheme.shadow.withOpacity(isDark ? 0.3 : 0.08);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.fastOutSlowIn,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            // FIX: Color moved INSIDE the BoxDecoration
            decoration: BoxDecoration(
              color: bgColor,
              border: isSelection
                  ? null
                  : Border.all(
                      color: colorScheme.onSurface.withOpacity(0.08),
                      width: 0.5,
                    ),
            ),
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
          Expanded(
            child: Text(
              app.t('files') ?? 'Files',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                fontSize: 20,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          ProFluidBounce(
            onTap: _toggleSearch,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_rounded,
                size: 20,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ProFluidBounce(
            onTap: () {
              HapticFeedback.lightImpact();
              app.toggleFilesLayout();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                app.isFilesGrid
                    ? Icons.view_list_rounded
                    : Icons.grid_view_rounded,
                size: 20,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ProFluidBounce(
            onTap: () => showSettingsModal(context, app),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 20,
                color: colorScheme.onSurface,
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
          Icon(
            Icons.search_rounded,
            color: colorScheme.onSurface.withOpacity(0.5),
            size: 22,
          ),
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
                  color: colorScheme.onSurface.withOpacity(0.4),
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
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                _searchController.clear();
              },
            ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: colorScheme.onSurface),
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
          IconButton(
            icon: Icon(Icons.close_rounded, color: colorScheme.surface),
            onPressed: () {
              HapticFeedback.lightImpact();
              app.clearPdfSelection();
            },
          ),
          Expanded(
            child: Text(
              "${app.selectedPdfs.length} Selected",
              style: TextStyle(
                color: colorScheme.surface,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                letterSpacing: -0.5,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              isAllSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
              color: colorScheme.surface,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              isAllSelected ? app.clearPdfSelection() : app.selectAllPdfs();
            },
          ),
          IconButton(
            icon: Icon(Icons.ios_share_rounded, color: colorScheme.surface),
            onPressed: () {
              Share.shareXFiles(app.selectedPdfs.map((p) => XFile(p)).toList());
              app.clearPdfSelection();
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
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

    return ProFluidBounce(
      onLongPress: () => app.togglePdfSelection(file.path),
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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(isSelected ? 0.95 : 1.0),
        transformAlignment: Alignment.center,
        margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.onSurface.withOpacity(0.05)
              : colorScheme.onSurface.withOpacity(0.02),
          borderRadius: BorderRadius.circular(isGrid ? 28 : 24),
          border: Border.all(
            color: isSelected
                ? colorScheme.onSurface.withOpacity(0.2)
                : colorScheme.onSurface.withOpacity(0.05),
            width: isSelected ? 1.5 : 1,
          ),
        ),
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
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                "$size MB • $date",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
        ProFluidBounce(
          onTap: () {
            HapticFeedback.lightImpact();
            app.togglePdfPin(file.path);
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: isPinned
                  ? Colors.amber
                  : colorScheme.onSurface.withOpacity(0.3),
              size: 20,
            ),
          ),
        ),
        ProFluidBounce(
          onTap: () => _showFileActionModal(context, app, file),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              Icons.more_horiz_rounded,
              color: colorScheme.onSurface.withOpacity(0.5),
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
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                "$size MB • $date",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -12,
          left: -12,
          child: ProFluidBounce(
            onTap: () {
              HapticFeedback.lightImpact();
              app.togglePdfPin(file.path);
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                color: isPinned
                    ? Colors.amber
                    : colorScheme.onSurface.withOpacity(0.3),
                size: 20,
              ),
            ),
          ),
        ),
        Positioned(
          top: -12,
          right: -12,
          child: ProFluidBounce(
            onTap: () => _showFileActionModal(context, app, file),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                Icons.more_horiz_rounded,
                color: colorScheme.onSurface.withOpacity(0.5),
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
    final size = large ? 56.0 : 44.0;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: isSelected
          ? Container(
              key: const ValueKey('selected'),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: colorScheme.onSurface,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.surface, width: 2),
              ),
              child: Center(
                child: Text(
                  '${selectionIndex + 1}',
                  style: TextStyle(
                    color: colorScheme.surface,
                    fontWeight: FontWeight.w700,
                    fontSize: large ? 18 : 14,
                  ),
                ),
              ),
            )
          : Container(
              key: const ValueKey('unselected'),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(large ? 16 : 12),
              ),
              child: Icon(
                Icons.picture_as_pdf_rounded,
                color: Colors.red,
                size: large ? 28 : 22,
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
              color: colorScheme.onSurface.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _searchQuery.isNotEmpty
                  ? Icons.search_off_rounded
                  : Icons.folder_open_rounded,
              size: 48,
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty
                ? 'No matches found'
                : (app.t('empty_files') ?? 'No Scanned PDFs'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
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
              color: colorScheme.onSurface.withOpacity(0.5),
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
