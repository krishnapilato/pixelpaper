import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

// A simple model to cache metadata so we don't hit the disk heavily during sorting
class FileEntry {
  final File file;
  final DateTime modified;
  FileEntry(this.file, this.modified);
}

class AppState extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  Color seedColor = Colors.deepOrange;
  String language = 'en';
  int gridColumns = 3;
  bool isFilesGrid = false;
  bool useExternalStorage = false;

  // Actual Files for the UI
  List<File> images = [];
  List<File> pdfs = [];

  // Metadata caches used for our Smart Diffing Algorithm
  List<FileEntry> _currentImageEntries = [];
  List<FileEntry> _currentPdfEntries = [];

  Set<String> selectedImages = {};
  Set<String> selectedPdfs = {};
  List<String> pinnedPdfs = [];

  bool get isImageSelectionMode => selectedImages.isNotEmpty;
  bool get isPdfSelectionMode => selectedPdfs.isNotEmpty;

  Map<String, dynamic> _localizedStrings = {};
  bool isLoading = false;
  bool isInitialLoading = true;

  AppState() {
    _initPrefsAndData();
  }

  Future<void> _initPrefsAndData() async {
    await loadLanguageJson();
    final prefs = await SharedPreferences.getInstance();

    language = prefs.getString('lang') ?? 'en';

    final isDark = prefs.getBool('isDark');
    if (isDark != null) themeMode = isDark ? ThemeMode.dark : ThemeMode.light;

    final colorVal = prefs.getInt('color');
    if (colorVal != null) seedColor = Color(colorVal);

    gridColumns = prefs.getInt('gridColumns') ?? 3;
    isFilesGrid = prefs.getBool('isFilesGrid') ?? false;
    useExternalStorage = prefs.getBool('useExtStorage') ?? false;
    pinnedPdfs = prefs.getStringList('pinnedPdfs') ?? [];

    await loadData();
    isInitialLoading = false;
    notifyListeners();
  }

  // Safely handles Android external storage gracefully falling back if unavailable
  Future<String> get activeDirectory async {
    if (useExternalStorage && Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      if (dir != null) return dir.path;
    }
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<void> toggleStorageDirectory() async {
    useExternalStorage = !useExternalStorage;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useExtStorage', useExternalStorage);

    // Clear lists so the UI visually refreshes to the new directory immediately
    images.clear();
    pdfs.clear();
    _currentImageEntries.clear();
    _currentPdfEntries.clear();

    // Clear selections that belong to the old directory
    clearImageSelection();
    clearPdfSelection();

    notifyListeners();
    await loadData();
  }

  // --- OPTIMIZED CORE LOAD ENGINE ---

  /// Reads directory, maps metadata, cleans up orphans, and performs Smart Diffing
  Future<void> loadData() async {
    if (isLoading) return;

    isLoading = true;
    notifyListeners(); // Ensure UI knows we are loading

    try {
      final dirPath = await activeDirectory;
      final dir = Directory(dirPath);
      if (!await dir.exists()) await dir.create(recursive: true);

      final List<FileEntry> newImageEntries = [];
      final List<FileEntry> newPdfEntries = [];

      // Safe Stream processing avoids memory spikes and race conditions
      await for (final entity in dir.list()) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (ext == '.jpg' ||
              ext == '.jpeg' ||
              ext == '.png' ||
              ext == '.pdf') {
            try {
              final stat = await entity.stat();
              final entry = FileEntry(entity, stat.modified);
              if (ext == '.pdf') {
                newPdfEntries.add(entry);
              } else {
                newImageEntries.add(entry);
              }
            } catch (_) {
              // Gracefully ignore files that get deleted mid-read
            }
          }
        }
      }

      // Sort by last modified (Chronological descending)
      newImageEntries.sort((a, b) => b.modified.compareTo(a.modified));
      newPdfEntries.sort((a, b) => b.modified.compareTo(a.modified));

      // SMART CLEANUP: Remove orphaned selections (e.g. files deleted externally)
      final imagePaths = newImageEntries.map((e) => e.file.path).toSet();
      final pdfPaths = newPdfEntries.map((e) => e.file.path).toSet();

      selectedImages.retainWhere((path) => imagePaths.contains(path));
      selectedPdfs.retainWhere((path) => pdfPaths.contains(path));

      // Update pins if a pinned file was deleted
      final validPins = pinnedPdfs
          .where((path) => pdfPaths.contains(path))
          .toList();
      if (validPins.length != pinnedPdfs.length) {
        pinnedPdfs = validPins;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('pinnedPdfs', pinnedPdfs);
      }

      // SMART DIFFING: Only update memory/rebuild UI if files actually changed
      final bool imagesChanged = _hasChanges(
        _currentImageEntries,
        newImageEntries,
      );
      final bool pdfsChanged = _hasChanges(_currentPdfEntries, newPdfEntries);

      if (imagesChanged) {
        _currentImageEntries = newImageEntries;
        images = newImageEntries.map((e) => e.file).toList();
      }

      if (pdfsChanged) {
        _currentPdfEntries = newPdfEntries;
        pdfs = newPdfEntries.map((e) => e.file).toList();
      }
    } finally {
      // Guarantee loading state completes
      isLoading = false;
      notifyListeners();
    }
  }

  /// Checks if two FileEntry lists differ in content, order, or modification dates
  bool _hasChanges(List<FileEntry> oldList, List<FileEntry> newList) {
    if (oldList.length != newList.length) return true;
    for (int i = 0; i < oldList.length; i++) {
      if (oldList[i].file.path != newList[i].file.path ||
          oldList[i].modified != newList[i].modified) {
        return true;
      }
    }
    return false;
  }

  // --- FILE OPERATIONS ---

  Future<void> saveImage(Uint8List bytes, {File? existingFile}) async {
    final path = await activeDirectory;
    DateTime? originalTimestamp;

    if (existingFile != null && await existingFile.exists()) {
      originalTimestamp = await existingFile.lastModified();
    }

    final file =
        existingFile ??
        File(p.join(path, 'IMG_${DateTime.now().millisecondsSinceEpoch}.jpg'));
    await file.writeAsBytes(bytes);

    if (originalTimestamp != null) {
      // Retain chronological order
      await file.setLastModified(originalTimestamp);

      // CRITICAL FIX: Evict the old image from Flutter's cache so the UI updates instantly
      await FileImage(file).evict();
      notifyListeners();
    }

    await loadData();
  }

  Future<bool> generatePDF(String customName) async {
    if (selectedImages.isEmpty) return false;

    final pdf = pw.Document();

    // CRITICAL FIX: Sets do not guarantee order. This ensures PDF pages
    // are generated in the exact visual chronological order shown in the UI.
    final sortedSelectedPaths = images
        .map((f) => f.path)
        .where((path) => selectedImages.contains(path))
        .toList();

    for (var imagePath in sortedSelectedPaths) {
      final file = File(imagePath);
      if (await file.exists()) {
        final imageBytes = await file.readAsBytes();
        final image = pw.MemoryImage(imageBytes);
        pdf.addPage(
          pw.Page(
            margin: const pw.EdgeInsets.all(0), // Pro borderless presentation
            build: (pw.Context context) => pw.Center(child: pw.Image(image)),
          ),
        );
      }
    }

    final path = await activeDirectory;
    String fileName = '$customName.pdf';
    File file = File(p.join(path, fileName));

    if (await file.exists()) {
      file = File(
        p.join(
          path,
          '${customName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
        ),
      );
    }

    await file.writeAsBytes(await pdf.save());
    clearImageSelection();
    await loadData();
    return true;
  }

  // --- SELECTION LOGIC ---

  void toggleImageSelection(String path) {
    selectedImages.contains(path)
        ? selectedImages.remove(path)
        : selectedImages.add(path);
    notifyListeners();
  }

  void clearImageSelection() {
    selectedImages.clear();
    notifyListeners();
  }

  void selectAllImages() {
    selectedImages.addAll(images.map((f) => f.path));
    notifyListeners();
  }

  void togglePdfSelection(String path) {
    selectedPdfs.contains(path)
        ? selectedPdfs.remove(path)
        : selectedPdfs.add(path);
    notifyListeners();
  }

  void clearPdfSelection() {
    selectedPdfs.clear();
    notifyListeners();
  }

  void selectAllPdfs() {
    selectedPdfs.addAll(pdfs.map((f) => f.path));
    notifyListeners();
  }

  // --- DELETE & RENAME ---

  Future<void> deleteSelectedImages() async {
    await Future.wait(
      selectedImages.map((path) async {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }),
    );
    clearImageSelection();
    await loadData();
  }

  Future<void> deleteSelectedPdfs() async {
    await Future.wait(
      selectedPdfs.map((path) async {
        final file = File(path);
        if (await file.exists()) await file.delete();
        pinnedPdfs.remove(path);
      }),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinnedPdfs', pinnedPdfs);
    clearPdfSelection();
    await loadData();
  }

  Future<bool> renamePdf(File file, String newName) async {
    try {
      final dir = file.parent.path;
      final newPath = p.join(dir, '$newName.pdf');

      if (file.path == newPath) return true; // No change made
      if (await File(newPath).exists()) return false; // Collision check

      await file.rename(newPath);

      bool needsPrefUpdate = false;

      // Smart Path Updates: Keep pins and selections alive across renames
      if (pinnedPdfs.contains(file.path)) {
        pinnedPdfs.remove(file.path);
        pinnedPdfs.add(newPath);
        needsPrefUpdate = true;
      }
      if (selectedPdfs.contains(file.path)) {
        selectedPdfs.remove(file.path);
        selectedPdfs.add(newPath);
      }

      if (needsPrefUpdate) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('pinnedPdfs', pinnedPdfs);
      }

      await loadData();
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- UI SETTINGS LOGIC ---

  void updateSettings({ThemeMode? theme, Color? color, String? lang}) async {
    final prefs = await SharedPreferences.getInstance();
    if (theme != null) {
      themeMode = theme;
      await prefs.setBool('isDark', theme == ThemeMode.dark);
    }
    if (color != null) {
      seedColor = color;
      await prefs.setInt('color', color.value);
    }
    if (lang != null) {
      language = lang;
      await prefs.setString('lang', lang);
    }
    notifyListeners();
  }

  Future<void> toggleGalleryGrid() async {
    gridColumns = gridColumns == 4 ? 2 : gridColumns + 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('gridColumns', gridColumns); // FIX: Now persists layout
    notifyListeners();
  }

  Future<void> toggleFilesLayout() async {
    isFilesGrid = !isFilesGrid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFilesGrid', isFilesGrid); // FIX: Now persists layout
    notifyListeners();
  }

  Future<void> togglePdfPin(String path) async {
    pinnedPdfs.contains(path) ? pinnedPdfs.remove(path) : pinnedPdfs.add(path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinnedPdfs', pinnedPdfs);
    notifyListeners();
  }

  // --- LOCALIZATION ---

  Future<void> loadLanguageJson() async {
    try {
      final String response = await rootBundle.loadString('assets/lang.json');
      _localizedStrings = json.decode(response);
    } catch (e) {
      _localizedStrings = {}; // Failsafe
    }
    notifyListeners();
  }

  String t(String key) {
    try {
      // Safe Cast implementation prevents crashes on faulty JSON parsing
      final langMap = _localizedStrings[language] as Map<String, dynamic>?;
      if (langMap != null && langMap.containsKey(key)) {
        return langMap[key].toString();
      }
    } catch (_) {}
    return key; // Fallback to raw key string
  }
}
