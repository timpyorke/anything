

class MetricDef {
  const MetricDef({required this.key, required this.label, this.unit = '', this.description = ''});
  final String key, label, unit, description;

  factory MetricDef.fromRow(Map<String, dynamic> r) => MetricDef(
        key: r['key'] as String,
        label: r['label'] as String,
        unit: (r['unit'] as String?) ?? '',
        description: (r['description'] as String?) ?? '',
      );

  Map<String, dynamic> toRow() => {'key': key, 'label': label, 'unit': unit, 'description': description};
}

class MetricValue {
  const MetricValue(this.key, this.value, [this.unit = '']);
  final String key;
  final double value;
  final String unit;

  factory MetricValue.fromRow(Map<String, dynamic> r) =>
      MetricValue(r['key'] as String, (r['value'] as num).toDouble(), (r['unit'] as String?) ?? '');
}
