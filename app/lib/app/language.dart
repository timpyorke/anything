import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/app_strings.dart';
import 'providers.dart';

/// ภาษาของแอป เป็นการตั้งค่าของเครื่อง (ไม่ผูกกับบัญชี หน้าเข้าสู่ระบบจึงใช้ภาษาเดียวกัน)
const languageKey = 'app.language';

final languageProvider = NotifierProvider<LanguageViewModel, AppLanguage>(LanguageViewModel.new);

/// ข้อความในภาษาที่เลือก — View ใช้ watch, ViewModel ใช้ read ตอนจะสร้างข้อความ
final stringsProvider = Provider<AppStrings>((ref) => AppStrings.of(ref.watch(languageProvider)));

class LanguageViewModel extends Notifier<AppLanguage> {
  /// ยังไม่เคยเลือก = ภาษาไทย
  @override
  AppLanguage build() => AppLanguage.th;

  /// เรียกครั้งแรกตอนเปิดแอป ก่อนวาดหน้าแรก
  Future<void> load() async {
    final code = await ref.read(secureStorageProvider).read(key: languageKey);
    state = AppLanguage.values.firstWhere((l) => l.code == code, orElse: () => AppLanguage.th);
  }

  Future<void> select(AppLanguage language) async {
    state = language;
    await ref.read(secureStorageProvider).write(key: languageKey, value: language.code);
  }
}
