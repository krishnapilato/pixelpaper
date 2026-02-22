import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:path/path.dart' as p; // Add path package to pubspec
import 'app_state.dart';
import 'pdf_editor_screen.dart';

class PdfPreviewScreen extends StatelessWidget {
  final File file;
  const PdfPreviewScreen({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final fileName = p.basename(file.path);
    final fileSize = (file.lengthSync() / 1024).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surfaceVariant.withOpacity(0.3),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              app.t('preview'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '$fileName • ${fileSize}KB',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          // Edit Button - Prominent for UX
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: IconButton(
                icon: Icon(
                  Icons.edit_note,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                onPressed: () => _navigateToEditor(context, app),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // The PDF Viewer
          Padding(
            padding: const EdgeInsets.only(
              bottom: 80.0,
            ), // Space for floating bottom bar
            child: PdfPreview(
              build: (format) => file.readAsBytesSync(),
              useActions: false, // Custom UI looks better than default actions
              canDebug: false,
              loadingWidget: const Center(
                child: CircularProgressIndicator.adaptive(),
              ),
            ),
          ),

          // Custom Glassmorphic Bottom Action Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomActionBar(context, app),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context, AppState app) {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 70,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.share_outlined,
            label: app.t('share'),
            onTap: () => Share.shareXFiles([XFile(file.path)]),
          ),
          _ActionButton(
            icon: Icons.print_outlined,
            label: app.t('print'),
            onTap: () async {
              await Printing.layoutPdf(onLayout: (_) => file.readAsBytesSync());
            },
          ),
          _ActionButton(
            icon: Icons.info_outline,
            label: app.t('details'),
            onTap: () => _showFileDetails(context),
          ),
        ],
      ),
    );
  }

  void _navigateToEditor(BuildContext context, AppState app) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VisualPdfEditorScreen(file: file, onSaved: () => app.loadData()),
      ),
    );
  }

  void _showFileDetails(BuildContext context) {
    final app = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              app.t('file_details'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.folder),
              title: Text(app.t('path')),
              subtitle: Text(file.path),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(app.t('modified')),
              subtitle: Text(file.lastModifiedSync().toString()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
