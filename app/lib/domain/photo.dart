import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'photo.freezed.dart';

/// รูปที่แนบกับข้อความ 1 ครั้งได้สูงสุด
const maxPhotosPerMessage = 4;

/// รูปของรายการ 1 รายการได้สูงสุด
const maxPhotosPerEntry = 10;

/// ขนาดไฟล์รูปสูงสุด (ตรงกับ file_size_limit ของ bucket ในฐานข้อมูล)
const maxPhotoBytes = 5 * 1024 * 1024;

/// รูปของรายการ: ที่เก็บแล้วมี [path] ใน storage ส่วนรูปที่ยังไม่บันทึกมีแค่ [bytes]
@freezed
abstract class Photo with _$Photo {
  const Photo._();
  const factory Photo({String? path, Uint8List? bytes}) = _Photo;

  bool get isNew => path == null;
}

/// ชนิดของไฟล์รูปจากไบต์ต้นไฟล์ (null = ชนิดที่ AI หรือ storage ไม่รองรับ)
String? imageMime(Uint8List b) {
  bool at(int offset, List<int> magic) =>
      b.length >= offset + magic.length && Iterable<int>.generate(magic.length).every((i) => b[offset + i] == magic[i]);
  if (at(0, const [0xff, 0xd8, 0xff])) return 'image/jpeg';
  if (at(0, const [0x89, 0x50, 0x4e, 0x47])) return 'image/png';
  if (at(0, 'GIF8'.codeUnits)) return 'image/gif';
  if (at(0, 'RIFF'.codeUnits) && at(8, 'WEBP'.codeUnits)) return 'image/webp';
  return null;
}
