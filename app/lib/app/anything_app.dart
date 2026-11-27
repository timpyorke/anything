import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_page.dart';
import '../features/timeline/timeline_page.dart';
import 'app_theme.dart';
import 'providers.dart';

class AnythingApp extends ConsumerWidget {
  const AnythingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ล็อกอินอยู่ไหม — ViewModel ที่ผูกกับผู้ใช้ (diary, filter) จะสร้างใหม่เองเมื่อ id เปลี่ยน
    final userId = ref.watch(currentUserIdProvider);
    return MaterialApp(
      title: "anything - diary's",
      debugShowCheckedModeBanner: false,
      // แอปเป็นภาษาไทย: ตัวเลือกวันที่ เมนูคัดลอก/วาง และคำอ่านปุ่มของระบบต้องเป็นไทยด้วย
      locale: const Locale('th'),
      supportedLocales: const [Locale('th')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      home: userId == null ? const AuthPage() : TimelinePage(key: ValueKey(userId)),
    );
  }
}
