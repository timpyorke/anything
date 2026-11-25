import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

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
  }) = _SettingsState;
}

final settingsViewModelProvider = NotifierProvider.autoDispose<SettingsViewModel, SettingsState>(SettingsViewModel.new);

class SettingsViewModel extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    Future.microtask(checkGemma);
    return const SettingsState();
  }

  Future<void> checkGemma() async {
    try {
      final ok = await OnDeviceProvider.isInstalled();
      state = state.copyWith(gemmaInstalled: ok);
    } catch (e) {
      state = state.copyWith(gemmaError: '$e');
    }
  }

  Future<void> downloadGemma() async {
    state = state.copyWith(progress: 0, gemmaError: null);
    try {
      await OnDeviceProvider.install(onProgress: (p) => state = state.copyWith(progress: p));
      state = state.copyWith(gemmaInstalled: true);
    } catch (e) {
      state = state.copyWith(gemmaError: 'ดาวน์โหลดไม่สำเร็จ: $e');
    } finally {
      state = state.copyWith(progress: null);
    }
  }

  Future<void> removeGemma() async {
    await OnDeviceProvider.uninstall();
    await checkGemma();
  }

  /// นำเข้าไฟล์ export ของระบบเดิม คืนข้อความสรุปให้ view แสดง
  Future<String> importFile(Uint8List bytes) async {
    state = state.copyWith(importing: true);
    try {
      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final n = await ref.read(diaryViewModelProvider.notifier).importExport(data);
      return n == 0 ? 'ไม่มีรายการใหม่ (นำเข้าครบแล้ว)' : 'นำเข้าแล้ว $n รายการ';
    } catch (e) {
      return 'นำเข้าไม่สำเร็จ: $e';
    } finally {
      state = state.copyWith(importing: false);
    }
  }
}
