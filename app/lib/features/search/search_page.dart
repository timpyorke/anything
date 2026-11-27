import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_theme.dart';
import '../../app/language.dart';
import '../../core/widgets/category_dot.dart';
import '../../core/widgets/empty_state.dart';
import '../diary/diary_view_model.dart';
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

  void _setText(String q) {
    _text.value = TextEditingValue(text: q, selection: TextSelection.collapsed(offset: q.length));
    ref.read(searchQueryProvider.notifier).setQuery(q);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final categories = ref.watch(diaryViewModelProvider.select((s) => s.categories));
    final vm = ref.read(searchQueryProvider.notifier);
    final theme = Theme.of(context);
    OutlineInputBorder pill([BorderSide side = BorderSide.none]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: side);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: Insets.page),
          child: TextField(
            controller: _text,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: t.searchHint,
              hintMaxLines: 1,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              border: pill(),
              enabledBorder: pill(),
              focusedBorder: pill(BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: t.clearSearch,
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => _setText(''),
                    ),
            ),
            onChanged: vm.setQuery,
          ),
        ),
      ),
      body: results == null
          // ยังไม่พิมพ์: เสนอหมวดให้แตะค้นได้ทันที
          ? SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(Insets.page, 32, Insets.page, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Icon(Icons.search_rounded, size: 40, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 8),
                Text(t.searchPrompt, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                if (categories.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(t.orPickCategory, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 4, children: [
                    for (final c in categories)
                      ActionChip(
                        avatar: Center(child: CategoryDot(c.color, size: 10)),
                        label: Text(c.label),
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          _setText(c.label);
                        },
                      ),
                  ]),
                ],
              ]),
            )
          : results.count == 0
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  text: t.noSearchResults,
                  detail: t.noSearchResultsDetail,
                )
              : CustomScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(Insets.page + 4, 8, Insets.page, 0),
                        child: Text(t.foundCount(results.count), style: theme.textTheme.bodySmall),
                      ),
                    ),
                    for (final MapEntry(key: y, value: items) in results.allByYear.entries)
                      EntrySection(title: t.yearLabel(y), items: items, now: results.now),
                    SliverToBoxAdapter(child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom)),
                  ],
                ),
    );
  }
}
