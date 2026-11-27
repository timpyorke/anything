import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:supabase_flutter/supabase_flutter.dart' as sb show AuthState;

import '../ai/on_device_provider.dart';
import '../ai/voice_recorder.dart';
import '../data/photo_picker.dart';
import '../data/supabase_diary_repository.dart';
import '../domain/repositories/diary_repository.dart';

/// Provider ระดับแอป (infrastructure) — ทดสอบได้โดย override ที่นี่

final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

final diaryRepositoryProvider =
    Provider<DiaryRepository>((ref) => SupabaseDiaryRepository(ref.watch(supabaseClientProvider)));

final authChangesProvider =
    StreamProvider<sb.AuthState>((ref) => ref.watch(supabaseClientProvider).auth.onAuthStateChange);

/// id ผู้ใช้ที่ล็อกอินอยู่ (null = ยังไม่ล็อกอิน) — viewmodel ที่ผูกกับผู้ใช้ watch ตัวนี้
/// เพื่อให้สร้างใหม่ทุกครั้งที่เปลี่ยนบัญชี ข้อมูลคนก่อนจะไม่ค้าง
final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authChangesProvider);
  return ref.watch(supabaseClientProvider).auth.currentSession?.user.id;
});

final currentUserEmailProvider = Provider<String?>((ref) {
  ref.watch(authChangesProvider);
  return ref.watch(supabaseClientProvider).auth.currentUser?.email;
});

final signOutProvider = Provider<Future<void> Function()>((ref) => ref.watch(supabaseClientProvider).auth.signOut);

final voiceRecorderProvider = Provider<VoiceRecorder>((ref) {
  final recorder = MicRecorder();
  ref.onDispose(recorder.dispose);
  return recorder;
});

final photoPickerProvider = Provider<PhotoPicker>((ref) => DevicePhotoPicker());

/// ถอดเสียงเป็นข้อความในเครื่อง (ใช้ Gemma เสมอ ไม่ว่าจะเลือก AI ตัวไหนไว้บันทึก)
final transcriberProvider = Provider<Transcriber>((ref) => const GemmaTranscriber());
