import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'app_state.dart';
import 'pdf_editor_screen.dart';

class PdfPreviewScreen extends StatelessWidget {
  final File file;
  const PdfPreviewScreen({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(app.t('preview')),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: app.t('edit'),
            onPressed: () {
              Navigator.pushReplacement(
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
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: app.t('share'),
            onPressed: () => Share.shareXFiles([XFile(file.path)]),
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => file.readAsBytesSync(),
        allowPrinting: false,
        allowSharing: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
      ),
    );
  }
}
