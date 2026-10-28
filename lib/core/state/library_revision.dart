import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped after every write to either library. Providers that summarise the
/// libraries (folder counts, the bin) watch it instead of being refreshed by
/// whoever made the change.
class LibraryRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final libraryRevisionProvider = NotifierProvider<LibraryRevision, int>(
  LibraryRevision.new,
);

extension LibraryChanged on Ref {
  void libraryChanged() => read(libraryRevisionProvider.notifier).bump();
}
