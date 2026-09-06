import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Multi-select state, held as a set of row ids.
///
/// It lives in its own provider so a tap on one tile repaints that tile and
/// the action bar — not the whole grid.
class SelectionController extends Notifier<Set<int>> {
  @override
  Set<int> build() => const <int>{};

  bool get isActive => state.isNotEmpty;

  void toggle(int id) {
    final next = Set<int>.of(state);
    next.contains(id) ? next.remove(id) : next.add(id);
    state = next;
  }

  void selectAll(Iterable<int> ids) => state = ids.toSet();

  void clear() {
    if (state.isEmpty) return;
    state = const <int>{};
  }

  /// Drops ids that no longer exist after a reload.
  void retain(Set<int> live) {
    if (state.isEmpty || state.every(live.contains)) return;
    state = state.where(live.contains).toSet();
  }
}
