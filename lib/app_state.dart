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
    (await SharedPreferences.getInstance()).setBool(
      'useExtStorage',
      useExternalStorage,
    );
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

  Future<void> saveImage(Uint8List bytes, {File? existingFile}) async {
    final path = await activeDirectory;
    final file =
        existingFile ??
        File('$path/IMG_${DateTime.now().millisecondsSinceEpoch}.jpg');

    await file.writeAsBytes(bytes);

    // NEW: Force Flutter to clear the old image from memory cache!
    await FileImage(file).evict();

    await loadData();
  }

  Future<bool> generatePDF(String customName) async {
    if (selectedImages.isEmpty) return false;

    final pdf = pw.Document();
    final selectedFiles = images
        .where((f) => selectedImages.contains(f.path))
        .toList();

    for (var file in selectedFiles) {
      final image = pw.MemoryImage(file.readAsBytesSync());
      pdf.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(10),
          build: (pw.Context context) => pw.Center(child: pw.Image(image)),
        ),
      );
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

  Future<bool> renamePdf(File file, String newName) async {
    try {
      final dir = file.parent.path;
      final newPath = '$dir/$newName.pdf';
      if (await File(newPath).exists()) return false;

      await file.rename(newPath);

      if (pinnedPdfs.contains(file.path)) {
        pinnedPdfs.remove(file.path);
        pinnedPdfs.add(newPath);
        (await SharedPreferences.getInstance()).setStringList(
          'pinnedPdfs',
          pinnedPdfs,
        );
      }
      await loadData();
      return true;
    } catch (e) {
      return false;
    }
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

  Future<void> deleteSelectedImages() async {
    for (String path in selectedImages) {
      if (await File(path).exists()) await File(path).delete();
    }
    clearImageSelection();
    await loadData();
  }

  Future<void> deleteSelectedPdfs() async {
    for (String path in selectedPdfs) {
      if (await File(path).exists()) await File(path).delete();
      pinnedPdfs.remove(path);
    }
    (await SharedPreferences.getInstance()).setStringList(
      'pinnedPdfs',
      pinnedPdfs,
    );
    clearPdfSelection();
    await loadData();
  }

  void toggleGalleryGrid() async {
    gridColumns = gridColumns == 4 ? 2 : gridColumns + 1;
    notifyListeners();
  }

  void toggleFilesLayout() async {
    isFilesGrid = !isFilesGrid;
    notifyListeners();
  }

  void togglePdfPin(String path) async {
    pinnedPdfs.contains(path) ? pinnedPdfs.remove(path) : pinnedPdfs.add(path);
    notifyListeners();
  }

  void updateSettings({ThemeMode? theme, Color? color, String? lang}) async {
    final prefs = await SharedPreferences.getInstance();
    if (theme != null) {
      themeMode = theme;
      prefs.setBool('isDark', theme == ThemeMode.dark);
    }
    if (color != null) {
      seedColor = color;
      prefs.setInt('color', color.value);
    }
    if (lang != null) {
      language = lang;
      prefs.setString('lang', lang);
    }
    notifyListeners();
  }

  void selectAllPdfs() {
    selectedPdfs.addAll(pdfs.map((f) => f.path));
    notifyListeners();
  }

  void selectAllImages() {
    selectedImages.addAll(images.map((f) => f.path));
    notifyListeners();
  }

  Future<void> loadLanguageJson() async {
    final String response = await rootBundle.loadString('assets/lang.json');
    _localizedStrings = json.decode(response);
    notifyListeners();
  }

  // Updated translation method
  String t(String key) {
    return _localizedStrings[language]?[key] ?? key;
  }
}
