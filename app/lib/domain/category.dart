import 'dart:ui' show Color;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'category.freezed.dart';

@freezed
abstract class EntryCategory with _$EntryCategory {
  const factory EntryCategory({
    required String key,
    required String label,
    required Color color,
    @Default('') String description,
    @Default(0) int sort,
  }) = _EntryCategory;
}
