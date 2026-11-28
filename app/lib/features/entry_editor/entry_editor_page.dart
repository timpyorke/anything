import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_theme.dart';
import '../../app/language.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/category_dot.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/notice_box.dart';
import '../../core/widgets/section.dart';
import '../../data/photo_picker.dart';
import '../../domain/entry.dart';
import '../../domain/photo.dart';
import '../../domain/recurrence.dart';
import '../diary/deleted_snack_bar.dart';
import '../diary/diary_view_model.dart';
import '../photos/photo_widgets.dart';
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

  /// ค่าตอนเปิดหน้า ใช้เทียบว่ามีอะไรแก้ค้างอยู่ไหม
  late final EntryEditorState _initial;
  late final String _initialText;

  late final _args = EditorArgs(entry: widget.entry, draft: widget.draft);
  EntryEditorViewModel get _vm => ref.read(entryEditorViewModelProvider(_args).notifier);

  @override
  void initState() {
    super.initState();
    _initial = ref.read(entryEditorViewModelProvider(_args));
    final e = _initial.entry;
    _title = TextEditingController(text: e.title);
    _body = TextEditingController(text: e.body);
    _times = TextEditingController(text: e.recurrence?.times?.toString() ?? '');
    for (final m in e.metrics) {
      _metricCtrls.add((m.key, TextEditingController(text: _fmt(m.value))));
    }
    _initialText = _formText();
  }

  @override
  void dispose() {
    for (final c in [_title, _body, _times, ..._metricCtrls.map((m) => m.$2)]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// ข้อความในทุกช่องรวมกัน (คั่นด้วยอักขระที่พิมพ์ไม่ได้)
  String _formText() => [
        _title.text,
        _body.text,
        _times.text,
        for (final (key, c) in _metricCtrls) '$key=${c.text}',
      ].join('\u0000');

  bool _dirty(EntryEditorState st) => st.entry != _initial.entry || st.every != _initial.every || _formText() != _initialText;

  Future<DateTime?> _pick(DateTime initial, {DateTime? first}) => showDatePicker(
        context: context,
        initialDate: first != null && initial.isBefore(first) ? first : initial,
        firstDate: first ?? DateTime(1900),
        lastDate: DateTime(2100),
      ).then((d) => d == null ? null : dayOf(d));

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
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
      showDeletedSnackBar(ScaffoldMessenger.of(context), diary, entry, ref.read(stringsProvider));
    }
    Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final e = ref.read(entryEditorViewModelProvider(_args)).entry;
    final t = ref.read(stringsProvider);
    final name = e.title.isEmpty ? t.fmtDate(e.date) : e.title;
    final ok = await confirmAction(
      context,
      title: t.deleteEntryTitle,
      message: [
        name,
        if (e.recurrence != null) t.deleteSeriesWarning,
        if (e.photos.any((p) => !p.isNew)) t.photosPurgedLater,
      ].join('\n'),
      cancelLabel: t.cancel,
      confirmLabel: t.delete,
    );
    if (ok) await _vm.delete();
  }

  Future<void> _confirmDiscard() async {
    // จับ navigator ไว้ก่อน await
    final nav = Navigator.of(context);
    final t = ref.read(stringsProvider);
    final ok = await confirmAction(
      context,
      title: t.discardTitle,
      message: t.discardMessage,
      cancelLabel: t.keepEditing,
      confirmLabel: t.discard,
    );
    if (ok) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(entryEditorViewModelProvider(_args).select((s) => s.exit), (_, exit) => _onExit(exit));
    ref.listen(entryEditorViewModelProvider(_args).select((s) => s.notice), (_, notice) {
      if (notice != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice)));
    });
    final st = ref.watch(entryEditorViewModelProvider(_args));
    // พิมพ์ในช่องไหนก็ต้องคำนวณใหม่ว่ามีของแก้ค้างอยู่ไหม
    return ListenableBuilder(
      listenable: Listenable.merge([_title, _body, _times, for (final m in _metricCtrls) m.$2]),
      child: _form(context, st),
      builder: (context, form) => PopScope(
        // กำลังบันทึกอยู่ออกได้เลย งานบันทึกทำต่อจนจบ
        canPop: st.saving || !_dirty(st),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmDiscard();
        },
        child: form!,
      ),
    );
  }

  Widget _form(BuildContext context, EntryEditorState st) {
    final t = ref.watch(stringsProvider);
    final s = ref.watch(diaryViewModelProvider);
    final e = st.entry, vm = _vm;
    final theme = Theme.of(context);
    final usedKeys = _metricCtrls.map((m) => m.$1).toSet();
    final freeMetrics = s.metricDefs.where((m) => !usedKeys.contains(m.key)).toList();
    final until = e.recurrence?.until;
    const gap = SizedBox(height: 20);
    final date = Labeled(
      st.every != null ? t.startDate : t.date,
      child: _DateField(
        value: e.date,
        onTap: () async {
          final d = await _pick(e.date);
          if (d != null) vm.setDate(d);
        },
      ),
    );
    final endDate = !e.isDaily && st.every == null
        ? Labeled(
            t.endDateOptional,
            child: _DateField(
              value: e.endDate,
              onClear: e.endDate == null ? null : () => vm.setEndDate(null),
              onTap: () async {
                final next = e.date.add(const Duration(days: 1));
                final d = await _pick(e.endDate ?? next, first: next);
                if (d != null) vm.setEndDate(d);
              },
            ),
          )
        : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(st.isNew ? (st.draft ? t.reviewEntry : t.newEntry) : t.edit),
        actions: [
          if (!st.isNew)
            IconButton(
              tooltip: t.delete,
              icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
              onPressed: st.saving ? null : _delete,
            ),
          const SizedBox(width: 4),
        ],
      ),
      // ปุ่มบันทึกอยู่ใน body (ไม่ใช่ bottomNavigationBar) จึงลอยขึ้นเหนือคีย์บอร์ดด้วย
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Insets.page, 4, Insets.page, 24),
            children: [
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 'event', label: Text(t.kindEvent)),
                  ButtonSegment(value: 'daily', label: Text(t.kindDaily)),
                ],
                selected: {e.kind},
                onSelectionChanged: (v) => vm.setKind(v.first),
              ),
              gap,
              Labeled(
                t.titleField,
                child: TextField(
                  controller: _title,
                  textInputAction: TextInputAction.next,
                  style: theme.textTheme.titleMedium,
                  decoration: InputDecoration(hintText: t.titleHint),
                ),
              ),
              gap,
              Labeled(
                t.details,
                child: TextField(
                  controller: _body,
                  minLines: 3,
                  maxLines: 12,
                  decoration: InputDecoration(
                    hintText: t.detailsHint,
                    helperText: t.markdownHelp,
                    helperMaxLines: 3,
                  ),
                ),
              ),
              gap,
              if (endDate == null)
                date
              // ตัวอักษรใหญ่: วางซ้อนกันแทนการบีบจนตกบรรทัด
              else if (MediaQuery.textScalerOf(context).scale(14) > 17)
                Column(children: [date, const SizedBox(height: 12), endDate])
              else
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: date),
                  const SizedBox(width: 12),
                  Expanded(child: endDate),
                ]),
              gap,
              Labeled(
                t.category,
                child: Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final c in s.categories)
                    ChoiceChip(
                      avatar: Center(child: CategoryDot(c.color, size: 10)),
                      label: Text(c.label),
                      selected: e.category == c.key,
                      onSelected: (_) => vm.setCategory(c.key),
                    ),
                ]),
              ),
              gap,
              Labeled(
                t.photos,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (e.photos.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PhotoStrip(e.photos, size: 88, onRemove: st.saving ? null : (i) => vm.removePhoto(e.photos[i])),
                    ),
                  Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    for (final (source, icon, label) in [
                      (PhotoSource.camera, Icons.photo_camera_outlined, t.takePhoto),
                      (PhotoSource.gallery, Icons.photo_library_outlined, t.gallery),
                    ])
                      OutlinedButton.icon(
                        onPressed: st.saving || st.picking || e.photos.length >= maxPhotosPerEntry ? null : () => vm.addPhotos(source),
                        icon: Icon(icon),
                        label: Text(label),
                      ),
                    if (st.picking) const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    Text('${e.photos.length}/$maxPhotosPerEntry', style: theme.textTheme.bodySmall),
                  ]),
                ]),
              ),
              gap,
              Labeled(
                t.numbers,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (var i = 0; i < _metricCtrls.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Expanded(flex: 2, child: Text(s.metricLabel(_metricCtrls[i].$1))),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: Semantics(
                            label: s.metricLabel(_metricCtrls[i].$1),
                            child: TextField(
                              controller: _metricCtrls[i].$2,
                              textAlign: TextAlign.end,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              decoration: InputDecoration(hintText: '0', suffixText: s.metricUnit(_metricCtrls[i].$1)),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: t.removeNumber,
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                          onPressed: () => setState(() => _metricCtrls.removeAt(i).$2.dispose()),
                        ),
                      ]),
                    ),
                  if (freeMetrics.isNotEmpty)
                    PopupMenuButton<String>(
                      tooltip: t.addNumber,
                      onSelected: (k) => setState(() => _metricCtrls.add((k, TextEditingController()))),
                      itemBuilder: (_) => [for (final m in freeMetrics) PopupMenuItem(value: m.key, child: Text('${m.label} ${m.unit}'.trim()))],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add_rounded, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(t.addNumber, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                        ]),
                      ),
                    ),
                ]),
              ),
              if (!e.isDaily) ...[
                gap,
                Labeled(
                  t.repeats,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      for (final value in [
                        null,
                        'daily',
                        'weekly',
                        'monthly',
                        'yearly',
                        // รอบแบบอื่นจาก AI หรือการนำเข้า เช่น 2w ต้องยังเลือกคงไว้ได้
                        if (_initial.every != null && !Recurrence.words.containsKey(_initial.every)) _initial.every,
                      ])
                        ChoiceChip(
                          label: Text(value == null ? t.noRepeat : t.recurrenceLabel(Recurrence(value))),
                          selected: st.every == value,
                          onSelected: (_) => vm.setEvery(value),
                        ),
                    ]),
                    if (st.every != null) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _times,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          hintText: t.unlimited,
                          prefixIcon: const Icon(Icons.repeat_rounded),
                          suffixText: t.timesSuffix,
                        ),
                      ),
                      if (until != null) ...[
                        const SizedBox(height: 8),
                        InputChip(
                          label: Text(t.endsOn(t.fmtDate(until))),
                          deleteButtonTooltipMessage: t.removeEndDate,
                          onDeleted: vm.clearUntil,
                        ),
                      ],
                    ],
                  ]),
                ),
              ],
              if (e.legacyRef != null) ...[
                gap,
                Text(t.importedFrom(e.legacyRef!), style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
        // ข้อผิดพลาดอยู่ติดปุ่มบันทึก เลื่อนอยู่ตรงไหนก็เห็น
        DecoratedBox(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant))),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Insets.page, 10, Insets.page, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (st.errors.isNotEmpty) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 140),
                    child: SingleChildScrollView(child: NoticeBox(st.errors.join('\n'))),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  onPressed: st.saving || st.picking ? null : _save,
                  child: st.saving
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(t.save),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _DateField extends ConsumerWidget {
  const _DateField({required this.value, required this.onTap, this.onClear});
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Corners.control),
        child: InputDecorator(
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.only(left: 14),
            suffixIcon: onClear == null
                ? const Icon(Icons.calendar_today_rounded, size: 18)
                : IconButton(tooltip: t.clearDate, icon: const Icon(Icons.close_rounded, size: 18), onPressed: onClear),
          ),
          child: Text(
            value == null ? t.pickDate : t.fmtDate(value!),
            style: value == null ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant) : null,
          ),
        ),
      );
  }
}
