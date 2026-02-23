import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:path/path.dart' as p;
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
    HapticFeedback.selectionClick();
    setState(() => _showUI = !_showUI);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final colorScheme = Theme.of(context).colorScheme;
    final fileName = p.basename(currentFile.path);
    final fileSize = (currentFile.lengthSync() / 1024).toStringAsFixed(1);

    final double safeAreaTop = MediaQuery.of(context).padding.top;
    final double appBarHeight = kToolbarHeight + safeAreaTop;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      extendBodyBehindAppBar: true,
      // 1. ANIMATED APP BAR
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedOpacity(
          opacity: _showUI ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: IgnorePointer(
            ignoring: !_showUI,
            child: AppBar(
              scrolledUnderElevation: 0,
              backgroundColor: Colors.transparent,
              elevation: 0,
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
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    app.t('preview') ?? 'Preview',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$fileName • ${fileSize}KB',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: IconButton.filledTonal(
                    onPressed: () => _navigateToEditor(context, app),
                    icon: const Icon(Icons.edit_note_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // FIXED: Positioned is now a DIRECT child of Stack
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleUI,
              behavior: HitTestBehavior.translucent,
              child: PdfPreview(
                build: (format) => currentFile.readAsBytesSync(),
                useActions: false,
                canDebug: false,
                // Adjust padding to ensure document is centered and not eaten by bars
                padding: EdgeInsets.only(
                  top: _showUI ? appBarHeight + 20 : safeAreaTop + 20,
                  left: 16,
                  right: 16,
                  bottom: _showUI ? 120 : 20,
                ),
                loadingWidget: const Center(
                  child: CircularProgressIndicator.adaptive(),
                ),
              ),
            ),
          ),

          // 2. PREMIUM GLASS BOTTOM BAR
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.fastOutSlowIn,
            bottom: _showUI ? 32 : -100,
            left: 20,
            right: 20,
            child: _buildGlassBottomBar(context, app),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassBottomBar(BuildContext context, AppState app) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            color: colorScheme.surface.withOpacity(0.8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionButton(
                  icon: Icons.ios_share_rounded,
                  label: app.t('share'),
                  onTap: () => Share.shareXFiles([XFile(currentFile.path)]),
                ),
                _ActionButton(
                  icon: Icons.open_in_new_rounded,
                  label: app.t('open'),
                  onTap: () => OpenFilex.open(currentFile.path),
                ),
                _ActionButton(
                  icon: Icons.print_rounded,
                  label: app.t('print'),
                  onTap: () => Printing.layoutPdf(
                    onLayout: (_) => currentFile.readAsBytesSync(),
                  ),
                ),
                _ActionButton(
                  icon: Icons.more_horiz_rounded,
                  label: app.t('more'),
                  onTap: () => _showMoreOptions(context, app),
                ),
              ],
            ),
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _buildOptionTile(
              context,
              Icons.info_outline_rounded,
              Colors.blue,
              app.t('file_details'),
              () {
                Navigator.pop(context);
                _showFileDetails(context, app);
              },
            ),
            _buildOptionTile(
              context,
              Icons.drive_file_rename_outline_rounded,
              Colors.orange,
              app.t('rename'),
              () {
                Navigator.pop(context);
                _showRenameDialog(context, app);
              },
            ),
            const Divider(indent: 24, endIndent: 24, height: 32),
            _buildOptionTile(
              context,
              Icons.delete_outline_rounded,
              Colors.red,
              app.t('delete'),
              () {
                Navigator.pop(context);
                _showDeleteDialog(context, app);
              },
              isDestructive: true,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context,
    IconData icon,
    Color color,
    String? title,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title ?? '',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : null,
        ),
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              app.t('file_details') ?? 'Details',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 24),
            _buildDetailCard(
              context,
              Icons.folder_open_rounded,
              Colors.teal,
              app.t('path'),
              currentFile.path,
              true,
            ),
            const SizedBox(height: 12),
            _buildDetailCard(
              context,
              Icons.access_time_rounded,
              Colors.purple,
              app.t('modified'),
              currentFile.lastModifiedSync().toString(),
              false,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(
    BuildContext context,
    IconData icon,
    Color color,
    String? label,
    String value,
    bool canCopy,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Path Copied"),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, AppState app) {
    final controller = TextEditingController(
      text: p.basenameWithoutExtension(currentFile.path),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Rename File'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            suffixText: '.pdf',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newPath = p.join(
                p.dirname(currentFile.path),
                '${controller.text}.pdf',
              );
              setState(() => currentFile = currentFile.renameSync(newPath));
              app.loadData();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, AppState app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Delete File?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              currentFile.deleteSync();
              app.loadData();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  const _ActionButton({
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
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colorScheme.primary, size: 24),
          const SizedBox(height: 4),
          Text(
            label ?? '',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
