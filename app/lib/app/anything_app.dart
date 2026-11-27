import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n/app_strings.dart';
import '../features/auth/auth_page.dart';
import '../features/timeline/timeline_page.dart';
import 'app_theme.dart';
import 'language.dart';
import 'providers.dart';

class AnythingApp extends ConsumerWidget {
  const AnythingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ล็อกอินอยู่ไหม — ViewModel ที่ผูกกับผู้ใช้ (diary, filter) จะสร้างใหม่เองเมื่อ id เปลี่ยน
    final userId = ref.watch(currentUserIdProvider);
    final language = ref.watch(languageProvider);
    return MaterialApp(
      title: "anything - diary's",
      debugShowCheckedModeBanner: false,
      // ตัวเลือกวันที่ เมนูคัดลอก/วาง และคำอ่านปุ่มของระบบต้องเป็นภาษาเดียวกับแอป
      locale: Locale(language.code),
      supportedLocales: [for (final l in AppLanguage.values) Locale(l.code)],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      home: userId == null ? const AuthPage() : TimelinePage(key: ValueKey(userId)),
    );
  }
}
