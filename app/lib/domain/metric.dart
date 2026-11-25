import 'package:freezed_annotation/freezed_annotation.dart';

part 'metric.freezed.dart';

@freezed
abstract class MetricDef with _$MetricDef {
  const factory MetricDef({
    required String key,
    required String label,
    @Default('') String unit,
    @Default('') String description,
  }) = _MetricDef;
}

@freezed
abstract class MetricValue with _$MetricValue {
  const factory MetricValue(String key, double value, [@Default('') String unit]) = _MetricValue;
}
