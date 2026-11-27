import 'package:flutter/material.dart';

import 'app_theme.dart';

class MissingConfigApp extends StatelessWidget {
  const MissingConfigApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        home: const _MissingConfigPage(),
      );
}

class _MissingConfigPage extends StatelessWidget {
  const _MissingConfigPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget code(String text) => Card(
          child: Padding(
            padding: const EdgeInsets.all(Insets.page),
            child: SelectableText(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface)),
          ),
        );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Icon(Icons.settings_ethernet, size: 40, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('ยังไม่ได้ตั้งค่า Supabase', textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
              const SizedBox(height: 24),
              Text('รันด้วย', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              code('flutter run --dart-define-from-file=env.json'),
              const SizedBox(height: 16),
              Text('ตัวอย่าง env.json', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              code('{\n  "SUPABASE_URL": "https://xxx.supabase.co",\n  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..."\n}'),
            ]),
          ),
        ),
      ),
    );
  }
}
