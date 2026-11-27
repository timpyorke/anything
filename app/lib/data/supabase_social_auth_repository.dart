import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/repositories/social_auth_repository.dart';

/// scheme ที่หน้าเว็บล็อกอินใช้ส่งผลกลับเข้าแอป — ต้องตรงกับ CallbackActivity ใน AndroidManifest.xml
const authCallbackScheme = 'com.codenour.anything';

/// ต้องเพิ่มใน Supabase → Authentication → URL Configuration → Redirect URLs
const authRedirectUrl = '$authCallbackScheme://login-callback';

/// เปิดหน้าเว็บล็อกอินแล้วคืน URL ที่ถูกส่งกลับมา — โยน PlatformException(code: 'CANCELED') ถ้าผู้ใช้ปิดเอง
typedef OpenAuthPage = Future<String> Function(String url);

/// ขอ identity token จากหน้าต่างของ iOS — คืน null ถ้าผู้ใช้กดยกเลิก
typedef RequestAppleIdToken = Future<String?> Function(String hashedNonce);

/// Apple บน iOS ใช้หน้าต่างของระบบ (Face ID) ที่เหลือใช้หน้าเว็บของผู้ให้บริการผ่าน Supabase (PKCE)
class SupabaseSocialAuthRepository implements SocialAuthRepository {
  SupabaseSocialAuthRepository(
    this._auth, {
    this._openAuthPage = _openInBrowser,
    this._requestAppleIdToken = _askApple,
  });

  final GoTrueClient _auth;
  final OpenAuthPage _openAuthPage;
  final RequestAppleIdToken _requestAppleIdToken;

  @override
  Future<void> signIn(SocialProvider provider) =>
      provider == SocialProvider.apple && defaultTargetPlatform == TargetPlatform.iOS
          ? _signInWithAppleNative()
          : _signInOnWeb(provider);

  Future<void> _signInWithAppleNative() async {
    // Apple ได้ nonce แบบ hash ส่วน Supabase ได้ค่าจริงไว้เทียบ — กันการนำ token เก่ามาใช้ซ้ำ
    final nonce = _auth.generateRawNonce();
    final idToken = await _requestAppleIdToken(sha256.convert(utf8.encode(nonce)).toString());
    if (idToken == null) return;
    await _auth.signInWithIdToken(provider: OAuthProvider.apple, idToken: idToken, nonce: nonce);
  }

  Future<void> _signInOnWeb(SocialProvider provider) async {
    final request = await _auth.getOAuthSignInUrl(
      provider: switch (provider) {
        SocialProvider.google => OAuthProvider.google,
        SocialProvider.apple => OAuthProvider.apple,
        SocialProvider.facebook => OAuthProvider.facebook,
      },
      redirectTo: authRedirectUrl,
      // ออกจากระบบแล้วเข้าใหม่ต้องเลือกบัญชี Google ได้ ไม่ใช่เข้าบัญชีเดิมทันที
      queryParams: provider == SocialProvider.google ? {'prompt': 'select_account'} : null,
    );
    final String result;
    try {
      result = await _openAuthPage(request.url);
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') return;
      rethrow;
    }
    final callback = Uri.parse(result);
    if (_cancelledAtProvider(callback)) return;
    await _auth.getSessionFromUrl(callback); // URL ที่มี error จะกลายเป็น AuthException
  }

  /// กด "ยกเลิก" ในหน้าของผู้ให้บริการ — ถ้ามี error_code แปลว่า Supabase ปฏิเสธเอง (เช่น ปิดรับสมัคร) ต้องแจ้งผู้ใช้
  static bool _cancelledAtProvider(Uri callback) {
    final params = {...Uri.splitQueryString(callback.fragment), ...callback.queryParameters};
    return const {'access_denied', 'user_cancelled_authorize'}.contains(params['error']) &&
        params['error_code'] == null;
  }

  static Future<String> _openInBrowser(String url) =>
      FlutterWebAuth2.authenticate(url: url, callbackUrlScheme: authCallbackScheme);

  static Future<String?> _askApple(String hashedNonce) async {
    try {
      // ขอแค่อีเมล แอปไม่ได้ใช้ชื่อ
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email],
        nonce: hashedNonce,
      );
      final token = credential.identityToken;
      if (token == null) throw const AuthException('Apple did not return an identity token');
      return token;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }
}
