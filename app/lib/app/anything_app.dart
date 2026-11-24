import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../ai/ai_settings.dart';
import '../features/auth/auth_page.dart';
import 'app_shell.dart';
import 'app_theme.dart';

class AnythingApp extends StatelessWidget {
  const AnythingApp({super.key, required this.ai});
  final AiSettings ai;

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return MaterialApp(
      title: "anything - diary's",
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      home: StreamBuilder<AuthState>(
        stream: client.auth.onAuthStateChange,
        builder: (context, _) {
          final session = client.auth.currentSession;
          if (session == null) return const AuthPage();
          // สร้าง state ใหม่ต่อผู้ใช้ เพื่อไม่ให้ข้อมูลของคนก่อนค้างอยู่
          return AppShell(key: ValueKey(session.user.id), client: client, ai: ai);
        },
      ),
    );
  }
}
