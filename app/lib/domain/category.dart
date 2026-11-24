import 'dart:ui' show Color;


Color parseHex(String hex) => Color(int.parse('ff${hex.replaceFirst('#', '')}', radix: 16));

class EntryCategory {
  const EntryCategory({required this.key, required this.label, required this.color, this.description = '', this.sort = 0});
  final String key, label, description;
  final Color color;
  final int sort;

  factory EntryCategory.fromRow(Map<String, dynamic> r) => EntryCategory(
        key: r['key'] as String,
        label: r['label'] as String,
        color: parseHex(r['color'] as String),
        description: (r['description'] as String?) ?? '',
        sort: (r['sort'] as int?) ?? 0,
      );
}
