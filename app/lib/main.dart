import 'package:flutter/material.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai/ai_settings.dart';
import 'app/anything_app.dart';
import 'app/missing_config_page.dart';

/// ค่าเชื่อมต่อ Supabase มาจากตอน build:
///   flutter run --dart-define-from-file=env.json
/// env.json (ไม่อยู่ใน git): {"SUPABASE_URL": "...", "SUPABASE_PUBLISHABLE_KEY": "..."}
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    runApp(const MissingConfigApp());
    return;
  }
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  await FlutterEdgeAi.initialize(inferenceEngines: [LiteRtLmEngine()]);
  final ai = AiSettings();
  await ai.load();
  runApp(AnythingApp(ai: ai));
}
