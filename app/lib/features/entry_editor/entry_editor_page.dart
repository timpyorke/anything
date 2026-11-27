import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/dates.dart';
import '../../domain/entry.dart';
import '../diary/deleted_snack_bar.dart';
import '../diary/diary_view_model.dart';
import 'entry_editor_view_model.dart';

/// เปิดหน้าแก้ไข คืน true ถ้าบันทึกหรือลบแล้ว
/// [draft] = รายการที่ AI เสนอ (ยังไม่อยู่ในฐานข้อมูลหรือยังไม่ได้บันทึกการแก้)
Future<bool> openEditor(BuildContext context, {Entry? entry, bool draft = false}) async {
  final saved = await Navigator.push<bool>(
    context,
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => EntryEditorPage(entry: entry, draft: draft)),
  );
  return saved ?? false;
}

class EntryEditorPage extends ConsumerStatefulWidget {
  const EntryEditorPage({super.key, this.entry, this.draft = false});
  final Entry? entry;
  final bool draft;

  @override
  ConsumerState<EntryEditorPage> createState() => _EntryEditorPageState();
}

/// View: เก็บเฉพาะ TextEditingController (เรื่องของ widget) — ค่าอื่นและการบันทึกอยู่ที่ EntryEditorViewModel
class _EntryEditorPageState extends ConsumerState<EntryEditorPage> {
  late final TextEditingController _title, _body, _times;
  final _metricCtrls = <(String, TextEditingController)>[];

  late final _args = EditorArgs(entry: widget.entry, draft: widget.draft);
  EntryEditorViewModel get _vm => ref.read(entryEditorViewModelProvider(_args).notifier);

  @override
  void initState() {
    super.initState();
    final e = ref.read(entryEditorViewModelProvider(_args)).entry;
    _title = TextEditingController(text: e.title);
    _body = TextEditingController(text: e.body);
    _times = TextEditingController(text: e.recurrence?.times?.toString() ?? '');
    for (final m in e.metrics) {
      _metricCtrls.add((m.key, TextEditingController(text: _fmt(m.value))));
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _body, _times, ..._metricCtrls.map((m) => m.$2)]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<DateTime?> _pick(DateTime initial) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      ).then((d) => d == null ? null : dayOf(d));

  Future<void> _save() async {
    await _vm.save(
      title: _title.text,
      body: _body.text,
      times: _times.text,
      metrics: [for (final (key, c) in _metricCtrls) (key, c.text)],
    );
  }

