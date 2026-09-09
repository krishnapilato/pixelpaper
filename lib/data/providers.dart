import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local/app_database.dart';
import 'local/capture_dao.dart';
import 'local/folder_dao.dart';
import 'local/document_dao.dart';
import 'repositories/capture_repository.dart';
import 'repositories/document_repository.dart';
import 'repositories/library_repository.dart';
import 'services/ocr_service.dart';
import 'services/pdf_service.dart';
import 'services/settings_store.dart';
import 'services/scanner_service.dart';
import 'services/storage_service.dart';

/// Composition root for the data layer. Everything below the feature folders
/// is wired here once and never constructed anywhere else.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(),
);

final pdfServiceProvider = Provider<PdfService>(
  (ref) => PdfService(ref.watch(storageServiceProvider)),
);

final scannerServiceProvider = Provider<ScannerService>(
  (ref) => ScannerService(),
);

/// Holds one ML Kit recogniser for the session and closes it on dispose.
final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = OcrService();
  ref.onDispose(service.dispose);
  return service;
});

final folderDaoProvider = Provider<FolderDao>(
  (ref) => FolderDao(ref.watch(appDatabaseProvider)),
);

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(
    folders: ref.watch(folderDaoProvider),
    documents: ref.watch(documentDaoProvider),
    captures: ref.watch(captureDaoProvider),
    storage: ref.watch(storageServiceProvider),
  ),
);

final documentDaoProvider = Provider<DocumentDao>(
  (ref) => DocumentDao(ref.watch(appDatabaseProvider)),
);

final captureDaoProvider = Provider<CaptureDao>(
  (ref) => CaptureDao(ref.watch(appDatabaseProvider)),
);

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => DocumentRepository(
    dao: ref.watch(documentDaoProvider),
    storage: ref.watch(storageServiceProvider),
    pdf: ref.watch(pdfServiceProvider),
  ),
);

final captureRepositoryProvider = Provider<CaptureRepository>(
  (ref) => CaptureRepository(
    dao: ref.watch(captureDaoProvider),
    storage: ref.watch(storageServiceProvider),
  ),
);

final settingsStoreProvider = Provider<SettingsStore>((ref) => SettingsStore());

/// The folder "Esporta" writes into, null while it should ask each time.
final exportFolderProvider =
    FutureProvider<({String uri, String name})?>((ref) async {
  return ref.watch(settingsStoreProvider).exportFolder();
});
