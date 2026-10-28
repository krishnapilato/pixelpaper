import 'package:sqflite/sqflite.dart';

/// SQLite builds before 3.32 (Android 10 and older) cap a statement at 999
/// bound parameters.
const int _chunk = 500;

/// Runs [run] with `id IN (?, …)` over [ids] in bounded chunks, inside one
/// transaction so the change is all-or-nothing.
Future<void> inChunks(
  Database db,
  Iterable<int> ids,
  Future<void> Function(Transaction txn, String placeholders, List<int> chunk)
  run,
) async {
  final all = ids.toSet().toList(growable: false);
  if (all.isEmpty) return;
  await db.transaction((txn) async {
    for (var start = 0; start < all.length; start += _chunk) {
      final chunk = all.sublist(
        start,
        start + _chunk > all.length ? all.length : start + _chunk,
      );
      await run(txn, List.filled(chunk.length, '?').join(','), chunk);
    }
  });
}
