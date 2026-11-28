import 'package:anything/domain/repositories/data_sharing_repository.dart';

class FakeDataSharingRepository implements DataSharingRepository {
  /// รายการคำสั่งที่ได้รับ
  final calls = <(DataSharing, bool)>[];
  Set<DataSharing>? restored;

  /// ระบบของเครื่องอนุญาตการแจ้งเตือนไหม
  var allowed = true;
  Object? failure;

  @override
  bool get isAvailable => true;

  @override
  Future<Set<DataSharing>> restore(Set<DataSharing> enabled) async {
    restored = enabled;
    return allowed ? enabled : enabled.difference({DataSharing.notifications});
  }

  @override
  Future<bool> setEnabled(DataSharing kind, bool enabled) async {
    if (failure case final error?) throw error;
    if (enabled && kind == DataSharing.notifications && !allowed) return false;
    calls.add((kind, enabled));
    return true;
  }
}
