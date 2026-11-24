import 'package:flutter/material.dart';

import 'app_theme.dart';

class MissingConfigApp extends StatelessWidget {
  const MissingConfigApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'ยังไม่ได้ตั้งค่า Supabase\n\nรันด้วย:\nflutter run --dart-define-from-file=env.json\n\n'
                'env.json:\n{"SUPABASE_URL": "https://xxx.supabase.co",\n "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..."}',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
