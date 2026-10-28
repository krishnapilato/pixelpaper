import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/limits.dart';
import '../../../data/models/document_page.dart';
import '../../../data/models/scanned_document.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/document_repository.dart';
import '../../documents/application/documents_controller.dart';

enum EditorActivity { idle, working, saving }

@immutable
class AlbumEditorState {
  const AlbumEditorState({
    required this.document,
    required this.pages,
    this.index = 0,
    this.dirty = false,
    this.activity = EditorActivity.idle,
  });

  final ScannedDocument document;
  final List<DocumentPage> pages;
  final int index;
  final bool dirty;
  final EditorActivity activity;

  bool get isIdle => activity == EditorActivity.idle;
  bool get canDelete => pages.length > 1;
  DocumentPage? get current =>
      index >= 0 && index < pages.length ? pages[index] : null;

  AlbumEditorState copyWith({
    ScannedDocument? document,
    List<DocumentPage>? pages,
    int? index,
    bool? dirty,
    EditorActivity? activity,
  }) {
    final nextPages = pages ?? this.pages;
    final nextIndex = (index ?? this.index).clamp(
      0,
      nextPages.isEmpty ? 0 : nextPages.length - 1,
    );
    return AlbumEditorState(
      document: document ?? this.document,
      pages: List.unmodifiable(nextPages),
      index: nextIndex,
      dirty: dirty ?? this.dirty,
      activity: activity ?? this.activity,
    );
  }
}

/// One editing session of an album. Nothing reaches the database before
/// [save]; files written for unsaved pages are swept on [discard], on save
/// and when the next session starts.
class AlbumEditorController extends AsyncNotifier<AlbumEditorState> {
  AlbumEditorController(this.documentId);

  final int documentId;

  DocumentRepository get _repository => ref.read(documentRepositoryProvider);

  @override
  Future<AlbumEditorState> build() async {
    final document =
        ref.read(documentByIdProvider(documentId)) ??
        await _repository.byId(documentId);
    if (document == null || !document.isAlbum) {
      throw StateError('Album $documentId non trovato');
    }
    await _repository.sweepAlbum(document);
    return AlbumEditorState(
      document: document,
      pages: List.unmodifiable(await _repository.pagesOf(document)),
    );
  }

  AlbumEditorState? get _state => state.value;

  void _set(AlbumEditorState next) {
    if (ref.mounted) state = AsyncData(next);
  }

  void show(int index) {
    final current = _state;
    if (current != null && index != current.index) {
      _set(current.copyWith(index: index));
    }
  }

  void reorder(int from, int to) {
    final current = _state;
    if (current == null || !current.isIdle) return;
    if (from < 0 || from >= current.pages.length) return;
    final pages = [...current.pages];
    final moved = pages.removeAt(from);
    final target = to.clamp(0, pages.length);
    pages.insert(target, moved);
    _set(current.copyWith(pages: pages, index: target, dirty: true));
  }

  void deleteCurrent() {
    final current = _state;
    if (current == null || !current.isIdle || !current.canDelete) return;
    final pages = [...current.pages]..removeAt(current.index);
    _set(current.copyWith(pages: pages, dirty: true));
  }

  /// A file copy: two pages sharing an image would edit each other.
  Future<void> duplicateCurrent() => _work((current) async {
    final page = current.current;
    if (page == null) return null;
    final copy = await _repository.addPageFile(
      current.document,
      page.fileIn(current.document.directory).path,
    );
    return _inserted(current, copy, current.index + 1);
  });

  /// Appends a page from a camera shot or a picked image; [consume] removes
  /// the source when it is a temporary file of the app.
  Future<void> append(File source, {bool consume = true}) =>
      _work((current) async {
        final page = await _repository.addPageFile(
          current.document,
          source.path,
          consume: consume,
        );
        return _inserted(current, page, current.pages.length);
      });

  /// Puts an edited image in place of the page on screen.
  Future<void> replaceCurrent(Uint8List bytes) => _work((current) async {
    if (current.current == null) return null;
    final page = await _repository.addPageBytes(current.document, bytes);
    final pages = [...current.pages]..[current.index] = page;
    return current.copyWith(pages: pages, dirty: true);
  });

  /// False when there was nothing to save or the write failed.
  Future<bool> save() async {
    final current = _state;
    if (current == null || !current.isIdle || !current.dirty) return false;
    _set(current.copyWith(activity: EditorActivity.saving));
    try {
      final saved = await ref
          .read(documentsControllerProvider.notifier)
          .savePages(current.document, current.pages)
          .bounded();
      final pages = await _repository.pagesOf(saved);
      _set(
        current.copyWith(
          document: saved,
          pages: pages,
          dirty: false,
          activity: EditorActivity.idle,
        ),
      );
      return true;
    } on Object {
      _set(current.copyWith(activity: EditorActivity.idle));
      return false;
    }
  }

  /// Drops the unsaved session and the files it wrote.
  Future<void> discard() async {
    final current = _state;
    if (current == null) return;
    await _repository.sweepAlbum(current.document);
  }

  AlbumEditorState _inserted(
    AlbumEditorState current,
    DocumentPage page,
    int at,
  ) {
    final pages = [...current.pages]..insert(at, page);
    return current.copyWith(pages: pages, index: at, dirty: true);
  }

  /// Runs one file operation at a time; the state it started from is what it
  /// edits, and a failure leaves that state untouched.
  Future<void> _work(
    Future<AlbumEditorState?> Function(AlbumEditorState current) task,
  ) async {
    final current = _state;
    if (current == null || !current.isIdle) return;
    _set(current.copyWith(activity: EditorActivity.working));
    try {
      final next = await task(current).bounded();
      _set((next ?? current).copyWith(activity: EditorActivity.idle));
    } on Object {
      _set(current.copyWith(activity: EditorActivity.idle));
      rethrow;
    }
  }
}

final albumEditorProvider =
    AsyncNotifierProvider.family<AlbumEditorController, AlbumEditorState, int>(
      AlbumEditorController.new,
      isAutoDispose: true,
    );
