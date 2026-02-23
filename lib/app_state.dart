import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:convert';
import 'package:flutter/services.dart';

class AppState extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  Color seedColor = Colors.deepOrange;
  String language = 'en';
  int gridColumns = 3;
  bool isFilesGrid = false;
  bool useExternalStorage = false;

  List<File> images = [];
  List<File> pdfs = [];

  // Using Set to keep unique paths and preserve tap order
  Set<String> selectedImages = {};
  Set<String> selectedPdfs = {};
  List<String> pinnedPdfs = [];

  bool get isImageSelectionMode => selectedImages.isNotEmpty;
  bool get isPdfSelectionMode => selectedPdfs.isNotEmpty;

  Map<String, dynamic> _localizedStrings = {};

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
  }

  Future<String> get activeDirectory async {
    if (useExternalStorage && Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      return dir!.path;
    }
    return (await getApplicationDocumentsDirectory()).path;
  }

  Future<void> toggleStorageDirectory() async {
    useExternalStorage = !useExternalStorage;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useExtStorage', useExternalStorage);
    await loadData();
  }

  Future<void> loadData() async {
    final dirPath = await activeDirectory;
    final dir = Directory(dirPath);
    if (!await dir.exists()) await dir.create(recursive: true);

    final files = dir.listSync().whereType<File>().toList();

    images = files.where((f) => f.path.toLowerCase().endsWith('.jpg')).toList();
    images.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    pdfs = files.where((f) => f.path.toLowerCase().endsWith('.pdf')).toList();
    pdfs.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    notifyListeners();
  }

  // --- SETTINGS METHOD (FIXES YOUR ERROR) ---
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

  Future<void> saveImage(Uint8List bytes, {File? existingFile}) async {
    final path = await activeDirectory;
    DateTime? originalTimestamp;

    // 1. If we are editing an existing file, capture its current "Last Modified" date
    if (existingFile != null && await existingFile.exists()) {
      originalTimestamp = await existingFile.lastModified();
    }

    final file =
        existingFile ??
        File('$path/IMG_${DateTime.now().millisecondsSinceEpoch}.jpg');

    // 2. Write the new edited bytes
    await file.writeAsBytes(bytes);

    // 3. IMPORTANT: Restore the original timestamp so the sort order doesn't change
    if (originalTimestamp != null) {
      await file.setLastModified(originalTimestamp);
    }

    // 4. Clear the image from Flutter's memory cache so the UI shows the new version
    await FileImage(file).evict();

    // 5. Reload the list
    await loadData();
  }

  Future<bool> generatePDF(String customName) async {
    if (selectedImages.isEmpty) return false;

    final pdf = pw.Document();

    // Logic: Iterate through the Set to maintain order of selection
    for (var imagePath in selectedImages) {
      final file = File(imagePath);
      if (file.existsSync()) {
        final image = pw.MemoryImage(file.readAsBytesSync());
        pdf.addPage(
          pw.Page(
            margin: const pw.EdgeInsets.all(10),
            build: (pw.Context context) => pw.Center(child: pw.Image(image)),
          ),
        );
      }
    }

    final path = await activeDirectory;
    File file = File('$path/$customName.pdf');
    if (await file.exists()) {
      file = File(
        '$path/${customName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    }

    await file.writeAsBytes(await pdf.save());
    clearImageSelection();
    await loadData();
    return true;
  }

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

  Future<void> deleteSelectedImages() async {
    for (String path in selectedImages) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    clearImageSelection();
    await loadData();
  }

  Future<void> deleteSelectedPdfs() async {
    for (String path in selectedPdfs) {
      final file = File(path);
      if (await file.exists()) await file.delete();
      pinnedPdfs.remove(path);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinnedPdfs', pinnedPdfs);
    clearPdfSelection();
    await loadData();
  }

  void toggleGalleryGrid() {
    gridColumns = gridColumns == 4 ? 2 : gridColumns + 1;
    notifyListeners();
  }

  void toggleFilesLayout() {
    isFilesGrid = !isFilesGrid;
    notifyListeners();
  }

  void togglePdfPin(String path) async {
    pinnedPdfs.contains(path) ? pinnedPdfs.remove(path) : pinnedPdfs.add(path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinnedPdfs', pinnedPdfs);
    notifyListeners();
  }

  Future<bool> renamePdf(File file, String newName) async {
    try {
      final dir = file.parent.path;
      final newPath = '$dir/$newName.pdf';
      if (await File(newPath).exists()) return false;
      await file.rename(newPath);

      if (pinnedPdfs.contains(file.path)) {
        pinnedPdfs.remove(file.path);
        pinnedPdfs.add(newPath);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('pinnedPdfs', pinnedPdfs);
      }
      await loadData();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> loadLanguageJson() async {
    final String response = await rootBundle.loadString('assets/lang.json');
    _localizedStrings = json.decode(response);
    notifyListeners();
  }

  String t(String key) {
    return _localizedStrings[language]?[key] ?? key;
  }
}
