import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

/// กล่องข้อความในหน้า: ผิดพลาด (สีแดง) หรือแจ้งให้ทราบ (สีเน้น) พร้อมปุ่มต่อท้ายได้
class NoticeBox extends StatelessWidget {
  const NoticeBox(this.text, {super.key, this.isError = true, this.action});
  final String text;
  final bool isError;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = isError
        ? (scheme.errorContainer, scheme.onErrorContainer)
        : (scheme.primaryContainer, scheme.onPrimaryContainer);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Corners.control)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(isError ? Icons.error_outline : Icons.info_outline, size: 18, color: fg),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(color: fg))),
          ]),
          if (action != null) Align(alignment: Alignment.centerRight, child: action!),
        ]),
      ),
    );
  }
}