  /// ปิดหน้าเมื่อ ViewModel แจ้งว่าบันทึก/ลบเสร็จ — รันใน listener จึงใช้ context ได้โดยไม่ต้องเช็ก mounted
  void _onExit(EditorExit? exit) {
    if (exit == null) return;
    if (exit == EditorExit.deleted) {
      final entry = ref.read(entryEditorViewModelProvider(_args)).entry;
      final diary = ref.read(diaryViewModelProvider.notifier);
      showDeletedSnackBar(ScaffoldMessenger.of(context), diary, entry);
    }
    Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final e = ref.read(entryEditorViewModelProvider(_args)).entry;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ลบรายการนี้?'),
        content: Text(e.title.isEmpty ? fmtDate(e.date) : e.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ลบ')),
        ],
      ),
    );
    if (ok == true) await _vm.delete();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(entryEditorViewModelProvider(_args).select((s) => s.exit), (_, exit) => _onExit(exit));
    final s = ref.watch(diaryViewModelProvider);
    final st = ref.watch(entryEditorViewModelProvider(_args));
    final e = st.entry, vm = _vm;
    final usedKeys = _metricCtrls.map((m) => m.$1).toSet();
    final freeMetrics = s.metricDefs.where((m) => !usedKeys.contains(m.key)).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(st.isNew ? (st.draft ? 'ตรวจก่อนบันทึก' : 'เพิ่มบันทึก') : 'แก้ไข'),
        actions: [
          if (!st.isNew)
            IconButton(tooltip: 'ลบ', icon: const Icon(Icons.delete_outline), onPressed: st.saving ? null : _delete),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(onPressed: st.saving ? null : _save, child: const Text('บันทึก')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (st.errors.isNotEmpty)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(st.errors.join('\n'), style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
              ),
            ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'event', label: Text('เหตุการณ์'), icon: Icon(Icons.event)),
              ButtonSegment(value: 'daily', label: Text('บันทึกรายวัน'), icon: Icon(Icons.today)),
            ],
            selected: {e.kind},
            onSelectionChanged: (v) => vm.setKind(v.first),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: _DateField(
                label: st.every != null ? 'เริ่ม' : 'วันที่',
                value: e.date,
                onTap: () async {
                  final d = await _pick(e.date);
                  if (d != null) vm.setDate(d);
                },
              ),
            ),
            if (!e.isDaily && st.every == null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'ถึง (ถ้ามี)',
                  value: e.endDate,
                  onClear: e.endDate == null ? null : () => vm.setEndDate(null),
                  onTap: () async {
                    final d = await _pick(e.endDate ?? e.date.add(const Duration(days: 1)));
                    if (d != null) vm.setEndDate(d);
                  },
                ),
              ),
            ],
          ]),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: s.categoryKeys.contains(e.category) ? e.category : null,
            decoration: const InputDecoration(labelText: 'หมวด', border: OutlineInputBorder()),
            items: [
              for (final c in s.categories)
                DropdownMenuItem(
                  value: c.key,
                  child: Row(children: [CircleAvatar(radius: 6, backgroundColor: c.color), const SizedBox(width: 10), Text(c.label)]),
                ),
            ],
            onChanged: vm.setCategory,
          ),
          const SizedBox(height: 16),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'ชื่อ', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(
            controller: _body,
            minLines: 3,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'รายละเอียด',
              helperText: 'รองรับ - list, - [ ] checklist, **ตัวหนา**',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text('ตัวเลข', style: Theme.of(context).textTheme.titleSmall),
          for (var i = 0; i < _metricCtrls.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _metricCtrls[i].$2,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: InputDecoration(
                      labelText: s.metricLabel(_metricCtrls[i].$1),
                      suffixText: s.metricUnit(_metricCtrls[i].$1),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'เอาออก',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => setState(() => _metricCtrls.removeAt(i).$2.dispose()),
                ),
              ]),
            ),
          if (freeMetrics.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: PopupMenuButton<String>(
                onSelected: (k) => setState(() => _metricCtrls.add((k, TextEditingController()))),
                itemBuilder: (_) => [for (final m in freeMetrics) PopupMenuItem(value: m.key, child: Text('${m.label} ${m.unit}'.trim()))],
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add), SizedBox(width: 6), Text('เพิ่มตัวเลข')]),
                ),
              ),
            ),
          if (!e.isDaily) ...[
            const SizedBox(height: 12),
            Text('เกิดซ้ำ', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: st.every,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('ไม่เกิดซ้ำ')),
                    DropdownMenuItem(value: 'weekly', child: Text('ทุกสัปดาห์')),
                    DropdownMenuItem(value: 'monthly', child: Text('ทุกเดือน')),
                    DropdownMenuItem(value: 'yearly', child: Text('ทุกปี')),
                    DropdownMenuItem(value: 'daily', child: Text('ทุกวัน')),
                  ],
                  onChanged: vm.setEvery,
                ),
              ),
              if (st.every != null) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _times,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'กี่ครั้ง', hintText: 'ไม่จำกัด', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ]),
          ],
          if (e.legacyRef != null) ...[
            const SizedBox(height: 16),
            Text('นำเข้าจาก ${e.legacyRef}', style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap, this.onClear});
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: onClear == null ? const Icon(Icons.calendar_today, size: 18) : IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: onClear),
          ),
          child: Text(value == null ? '—' : fmtDate(value!)),
        ),
      );
}
