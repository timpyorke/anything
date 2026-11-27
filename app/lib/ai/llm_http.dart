import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/l10n/app_strings.dart';
import 'llm_provider.dart';

/// ส่งคำขอ HTTP ไปยังบริการ AI แล้วคืนสถานะกับ JSON ที่ตอบกลับ
/// [cancel] จบ = ยกเลิกคำขอ (โยน [LlmCancelled]); ปัญหาเครือข่าย/รูปแบบโยน [LlmException] ตามภาษาใน [strings]
Future<(int, Map<String, dynamic>)> llmRequest(
  http.Client client,
  String service,
  Uri uri, {
  required Map<String, String> headers,
  required AppStrings strings,
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
    throw LlmException(strings.serviceUnreachable(service, e));
  }
  try {
    return (res.statusCode, jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  } catch (_) {
    throw LlmException(strings.malformedResponse(service, res.statusCode));
  }
}

/// ข้อความ error ของคำขอที่ไม่สำเร็จ (ทุกบริการใช้รูปแบบ {"error": {"message": ...}})
LlmException llmError(String service, int status, Map<String, dynamic> json, {required AppStrings strings, String? model}) {
  final error = json['error'];
  final message = (error is Map ? error['message'] : null) ?? 'HTTP $status';
  return LlmException(switch (status) {
    401 => strings.invalidApiKeyCheckSettings,
    402 => strings.outOfCredit(service),
    403 => strings.requestForbidden(service, message),
    404 when model != null => strings.modelNotFound(model),
    429 => strings.quotaExceeded(service),
    529 => strings.serviceOverloaded(service),
    _ => '$service: $message',
  });
}
