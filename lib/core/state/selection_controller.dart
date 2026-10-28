import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Multi-select state as a set of row ids, apart from the list it selects in
/// so a tap repaints one tile and the action bar.
class SelectionController extends Notifier<Set<int>> {
  @override
  Set<int> build() => const <int>{};

  bool get isActive => state.isNotEmpty;

  void toggle(int id) => state = state.contains(id)
      ? (Set<int>.of(state)..remove(id))
      : {...state, id};

  void selectAll(Iterable<int> ids) => state = Set.unmodifiable(ids);

  void clear() {
    if (state.isNotEmpty) state = const <int>{};
  }

  /// Drops ids that no longer exist.
  void retain(Set<int> live) {
    if (state.every(live.contains)) return;
    state = Set.unmodifiable(state.where(live.contains));
  }
}
