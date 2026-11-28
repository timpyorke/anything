import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/l10n/app_strings.dart';
import '../core/l10n/strings_th.dart';
import '../domain/photo.dart';
import 'llm_http.dart';
import 'llm_provider.dart';

/// ที่อยู่และสิทธิ์ของ Edge Function `ai-generate` — [accessToken] คืน null เมื่อไม่มีเซสชัน
typedef ManagedAiAccess = ({Uri endpoint, String apiKey, Future<String?> Function() accessToken});

/// AI ของแอป: ส่งผ่าน Edge Function ซึ่งถือ API key และหักโควตา (สัญญาตรงกับ supabase/functions/ai-generate)
class ManagedProvider implements LlmProvider {
  ManagedProvider({required this.access, this.strings = const ThStrings(), http.Client? client})
      : _client = client ?? http.Client();

  final ManagedAiAccess access;
  final AppStrings strings;
  final http.Client _client;

  @override
  AiProviderKind get kind => AiProviderKind.managed;

  /// server เป็นคนเลือกโมเดล (บันทึกจริงอยู่ในตาราง ai_usage)
  @override
  String get model => 'default';

  @override
  Future<String> generateJson({
    required String system,
    required String user,
    List<Uint8List> images = const [],
    Future<void>? cancel,
  }) async {
    final token = await access.accessToken();
    if (token == null) throw LlmException(strings.sessionExpired);
    final (status, json) = await llmRequest(
      _client,
      kind.label,
      access.endpoint,
      headers: {'authorization': 'Bearer $token', 'apikey': access.apiKey},
      body: {
        'system': system,
        'user': user,
        'images': [
          for (final image in images) {'mime': imageMime(image), 'data': base64Encode(image)},
        ],
      },
      strings: strings,
      cancel: cancel,
      // นานกว่าที่ server รอผู้ให้บริการ (55 วินาที)
      timeout: const Duration(seconds: 70),
    );
    final text = json['text'];
    if (status == 200 && text is String && text.trim().isNotEmpty) return text;
    throw _error(status, json['error']);
  }

  LlmException _error(int status, Object? error) {
    final code = error is Map ? error['code'] : null;
    final resetAt = DateTime.tryParse('${error is Map ? error['reset_at'] : null}')?.toLocal();
    String when() => resetAt == null ? strings.aiResetLater : strings.fmtDateTime(resetAt);
    final quota = switch (code) {
      'quota_minute' => strings.aiQuotaMinute,
      'quota_day' => strings.aiQuotaDay(when()),
      'quota_month' => strings.aiQuotaMonth(when()),
      'service_busy' => strings.aiServiceBusy,
      _ => null,
    };
    if (quota != null) return AiQuotaException(quota);
    return LlmException(switch (code) {
      'unauthorized' => strings.sessionExpired,
      'too_large' => strings.aiRequestTooLarge,
      'refused' => strings.requestRefused(kind.label),
      'answer_too_long' => strings.answerTooLong,
      'empty_answer' => strings.emptyAnswer(null),
      _ => strings.managedAiFailed(status),
    });
  }
}
