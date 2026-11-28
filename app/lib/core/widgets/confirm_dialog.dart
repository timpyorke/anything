import 'package:material_ui/material_ui.dart';

/// ถามยืนยันก่อนทำสิ่งที่ย้อนยากหรือกระทบข้อมูล คืน true เมื่อผู้ใช้กดยืนยัน
/// [destructive] = ปุ่มยืนยันสีแดง (ลบ, ออกจากระบบ, ทิ้งการแก้ไข)
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) {
      final scheme = Theme.of(c).colorScheme;
      return AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(cancelLabel)),
          FilledButton(
            style: destructive ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError) : null,
            onPressed: () => Navigator.pop(c, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return ok ?? false;
}
