import 'package:flutter/foundation.dart';

import 'rows.dart';

/// Documents and photos keep separate, flat folder sets.
enum FolderKind { document, capture }

@immutable
class Folder {
  const Folder({
    required this.id,
    required this.name,
    required this.kind,
    required this.createdAt,
    this.itemCount = 0,
  });

  static const int maxNameLength = 60;

  final int id;
  final String name;
  final FolderKind kind;
  final DateTime createdAt;

  /// Live items inside; computed when listing, not stored.
  final int itemCount;

  /// Trimmed, single-line, bounded; null when nothing usable is left.
  static String? cleanName(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(
          RegExp(r'[\x00-\x1F\x7F\u200B-\u200F\u202A-\u202E\u2066-\u2069]'),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return null;
    final runes = cleaned.runes;
    return runes.length <= maxNameLength
        ? cleaned
        : String.fromCharCodes(runes.take(maxNameLength)).trim();
  }

  Folder copyWith({int? id, String? name, int? itemCount}) => Folder(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind,
    createdAt: createdAt,
    itemCount: itemCount ?? this.itemCount,
  );

  Map<String, Object?> toRow() => {
    'name': name,
    'kind': kind.name,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  static Folder fromRow(Map<String, Object?> row, {int itemCount = 0}) =>
      Folder(
        id: Rows.integer(row, 'id'),
        name: Rows.text(row, 'name'),
        kind: FolderKind.values.firstWhere(
          (k) => k.name == row['kind'],
          orElse: () => FolderKind.document,
        ),
        createdAt: Rows.time(row, 'created_at'),
        itemCount: itemCount,
      );

  @override
  bool operator ==(Object other) =>
      other is Folder &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.createdAt == createdAt &&
      other.itemCount == itemCount;

  @override
  int get hashCode => Object.hash(id, name, kind, createdAt, itemCount);
}
