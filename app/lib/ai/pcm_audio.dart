/// เสียงดิบที่ใช้ในแอป: PCM 16-bit little-endian, mono, 16 kHz (รูปแบบที่ Gemma ใช้)
library;

import 'dart:typed_data';

const pcmSampleRate = 16000;
const _bytesPerSecond = pcmSampleRate * 2;

/// เสียงที่ดังสุดในคลิป (0–32768) — ใช้แยกคลิปเงียบ
int pcmPeak(Uint8List pcm) {
  final data = ByteData.sublistView(pcm);
  var peak = 0;
  for (var i = 0; i + 1 < pcm.length; i += 2) {
    final v = data.getInt16(i, Endian.little).abs();
    if (v > peak) peak = v;
  }
  return peak;
}

/// สั้นกว่าครึ่งวินาทีหรือเบามาก = ไม่มีคำพูด
/// (ต้องกรองก่อน เพราะโมเดลอาจแต่งข้อความขึ้นมาเองจากเสียงเงียบ)
bool isSilent(Uint8List pcm) => pcm.length < _bytesPerSecond ~/ 2 || pcmPeak(pcm) < 500;

/// ใส่หัวไฟล์ WAV ให้ PCM
Uint8List wavFromPcm(Uint8List pcm) {
  final header = ByteData(44);
  void tag(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  header.setUint32(16, 16, Endian.little); // ขนาด chunk fmt
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, pcmSampleRate, Endian.little);
  header.setUint32(28, _bytesPerSecond, Endian.little);
  header.setUint16(32, 2, Endian.little); // ไบต์ต่อ sample
  header.setUint16(34, 16, Endian.little); // บิตต่อ sample
  tag(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  return Uint8List(44 + pcm.length)
    ..setAll(0, header.buffer.asUint8List())
    ..setAll(44, pcm);
}
