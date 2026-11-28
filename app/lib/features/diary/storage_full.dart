import '../../core/l10n/app_strings.dart';
import '../../core/utils/format.dart';
import '../../domain/repositories/diary_repository.dart';

/// ข้อความของ [error] ถ้าบันทึกไม่ได้เพราะพื้นที่เก็บรูปเต็ม (null = สาเหตุอื่น)
String? storageFullMessage(Object error, AppStrings strings) =>
    error is StorageFullException ? strings.storageFull(fmtBytes(error.limit)) : null;
