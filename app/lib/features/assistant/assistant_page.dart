import 'package:flutter/material.dart';

import '../../ai/ai_settings.dart';
import '../../ai/ai_studio_provider.dart';
import '../../ai/llm_provider.dart';
import '../../ai/on_device_provider.dart';
import '../../state/app_state.dart';
import '../entry_editor/entry_editor_page.dart';
import '../settings/settings_page.dart';
import 'recorder.dart';

class _Turn {
  _Turn(this.text);
  final String text;
  AiResult? result;
  String? error;
  bool busy = true;
  bool applied = false;
}

/// เล่าเป็นภาษาธรรมชาติ → AI เสนอสิ่งที่จะบันทึก → ผู้ใช้ยืนยัน
class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key, required this.state, required this.ai});
  final AppState state;
  final AiSettings ai;

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _turns = <_Turn>[];
  bool get _busy => _turns.any((t) => t.busy);

  static const _examples = [
    'วันนี้ชั่งน้ำหนักได้ 74.5 นอน 7 ชม. อารมณ์ดี',
    'สมัคร Netflix เดือนละ 419 บาท',
    'จองตั๋วเครื่องบินไปปักกิ่งแล้ว',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<LlmProvider?> _provider() async {
    final ai = widget.ai;
    if (ai.provider == AiProviderKind.aiStudio) {
      final key = await ai.studioKey();
      if (key == null || key.isEmpty) return null;
      return AiStudioProvider(apiKey: key, model: ai.studioModel);
    }
    return await OnDeviceProvider.isInstalled() ? OnDeviceProvider() : null;
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _busy) return;
    final provider = await _provider();
    if (!mounted) return;
    if (provider == null) {
      final setUp = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('ยังไม่ได้ตั้งค่า AI'),
          content: Text(widget.ai.provider == AiProviderKind.aiStudio
              ? 'ใส่ API key ของ Google AI Studio ในหน้าตั้งค่าก่อน'
              : 'ดาวน์โหลดโมเดล Gemma (${OnDeviceProvider.sizeLabel}) ในหน้าตั้งค่าก่อน'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ไว้ก่อน')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ไปตั้งค่า')),
          ],
        ),
      );
      if (setUp == true && mounted) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage(state: widget.state, ai: widget.ai)));
      }
      return;
    }
    final turn = _Turn(text);
    setState(() {
      _turns.add(turn);
      _input.clear();
    });
    _scrollToEnd();
    try {
      turn.result = await Recorder(widget.state).run(provider, text);
      if (turn.result!.actions.isEmpty) {
        await _log(provider, text, turn.result!.raw, 'rejected');
      }
    } on LlmException catch (e) {
      turn.error = e.message;
      await _log(provider, text, null, 'error', e.message);
    } catch (e) {
      turn.error = 'เกิดข้อผิดพลาด: $e';
      await _log(provider, text, null, 'error', '$e');
    }
    if (mounted) setState(() => turn.busy = false);
    _scrollToEnd();
  }

  Future<void> _apply(_Turn turn) async {
    final r = turn.result!;
    final chosen = r.actions.where((a) => a.selected && a.valid).toList()
      ..sort((a, b) => (a.type == 'new_metric' ? 0 : 1).compareTo(b.type == 'new_metric' ? 0 : 1));
    setState(() => turn.busy = true);
    final failures = <String>[];
    for (final a in chosen) {
      try {
        await a.run!(widget.state);
      } catch (e) {
        failures.add('${a.summary}: $e');
      }
    }
    final provider = await _provider();
    if (provider != null) {
      await _log(provider, turn.text, {'actions': [for (final a in chosen) a.summary], 'raw': r.raw},
          failures.isEmpty ? 'applied' : 'error', failures.isEmpty ? null : failures.join('\n'));
    }
    if (!mounted) return;
    setState(() {
      turn.busy = false;
      turn.applied = failures.isEmpty;
      if (failures.isNotEmpty) turn.error = 'บางรายการบันทึกไม่สำเร็จ:\n${failures.join('\n')}';
    });
    if (failures.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('บันทึกแล้ว ${chosen.length} รายการ')));
    }
  }

  Future<void> _log(LlmProvider p, String input, Object? output, String status, [String? error]) async {
    try {
      await widget.state.repo.logAi(provider: p.kind.id, model: p.model, input: input, output: output, status: status, error: error);
    } catch (_) {
      // log ไม่สำเร็จไม่ควรขวางการบันทึก
    }
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('บันทึก'),
        actions: [
          ListenableBuilder(
            listenable: widget.ai,
            builder: (_, _) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ActionChip(
                avatar: Icon(widget.ai.provider == AiProviderKind.onDevice ? Icons.phone_iphone : Icons.cloud_outlined, size: 18),
                label: Text(widget.ai.provider == AiProviderKind.onDevice ? 'Gemma' : widget.ai.studioModel),
                tooltip: 'เปลี่ยน AI ในหน้าตั้งค่า',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SettingsPage(state: widget.state, ai: widget.ai)),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'เพิ่มเอง',
            icon: const Icon(Icons.edit_calendar_outlined),
            onPressed: () => openEditor(context, widget.state),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _turns.isEmpty
              ? ListView(padding: const EdgeInsets.all(24), children: [
                  Icon(Icons.auto_awesome, size: 40, color: scheme.primary),
                  const SizedBox(height: 12),
                  Text('เล่าให้ฟังได้เลย', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('AI จะเลือกหมวด วันที่ และตัวเลขให้ แล้วให้คุณยืนยันก่อนบันทึก',
                      textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 20),
                  for (final ex in _examples)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton(
                        onPressed: () => _send(ex),
                        style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.all(14)),
                        child: Text(ex),
                      ),
                    ),
                ])
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: _turns.length,
                  itemBuilder: (_, i) => _TurnView(turn: _turns[i], state: widget.state, onApply: () => _apply(_turns[i]), onChanged: () => setState(() {})),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'วันนี้เกิดอะไรขึ้นบ้าง…',
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                tooltip: 'ส่ง',
                onPressed: _busy ? null : _send,
                icon: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.arrow_upward),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _TurnView extends StatelessWidget {
  const _TurnView({required this.turn, required this.state, required this.onApply, required this.onChanged});
  final _Turn turn;
  final AppState state;
  final VoidCallback onApply, onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = turn.result;
    final selectable = r?.actions.where((a) => a.valid).toList() ?? const <ProposedAction>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(left: 48, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(18)),
          child: Text(turn.text, style: TextStyle(color: scheme.onPrimaryContainer)),
        ),
      ),
      if (turn.busy && r == null)
        const Padding(padding: EdgeInsets.all(12), child: Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('AI กำลังคิด…'),
        ])),
      if (turn.error != null)
        Card(
          color: scheme.errorContainer,
          child: Padding(padding: const EdgeInsets.all(12), child: Text(turn.error!, style: TextStyle(color: scheme.onErrorContainer))),
        ),
      if (r != null)
        Card(
          margin: const EdgeInsets.only(right: 24, bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (r.reply.isNotEmpty) Text(r.reply),
              for (final q in r.questions)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.help_outline, size: 18, color: scheme.tertiary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(q, style: TextStyle(color: scheme.tertiary))),
                  ]),
                ),
              if (r.actions.isNotEmpty) const Divider(height: 20),
              for (final a in r.actions) _ActionTile(action: a, state: state, locked: turn.applied || turn.busy, onChanged: onChanged),
              if (selectable.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: turn.applied
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_circle, color: scheme.primary, size: 18),
                          const SizedBox(width: 6),
                          const Text('บันทึกแล้ว'),
                        ])
                      : FilledButton.icon(
                          onPressed: turn.busy || !selectable.any((a) => a.selected) ? null : onApply,
                          icon: const Icon(Icons.check),
                          label: Text('บันทึก ${selectable.where((a) => a.selected).length} รายการ'),
                        ),
                ),
              ],
            ]),
          ),
        ),
    ]);
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action, required this.state, required this.locked, required this.onChanged});
  final ProposedAction action;
  final AppState state;
  final bool locked;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final a = action;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Checkbox(
          value: a.valid && a.selected,
          onChanged: !a.valid || locked
              ? null
              : (v) {
                  a.selected = v ?? false;
                  onChanged();
                },
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.summary, style: TextStyle(fontWeight: FontWeight.w500, color: a.valid ? null : scheme.onSurfaceVariant)),
              if (a.detail.isNotEmpty)
                Text(a.detail, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant), maxLines: 6, overflow: TextOverflow.ellipsis),
              for (final err in a.errors) Text('⚠ $err', style: TextStyle(fontSize: 13, color: scheme.error)),
            ]),
          ),
        ),
        if (a.entry != null && !locked)
          IconButton(
            tooltip: 'แก้ก่อนบันทึก',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () async {
              final saved = await openEditor(context, state, entry: a.entry, draft: true);
              if (saved) {
                a.selected = false;
                onChanged();
              }
            },
          ),
      ]),
    );
  }
}
