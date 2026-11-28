import 'dart:async';
import 'dart:typed_data';

import 'package:anything/ai/ai_settings.dart';
import 'package:anything/ai/llm_provider.dart';
import 'package:anything/app/providers.dart';
import 'package:anything/features/assistant/anything_button.dart';
import 'package:anything/features/assistant/assistant_page.dart';
import 'package:anything/features/settings/ai_settings_page.dart';
import 'package:anything/features/subscription/paywall_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_billing_repository.dart';
import '../../support/fake_diary_repository.dart';
import '../../support/fake_usage_repository.dart';

class _Llm implements LlmProvider {
  final reply = Completer<String>();
  var cancelled = false;
  @override
  AiProviderKind get kind => AiProviderKind.onDevice;
  @override
  String get model => 'fake';
  @override
  Future<String> generateJson({required String system, required String user, List<Uint8List> images = const [], Future<void>? cancel}) {
    cancel?.then((_) => cancelled = true);
    return reply.future;
  }
}

class _Ai extends AiSettingsViewModel {
  _Ai(this.llm);
  final LlmProvider llm;
  @override
  AiSettingsState build() => const AiSettingsState();
  @override
  Future<LlmProvider?> resolveProvider() async => llm;
}

void main() {
  late _Llm llm;

  /// เดินเวลาแทน pumpAndSettle เพราะวงโหลดหมุนไม่หยุด
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openSheet(WidgetTester tester) async {
    llm = _Llm();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        diaryRepositoryProvider.overrideWithValue(FakeDiaryRepository()),
        usageRepositoryProvider.overrideWithValue(FakeUsageRepository()),
        billingRepositoryProvider.overrideWithValue(FakeBillingRepository()),
        currentUserIdProvider.overrideWithValue('user'),
        aiSettingsProvider.overrideWith(() => _Ai(llm)),
      ],
      child: const MaterialApp(home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: AnythingButton()))),
    ));
    await tester.enterText(find.byType(TextField), 'ไปวิ่งมา');
    await tester.pump();
    await tester.tap(find.byTooltip('ส่ง'));
    await settle(tester);
    expect(find.text('AI กำลังคิด…'), findsOneWidget);
  }

  testWidgets('tapping outside, swiping and back do not close the sheet while thinking', (tester) async {
    await openSheet(tester);
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);
    expect(find.byType(TurnView), findsOneWidget);
    await tester.fling(find.byType(TurnView), const Offset(0, 500), 2000);
    await settle(tester);
    expect(find.byType(TurnView), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(TurnView), findsOneWidget);
    expect(llm.cancelled, isFalse);
  });

  testWidgets('the cancel button closes the sheet and cancels the request', (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('ยกเลิก'));
    await settle(tester);
    expect(find.byType(TurnView), findsNothing);
    expect(llm.cancelled, isTrue);
  });

  testWidgets('tapping outside closes the sheet once the AI has answered', (tester) async {
    await openSheet(tester);
    llm.reply.complete('{"reply":"รับทราบ","actions":[]}');
    await settle(tester);
    expect(find.text('ยกเลิก'), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);
    expect(find.byType(TurnView), findsNothing);
  });

  testWidgets('a full quota offers another AI as well as retrying', (tester) async {
    await openSheet(tester);
    llm.reply.completeError(AiQuotaException('ครบโควตา'));
    await settle(tester);
    expect(find.text('ครบโควตา'), findsOneWidget);
    expect(find.text('ลองใหม่'), findsOneWidget);
    await tester.tap(find.text('ใช้ AI อื่น'));
    await settle(tester);
    expect(find.byType(AiSettingsPage), findsOneWidget);
  });

  testWidgets('other failures only offer retrying', (tester) async {
    await openSheet(tester);
    llm.reply.completeError(LlmException('ล่ม'));
    await settle(tester);
    expect(find.text('ลองใหม่'), findsOneWidget);
    expect(find.text('ใช้ AI อื่น'), findsNothing);
    expect(find.text('สมัคร Member'), findsNothing);
  });

  testWidgets('a quota that subscribing would raise offers the membership', (tester) async {
    await openSheet(tester);
    llm.reply.completeError(AiQuotaException('ครบโควตา', upgradable: true));
    await settle(tester);
    await tester.tap(find.text('สมัคร Member'));
    await settle(tester);
    expect(find.byType(PaywallPage), findsOneWidget);
  });
}
