import 'dart:convert';

import 'package:anything/data/supabase_social_auth_repository.dart';
import 'package:anything/domain/repositories/social_auth_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MemoryStorage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> removeItem({required String key}) async => values.remove(key);
  @override
  Future<void> setItem({required String key, required String value}) async => values[key] = value;
}

void main() {
  late List<http.Request> requests;
  late GoTrueClient auth;

  setUp(() {
    requests = [];
    auth = GoTrueClient(
      url: 'https://example.supabase.co/auth/v1',
      autoRefreshToken: false,
      asyncStorage: _MemoryStorage(),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'access_token': 'access',
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'refresh',
            'user': {
              'id': 'user',
              'aud': 'authenticated',
              'app_metadata': <String, dynamic>{},
              'user_metadata': <String, dynamic>{},
              'created_at': '2026-01-01T00:00:00Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });

  SupabaseSocialAuthRepository browserReturning(String callback, [void Function(Uri url)? onOpen]) =>
      SupabaseSocialAuthRepository(auth, openAuthPage: (url) async {
        onOpen?.call(Uri.parse(url));
        return callback;
      });

  test('the web flow asks Supabase to return to the app and exchanges the code for a session', () async {
    late Uri opened;
    await browserReturning('$authRedirectUrl?code=abc', (url) => opened = url).signIn(SocialProvider.google);

    expect(opened.path, '/auth/v1/authorize');
    expect(opened.queryParameters['provider'], 'google');
    expect(opened.queryParameters['redirect_to'], authRedirectUrl);
    expect(opened.queryParameters['prompt'], 'select_account');
    expect(opened.queryParameters['code_challenge'], isNotEmpty);
    expect(requests.single.url.queryParameters['grant_type'], 'pkce');
    expect(jsonDecode(requests.single.body)['auth_code'], 'abc');
    expect(auth.currentSession?.user.id, 'user');
  });

  test('closing the browser is not an error', () async {
    final repo = SupabaseSocialAuthRepository(auth,
        openAuthPage: (_) async => throw PlatformException(code: 'CANCELED'));
    await repo.signIn(SocialProvider.facebook);
    expect(requests, isEmpty);
    expect(auth.currentSession, isNull);
  });

  test('cancelling on the provider page is not an error', () async {
    for (final error in ['access_denied', 'user_cancelled_authorize']) {
      await browserReturning('$authRedirectUrl?error=$error&error_description=denied')
          .signIn(SocialProvider.facebook);
    }
    expect(requests, isEmpty);
  });

  test('a rejection from Supabase is reported with its error code', () async {
    const query = 'error=access_denied&error_code=signup_disabled&error_description=Signups+not+allowed';
    await expectLater(
      browserReturning('$authRedirectUrl?$query#$query').signIn(SocialProvider.google),
      throwsA(isA<AuthException>().having((e) => e.statusCode, 'statusCode', 'signup_disabled')),
    );
    expect(requests, isEmpty);
  });

  test('other browser failures are not swallowed', () async {
    final repo = SupabaseSocialAuthRepository(auth,
        openAuthPage: (_) async => throw PlatformException(code: 'NO_BROWSER'));
    await expectLater(repo.signIn(SocialProvider.google), throwsA(isA<PlatformException>()));
  });

  group('on iOS', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('Apple uses the system sheet, giving Apple the hashed nonce and Supabase the raw one', () async {
      late String hashed;
      final repo = SupabaseSocialAuthRepository(
        auth,
        openAuthPage: (_) async => fail('must not open a browser'),
        requestAppleIdToken: (nonce) async {
          hashed = nonce;
          return 'apple-token';
        },
      );
      await repo.signIn(SocialProvider.apple);

      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(requests.single.url.queryParameters['grant_type'], 'id_token');
      expect(body['provider'], 'apple');
      expect(body['id_token'], 'apple-token');
      expect(sha256.convert(utf8.encode(body['nonce'] as String)).toString(), hashed);
      expect(auth.currentSession?.user.id, 'user');
    });

    test('dismissing the Apple sheet does nothing', () async {
      await SupabaseSocialAuthRepository(auth, requestAppleIdToken: (_) async => null)
          .signIn(SocialProvider.apple);
      expect(requests, isEmpty);
    });

    test('Google still uses the web flow', () async {
      Uri? opened;
      await browserReturning('$authRedirectUrl?code=abc', (url) => opened = url).signIn(SocialProvider.google);
      expect(opened?.queryParameters['provider'], 'google');
    });
  });

  test('Apple on Android uses the web flow', () async {
    Uri? opened;
    await browserReturning('$authRedirectUrl?code=abc', (url) => opened = url).signIn(SocialProvider.apple);
    expect(opened?.queryParameters['provider'], 'apple');
    expect(opened?.queryParameters.containsKey('prompt'), isFalse);
  });
}
