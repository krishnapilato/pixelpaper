import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'app_state.dart';
import 'gallery_screen.dart';
import 'files_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isMenuOpen = false;

  void _toggleMenu() => setState(() => _isMenuOpen = !_isMenuOpen);

  Future<void> _processImage(ImageSource source) async {
    _toggleMenu();
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProImageEditor.file(
              File(image.path),
              callbacks: ProImageEditorCallbacks(
                onImageEditingComplete: (bytes) async {
                  if (mounted) {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 0);
                  }
                  await context.read<AppState>().saveImage(bytes);
                },
              ),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: const [GalleryScreen(), FilesScreen()],
          ),
          if (_isMenuOpen)
            GestureDetector(
              onTap: _toggleMenu,
              child: Container(color: Colors.black54),
            ),
          if (_isMenuOpen)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.extended(
                    heroTag: "t1",
                    onPressed: () => _processImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: Text(app.t('take_photo')),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton.extended(
                    heroTag: "t2",
                    onPressed: () => _processImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: Text(app.t('import_photo')),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        backgroundColor: _isMenuOpen
            ? colorScheme.secondaryContainer
            : colorScheme.primary,
        foregroundColor: _isMenuOpen
            ? colorScheme.onSecondaryContainer
            : colorScheme.onPrimary,
        elevation: _isMenuOpen ? 0 : 4,
        onPressed: _toggleMenu,
        child: Icon(_isMenuOpen ? Icons.close : Icons.add, size: 30),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.photo_library, app.t('gallery'), 0, app),
            const SizedBox(width: 48),
            _buildNavItem(Icons.folder, app.t('files'), 1, app),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, AppState app) {
    final color = _currentIndex == index
        ? Theme.of(context).colorScheme.primary
        : Colors.grey;
    return InkWell(
      onTap: () {
        app.clearImageSelection();
        app.clearPdfSelection();
        setState(() => _currentIndex = index);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
