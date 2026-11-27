import 'dart:async';

import 'package:anything/app/providers.dart';
import 'package:anything/domain/repositories/social_auth_repository.dart';
import 'package:anything/features/auth/auth_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

class _FakeSocialAuth implements SocialAuthRepository {
  final calls = <SocialProvider>[];
  Completer<void> result = Completer();

  @override
  Future<void> signIn(SocialProvider provider) {
    calls.add(provider);
    return result.future;
  }
}

void main() {
  late _FakeSocialAuth social;

  Future<void> pump(WidgetTester tester) async {
    social = _FakeSocialAuth();
    await tester.pumpWidget(ProviderScope(
      overrides: [socialAuthRepositoryProvider.overrideWithValue(social)],
      child: const MaterialApp(home: AuthPage()),
    ));
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pump();
    await tester.tap(find.text(label));
    await tester.pump();
  }

  testWidgets('offers Google, Apple and Facebook', (tester) async {
    await pump(tester);
    for (final provider in SocialProvider.values) {
      expect(find.text('ดำเนินการต่อด้วย ${provider.label}'), findsOneWidget);
    }
  });

  testWidgets('waiting on one provider locks every button until it finishes', (tester) async {
    await pump(tester);
    await tapButton(tester, 'ดำเนินการต่อด้วย Facebook');

    expect(social.calls, [SocialProvider.facebook]);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    for (final button in tester.widgetList<OutlinedButton>(find.byType(OutlinedButton))) {
      expect(button.onPressed, isNull);
    }

    social.result.complete(); // ผู้ใช้ยกเลิก
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
  });

  testWidgets('explains why a sign-in failed', (tester) async {
    await pump(tester);
    await tapButton(tester, 'ดำเนินการต่อด้วย Google');
    social.result.completeError(
        const AuthException('Signups not allowed', code: 'access_denied', statusCode: 'signup_disabled'));
    await tester.pumpAndSettle();
    expect(find.text('ปิดรับสมัครบัญชีใหม่ — ใช้บัญชีที่มีอยู่แล้ว'), findsOneWidget);

    social.result = Completer();
    await tapButton(tester, 'ดำเนินการต่อด้วย Apple');
    expect(find.byIcon(Icons.error_outline), findsNothing);
    social.result.completeError(StateError('boom'));
    await tester.pumpAndSettle();
    expect(find.textContaining('เข้าสู่ระบบด้วย Apple ไม่สำเร็จ'), findsOneWidget);
  });
}
