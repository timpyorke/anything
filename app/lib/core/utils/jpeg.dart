import 'dart:typed_data';

/// ตัดข้อมูลกำกับของไฟล์ JPEG (EXIF/XMP/IPTC เช่น พิกัด GPS และรุ่นกล้อง) ก่อนส่งให้ AI หรืออัปโหลด
/// เก็บไว้เฉพาะทิศของรูป ไม่งั้นรูปแนวตั้งจะแสดงตะแคง — ไฟล์ชนิดอื่นหรือไฟล์ที่อ่านไม่ได้คืนตามเดิม
Uint8List stripJpegMetadata(Uint8List b) {
  if (b.length < 4 || b[0] != 0xff || b[1] != 0xd8) return b;
  final kept = BytesBuilder();
  var orientation = 1;
  var i = 2;
  while (i + 4 <= b.length && b[i] == 0xff && b[i + 1] != 0xda) {
    final marker = b[i + 1];
    final end = i + 2 + (b[i + 2] << 8 | b[i + 3]);
    if (end < i + 4 || end > b.length) return b;
    if (marker == 0xe1) {
      orientation = _orientation(Uint8List.sublistView(b, i + 4, end)) ?? orientation;
    } else if (marker != 0xed) {
      kept.add(Uint8List.sublistView(b, i, end));
    }
    i = end;
  }
  // ต้องจบที่ข้อมูลภาพ (SOS) ไม่งั้นแปลว่าอ่านโครงสร้างผิด
  if (i + 2 > b.length || b[i] != 0xff || b[i + 1] != 0xda) return b;
  return (BytesBuilder()
        ..add(const [0xff, 0xd8])
        ..add(orientation == 1 ? const [] : _orientationOnly(orientation))
        ..add(kept.takeBytes())
        ..add(Uint8List.sublistView(b, i)))
      .takeBytes();
}

/// ค่าทิศของรูปจากเนื้อ APP1 แบบ Exif (null = ไม่มี)
int? _orientation(Uint8List app1) {
  if (app1.length < 14 || String.fromCharCodes(app1, 0, 4) != 'Exif') return null;
  final tiff = ByteData.sublistView(app1, 6);
  final endian = tiff.getUint8(0) == 0x49 ? Endian.little : Endian.big;
  final ifd = tiff.getUint32(4, endian);
  if (ifd + 2 > tiff.lengthInBytes) return null;
  final count = tiff.getUint16(ifd, endian);
  for (var e = ifd + 2; e + 12 <= tiff.lengthInBytes && e < ifd + 2 + count * 12; e += 12) {
    if (tiff.getUint16(e, endian) != 0x0112) continue;
    final v = tiff.getUint16(e + 8, endian);
    return v >= 1 && v <= 8 ? v : null;
  }
  return null;
}

/// APP1 ที่มีแค่ tag ทิศของรูป
List<int> _orientationOnly(int value) => [
      0xff, 0xe1, 0x00, 0x22, ...'Exif'.codeUnits, 0, 0, //
      0x4d, 0x4d, 0x00, 0x2a, 0, 0, 0, 8, // TIFF แบบ big-endian
      0, 1, 0x01, 0x12, 0, 3, 0, 0, 0, 1, 0, value, 0, 0, //
      0, 0, 0, 0,
    ];
