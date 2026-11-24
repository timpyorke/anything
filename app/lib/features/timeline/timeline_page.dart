import 'package:flutter/material.dart';

import '../../core/utils/dates.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/entry.dart';
import '../../state/app_state.dart';
import '../entry_editor/entry_editor_page.dart';
import 'entry_card.dart';
import 'timeline_filter.dart';

class TimelinePage extends StatefulWidget {
  const TimelinePage({
    super.key,
    required this.state,
    required this.filter,
    required this.captureButton,
    required this.openOverview,
    required this.openSettings,
  });
  final AppState state;
  final TimelineFilter filter;
  final Widget captureButton;
  final VoidCallback openOverview, openSettings;

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
              IconButton(tooltip: 'ภาพรวม', icon: const Icon(Icons.calendar_month_outlined), onPressed: widget.openOverview),
              IconButton(tooltip: 'ตั้งค่า', icon: const Icon(Icons.settings_outlined), onPressed: widget.openSettings),
            ],
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: widget.captureButton,
          body: RefreshIndicator(
            onRefresh: s.load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _Summary(state: s, now: now)),
                if (f.active)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
                      child: Row(children: [
                        if (f.day != null)
                          Text('${fmtDate(f.day!)} · ', style: Theme.of(context).textTheme.bodySmall),
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
                      text: f.active ? 'ไม่พบรายการที่ตรงกับตัวกรอง' : 'ยังไม่มีบันทึก\nกดค้างที่ปุ่ม "กดค้างเพื่อคุย" แล้วเล่าให้ AI ฟังได้เลย',
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
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 8),
              Text(sub, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.zero,
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
    final scheme = Theme.of(context).colorScheme;
    final birth = state.birth;
    final next = (state.entries.where((e) => !e.hidden && (e.shownDate(now).isAfter(now) || (e.endDate != null && e.isUpcoming(now)))).toList()
          ..sort((a, b) => a.shownDate(now).compareTo(b.shownDate(now))))
        .firstOrNull;
    final facts = [if (birth != null) 'อายุ ${ageOn(birth.date, now)} ปี'];
    final nextRel = next == null
        ? null
        : relativeLabel(next.shownDate(now), next.lastDate(now), now, isRange: next.endDate != null);
    // ไม่ล็อกความสูง: ข้อความยาวแค่ขึ้นบรรทัดใหม่ ไม่มีวันล้นทับ
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (facts.isNotEmpty)
          Text(facts.join(' · '), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        if (next != null) ...[
          if (facts.isNotEmpty) const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ถัดไป${nextRel == null ? '' : ' · $nextRel'}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(next.title.isEmpty ? state.category(next.category).label : next.title,
                  style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ],
      ]),
    );
  }
}

