import 'package:material_ui/material_ui.dart';

import '../../app/app_theme.dart';

/// ป้ายเหนือช่องกรอกหรือกลุ่มตัวเลือก — ใช้แทนป้ายลอยในช่อง ซึ่งล้นขอบเมื่อเป็นอักษรไทย
class Labeled extends StatelessWidget {
  const Labeled(this.label, {super.key, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(label, style: Theme.of(context).textTheme.titleSmall),
          ),
          child,
        ],
      );
}

/// กลุ่มรายการในการ์ดเดียว มีหัวข้อด้านบน (ถ้ามี) และเส้นคั่นระหว่างแถว
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.page, 0, Insets.page, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title!, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
          ),
        Card(
          child: Column(children: [
            for (final (i, child) in children.indexed) ...[if (i > 0) const Divider(), child],
          ]),
        ),
      ]),
    );
  }
}
