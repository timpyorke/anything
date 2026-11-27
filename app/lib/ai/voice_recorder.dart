import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'pcm_audio.dart';

/// อัดเสียงเก็บในหน่วยความจำเท่านั้น (ไม่เขียนลงไฟล์ ไม่ส่งออกจากเครื่อง)
abstract class VoiceRecorder {
  /// ขอสิทธิ์ไมโครโฟนถ้ายังไม่ได้ให้
  Future<bool> hasPermission();
  Future<void> start();

  /// หยุดและคืนเสียงทั้งหมดที่อัดได้ (รูปแบบตาม pcm_audio.dart)
  Future<Uint8List> stop();

  /// หยุดและทิ้ง
  Future<void> cancel();
}

class MicRecorder implements VoiceRecorder {
  AudioRecorder? _recorder;
  AudioRecorder get _mic => _recorder ??= AudioRecorder();
  final _pcm = BytesBuilder();
  Completer<void>? _closed;

  @override
  Future<bool> hasPermission() => _mic.hasPermission();

  @override
  Future<void> start() async {
    _pcm.clear();
    final stream = await _mic.startStream(
      const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: pcmSampleRate, numChannels: 1),
    );
    final closed = _closed = Completer<void>();
    stream.listen(_pcm.add, onError: (Object _) {}, onDone: closed.complete);
  }

  @override
  Future<Uint8List> stop() async {
    await _mic.stop();
    // ข้อมูลครบเมื่อ stream ปิด
    await _closed?.future.timeout(const Duration(seconds: 1), onTimeout: () {});
    return _pcm.takeBytes();
  }

  @override
  Future<void> cancel() async {
    await _mic.cancel();
    _pcm.clear();
  }

  Future<void> dispose() async => _recorder?.dispose();
}
