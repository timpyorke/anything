import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:supabase_flutter/supabase_flutter.dart' as sb show AuthState;
import 'package:url_launcher/url_launcher.dart';

import '../ai/on_device_provider.dart';
import '../ai/voice_recorder.dart';
import '../data/photo_picker.dart';
import '../data/revenuecat_billing_repository.dart';
import '../data/supabase_account_repository.dart';
import '../data/supabase_diary_repository.dart';
import '../data/supabase_social_auth_repository.dart';
import '../data/supabase_usage_repository.dart';
import '../domain/repositories/account_repository.dart';
import '../domain/repositories/billing_repository.dart';
import '../domain/repositories/data_sharing_repository.dart';
import '../domain/repositories/diary_repository.dart';
import '../domain/repositories/social_auth_repository.dart';
import '../domain/repositories/usage_repository.dart';
import 'env.dart';
import 'language.dart';

/// Provider ระดับแอป (infrastructure) — ทดสอบได้โดย override ที่นี่

final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

final diaryRepositoryProvider =
    Provider<DiaryRepository>((ref) => SupabaseDiaryRepository(ref.watch(supabaseClientProvider)));

final usageRepositoryProvider =
    Provider<UsageRepository>((ref) => SupabaseUsageRepository(ref.watch(supabaseClientProvider)));

final accountRepositoryProvider =
    Provider<AccountRepository>((ref) => SupabaseAccountRepository(ref.watch(supabaseClientProvider)));

final billingRepositoryProvider = Provider<BillingRepository>((ref) => RevenueCatBillingRepository(
    apiKey: switch (defaultTargetPlatform) {
      TargetPlatform.iOS => revenueCatAppleKey,
      TargetPlatform.android => revenueCatGoogleKey,
      _ => '',
    }));

/// Firebase — main.dart override ด้วยของจริงเมื่อ build มีไฟล์ตั้งค่า
final dataSharingRepositoryProvider = Provider<DataSharingRepository>((ref) => const NoDataSharingRepository());

/// ผูกการซื้อกับบัญชีที่ล็อกอินอยู่ (แอป watch ไว้ตลอด)
final billingSessionProvider = Provider<void>((ref) {
  final billing = ref.watch(billingRepositoryProvider);
  // ผูกไม่สำเร็จ (เช่น ไม่มีเน็ต) ไม่ควรกวนผู้ใช้ — ก่อนซื้อจะลองผูกใหม่เอง
  billing.identify(ref.watch(currentUserIdProvider)).ignore();
});

/// หน้าข้อกำหนดและความเป็นส่วนตัว (ว่าง = ไม่แสดงลิงก์)
final legalLinksProvider = Provider<({String terms, String privacy})>((ref) => (terms: termsUrl, privacy: privacyUrl));

/// เปิดลิงก์ในเบราว์เซอร์ คืน false ถ้าเปิดไม่ได้
final openLinkProvider = Provider<Future<bool> Function(Uri)>(
    (ref) => (url) => launchUrl(url, mode: LaunchMode.externalApplication));

final socialAuthRepositoryProvider = Provider<SocialAuthRepository>(
    (ref) => SupabaseSocialAuthRepository(ref.watch(supabaseClientProvider).auth));

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
  final email = ref.watch(supabaseClientProvider).auth.currentUser?.email;
  // บัญชีจากบริการภายนอกบางบัญชีไม่มีอีเมล (เช่น Facebook ที่สมัครด้วยเบอร์โทร) และได้ค่าว่างมาแทน null
  return email == null || email.isEmpty ? null : email;
});

final signOutProvider = Provider<Future<void> Function()>((ref) => ref.watch(supabaseClientProvider).auth.signOut);

final voiceRecorderProvider = Provider<VoiceRecorder>((ref) {
  final recorder = MicRecorder();
  ref.onDispose(recorder.dispose);
  return recorder;
});

final photoPickerProvider = Provider<PhotoPicker>((ref) => DevicePhotoPicker());

/// ถอดเสียงเป็นข้อความในเครื่อง (ใช้ Gemma เสมอ ไม่ว่าจะเลือก AI ตัวไหนไว้บันทึก)
final transcriberProvider = Provider<Transcriber>((ref) => GemmaTranscriber(strings: ref.watch(stringsProvider)));
