/// Typed reads from a database row. A row with a missing or mistyped
/// required column is corrupt and raises [FormatException].
abstract final class Rows {
  static int integer(Map<String, Object?> row, String column) =>
      switch (row[column]) {
        final int value => value,
        _ => throw FormatException('Column $column is not an integer'),
      };

  static int integerOr(Map<String, Object?> row, String column, [int or = 0]) =>
      switch (row[column]) {
        final int value => value,
        _ => or,
      };

  static int? integerOrNull(Map<String, Object?> row, String column) =>
      switch (row[column]) {
        final int value => value,
        _ => null,
      };

  static String text(Map<String, Object?> row, String column) =>
      switch (row[column]) {
        final String value => value,
        _ => throw FormatException('Column $column is not text'),
      };

  static String? textOrNull(Map<String, Object?> row, String column) =>
      switch (row[column]) {
        final String value => value,
        _ => null,
      };

  static DateTime time(Map<String, Object?> row, String column) =>
      DateTime.fromMillisecondsSinceEpoch(integer(row, column));

  static DateTime? timeOrNull(Map<String, Object?> row, String column) =>
      switch (row[column]) {
        final int value => DateTime.fromMillisecondsSinceEpoch(value),
        _ => null,
      };
}

extension MillisecondPrecision on DateTime {
  /// The precision the database keeps, so a fresh object equals its row.
  DateTime get toMillis =>
      DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
}
