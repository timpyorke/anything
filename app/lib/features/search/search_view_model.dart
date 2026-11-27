import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/dates.dart';
import '../diary/diary_view_model.dart';
import '../timeline/timeline_filter.dart';
import '../timeline/timeline_view_model.dart';

/// คำค้นของหน้าค้นหา (ปิดหน้าแล้วทิ้ง ไม่กระทบตัวกรองของ Timeline)
final searchQueryProvider = NotifierProvider.autoDispose<SearchViewModel, String>(SearchViewModel.new);

class SearchViewModel extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String q) => state = q;
}

/// ผลค้นหาจากทุกรายการ (null = ยังไม่ได้พิมพ์คำค้น)
final searchResultsProvider = Provider.autoDispose<TimelineViewState?>((ref) {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return null;
  return buildTimelineView(ref.watch(diaryViewModelProvider), TimelineFilter(query: query), today());
});
