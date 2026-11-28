import 'package:material_ui/material_ui.dart';

import '../../core/l10n/app_strings.dart';
import '../../domain/entry.dart';
import 'diary_view_model.dart';

/// แจ้งว่าลบแล้วพร้อมปุ่มเลิกทำ — รับ messenger/view model มาตรงๆ เพราะ widget ที่สั่งลบถูกถอดไปแล้ว
void showDeletedSnackBar(ScaffoldMessengerState messenger, DiaryViewModel diary, Entry entry, AppStrings t) {
  messenger.showSnackBar(SnackBar(
    content: Text([
      entry.recurrence == null ? t.deleted : t.deletedSeries,
      if (entry.photos.isNotEmpty) t.photosPurgedLater,
    ].join(' · ')),
    // มีปุ่มแล้ว Flutter จะค้างแถบไว้ตลอดถ้าไม่กำหนด ซึ่งบังช่องพิมพ์ด้านล่าง
    persist: false,
    duration: const Duration(seconds: 5),
    action: SnackBarAction(
      label: t.undo,
      onPressed: () async {
        try {
          await diary.undoDelete(entry);
        } catch (err) {
          messenger.showSnackBar(SnackBar(content: Text(t.undoFailed(err))));
        }
      },
    ),
  ));
}
