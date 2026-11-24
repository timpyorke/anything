import 'package:flutter/material.dart';

import '../../core/utils/dates.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/stat_tile.dart';
import '../../domain/entry.dart';
import '../../state/app_state.dart';
import '../entry_editor/entry_editor_page.dart';
import 'entry_card.dart';
import 'timeline_filter.dart';

class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key, required this.state, required this.filter});
  final AppState state;
  final TimelineFilter filter;

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  final _search = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.state, widget.filter]),
      builder: (context, _) {
        final s = widget.state, f = widget.filter, now = today();
        final words = f.query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
        final list = s.entries.where((e) {
          if (f.day != null) {
            if (!e.coveredDays(now).contains(f.day)) return false;
          } else if (e.hidden) {
            return false;
          }
          if (f.cats != null && !f.cats!.contains(e.category)) return false;
          final text = '${e.searchText} ${s.category(e.category).label.toLowerCase()}';
          return words.every(text.contains);
        }).toList();
        final upcoming = list.where((e) => e.isUpcoming(now)).toList()
          ..sort((a, b) => a.shownDate(now).compareTo(b.shownDate(now)));
        final past = list.where((e) => !e.isUpcoming(now)).toList()
          ..sort((a, b) => b.shownDate(now).compareTo(a.shownDate(now)));

        return Scaffold(
          appBar: AppBar(
            title: _searching
                ? TextField(
                    controller: _search,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'ค้นหาชื่อ เนื้อหา หมวด…', border: InputBorder.none),
                    onChanged: (v) => f.set(query: v),
                  )
                : const Text('Timeline'),
            actions: [
              IconButton(
                tooltip: _searching ? 'ปิดการค้นหา' : 'ค้นหา',
                icon: Icon(_searching ? Icons.close : Icons.search),
                onPressed: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) {
                    _search.clear();
                    f.set(query: '');
                  }
                }),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: s.load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _Summary(state: s, now: now)),
                SliverToBoxAdapter(child: _CategoryChips(state: s, filter: f)),
                if (f.active)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                      child: Row(children: [
                        if (f.day != null)
                          InputChip(
                            label: Text(fmtDate(f.day!)),
                            avatar: const Icon(Icons.event, size: 18),
                            onDeleted: () => f.set(clearDay: true),
                            deleteButtonTooltipMessage: 'ล้างตัวกรองวันที่',
                          ),
                        const SizedBox(width: 8),
                        Text('${list.length} รายการ', style: Theme.of(context).textTheme.bodySmall),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            _search.clear();
                            f.clear();
                          },
                          child: const Text('ล้างตัวกรอง'),
                        ),
                      ]),
                    ),
                  ),
                if (s.loading && s.entries.isEmpty)
                  const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                else if (s.error != null && s.entries.isEmpty)
                  SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.cloud_off,
                      text: 'โหลดข้อมูลไม่สำเร็จ\n${s.error}',
                      action: FilledButton(onPressed: s.load, child: const Text('ลองใหม่')),
                    ),
                  )
                else if (list.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: f.active ? Icons.filter_alt_off : Icons.edit_note,
                      text: f.active ? 'ไม่พบรายการที่ตรงกับตัวกรอง' : 'ยังไม่มีบันทึก\nกดปุ่ม "บันทึก" แล้วเล่าให้ AI ฟังได้เลย',
                    ),
                  )
                else ...[
                  if (upcoming.isNotEmpty) ..._section(context, 'กำลังจะมาถึง', '${upcoming.length} รายการ', upcoming, now),
                  if (upcoming.isNotEmpty && past.isNotEmpty) SliverToBoxAdapter(child: _TodayDivider(now: now)),
                  ..._pastByYear(context, past, now),
                  const SliverToBoxAdapter(child: SizedBox(height: 96)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _section(BuildContext context, String title, String sub, List<Entry> items, DateTime now) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(sub, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => EntryCard(
              entry: items[i],
              state: widget.state,
              now: now,
              onTap: () => openEditor(context, widget.state, entry: items[i]),
            ),
          ),
        ),
      ];

  List<Widget> _pastByYear(BuildContext context, List<Entry> past, DateTime now) {
    final out = <Widget>[];
    final byYear = <int, List<Entry>>{};
    for (final e in past) {
      (byYear[e.shownDate(now).year] ??= []).add(e);
    }
    for (final y in byYear.keys) {
      out.addAll(_section(context, '$y', 'พ.ศ. ${be(y)}', byYear[y]!, now));
    }
    return out;
  }
}

class _TodayDivider extends StatelessWidget {
  const _TodayDivider({required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        Expanded(child: Divider(color: c.withValues(alpha: 0.5))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('วันนี้ · ${fmtDate(now)}', style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Divider(color: c.withValues(alpha: 0.5))),
      ]),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.state, required this.now});
  final AppState state;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final birth = state.birth;
    final next = (state.entries.where((e) => !e.hidden && (e.shownDate(now).isAfter(now) || (e.endDate != null && e.isUpcoming(now)))).toList()
          ..sort((a, b) => a.shownDate(now).compareTo(b.shownDate(now))))
        .firstOrNull;
    final monthDays = state.entries
        .where((e) => e.recurrence == null && e.date.year == now.year && e.date.month == now.month && !e.date.isAfter(now))
        .map((e) => e.date)
        .toSet()
        .length;
    final tiles = [
      if (birth != null) StatTile(value: '${ageOn(birth.date, now)} ปี', label: 'อายุ', sub: 'เกิด ${fmtDate(birth.date)}'),
      if (next != null)
        StatTile(
          value: relativeLabel(next.shownDate(now), next.lastDate(now), now, isRange: next.endDate != null) ?? '',
          label: 'ถัดไป',
          sub: next.title,
        ),
      StatTile(value: '$monthDays วัน', label: 'บันทึกเดือนนี้', sub: fmtMonthYear(now)),
    ];
    // ความสูงตามขนาดตัวอักษรของระบบ — กันการ์ดสรุปล้นทับรายการด้านล่าง
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return SizedBox(
      height: 124 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        itemCount: tiles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => SizedBox(width: 150, child: tiles[i]),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.state, required this.filter});
  final AppState state;
  final TimelineFilter filter;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final e in state.entries.where((e) => !e.hidden)) {
      counts[e.category] = (counts[e.category] ?? 0) + 1;
    }
    final cats = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: const Text('ทั้งหมด'),
              selected: filter.cats == null,
              onSelected: (_) => filter.set(clearCats: true),
            ),
          ),
          for (final c in cats)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                // กดค้าง = เลือกหลายหมวด
                onLongPress: () {
                  final s = {...(filter.cats ?? cats.toSet())};
                  s.contains(c) ? s.remove(c) : s.add(c);
                  filter.set(cats: (s.isEmpty || s.length == cats.length) ? null : s, clearCats: true);
                },
                child: FilterChip(
                  avatar: CircleAvatar(backgroundColor: state.category(c).color, radius: 5),
                  label: Text('${state.category(c).label} ${counts[c]}'),
                  selected: filter.cats?.contains(c) ?? false,
                  onSelected: (_) {
                    final solo = filter.cats?.length == 1 && filter.cats!.contains(c);
                    filter.set(cats: solo ? null : {c}, clearCats: solo);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
