/// Which library a folder belongs to. Documents and photos keep separate
/// folder sets: a scan archive and a photo roll are organised by different
/// criteria, and merging them would force one naming scheme onto both.
enum FolderKind { document, capture }

/// A single, flat folder.
///
/// Deliberately not nested: one level covers "Fatture", "Università",
/// "Ricette" without breadcrumbs, back stacks or recursive moves — and a
/// scanner archive that needs a tree is one that wants a file manager.
class Folder {
  const Folder({
    required this.id,
    required this.name,
    required this.kind,
    required this.createdAt,
    this.itemCount = 0,
  });

  final int id;
  final String name;
  final FolderKind kind;
  final DateTime createdAt;

  /// Filled by the repository when listing; not stored.
  final int itemCount;

  Folder copyWith({String? name, int? itemCount}) => Folder(
        id: id,
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
        id: row['id']! as int,
        name: row['name']! as String,
        kind: FolderKind.values.firstWhere(
          (k) => k.name == row['kind'],
          orElse: () => FolderKind.document,
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['created_at']! as int,
        ),
        itemCount: itemCount,
      );
}
