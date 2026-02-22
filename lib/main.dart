import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'main_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const DocScannerApp(),
    ),
  );
}

class DocScannerApp extends StatelessWidget {
  const DocScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PixelPaper',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: app.seedColor,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: app.seedColor,
        brightness: Brightness.dark,
      ),
      themeMode: app.themeMode,
      home: const MainScreen(),
    );
  }
}
