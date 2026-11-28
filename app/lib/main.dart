import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai/ai_settings.dart';
import 'app/anything_app.dart';
import 'app/data_sharing.dart';
import 'app/env.dart';
import 'app/language.dart';
import 'app/missing_config_page.dart';
import 'app/providers.dart';
import 'data/firebase_data_sharing_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    runApp(const MissingConfigApp());
    return;
  }
  // เริ่มก่อนส่วนอื่น เพื่อให้รายงาน error ตอนเปิดแอปได้ (เมื่อผู้ใช้เปิดไว้)
  final dataSharing = await FirebaseDataSharingRepository.initialize();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  await FlutterEdgeAi.initialize(inferenceEngines: [LiteRtLmEngine()]);
  final container = ProviderContainer(overrides: [dataSharingRepositoryProvider.overrideWithValue(dataSharing)]);
  // ตั้งค่า Firebase ไม่สำเร็จ ไม่ควรทำให้เปิดแอปไม่ได้
  await container.read(dataSharingProvider.notifier).load().catchError((Object e) => debugPrint('$e'));
  await container.read(languageProvider.notifier).load();
  await container.read(aiSettingsProvider.notifier).load();
  runApp(UncontrolledProviderScope(container: container, child: const AnythingApp()));
}
