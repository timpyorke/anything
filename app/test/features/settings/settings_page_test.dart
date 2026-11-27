import 'dart:convert';

import 'package:anything/ai/ai_settings.dart';
import 'package:anything/ai/llm_provider.dart';
import 'package:anything/app/providers.dart';
import 'package:anything/features/assistant/assistant_page.dart';
import 'package:anything/features/settings/ai_settings_page.dart';
import 'package:anything/features/settings/local_model_page.dart';
import 'package:anything/features/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/fake_diary_repository.dart';

void main() {
  late int signOuts;

  Future<void> pump(WidgetTester tester, Widget home) async {
    FlutterSecureStorage.setMockInitialValues({});
    signOuts = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        diaryRepositoryProvider.overrideWithValue(FakeDiaryRepository()),
        currentUserIdProvider.overrideWithValue('user'),
        currentUserEmailProvider.overrideWithValue('name@example.com'),
        signOutProvider.overrideWithValue(() async => signOuts++),
        aiHttpClientProvider.overrideWithValue(MockClient((_) async => http.Response(jsonEncode({'models': []}), 200))),
      ],
      child: MaterialApp(home: home),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the account is at the top and AI settings live on their own pages', (tester) async {
    await pump(tester, const SettingsPage());
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
    await pump(tester, const SettingsPage());
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
    await pump(
      tester,
      Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TextButton(onPressed: () => ensureLlmProvider(Navigator.of(context), ref), child: const Text('go')),
        ),
      ),
    );
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
    await pump(tester, const AiSettingsPage());
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
}
