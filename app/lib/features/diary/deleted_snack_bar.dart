import 'package:flutter/material.dart';

import '../../domain/entry.dart';
import 'diary_view_model.dart';

/// แจ้งว่าลบแล้วพร้อมปุ่มเลิกทำ — รับ messenger/view model มาตรงๆ เพราะ widget ที่สั่งลบถูกถอดไปแล้ว
void showDeletedSnackBar(ScaffoldMessengerState messenger, DiaryViewModel diary, Entry entry) {
  messenger.showSnackBar(SnackBar(
    content: Text(entry.recurrence == null ? 'ลบแล้ว' : 'ลบรายการที่เกิดซ้ำทั้งชุดแล้ว'),
    // มีปุ่มแล้ว Flutter จะค้างแถบไว้ตลอดถ้าไม่กำหนด ซึ่งบังช่องพิมพ์ด้านล่าง
    persist: false,
    duration: const Duration(seconds: 5),
    action: SnackBarAction(
      label: 'เลิกทำ',
      onPressed: () async {
        try {
          await diary.undoDelete(entry);
        } catch (err) {
          messenger.showSnackBar(SnackBar(content: Text('เลิกทำไม่สำเร็จ: $err')));
        }
      },
    ),
  ));
}
