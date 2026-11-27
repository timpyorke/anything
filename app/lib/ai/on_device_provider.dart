import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';

import '../domain/photo.dart';
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
      // เปิดรับรูปและเสียงเสมอแม้ใช้แค่ข้อความ: ตั้งค่าต่างกันจะโหลดโมเดล 2.6 GB ใหม่ทุกครั้งที่สลับ
      supportImage: true,
      maxNumImages: maxPhotosPerMessage,
      supportAudio: true,
      // GPU ของ Gemma 4 ที่ใช้ half precision อาจคัดลอกตัวเลข/วันที่ผิด (LiteRT-LM#3012)
      // iOS: ใช้ GPU แบบ float32 · Android: ใช้ CPU (float32 บน Adreno 8xx ยังมีปัญหา)
      preferredBackend: Platform.isAndroid ? PreferredBackend.cpu : PreferredBackend.gpu,
      activationDataType: Platform.isIOS ? ActivationDataType.float32 : null,
      maxConcurrentSessions: 1,
    );
  }

  // sampler ถูกล็อกตั้งแต่การสร้างข้อความครั้งแรกของโมเดล (LiteRT-LM#2080) ทุก session จึงใช้ค่าเดียวกัน
  static const _temperature = 0.2;

  static Future<void> _queue = Future.value();

  /// โมเดลเปิดได้ทีละ session: งานที่เข้ามาซ้อน (เช่น อัดเสียงขณะรอบก่อนยังคิดอยู่) ต้องต่อคิว
  static Future<T> _exclusive<T>(Future<T> Function() job) {
    final result = _queue.then((_) => job());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  static Future<void> _requireInstalled() async {
    if (!await isInstalled()) {
      throw LlmException('ยังไม่ได้ดาวน์โหลดโมเดล Gemma ($sizeLabel) — ไปที่หน้าตั้งค่า');
    }
  }

  /// ถอดเสียงพูดภาษาไทยเป็นข้อความ ([wav] ยาวไม่เกิน 30 วินาที)
  Future<String> transcribe(Uint8List wav) => _exclusive(() async {
        await _requireInstalled();
        final model = await _model();
        final session = await model.openSession(temperature: _temperature, maxOutputTokens: 512, enableAudioModality: true);
        try {
          // พรอมต์ถอดเสียงตาม model card ของ Gemma 4 (เสียงอยู่หลังข้อความ แพ็กเกจจัดลำดับให้)
          await session.addQueryChunk(Message.withAudio(
            text: 'Transcribe the following speech segment in Thai into Thai text. '
                'Follow these specific instructions for formatting the answer:\n'
                '* Only output the transcription, with no newlines.\n'
                '* When transcribing numbers, write the digits.',
            audioBytes: wav,
            isUser: true,
          ));
          return await session.getResponse();
        } finally {
          await session.close();
        }
      });

  @override
  Future<String> generateJson({
    required String system,
    required String user,
    List<Uint8List> images = const [],
    Future<void>? cancel,
  }) {
    // จำไว้ตั้งแต่ตอนเข้าคิว: ถูกยกเลิกระหว่างรอคิวหรือโหลดโมเดลก็ไม่ต้องเริ่มคิด
    var cancelled = false;
    cancel?.then((_) => cancelled = true);
    return _exclusive(() => _generateJson(system, user, images, cancel, () => cancelled));
  }

  Future<String> _generateJson(
    String system,
    String user,
    List<Uint8List> images,
    Future<void>? cancel,
    bool Function() cancelled,
  ) async {
    if (cancelled()) throw LlmCancelled();
    await _requireInstalled();
    final model = await _model();
    final format = ResponseFormat.jsonObject();
    final enforce = model.refusalFor(format) == null;
    final session = await model.openSession(
      systemInstruction: system,
      maxOutputTokens: 1024,
      temperature: _temperature,
      responseFormat: enforce ? format : null,
      enableVisionModality: images.isNotEmpty,
    );
    var done = false;
    try {
      await session.addQueryChunk(images.isEmpty
          ? Message(text: user, isUser: true)
          : Message.withImages(text: user, imageBytes: images, isUser: true));
      if (cancelled()) throw LlmCancelled();
      final response = session.getResponse();
      // หยุดการคิดในเครื่องจริงๆ คิวจะได้ว่างให้คำขอถัดไป
      cancel?.then((_) async {
        if (!done) await session.stopGeneration();
      }).ignore();
      return await response;
    } on ContextLimitException {
      throw LlmException('ข้อความหรือรูปมากเกินกว่าที่โมเดลบนเครื่องรับได้ — แบ่งเป็นหลายครั้ง');
    } on IncompleteStructuredOutputException catch (e) {
      return e.partialText;
    } on NonConformingStructuredOutputException catch (e) {
      return e.text;
    } finally {
      done = true;
      await session.close();
    }
  }
}

abstract class Transcriber {
  /// พร้อมถอดเสียงไหม (ดาวน์โหลดโมเดลแล้ว)
  Future<bool> isReady();
  Future<String> transcribe(Uint8List wav);
}

class GemmaTranscriber implements Transcriber {
  const GemmaTranscriber();

  @override
  Future<bool> isReady() => OnDeviceProvider.isInstalled();

  @override
  Future<String> transcribe(Uint8List wav) => OnDeviceProvider().transcribe(wav);
}
