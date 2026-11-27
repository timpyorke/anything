import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../ai/ai_settings.dart';
import '../../ai/on_device_provider.dart';
import '../diary/diary_view_model.dart';

part 'settings_view_model.freezed.dart';

@freezed
abstract class SettingsState with _$SettingsState {
  const factory SettingsState({
    bool? gemmaInstalled, // null = กำลังตรวจ
    int? progress, // เปอร์เซ็นต์ดาวน์โหลด, null = ไม่ได้โหลดอยู่
    String? gemmaError,
    @Default(false) bool importing,
    String? notice, // ข้อความแจ้งผู้ใช้ครั้งเดียว (View ฟังผ่าน ref.listen แล้วแสดง snackbar)
  }) = _SettingsState;
}

final settingsViewModelProvider = NotifierProvider.autoDispose<SettingsViewModel, SettingsState>(SettingsViewModel.new);

class SettingsViewModel extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    Future.microtask(checkGemma);
    return const SettingsState();
  }

  // provider นี้ถูกทิ้งเมื่อปิดหน้าตั้งค่า: หลัง await ต้องเช็ก ref.mounted ก่อนแตะ state
  // งานยาว (ดาวน์โหลด, นำเข้า) ใช้ keepAlive ให้กลับมาเปิดหน้าแล้วยังเห็นความคืบหน้า ไม่สั่งซ้ำ
  Future<void> checkGemma() async {
    if (!ref.mounted) return;
    try {
      final ok = await OnDeviceProvider.isInstalled();
      if (ref.mounted) state = state.copyWith(gemmaInstalled: ok);
    } catch (e) {
      if (ref.mounted) state = state.copyWith(gemmaError: '$e');
    }
  }

  Future<void> downloadGemma() async {
    final link = ref.keepAlive();
    state = state.copyWith(progress: 0, gemmaError: null);
    try {
      await OnDeviceProvider.install(onProgress: (p) => state = state.copyWith(progress: p));
      state = state.copyWith(gemmaInstalled: true);
    } catch (e) {
      state = state.copyWith(gemmaError: 'ดาวน์โหลดไม่สำเร็จ: $e');
    } finally {
      state = state.copyWith(progress: null);
      link.close();
    }
  }

  Future<void> removeGemma() async {
    await OnDeviceProvider.uninstall();
    await checkGemma();
  }

  Future<void> saveKey(String key) async {
    state = state.copyWith(notice: null);
    await ref.read(aiSettingsProvider.notifier).setStudioKey(key);
    if (!ref.mounted) return;
    state = state.copyWith(notice: 'บันทึก API key แล้ว (เก็บในเครื่องเท่านั้น)');
  }

  /// นำเข้าไฟล์ export ของระบบเดิม ผลสรุปอยู่ที่ state.notice
  Future<void> importFile(Uint8List bytes) async {
    final link = ref.keepAlive();
    state = state.copyWith(importing: true, notice: null);
    String notice;
    try {
      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final n = await ref.read(diaryViewModelProvider.notifier).importExport(data);
      notice = n == 0 ? 'ไม่มีรายการใหม่ (นำเข้าครบแล้ว)' : 'นำเข้าแล้ว $n รายการ';
    } catch (e) {
      notice = 'นำเข้าไม่สำเร็จ: $e';
    }
    state = state.copyWith(importing: false, notice: notice);
    link.close();
  }
}
