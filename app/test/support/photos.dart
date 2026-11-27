import 'dart:convert';
import 'dart:typed_data';

import 'package:anything/data/photo_picker.dart';

/// PNG 1×1 พิกเซลที่ถอดรหัสได้จริง ต่อท้ายด้วย [tag] ให้แยกรูปกันได้
Uint8List png([int tag = 0]) => Uint8List.fromList([
      ...base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='),
      tag,
    ]);

class FakePhotoPicker implements PhotoPicker {
  /// สิ่งที่จะคืนจากการเลือกครั้งถัดไป
  List<Uint8List> next = [png()];
  List<Uint8List> lost = [];
  Object? error;
  final calls = <(PhotoSource, int)>[];

  @override
  Future<List<Uint8List>> pick(PhotoSource source, int limit) async {
    calls.add((source, limit));
    if (error != null) throw error!;
    return next;
  }

  @override
  Future<List<Uint8List>> recoverLost() async {
    final out = lost;
    lost = [];
    return out;
  }
}
