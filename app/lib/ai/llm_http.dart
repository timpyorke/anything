import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_provider.dart';

/// ส่งคำขอ HTTP ไปยังบริการ AI แล้วคืนสถานะกับ JSON ที่ตอบกลับ
/// [cancel] จบ = ยกเลิกคำขอ (โยน [LlmCancelled]); ปัญหาเครือข่าย/รูปแบบโยน [LlmException] ภาษาไทย
Future<(int, Map<String, dynamic>)> llmRequest(
  http.Client client,
  String service,
  Uri uri, {
  required Map<String, String> headers,
  Object? body,
  Future<void>? cancel,
  Duration timeout = const Duration(seconds: 15),
}) async {
  final http.Response res;
  try {
    final request = http.AbortableRequest(body == null ? 'GET' : 'POST', uri, abortTrigger: cancel)..headers.addAll(headers);
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    res = await client.send(request).then(http.Response.fromStream).timeout(timeout);
  } on http.RequestAbortedException {
    throw LlmCancelled();
  } catch (e) {
    throw LlmException('เชื่อมต่อ $service ไม่ได้: $e');
  }
  try {
    return (res.statusCode, jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  } catch (_) {
    throw LlmException('$service ตอบกลับผิดรูปแบบ (HTTP ${res.statusCode})');
  }
}

/// ข้อความ error ของคำขอที่ไม่สำเร็จ (ทุกบริการใช้รูปแบบ {"error": {"message": ...}})
LlmException llmError(String service, int status, Map<String, dynamic> json, {String? model}) {
  final error = json['error'];
  final message = (error is Map ? error['message'] : null) ?? 'HTTP $status';
  return LlmException(switch (status) {
    401 => 'API key ไม่ถูกต้อง — ตรวจในหน้าตั้งค่า',
    402 => 'เครดิต $service ไม่พอ',
    403 => '$service ไม่อนุญาตคำขอนี้: $message',
    404 when model != null => 'ไม่พบโมเดล "$model" — เลือกโมเดลใหม่ในหน้าตั้งค่า',
    429 => 'ใช้โควตา $service เกินแล้ว ลองใหม่ภายหลัง',
    529 => '$service มีผู้ใช้มากในขณะนี้ ลองใหม่ภายหลัง',
    _ => '$service: $message',
  });
}
