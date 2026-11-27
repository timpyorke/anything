import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_settings.dart';
import '../../ai/llm_provider.dart';
import '../../app/app_theme.dart';
import '../../app/language.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/section.dart';
import 'local_model_page.dart';
import 'settings_view_model.dart';

/// เลือก AI ที่ใช้บันทึก พร้อม API key และโมเดลของบริการที่เลือก
class AiSettingsPage extends ConsumerStatefulWidget {
  const AiSettingsPage({super.key});

  @override
  ConsumerState<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends ConsumerState<AiSettingsPage> {
  final _key = TextEditingController();
  bool _showKey = false;

  SettingsViewModel get _vm => ref.read(settingsViewModelProvider.notifier);

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  void _saveKey() {
    final key = _key.text;
    _key.clear();
    FocusScope.of(context).unfocus();
    _vm.saveKey(ref.read(aiSettingsProvider).provider, key);
  }

  Future<void> _deleteKey(AiProviderKind kind) async {
    final aiVm = ref.read(aiSettingsProvider.notifier);
    final t = ref.read(stringsProvider);
    final ok = await confirmAction(
      context,
      title: t.deleteKeyTitle,
      message: t.deleteKeyMessage(kind.label),
      cancelLabel: t.cancel,
      confirmLabel: t.delete,
    );
    if (ok) await aiVm.setKey(kind, null);
  }

  Future<void> _copyKeyUrl(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final t = ref.read(stringsProvider);
    await Clipboard.setData(ClipboardData(text: 'https://$url'));
    messenger.showSnackBar(SnackBar(content: Text(t.linkCopied)));
  }

  /// ตั้งค่าของบริการที่เลือก แสดงในการ์ดเดียวกับตัวเลือกนั้น
  Widget _config(AiSettingsState ai, AppStrings t) {
    final kind = ai.provider;
    if (!kind.isCloud) {
      return ListTile(
        leading: const Icon(Icons.memory_rounded),
        title: Text(t.manageLocalModel),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const LocalModelPage())),
      );
    }
    final hasKey = ai.savedKeys.contains(kind);
    return Padding(
      padding: const EdgeInsets.all(Insets.page),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Labeled(
          hasKey ? t.apiKeyReplace : t.apiKeyFor(kind.label),
          child: TextField(
            controller: _key,
            obscureText: !_showKey,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: hasKey ? '••••••••••••' : t.pasteKey,
              helperText: t.keyHelp(kind.keyUrl),
              helperMaxLines: 3,
              suffixIcon: IconButton(
                tooltip: _showKey ? t.hide : t.show,
                icon: Icon(_showKey ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _showKey = !_showKey),
              ),
            ),
            onSubmitted: (_) => _saveKey(),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton(onPressed: _saveKey, child: Text(t.saveKey)),
          TextButton.icon(
            onPressed: () => _copyKeyUrl(kind.keyUrl),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: Text(t.copyLink),
          ),
          if (hasKey)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => _deleteKey(kind),
              child: Text(t.deleteKey),
            ),
        ]),
        const SizedBox(height: 16),
        _ModelField(kind, key: ValueKey(kind)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final ai = ref.watch(aiSettingsProvider);
    final aiVm = ref.read(aiSettingsProvider.notifier);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // ถือ view model ไว้ตลอดอายุหน้า ผลการบันทึก key แสดงโดยหน้าตั้งค่าที่อยู่ข้างใต้
    ref.watch(settingsViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.aiForRecording)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Insets.page, 4, Insets.page, 32 + MediaQuery.paddingOf(context).bottom),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          for (final k in AiProviderKind.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Corners.card),
                  side: BorderSide(
                    color: k == ai.provider ? scheme.primary : scheme.outlineVariant,
                    width: k == ai.provider ? 1.5 : 1,
                  ),
                ),
                child: Column(children: [
                  // วาดปุ่มเลือกเอง: RadioGroup จะแย่งปุ่มลูกศรจากช่องกรอกที่อยู่ในกลุ่มเดียวกัน
                  Semantics(
                    inMutuallyExclusiveGroup: true,
                    checked: k == ai.provider,
                    child: ListTile(
                      leading: Icon(
                        k == ai.provider ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: k == ai.provider ? scheme.primary : null,
                      ),
                      title: Text(t.providerLabel(k), style: theme.textTheme.titleMedium),
                      subtitle: Text(t.providerDescription(k)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: Insets.page, vertical: 4),
                      onTap: () {
                        if (k == ai.provider) return;
                        _key.clear(); // key ที่พิมพ์ค้างไว้เป็นของบริการเดิม ห้ามบันทึกให้บริการใหม่
                        aiVm.setProvider(k);
                      },
                    ),
                  ),
                  if (k == ai.provider) ...[const Divider(), _config(ai, t)],
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

/// เลือกโมเดลของบริการ จากรายชื่อที่ดึงมาอัตโนมัติ
class _ModelField extends ConsumerWidget {
  const _ModelField(this.kind, {super.key});
  final AiProviderKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final selected = ref.watch(aiSettingsProvider.select((s) => s.modelFor(kind)));
    final hasKey = ref.watch(aiSettingsProvider.select((s) => s.savedKeys.contains(kind)));
    final models = ref.watch(aiModelsProvider(kind));
    final list = models.value ?? const <String>[];
    final error = models.isLoading ? null : models.error;
    // โมเดลที่เลือกไว้ต้องอยู่ในรายการเสมอ แม้ยังโหลดไม่เสร็จหรือบริการไม่มีแล้ว
    final items = [if (!list.contains(selected)) selected, ...list];
    return Labeled(t.model, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: DropdownButtonFormField<String>(
          key: ValueKey(selected),
          initialValue: selected,
          isExpanded: true,
          menuMaxHeight: 400,
          decoration: InputDecoration(
            errorText: error == null ? null : t.modelListFailed(error),
            errorMaxLines: 3,
            helperText: !hasKey
                ? t.saveKeyForModels
                : models.isLoading
                    ? t.loadingModels
                    : list.contains(selected)
                        ? t.modelCount(list.length, kind.label)
                        : t.modelNotListed,
            helperMaxLines: 2,
          ),
          items: [for (final id in items) DropdownMenuItem(value: id, child: Text(id, overflow: TextOverflow.ellipsis))],
          onChanged: list.isEmpty ? null : (id) => id == null ? null : ref.read(aiSettingsProvider.notifier).setModel(kind, id),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: IconButton(
          tooltip: t.reloadModels,
          onPressed: !hasKey || models.isLoading ? null : () => ref.invalidate(aiModelsProvider(kind)),
          icon: models.isLoading
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh),
        ),
      ),
    ]));
  }
}
