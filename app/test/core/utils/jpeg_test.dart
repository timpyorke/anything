import 'dart:typed_data';

import 'package:anything/core/utils/jpeg.dart';
import 'package:anything/domain/photo.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> _segment(int marker, List<int> data) => [0xff, marker, (data.length + 2) >> 8, (data.length + 2) & 0xff, ...data];

/// Exif แบบ little-endian: tag ทิศของรูป ตามด้วยข้อความแทนพิกัด GPS
List<int> _exif(int orientation) => [
      ...'Exif'.codeUnits, 0, 0, 0x49, 0x49, 0x2a, 0, 8, 0, 0, 0, //
      1, 0, 0x12, 0x01, 3, 0, 1, 0, 0, 0, orientation, 0, 0, 0, //
      0, 0, 0, 0, ...'SECRET-GPS'.codeUnits,
    ];

const _scan = [0xff, 0xda, 0, 2, 1, 2, 3, 0xff, 0xd9];

Uint8List _jpeg(List<List<int>> segments) => Uint8List.fromList([0xff, 0xd8, for (final s in segments) ...s, ..._scan]);

void main() {
  final jfif = _segment(0xe0, 'JFIF'.codeUnits);

  test('removes location and other metadata but keeps the picture', () {
    final out = stripJpegMetadata(_jpeg([jfif, _segment(0xe1, _exif(1)), _segment(0xed, 'IPTC'.codeUnits)]));
    expect(out, _jpeg([jfif]));
  });

  test('keeps only the orientation so portrait photos are not shown sideways', () {
    final out = stripJpegMetadata(_jpeg([jfif, _segment(0xe1, _exif(6))]));
    final text = String.fromCharCodes(out);
    expect(text, isNot(contains('SECRET-GPS')));
    expect(text, contains('Exif'));
    // ตัดซ้ำได้ผลเดิม แปลว่าส่วนที่เขียนกลับอ่านทิศได้ถูก
    expect(stripJpegMetadata(out), out);
    expect(out.length, 2 + 36 + jfif.length + _scan.length);
    expect(out[2 + 29], 6);
    expect(out.sublist(out.length - _scan.length), _scan);
  });

  test('leaves other formats and unreadable files untouched', () {
    for (final bytes in [
      Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 1, 2]),
      Uint8List.fromList([0xff, 0xd8, 0xff, 0xe1, 0xff, 0xff, 0]),
      Uint8List.fromList([0xff, 0xd8, ...jfif]),
    ]) {
      expect(stripJpegMetadata(bytes), same(bytes));
    }
  });

  test('image types are recognised from their first bytes', () {
    expect(imageMime(_jpeg([])), 'image/jpeg');
    expect(imageMime(Uint8List.fromList('GIF89a'.codeUnits)), 'image/gif');
    expect(imageMime(Uint8List.fromList('RIFF0000WEBP'.codeUnits)), 'image/webp');
    expect(imageMime(Uint8List.fromList('RIFF0000WAVE'.codeUnits)), isNull);
    expect(imageMime(Uint8List(0)), isNull);
  });
}
