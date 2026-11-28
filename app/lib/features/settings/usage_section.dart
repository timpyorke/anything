import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_theme.dart';
import '../../app/language.dart';
import '../../app/providers.dart';
import '../../core/utils/format.dart';
import '../../domain/usage.dart';

/// การใช้งานของบัญชีนี้ — โหลดใหม่ทุกครั้งที่เปิดหน้า
/// ปิด retry อัตโนมัติ: ให้ผู้ใช้กดลองใหม่เอง
final usageProvider = FutureProvider.autoDispose<UsageSummary>(retry: (_, _) => null, (ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(usageRepositoryProvider).mine();
});

/// แถวแสดงแผนและโควตา ใช้ได้ทั้งในการ์ดของหน้าตั้งค่าและหน้าเลือก AI
class UsageRows extends ConsumerWidget {
  const UsageRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final usage = ref.watch(usageProvider);
    final theme = Theme.of(context);
    final data = usage.value;
    if (data == null) {
      return usage.isLoading
          ? const Padding(padding: EdgeInsets.all(Insets.page), child: LinearProgressIndicator())
          : ListTile(
              title: Text(t.usageFailed),
              trailing: TextButton(onPressed: () => ref.invalidate(usageProvider), child: Text(t.retry)),
            );
    }

    Widget meter(String label, Quota q, String Function(int) show) {
      final full = q.used >= q.limit;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.page, vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(alignment: WrapAlignment.spaceBetween, spacing: 8, children: [
            Text(label),
            Text(t.usageOf(show(q.used), show(q.limit)),
                style: theme.textTheme.bodySmall?.copyWith(color: full ? theme.colorScheme.error : null)),
          ]),
          const SizedBox(height: 4),
          // ข้อความข้างบนบอกค่าครบแล้ว โปรแกรมอ่านจอไม่ต้องอ่านแถบซ้ำ
          ExcludeSemantics(
            child: LinearProgressIndicator(
              value: q.limit == 0 ? 1 : (q.used / q.limit).clamp(0, 1),
              color: full ? theme.colorScheme.error : null,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.page, vertical: 6),
          child: Text('${t.plan}: ${data.member ? t.planMember : t.planFree}', style: theme.textTheme.titleSmall),
        ),
        meter(t.usageAiToday, data.aiToday, (n) => '$n'),
        meter(t.usageAiMonth, data.aiMonth, (n) => '$n'),
        meter(t.usageStorage, data.storage, fmtBytes),
      ]),
    );
  }
}
