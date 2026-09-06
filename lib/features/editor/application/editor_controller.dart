import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/scanned_document.dart';
import '../../../data/providers.dart';
import '../../../data/services/pdf_service.dart';
import '../../documents/application/documents_controller.dart';

/// One page while it is being edited.
///
/// Pages kept from the original carry only their source index — the preview is
/// rendered from the file on demand, so a 60-page document does not hold 60
/// bitmaps in memory just to be reordered.
@immutable
class EditorPageItem {
  const EditorPageItem({
    required this.id,
    this.sourceIndex,
    this.imageBytes,
    this.blank = false,
  });

  final String id;
  final int? sourceIndex;
  final Uint8List? imageBytes;
  final bool blank;

  bool get isFromSource => sourceIndex != null;

  PageBlueprint toBlueprint() {
    if (blank) return const PageBlueprint.blank();
    if (imageBytes != null) return PageBlueprint.image(imageBytes!);
    return PageBlueprint.fromSource(sourceIndex!);
  }
}

@immutable
class EditorState {
  const EditorState({
    required this.document,
    required this.pages,
    this.selectedId,
    this.dirty = false,
    this.saving = false,
  });

  final ScannedDocument document;
  final List<EditorPageItem> pages;

  /// The page the bottom dock acts on. Tapping a page selects it, so no card
  /// needs an overflow button sitting on top of the content.
  final String? selectedId;
  final bool dirty;
  final bool saving;

  int get selectedIndex =>
      selectedId == null ? -1 : pages.indexWhere((p) => p.id == selectedId);
  bool get hasSelection => selectedIndex >= 0;

  EditorState copyWith({
    List<EditorPageItem>? pages,
    String? selectedId,
    bool clearSelection = false,
    bool? dirty,
    bool? saving,
  }) {
    return EditorState(
      document: document,
      pages: pages ?? this.pages,
      selectedId: clearSelection ? null : (selectedId ?? this.selectedId),
      dirty: dirty ?? this.dirty,
      saving: saving ?? this.saving,
    );
  }
}

class EditorController extends AsyncNotifier<EditorState> {
  EditorController(this.documentId);

  final int documentId;
  int _sequence = 0;

  @override
  Future<EditorState> build() async {
    final document =
        ref.read(documentByIdProvider(documentId)) ??
        await ref.read(documentRepositoryProvider).byId(documentId);
    if (document == null) {
      throw StateError('Documento $documentId non trovato');
    }

    var count = document.pageCount;
    if (count <= 0) {
      count = await ref.read(pdfServiceProvider).pageCount(document.file);
    }

    return EditorState(
      document: document,
      pages: [
        for (var i = 0; i < count; i++)
          EditorPageItem(id: 'src-${_sequence++}', sourceIndex: i),
      ],
    );
  }

  EditorState? get _current => state.value;

  void _mutate(List<EditorPageItem> pages, {String? select}) {
    final current = _current;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(pages: pages, selectedId: select, dirty: true),
    );
  }

  /// Tap to select; tapping the selected page again clears the selection.
  void select(String id) {
    final current = _current;
    if (current == null) return;
    state = AsyncData(
      current.selectedId == id
          ? current.copyWith(clearSelection: true)
          : current.copyWith(selectedId: id),
    );
  }

  /// [newIndex] is the slot the page ends up in.
  ///
  /// The filmstrip uses `ReorderableListView.onReorderItem`, which already
  /// accounts for the removed item — unlike the older `onReorder`, whose
  /// insert-before index needs a -1 correction when moving an item down.
  void reorder(int oldIndex, int newIndex) {
    final current = _current;
    if (current == null) return;
    final pages = [...current.pages];
    final moved = pages.removeAt(oldIndex);
    pages.insert(newIndex, moved);
    _mutate(pages);
  }

  /// Duplicates a page and selects the copy, so the dock keeps acting on what
  /// the user just created.
  void duplicate(int index) {
    final current = _current;
    if (current == null || index < 0 || index >= current.pages.length) return;
    final pages = [...current.pages];
    final source = pages[index];
    final copy = EditorPageItem(
      id: 'dup-${_sequence++}',
      sourceIndex: source.sourceIndex,
      imageBytes: source.imageBytes,
      blank: source.blank,
    );
    pages.insert(index + 1, copy);
    _mutate(pages, select: copy.id);
  }

  /// Replaces one page with a picture of itself, edited.
  ///
  /// A PDF page is not editable as a document — Syncfusion can stamp pages,
  /// not rewrite their content — so "modifica pagina" renders the page, hands
  /// the bitmap to the image editor and puts the result back in its slot. The
  /// page keeps its position and the rest of the document is untouched.
  void replaceWithImage(int index, Uint8List bytes) {
    final current = _current;
    if (current == null || index < 0 || index >= current.pages.length) return;
    final pages = [...current.pages];
    final edited = EditorPageItem(id: 'edit-${_sequence++}', imageBytes: bytes);
    pages[index] = edited;
    _mutate(pages, select: edited.id);
  }

  void remove(int index) {
    final current = _current;
    if (current == null || current.pages.length <= 1) return;
    if (index < 0 || index >= current.pages.length) return;
    final pages = [...current.pages]..removeAt(index);
    state = AsyncData(
      current.copyWith(pages: pages, clearSelection: true, dirty: true),
    );
  }

  void addBlank() {
    final current = _current;
    if (current == null) return;
    final page = EditorPageItem(id: 'blank-${_sequence++}', blank: true);
    _mutate([...current.pages, page], select: page.id);
  }

  void addImage(Uint8List bytes) {
    final current = _current;
    if (current == null) return;
    final page = EditorPageItem(id: 'img-${_sequence++}', imageBytes: bytes);
    _mutate([...current.pages, page], select: page.id);
  }

  /// Rewrites the file on a background isolate and refreshes the archive row.
  Future<bool> save() async {
    final current = _current;
    if (current == null || current.pages.isEmpty) return false;

    state = AsyncData(current.copyWith(saving: true));
    try {
      await ref
          .read(pdfServiceProvider)
          .rewrite(
            target: current.document.file,
            pages: [for (final page in current.pages) page.toBlueprint()],
          );
      final refreshed = await ref
          .read(documentsControllerProvider.notifier)
          .reload(current.document);

      state = AsyncData(
        EditorState(
          document: refreshed,
          pages: [
            for (var i = 0; i < current.pages.length; i++)
              EditorPageItem(id: 'src-${_sequence++}', sourceIndex: i),
          ],
        ),
      );
      return true;
    } on Object {
      state = AsyncData(current.copyWith(saving: false));
      return false;
    }
  }
}

/// Auto-disposed: leaving the editor must release any picked image bytes.
final editorControllerProvider =
    AsyncNotifierProvider.family<EditorController, EditorState, int>(
      EditorController.new,
      isAutoDispose: true,
    );
