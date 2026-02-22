import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as s_pdf;
import 'package:printing/printing.dart';
import 'app_state.dart';

class PdfPageData {
  final Uint8List displayImage;
  final int? originalIndex;
  final Uint8List? newRawImage;
  PdfPageData({
    required this.displayImage,
    this.originalIndex,
    this.newRawImage,
  });
}

class VisualPdfEditorScreen extends StatefulWidget {
  final File file;
  final VoidCallback onSaved;
  const VisualPdfEditorScreen({
    super.key,
    required this.file,
    required this.onSaved,
  });

  @override
  State<VisualPdfEditorScreen> createState() => _VisualPdfEditorScreenState();
}

class _VisualPdfEditorScreenState extends State<VisualPdfEditorScreen> {
  List<PdfPageData> _pages = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadVisualThumbnails();
  }

  Future<void> _loadVisualThumbnails() async {
    final bytes = await widget.file.readAsBytes();
    List<PdfPageData> tempPages = [];
    int index = 0;
    await for (final page in Printing.raster(bytes, dpi: 100)) {
      tempPages.add(
        PdfPageData(displayImage: await page.toPng(), originalIndex: index),
      );
      index++;
    }
    setState(() {
      _pages = tempPages;
      _isLoading = false;
    });
  }

  Future<void> _addNewPhoto(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(
        () => _pages.add(PdfPageData(displayImage: bytes, newRawImage: bytes)),
      );
    }
  }

  Future<void> _savePdf() async {
    setState(() => _isSaving = true);
    final originalDoc = s_pdf.PdfDocument(
      inputBytes: await widget.file.readAsBytes(),
    );
    final newDoc = s_pdf.PdfDocument();

    for (var pageData in _pages) {
      if (pageData.originalIndex != null) {
        s_pdf.PdfPage oldPage = originalDoc.pages[pageData.originalIndex!];
        newDoc.pageSettings
          ..size = oldPage.size
          ..margins.all = 0;
        newDoc.pages.add().graphics.drawPdfTemplate(
          oldPage.createTemplate(),
          const Offset(0, 0),
        );
      } else if (pageData.newRawImage != null) {
        final bitmap = s_pdf.PdfBitmap(pageData.newRawImage!);
        newDoc.pageSettings
          ..size = Size(bitmap.width.toDouble(), bitmap.height.toDouble())
          ..margins.all = 0;
        newDoc.pages.add().graphics.drawImage(
          bitmap,
          Rect.fromLTWH(
            0,
            0,
            newDoc.pageSettings.size.width,
            newDoc.pageSettings.size.height,
          ),
        );
      }
    }
    await widget.file.writeAsBytes(await newDoc.save());
    originalDoc.dispose();
    newDoc.dispose();
    widget.onSaved();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF Saved!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.read<AppState>().t('edit')),
        actions: [
          if (!_isLoading)
            TextButton.icon(
              onPressed: _isSaving ? null : _savePdf,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(),
                    )
                  : const Icon(Icons.save),
              label: Text(context.read<AppState>().t('save')),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _pages.length,
              onReorder: (oldIndex, newIndex) => setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _pages.removeAt(oldIndex);
                _pages.insert(newIndex, item);
              }),
              itemBuilder: (context, index) {
                final page = _pages[index];
                return Dismissible(
                  key: ValueKey('page_${page.originalIndex}_$index'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => setState(() => _pages.removeAt(index)),
                  child: Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 100,
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: MemoryImage(page.displayImage),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Expanded(child: Text('Page ${index + 1}')),
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Icon(Icons.drag_handle, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text("Photo"),
                onPressed: () => _addNewPhoto(ImageSource.camera),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text("Gallery"),
                onPressed: () => _addNewPhoto(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
