import 'package:flutter/services.dart';

import '../../core/utils/jpeg.dart';
import '../../data/photo_picker.dart';
import '../../domain/photo.dart';

/// ผลการเลือกรูป: รูปที่ใช้ได้ และข้อความแจ้งผู้ใช้ถ้ามีปัญหา
typedef PickedPhotos = ({List<Uint8List> photos, String? notice});

/// เลือกรูปเพิ่มได้อีกไม่เกิน [room] รูป แล้วเตรียมให้พร้อมส่ง/อัปโหลด
Future<PickedPhotos> pickPhotos(PhotoPicker picker, PhotoSource source, {required int room}) async {
  if (room <= 0) return (photos: const <Uint8List>[], notice: 'แนบรูปได้ไม่เกินนี้แล้ว เอารูปเดิมออกก่อน');
  try {
    return preparePhotos(await picker.pick(source, room), room: room);
  } on PlatformException catch (e) {
    final notice = switch (e.code) {
      'camera_access_denied' || 'camera_access_denied_without_prompt' || 'camera_access_restricted' =>
        'ใช้กล้องไม่ได้ ตรวจสิทธิ์ในการตั้งค่าเครื่อง',
      'photo_access_denied' || 'photo_access_restricted' => 'เปิดคลังรูปไม่ได้ ตรวจสิทธิ์ในการตั้งค่าเครื่อง',
      _ => 'เปิดรูปไม่ได้: ${e.message ?? e.code}',
    };
    return (photos: const <Uint8List>[], notice: notice);
  } catch (e) {
    return (photos: const <Uint8List>[], notice: 'เปิดรูปไม่ได้: $e');
  }
}

/// ตัดข้อมูลกำกับรูป และคัดรูปที่ใช้ไม่ได้ออก
PickedPhotos preparePhotos(List<Uint8List> raw, {required int room}) {
  final usable = [
    for (final b in raw.map(stripJpegMetadata))
      if (imageMime(b) != null && b.length <= maxPhotoBytes) b,
  ];
  final notice = usable.length < raw.length
      ? 'บางรูปใช้ไม่ได้ (รองรับ JPEG, PNG, WebP, GIF ขนาดไม่เกิน 5 MB)'
      : usable.length > room
          ? 'เพิ่มได้อีก $room รูป ที่เหลือไม่ได้แนบ'
          : null;
  return (photos: usable.take(room).toList(), notice: notice);
}
