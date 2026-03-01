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
    HapticFeedback.lightImpact();
    setState(() => _showUI = !_showUI);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final colorScheme = Theme.of(context).colorScheme;
    final double safeAreaTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // --- 1. THE PDF CANVAS ---
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleUI,
              behavior: HitTestBehavior.translucent,
              child: Container(
                color: colorScheme.surfaceContainerLowest,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.fastOutSlowIn,
                  padding: EdgeInsets.only(
                    top: _showUI ? safeAreaTop + 104 : safeAreaTop + 12,
                    left: 12,
                    right: 12,
                    bottom: _showUI ? 132 : 24,
                  ),
                  child: PdfPreview(
                    build: (format) => currentFile.readAsBytesSync(),
                    useActions: false, // Custom UI handles this
                    canDebug: false,
                    loadingWidget: const Center(
                      child: CircularProgressIndicator.adaptive(),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // --- 2. FLOATING HEADER ISLAND ---
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.fastOutSlowIn,
            top: _showUI ? safeAreaTop + 16 : -100,
            left: 20,
            right: 20,
            child: _buildHeaderIsland(context, app),
          ),

          // --- 3. FLOATING ACTION DOCK ---
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.fastOutSlowIn,
            bottom: _showUI ? 32 : -120,
            left: 20,
            right: 20,
            child: _buildProActionDock(context, app),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIsland(BuildContext context, AppState app) {
    final colorScheme = Theme.of(context).colorScheme;
    final fileName = p.basename(currentFile.path);

    // CHANGED TO MB: Divide by (1024 * 1024) and format to 2 decimal places
    final fileSizeMB = (currentFile.lengthSync() / (1024 * 1024))
        .toStringAsFixed(2);
    final formattedDate = DateFormat(
      'MMM d, yyyy',
    ).format(currentFile.lastModifiedSync());

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
                  icon: const Icon(Icons.arrow_back_rounded),
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
                        '$fileSizeMB MB • $formattedDate', // APPLIED MB HERE
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => _navigateToEditor(context, app),
                  icon: const Icon(Icons.edit_note_rounded, size: 24),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProActionDock(BuildContext context, AppState app) {
    final colorScheme = Theme.of(context).colorScheme;

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
            color: colorScheme.surfaceContainerHigh.withOpacity(0.95),
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

  void _showOpenExternalDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.open_in_new_rounded,
                  color: Colors.blue,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Open Externally?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to open this document in another application?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        Navigator.pop(context);
                        OpenFilex.open(currentFile.path);
                      },
                      child: const Text(
                        'Open',
                        style: TextStyle(fontWeight: FontWeight.bold),
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

  void _showMoreOptions(BuildContext context, AppState app) {
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
            _buildActionRow(
              context,
              icon: Icons.info_outline_rounded,
              label: app.t('file_details') ?? 'File Details',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _showFileDetails(context, app);
              },
            ),
            _buildActionRow(
              context,
              icon: Icons.drive_file_rename_outline_rounded,
              label: app.t('rename') ?? 'Rename',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, app);
              },
            ),
            Divider(
              indent: 24,
              endIndent: 24,
              height: 32,
              color: colorScheme.outline.withOpacity(0.1),
            ),
            _buildActionRow(
              context,
              icon: Icons.delete_outline_rounded,
              label: app.t('delete') ?? 'Delete',
              color: Colors.red,
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, app);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = isDestructive ? Colors.red : colorScheme.onSurface;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
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
                  color: textColor,
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

  void _showFileDetails(BuildContext context, AppState app) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              app.t('file_details') ?? 'Details',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            _buildInfoIsland(
              context,
              Icons.folder_rounded,
              Colors.teal,
              app.t('path') ?? 'Path',
              currentFile.path,
              true,
            ),
            const SizedBox(height: 12),
            _buildInfoIsland(
              context,
              Icons.calendar_month_rounded,
              Colors.indigo,
              app.t('modified') ?? 'Modified',
              DateFormat(
                'MMM d, yyyy • h:mm a',
              ).format(currentFile.lastModifiedSync()),
              false,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoIsland(
    BuildContext context,
    IconData icon,
    Color color,
    String label,
    String value,
    bool canCopy,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface.withOpacity(0.5),
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (canCopy)
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                HapticFeedback.lightImpact();
              },
            ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, AppState app) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = TextEditingController(
      text: p.basenameWithoutExtension(currentFile.path),
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.drive_file_rename_outline_rounded,
                  color: Colors.orange,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Rename PDF',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  suffixText: '.pdf',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withOpacity(
                    0.5,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        if (controller.text.trim().isEmpty) return;
                        final newPath = p.join(
                          p.dirname(currentFile.path),
                          '${controller.text.trim()}.pdf',
                        );
                        setState(
                          () => currentFile = currentFile.renameSync(newPath),
                        );
                        app.loadData();
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Rename',
                        style: TextStyle(fontWeight: FontWeight.bold),
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

  void _showDeleteDialog(BuildContext context, AppState app) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
          ),
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
              const SizedBox(height: 16),
              const Text(
                'Delete PDF?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This document will be removed from your device permanently. This cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
                        currentFile.deleteSync();
                        app.loadData();
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Delete',
                        style: TextStyle(fontWeight: FontWeight.bold),
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

  void _navigateToEditor(BuildContext context, AppState app) {
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
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colorScheme.primary, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: colorScheme.primary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
