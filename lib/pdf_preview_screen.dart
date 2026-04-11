import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import 'app_state.dart';
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
// PDF PREVIEW SCREEN
// -----------------------------------------------------------------------------
class PdfPreviewScreen extends StatefulWidget {
  final File file;
  const PdfPreviewScreen({super.key, required this.file});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  late File currentFile;
  bool _showUI = true;

  @override
  void initState() {
    super.initState();
    currentFile = widget.file;
  }

  void _toggleUI() {
    HapticFeedback.selectionClick();
    setState(() => _showUI = !_showUI);
  }

  // --- PREMIUM APPLE-STYLE MODALS & SHEETS ---

  void _showOpenExternalDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                        isDark ? 0.6 : 0.85,
                      ),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: colorScheme.onSurface.withOpacity(0.08),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_new_rounded,
                          color: colorScheme.onSurface,
                          size: 48,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Open Externally?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Open this document in another application.',
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
                                    'Cancel',
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
                                  Navigator.pop(context);
                                  OpenFilex.open(currentFile.path);
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
                                    'Open',
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

  void _showRenameDialog(BuildContext context, AppState app) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(
      text: p.basenameWithoutExtension(currentFile.path),
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
                        isDark ? 0.6 : 0.85,
                      ),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: colorScheme.onSurface.withOpacity(0.08),
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
                          'Rename PDF',
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
                            controller: controller,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            decoration: const InputDecoration(
                              suffixText: '.pdf',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
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
                                    'Cancel',
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
                                  if (controller.text.trim().isEmpty) return;
                                  final newPath = p.join(
                                    p.dirname(currentFile.path),
                                    '${controller.text.trim()}.pdf',
                                  );
                                  setState(
                                    () => currentFile = currentFile.renameSync(
                                      newPath,
                                    ),
                                  );
                                  app.loadData();
                                  Navigator.pop(context);
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
                                    'Rename',
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

  void _showDeleteDialog(BuildContext context, AppState app) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                        isDark ? 0.6 : 0.85,
                      ),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: colorScheme.onSurface.withOpacity(0.08),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Delete PDF?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This document will be permanently removed.',
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
                                    'Cancel',
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
                                  currentFile.deleteSync();
                                  app.loadData();
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(
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
          ),
        );
      },
    );
  }

  void _showMoreOptions(BuildContext context, AppState app) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fileName = p.basename(currentFile.path);
    final fileSize = (currentFile.lengthSync() / (1024 * 1024)).toStringAsFixed(
      2,
    );
    final formattedDate = DateFormat(
      'MMM d, yyyy',
    ).format(currentFile.lastModifiedSync());

    HapticFeedback.mediumImpact();
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

                  // Action Group 1
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        _buildBottomSheetItem(
                          context,
                          icon: Icons.info_outline_rounded,
                          title: app.t('file_details') ?? 'File Details',
                          onTap: () {
                            Navigator.pop(context);
                            _showFileDetails(context, app);
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
                            _showRenameDialog(context, app);
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
                        _showDeleteDialog(context, app);
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

  void _showFileDetails(BuildContext context, AppState app) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDate = DateFormat(
      'MMM d, yyyy • h:mm a',
    ).format(currentFile.lastModifiedSync());
    final fileSize = (currentFile.lengthSync() / (1024 * 1024)).toStringAsFixed(
      2,
    );

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
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
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
                    app.t('file_details') ?? 'Info',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildDetailCard(
                    Icons.folder_rounded,
                    app.t('path') ?? 'Path',
                    currentFile.path,
                    canCopy: true,
                  ),
                  _buildDetailCard(
                    Icons.sd_storage_rounded,
                    'Size',
                    '$fileSize MB',
                  ),
                  _buildDetailCard(
                    Icons.calendar_month_rounded,
                    app.t('modified') ?? 'Date Modified',
                    formattedDate,
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

  Widget _buildDetailCard(
    IconData icon,
    String label,
    String value, {
    bool canCopy = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSurface.withOpacity(0.6), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface.withOpacity(0.4),
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (canCopy)
            ProFluidBounce(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                HapticFeedback.lightImpact();
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Icon(
                  Icons.copy_rounded,
                  size: 20,
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToEditor(BuildContext context, AppState app) {
    HapticFeedback.lightImpact();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VisualPdfEditorScreen(
          file: currentFile,
          onSaved: () => app.loadData(),
        ),
      ),
    );
  }

  // --- MAIN BUILD ---

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final colorScheme = Theme.of(context).colorScheme;
    final double safeAreaTop = MediaQuery.of(context).padding.top;
    final double safeAreaBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // 1. THE PDF CANVAS
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleUI,
              behavior: HitTestBehavior.translucent,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(
                  top: _showUI ? safeAreaTop + 96 : safeAreaTop + 16,
                  left: 12,
                  right: 12,
                  bottom: _showUI ? safeAreaBottom + 112 : safeAreaBottom + 16,
                ),
                child: PdfPreview(
                  build: (format) => currentFile.readAsBytesSync(),
                  useActions: false,
                  canDebug: false,
                  loadingWidget: Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.onSurface,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. FLOATING HEADER ISLAND
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            top: _showUI ? safeAreaTop + 16 : -120,
            left: 20,
            right: 20,
            child: _buildHeaderIsland(context, app),
          ),

          // 3. FLOATING ACTION DOCK
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            bottom: _showUI ? (safeAreaBottom > 0 ? safeAreaBottom : 24) : -120,
            left: 32,
            right: 32,
            child: _buildProActionDock(context, app),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIsland(BuildContext context, AppState app) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fileName = p.basename(currentFile.path);
    final fileSizeMB = (currentFile.lengthSync() / (1024 * 1024))
        .toStringAsFixed(2);
    final formattedDate = DateFormat(
      'MMM d, yyyy',
    ).format(currentFile.lastModifiedSync());

    return Container(
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            // FIX: Moved color inside BoxDecoration
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
                      const SizedBox(height: 2),
                      Text(
                        '$fileSizeMB MB • $formattedDate',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                ProFluidBounce(
                  onTap: () => _navigateToEditor(context, app),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          size: 18,
                          color: colorScheme.surface,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Edit',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.surface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProActionDock(BuildContext context, AppState app) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            // FIX: Moved color inside BoxDecoration
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(isDark ? 0.5 : 0.7),
              border: Border.all(
                color: colorScheme.onSurface.withOpacity(0.08),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _DockAction(
                  icon: Icons.ios_share_rounded,
                  label: app.t('share') ?? 'Share',
                  onTap: () => Share.shareXFiles([XFile(currentFile.path)]),
                ),
                _DockAction(
                  icon: Icons.open_in_new_rounded,
                  label: app.t('open') ?? 'Open',
                  onTap: () => _showOpenExternalDialog(context),
                ),
                _DockAction(
                  icon: Icons.print_rounded,
                  label: app.t('print') ?? 'Print',
                  onTap: () => Printing.layoutPdf(
                    onLayout: (_) => currentFile.readAsBytesSync(),
                  ),
                ),
                _DockAction(
                  icon: Icons.more_horiz_rounded,
                  label: app.t('more') ?? 'More',
                  onTap: () => _showMoreOptions(context, app),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DockAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ProFluidBounce(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colorScheme.onSurface, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withOpacity(0.8),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
