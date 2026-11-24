import 'package:flutter/material.dart';

import '../../core/utils/dates.dart';
import '../../domain/entry.dart';
import '../../domain/metric.dart';
import '../../domain/recurrence.dart';
import '../../state/app_state.dart';

/// เปิดหน้าแก้ไข คืน true ถ้าบันทึกหรือลบแล้ว
/// [draft] = รายการที่ AI เสนอ (ยังไม่อยู่ในฐานข้อมูลหรือยังไม่ได้บันทึกการแก้)
Future<bool> openEditor(BuildContext context, AppState state, {Entry? entry, bool draft = false}) async {
  final saved = await Navigator.push<bool>(
    context,
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => EntryEditorPage(state: state, entry: entry, draft: draft)),
  );
  return saved ?? false;
}

class EntryEditorPage extends StatefulWidget {
  const EntryEditorPage({super.key, required this.state, this.entry, this.draft = false});
  final AppState state;
  final Entry? entry;
  final bool draft;

  @override
  State<EntryEditorPage> createState() => _EntryEditorPageState();
}

class _EntryEditorPageState extends State<EntryEditorPage> {
  late final Entry e;
  late final TextEditingController _title, _body, _times;
  final _metricCtrls = <(String, TextEditingController)>[];
  String? _every;
  bool _saving = false;
  List<String> _errors = [];

  bool get _isNew => e.id == null;

  @override
  void initState() {
    super.initState();
    e = widget.entry?.copy() ?? Entry(date: today(), category: widget.state.categories.firstOrNull?.key ?? 'daily');
    _title = TextEditingController(text: e.title);
    _body = TextEditingController(text: e.body);
    _every = e.recurrence?.every;
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

  Entry _collect() {
    final out = e.copy()
      ..title = _title.text.trim()
      ..body = _body.text.trim()
      ..recurrence = _every == null ? null : Recurrence(_every!, times: int.tryParse(_times.text.trim()))
      ..metrics = [
        for (final (key, c) in _metricCtrls)
          if (c.text.trim().isNotEmpty)
            MetricValue(key, double.tryParse(c.text.trim().replaceAll(',', '')) ?? double.nan, widget.state.metricUnit(key)),
      ];
    if (out.isDaily) out.endDate = null;
    return out;
  }

  Future<void> _save() async {
    final out = _collect();
    final errors = widget.state.validate(out);
    if (out.isDaily && _isNew && widget.state.dailyOn(out.date) != null) {
      errors.add('มีบันทึกรายวันของ ${fmtDate(out.date)} อยู่แล้ว — เปิดรายการนั้นเพื่อแก้แทน');
    }
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.state.save(out);
      if (mounted) Navigator.pop(context, true);
    } catch (err) {
      if (mounted) setState(() => _errors = ['บันทึกไม่สำเร็จ: $err']);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
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
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await widget.state.delete(e);
    messenger.showSnackBar(SnackBar(
      content: const Text('ลบแล้ว'),
      action: SnackBarAction(label: 'เลิกทำ', onPressed: () => widget.state.undoDelete(e)),
    ));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final usedKeys = _metricCtrls.map((m) => m.$1).toSet();
    final freeMetrics = s.metricDefs.where((m) => !usedKeys.contains(m.key)).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? (widget.draft ? 'ตรวจก่อนบันทึก' : 'เพิ่มบันทึก') : 'แก้ไข'),
        actions: [
          if (!_isNew)
            IconButton(tooltip: 'ลบ', icon: const Icon(Icons.delete_outline), onPressed: _saving ? null : _delete),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(onPressed: _saving ? null : _save, child: const Text('บันทึก')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_errors.isNotEmpty)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_errors.join('\n'), style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
              ),
            ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'event', label: Text('เหตุการณ์'), icon: Icon(Icons.event)),
              ButtonSegment(value: 'daily', label: Text('บันทึกรายวัน'), icon: Icon(Icons.today)),
            ],
            selected: {e.kind},
            onSelectionChanged: (v) => setState(() => e.kind = v.first),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: _DateField(
                label: e.recurrence != null || _every != null ? 'เริ่ม' : 'วันที่',
                value: e.date,
                onTap: () async {
                  final d = await _pick(e.date);
                  if (d != null) setState(() => e.date = d);
                },
              ),
            ),
            if (!e.isDaily && _every == null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'ถึง (ถ้ามี)',
                  value: e.endDate,
                  onClear: e.endDate == null ? null : () => setState(() => e.endDate = null),
                  onTap: () async {
                    final d = await _pick(e.endDate ?? e.date.add(const Duration(days: 1)));
                    if (d != null) setState(() => e.endDate = d);
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
            onChanged: (v) => setState(() => e.category = v ?? e.category),
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
                  initialValue: _every,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('ไม่เกิดซ้ำ')),
                    DropdownMenuItem(value: 'weekly', child: Text('ทุกสัปดาห์')),
                    DropdownMenuItem(value: 'monthly', child: Text('ทุกเดือน')),
                    DropdownMenuItem(value: 'yearly', child: Text('ทุกปี')),
                    DropdownMenuItem(value: 'daily', child: Text('ทุกวัน')),
                  ],
                  onChanged: (v) => setState(() {
                    _every = v;
                    if (v != null) e.endDate = null;
                  }),
                ),
              ),
              if (_every != null) ...[
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
