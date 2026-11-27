import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/jpeg.dart';
import '../../data/photo_picker.dart';
import '../../domain/photo.dart';

/// ผลการเลือกรูป: รูปที่ใช้ได้ และข้อความแจ้งผู้ใช้ถ้ามีปัญหา
typedef PickedPhotos = ({List<Uint8List> photos, String? notice});

/// เลือกรูปเพิ่มได้อีกไม่เกิน [room] รูป แล้วเตรียมให้พร้อมส่ง/อัปโหลด
Future<PickedPhotos> pickPhotos(PhotoPicker picker, PhotoSource source,
    {required int room, required AppStrings strings}) async {
  if (room <= 0) return (photos: const <Uint8List>[], notice: strings.photoLimitReached);
  try {
    return preparePhotos(await picker.pick(source, room), room: room, strings: strings);
  } on PlatformException catch (e) {
    final notice = switch (e.code) {
      'camera_access_denied' || 'camera_access_denied_without_prompt' || 'camera_access_restricted' =>
        strings.cameraDenied,
      'photo_access_denied' || 'photo_access_restricted' => strings.galleryDenied,
      _ => strings.photoOpenFailed(e.message ?? e.code),
    };
    return (photos: const <Uint8List>[], notice: notice);
  } catch (e) {
    return (photos: const <Uint8List>[], notice: strings.photoOpenFailed(e));
  }
}

/// ตัดข้อมูลกำกับรูป และคัดรูปที่ใช้ไม่ได้ออก
PickedPhotos preparePhotos(List<Uint8List> raw, {required int room, required AppStrings strings}) {
  final usable = [
    for (final b in raw.map(stripJpegMetadata))
      if (imageMime(b) != null && b.length <= maxPhotoBytes) b,
  ];
  final notice = usable.length < raw.length
      ? strings.photosUnusable
      : usable.length > room
          ? strings.photosOverRoom(room)
          : null;
  return (photos: usable.take(room).toList(), notice: notice);
}
