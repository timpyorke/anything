import 'dart:convert';

import 'package:anything/ai/ai_settings.dart';
import 'package:anything/ai/llm_provider.dart';
import 'package:anything/ai/managed_provider.dart';
import 'package:anything/app/providers.dart';
import 'package:anything/features/assistant/assistant_page.dart';
import 'package:anything/features/settings/ai_settings_page.dart';
import 'package:anything/features/settings/local_model_page.dart';
import 'package:anything/features/settings/settings_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_diary_repository.dart';
import '../../support/fake_usage_repository.dart';

void main() {
  late int signOuts;
  late FakeUsageRepository usage;

  /// [provider] = AI ที่ผู้ใช้เลือกไว้ (null = ผู้ใช้ใหม่)
  Future<void> pump(WidgetTester tester, Widget home, {AiProviderKind? provider}) async {
    FlutterSecureStorage.setMockInitialValues({});
    signOuts = 0;
    usage = FakeUsageRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        diaryRepositoryProvider.overrideWithValue(FakeDiaryRepository()),
        usageRepositoryProvider.overrideWithValue(usage),
        currentUserIdProvider.overrideWithValue('user'),
        currentUserEmailProvider.overrideWithValue('name@example.com'),
        signOutProvider.overrideWithValue(() async => signOuts++),
        aiHttpClientProvider.overrideWithValue(MockClient((_) async => http.Response(jsonEncode({'models': []}), 200))),
      ],
      child: MaterialApp(home: home),
    ));
    if (provider != null) {
      final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      await container.read(aiSettingsProvider.notifier).setProvider(provider);
    }
    await tester.pumpAndSettle();
  }

  /// หน้าที่มีปุ่มเดียว กดแล้วขอ provider ที่พร้อมใช้ ผลเก็บไว้ใน [asked]
  late List<LlmProvider?> asked;
  Widget askButton() {
    asked = [];
    return Scaffold(
      body: Consumer(
        builder: (context, ref, _) => TextButton(
            onPressed: () async => asked.add(await ensureLlmProvider(Navigator.of(context), ref)), child: const Text('go')),
      ),
    );
  }

  testWidgets('the account is at the top and AI settings live on their own pages', (tester) async {
    await pump(tester, const SettingsPage(), provider: AiProviderKind.aiStudio);
    expect(
      tester.getTopLeft(find.text('name@example.com')).dy,
      lessThan(tester.getTopLeft(find.text('AI ที่ใช้บันทึก')).dy),
    );
    expect(find.text('Google AI Studio · ยังไม่ได้ใส่ API key'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('โมเดลในเครื่อง'));
    await tester.pumpAndSettle();
    expect(find.byType(LocalModelPage), findsOneWidget);
  });

  testWidgets('saving a key on the AI page confirms it and updates the summary', (tester) async {
    await pump(tester, const SettingsPage(), provider: AiProviderKind.aiStudio);
    await tester.tap(find.text('AI ที่ใช้บันทึก'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'k');
    await tester.tap(find.text('บันทึก key'));
    await tester.pumpAndSettle();
    expect(find.text('บันทึก API key แล้ว (เก็บในเครื่องเท่านั้น)'), findsOneWidget);
    expect(await const FlutterSecureStorage().read(key: aiKeyName(AiProviderKind.aiStudio, 'user')), 'k');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Google AI Studio'), findsOneWidget);
  });

  testWidgets('signing out asks first', (tester) async {
    await pump(tester, const SettingsPage());
    // อยู่ล่างสุด จออาจต้องเลื่อน
    await tester.scrollUntilVisible(find.text('ออกจากระบบ'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ออกจากระบบ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(signOuts, 0);

    await tester.tap(find.text('ออกจากระบบ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ออกจากระบบ'));
    await tester.pumpAndSettle();
    expect(signOuts, 1);
  });

  testWidgets('being asked to set up AI opens the AI page, with settings behind it', (tester) async {
    await pump(tester, askButton(), provider: AiProviderKind.aiStudio);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ไปตั้งค่า'));
    await tester.pumpAndSettle();
    expect(find.byType(AiSettingsPage), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'k');
    await tester.tap(find.text('บันทึก key'));
    await tester.pumpAndSettle();
    expect(find.text('บันทึก API key แล้ว (เก็บในเครื่องเท่านั้น)'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
  });

  testWidgets('a key typed for one service is not saved to another', (tester) async {
    await pump(tester, const AiSettingsPage(), provider: AiProviderKind.aiStudio);
    await tester.enterText(find.byType(TextField), 'google-key');
    // ช่อง key อยู่ใต้บริการที่เลือก บริการถัดๆ ไปจึงอาจต้องเลื่อนหา
    await tester.scrollUntilVisible(find.text('OpenAI'), 100, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OpenAI'));
    await tester.pumpAndSettle();
    expect(find.text('API key ของ OpenAI'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);

    await tester.enterText(find.byType(TextField), 'openai-key');
    await tester.scrollUntilVisible(find.text('บันทึก key'), 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('บันทึก key'));
    await tester.pumpAndSettle();
    const storage = FlutterSecureStorage();
    expect(await storage.read(key: aiKeyName(AiProviderKind.openAi, 'user')), 'openai-key');
    expect(await storage.read(key: aiKeyName(AiProviderKind.aiStudio, 'user')), isNull);
  });

  testWidgets('a new user is asked to agree before anything goes through the app’s AI', (tester) async {
    await pump(tester, askButton());
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Anthropic (Claude) หรือ Google (Gemini)'), findsOneWidget);
    await tester.tap(find.text('ไว้ก่อน'));
    await tester.pumpAndSettle();
    expect(asked, [null]);
    const storage = FlutterSecureStorage();
    expect(await storage.read(key: managedConsentName('user')), isNull);

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยินยอม'));
    await tester.pumpAndSettle();
    expect(asked.last, isA<ManagedProvider>());
    expect(await storage.read(key: managedConsentName('user')), 'true');

    // ยินยอมแล้วไม่ถามซ้ำ
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(asked, hasLength(3));
  });

  testWidgets('consent can be given and withdrawn on the AI page', (tester) async {
    await pump(tester, const AiSettingsPage());
    const storage = FlutterSecureStorage();
    await tester.tap(find.text('ยินยอม'));
    await tester.pumpAndSettle();
    expect(await storage.read(key: managedConsentName('user')), 'true');
    await tester.tap(find.text('ถอนความยินยอม'));
    await tester.pumpAndSettle();
    expect(await storage.read(key: managedConsentName('user')), isNull);
    expect(find.text('ยินยอม'), findsOneWidget);
  });

  testWidgets('settings show the plan and what is left of each quota', (tester) async {
    await pump(tester, const SettingsPage());
    expect(find.text('AI ของแอป · ยังไม่ได้ยินยอม'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('พื้นที่เก็บรูป'), 100);
    expect(find.text('แผน: Free'), findsOneWidget);
    expect(find.text('2 จาก 5'), findsOneWidget);
    expect(find.text('12 จาก 30'), findsOneWidget);
    expect(find.text('1.5 MB จาก 100 MB'), findsOneWidget);
  });

  testWidgets('usage that fails to load can be retried', (tester) async {
    await pump(tester, const Scaffold(body: SizedBox()));
    usage.failure = Exception('offline');
    Navigator.of(tester.element(find.byType(Scaffold)))
        .push(MaterialPageRoute<void>(builder: (_) => const AiSettingsPage()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('โหลดการใช้งานไม่ได้'), 100, scrollable: find.byType(Scrollable).first);
    usage.failure = null;
    await tester.tap(find.text('ลองใหม่'));
    await tester.pumpAndSettle();
    expect(find.text('2 จาก 5'), findsOneWidget);
  });
}
