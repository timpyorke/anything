import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/dates.dart';
import '../../core/widgets/empty_state.dart';
import '../timeline/entry_section.dart';
import 'search_view_model.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final vm = ref.read(searchQueryProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _text,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'ค้นหาชื่อ เนื้อหา หมวด…',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: vm.setQuery,
        ),
        actions: [
          if (query.isNotEmpty)
            IconButton(
              tooltip: 'ล้างคำค้น',
              icon: const Icon(Icons.close),
              onPressed: () {
                _text.clear();
                vm.setQuery('');
              },
            ),
        ],
      ),
      body: results == null
          ? const EmptyState(icon: Icons.search, text: 'พิมพ์คำที่ต้องการค้นหา')
          : results.count == 0
              ? const EmptyState(icon: Icons.search_off, text: 'ไม่พบรายการที่ตรงกับคำค้น')
              : CustomScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Text('พบ ${results.count} รายการ', style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ),
                    if (results.upcoming.isNotEmpty)
                      EntrySection(
                        title: 'กำลังจะมาถึง',
                        subtitle: '${results.upcoming.length} รายการ',
                        items: results.upcoming,
                        now: results.now,
                      ),
                    for (final MapEntry(key: y, value: items) in results.pastByYear.entries)
                      EntrySection(title: '$y', subtitle: 'พ.ศ. ${be(y)}', items: items, now: results.now),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
    );
  }
}
