import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/data_sharing_repository.dart';
import 'providers.dart';

/// การตั้งค่าของเครื่อง (ไม่ผูกกับบัญชี เพราะเก็บข้อมูลตั้งแต่ก่อนเข้าสู่ระบบ)
String dataSharingKey(DataSharing kind) => 'share.${kind.name}';

/// รายการที่ผู้ใช้เปิดไว้
final dataSharingProvider = NotifierProvider<DataSharingViewModel, Set<DataSharing>>(DataSharingViewModel.new);

class DataSharingViewModel extends Notifier<Set<DataSharing>> {
  /// ยังไม่เคยเลือก = ปิดทั้งหมด
  @override
  Set<DataSharing> build() => const {};

  /// เรียกครั้งแรกตอนเปิดแอป
  Future<void> load() async {
    final repository = ref.read(dataSharingRepositoryProvider);
    if (!repository.isAvailable) return;
    final storage = ref.read(secureStorageProvider);
    final saved = <DataSharing>{
      for (final kind in DataSharing.values)
        if (await storage.read(key: dataSharingKey(kind)) == 'true') kind,
    };
    state = await repository.restore(saved);
  }

  /// คืน false ถ้าเปิดไม่ได้เพราะระบบของเครื่องไม่อนุญาต
  Future<bool> setEnabled(DataSharing kind, bool enabled) async {
    final storage = ref.read(secureStorageProvider);
    if (!await ref.read(dataSharingRepositoryProvider).setEnabled(kind, enabled)) return false;
    state = enabled ? {...state, kind} : ({...state}..remove(kind));
    if (enabled) {
      await storage.write(key: dataSharingKey(kind), value: 'true');
    } else {
      await storage.delete(key: dataSharingKey(kind));
    }
    return true;
  }

  /// ปิดทั้งหมด (ตอนลบบัญชี) — ล้างข้อมูล Analytics และ token ของเครื่องด้วย
  Future<void> disableAll() async {
    for (final kind in state) {
      await setEnabled(kind, false);
    }
  }
}
