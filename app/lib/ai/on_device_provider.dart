import 'dart:io' show Platform;
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';

import 'llm_provider.dart';

/// Gemma 4 E2B รันบนมือถือผ่าน flutter_edge_ai (LiteRT-LM)
/// ไฟล์โมเดล 2.59 GB ดาวน์โหลดครั้งเดียว ไม่ต้องใช้ token (Apache-2.0)
class OnDeviceProvider implements LlmProvider {
  static final LiteRtLmVariant variant = LiteRtLmModels.gemma4E2bIt.generic;
  static const sizeLabel = '2.6 GB';

  @override
  AiProviderKind get kind => AiProviderKind.onDevice;

  @override
  String get model => variant.id;

  static String get _file => variant.files.first.installFilename;

  static Future<bool> isInstalled() => FlutterEdgeAi.isModelInstalled(_file);

  /// ดาวน์โหลด (ถ้ายังไม่มี) และตั้งเป็นโมเดลที่ใช้งาน — เรียกซ้ำได้ ไม่โหลดซ้ำ
  static Future<void> install({void Function(int percent)? onProgress}) async {
    var builder = FlutterEdgeAi.installModelFromCatalog(variant);
    if (onProgress != null) builder = builder.withProgress(onProgress);
    await builder.install();
  }

  static Future<void> uninstall() => FlutterEdgeAi.uninstallModel(_file);

  Future<InferenceModel> _model() async {
    await install(); // ตั้งเป็น active model หลังเปิดแอปใหม่ (ไม่ดาวน์โหลดซ้ำ)
    return FlutterEdgeAi.getActiveModel(
      defaults: variant.runtimeDefaults,
      supportImage: false,
      supportAudio: false,
      // GPU ของ Gemma 4 ที่ใช้ half precision อาจคัดลอกตัวเลข/วันที่ผิด (LiteRT-LM#3012)
      // iOS: ใช้ GPU แบบ float32 · Android: ใช้ CPU (float32 บน Adreno 8xx ยังมีปัญหา)
      preferredBackend: Platform.isAndroid ? PreferredBackend.cpu : PreferredBackend.gpu,
      activationDataType: Platform.isIOS ? ActivationDataType.float32 : null,
      maxConcurrentSessions: 1,
    );
  }

  @override
  Future<String> generateJson({required String system, required String user}) async {
    if (!await isInstalled()) {
      throw LlmException('ยังไม่ได้ดาวน์โหลดโมเดล Gemma ($sizeLabel) — ไปที่หน้าตั้งค่า');
    }
    final model = await _model();
    final format = ResponseFormat.jsonObject();
    final enforce = model.refusalFor(format) == null;
    final session = await model.openSession(
      systemInstruction: system,
      maxOutputTokens: 1024,
      temperature: 0.2,
      responseFormat: enforce ? format : null,
    );
    try {
      await session.addQueryChunk(Message(text: user, isUser: true));
      return await session.getResponse();
    } on ContextLimitException {
      throw LlmException('ข้อความยาวเกินกว่าที่โมเดลบนเครื่องรับได้ — แบ่งเป็นหลายครั้ง');
    } on IncompleteStructuredOutputException catch (e) {
      return e.partialText;
    } on NonConformingStructuredOutputException catch (e) {
      return e.text;
    } finally {
      await session.close();
    }
  }
}
