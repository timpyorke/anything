import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai/ai_settings.dart';
import 'app/anything_app.dart';
import 'app/env.dart';
import 'app/language.dart';
import 'app/missing_config_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    runApp(const MissingConfigApp());
    return;
  }
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  await FlutterEdgeAi.initialize(inferenceEngines: [LiteRtLmEngine()]);
  final container = ProviderContainer();
  await container.read(languageProvider.notifier).load();
  await container.read(aiSettingsProvider.notifier).load();
  runApp(UncontrolledProviderScope(container: container, child: const AnythingApp()));
}
