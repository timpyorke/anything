import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

enum PhotoSource { camera, gallery }

/// ถ่ายรูปหรือเลือกรูปจากเครื่อง
abstract class PhotoPicker {
  /// คืนรูปไม่เกิน [limit] รูปเมื่อเลือกจากคลัง (กล้องได้ 1 รูป) — คืนรายการว่างถ้าผู้ใช้ยกเลิก
  Future<List<Uint8List>> pick(PhotoSource source, int limit);

  /// Android อาจปิดแอประหว่างเปิดกล้อง รูปที่ถ่ายไว้ต้องมาขอคืนหลังเปิดใหม่
  Future<List<Uint8List>> recoverLost();
}

class DevicePhotoPicker implements PhotoPicker {
  DevicePhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  // ย่อรูปก่อนใช้: AI อ่านใบเสร็จได้ชัดพอ ส่งเร็ว และไม่เปลืองพื้นที่เก็บ
  static const _maxSide = 1600.0;
  static const _quality = 85;

  @override
  Future<List<Uint8List>> pick(PhotoSource source, int limit) async {
    final List<XFile> files;
    if (source == PhotoSource.gallery && limit > 1) {
      files = await _picker.pickMultiImage(
        limit: limit,
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
        // ไม่ขอข้อมูลกำกับรูป iOS จึงไม่ต้องขอสิทธิ์เข้าถึงคลังรูปทั้งหมด
        requestFullMetadata: false,
      );
    } else {
      final file = await _picker.pickImage(
        source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
        requestFullMetadata: false,
      );
      files = [?file];
    }
    return [for (final f in files) await f.readAsBytes()];
  }

  @override
  Future<List<Uint8List>> recoverLost() async {
    if (defaultTargetPlatform != TargetPlatform.android) return const [];
    final lost = await _picker.retrieveLostData();
    return [for (final f in lost.files ?? const <XFile>[]) await f.readAsBytes()];
  }
}
