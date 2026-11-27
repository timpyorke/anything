import 'dart:async';
import 'dart:typed_data';

import 'package:anything/ai/ai_settings.dart';
import 'package:anything/ai/llm_provider.dart';
import 'package:anything/ai/on_device_provider.dart';
import 'package:anything/ai/pcm_audio.dart';
import 'package:anything/ai/voice_recorder.dart';
import 'package:anything/app/providers.dart';
import 'package:anything/features/assistant/voice_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// เสียง 1 วินาทีที่ทุก sample ดังเท่ากับ [level]
Uint8List _tone(int level) {
  final data = ByteData(pcmSampleRate * 2);
  for (var i = 0; i < data.lengthInBytes; i += 2) {
    data.setInt16(i, level, Endian.little);
  }
  return data.buffer.asUint8List();
}

class _Mic implements VoiceRecorder {
  Uint8List pcm = _tone(8000);
  bool allowed = true;
  int cancelled = 0;
  @override
  Future<bool> hasPermission() async => allowed;
  @override
  Future<void> start() async {}
  @override
  Future<Uint8List> stop() async => pcm;
  @override
  Future<void> cancel() async => cancelled++;
}

class _Transcriber implements Transcriber {
  bool ready = true;
  Completer<String> reply = Completer();
  Uint8List? heard;
  @override
  Future<bool> isReady() async => ready;
  @override
  Future<String> transcribe(Uint8List wav) {
    heard = wav;
    return reply.future;
  }
}

class _Llm implements LlmProvider {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Ai extends AiSettingsViewModel {
  @override
  Future<LlmProvider?> resolveProvider() async => _Llm();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Mic mic;
  late _Transcriber stt;
  late ProviderContainer c;
  VoiceViewModel vm() => c.read(voiceViewModelProvider.notifier);
  VoiceState state() => c.read(voiceViewModelProvider);

  setUp(() {
    mic = _Mic();
    stt = _Transcriber();
    c = ProviderContainer(overrides: [
      aiSettingsProvider.overrideWith(_Ai.new),
      currentUserIdProvider.overrideWithValue('user'),
      voiceRecorderProvider.overrideWithValue(mic),
      transcriberProvider.overrideWithValue(stt),
    ]);
    addTearDown(c.dispose);
  });

  test('records, transcribes in WAV form and returns the text once', () async {
    expect(await vm().start(), VoiceStart.started);
    expect(state().listening, isTrue);
    final first = vm().finish(), second = vm().finish(); // แตะส่งซ้ำ
    expect(state().transcribing, isTrue);
    stt.reply.complete(' กินข้าวเย็น\n');
    expect(await first, 'กินข้าวเย็น');
    expect(await second, isNull);
    expect(String.fromCharCodes(stt.heard!.sublist(0, 4)), 'RIFF');
    expect(stt.heard!.length, 44 + mic.pcm.length);
    expect(state(), const VoiceState());
  });

  test('silence is not sent to the model', () async {
    mic.pcm = _tone(20);
    await vm().start();
    expect(await vm().finish(), isNull);
    expect(stt.heard, isNull);
    expect(state().notice, contains('ไม่ได้ยินเสียง'));
  });

  test('cancel while recording discards the clip', () async {
    await vm().start();
    vm().discard();
    expect(mic.cancelled, 1);
    expect(await vm().finish(), isNull);
    expect(stt.heard, isNull);
  });

  test('cancel while transcribing drops the late result', () async {
    await vm().start();
    final result = vm().finish();
    await Future<void>.delayed(Duration.zero);
    vm().discard();
    stt.reply.complete('ช้าไป');
    expect(await result, isNull);
    expect(state(), const VoiceState());
  });

  test('transcription failure is reported', () async {
    await vm().start();
    final result = vm().finish();
    await Future<void>.delayed(Duration.zero);
    stt.reply.completeError(LlmException('โมเดลโหลดไม่ได้'));
    expect(await result, isNull);
    expect(state().notice, contains('โมเดลโหลดไม่ได้'));
  });

  test('needs the voice model and microphone permission before recording', () async {
    stt.ready = false;
    expect(await vm().start(), VoiceStart.needsVoiceModel);
    stt.ready = true;
    mic.allowed = false;
    expect(await vm().start(), VoiceStart.unavailable);
    expect(state().listening, isFalse);
    expect(state().notice, isNotNull);
  });
}
