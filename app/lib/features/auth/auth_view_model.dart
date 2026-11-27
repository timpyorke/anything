import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../app/language.dart';
import '../../app/providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../domain/repositories/social_auth_repository.dart';

part 'auth_view_model.freezed.dart';

@freezed
abstract class AuthFormState with _$AuthFormState {
  const factory AuthFormState({
    @Default(false) bool signUp,
    @Default(false) bool busy,

    /// ปุ่มบริการภายนอกที่กำลังรอผล (null = ไม่มี หรือกำลังใช้อีเมล)
    SocialProvider? signingInWith,
    String? error,
    String? info,
  }) = _AuthFormState;
}

/// ไม่ใช่ autoDispose: ล็อกอินสำเร็จแล้วหน้านี้ถูกแทนที่ระหว่างที่ submit ยังรออยู่ provider ต้องยังอยู่ให้ตั้ง state ได้
final authViewModelProvider = NotifierProvider<AuthViewModel, AuthFormState>(AuthViewModel.new);

class AuthViewModel extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  void toggleMode() => state = AuthFormState(signUp: !state.signUp);

  Future<void> submit(String rawEmail, String password) async {
    final t = ref.read(stringsProvider);
    final email = rawEmail.trim();
    if (!email.contains('@') || password.length < 8) {
      state = state.copyWith(error: t.credentialsRequired);
      return;
    }
    state = state.copyWith(busy: true, error: null, info: null);
    final auth = ref.read(supabaseClientProvider).auth;
    String? error, info;
    try {
      if (state.signUp) {
        final res = await auth.signUp(email: email, password: password);
        if (res.session == null) info = t.confirmationSent(email);
      } else {
        await auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException catch (e) {
      error = _message(t, e);
    } catch (e) {
      error = t.connectionFailed(e);
    }
    state = state.copyWith(busy: false, error: error, info: info);
  }

  Future<void> signInWith(SocialProvider provider) async {
    if (state.busy) return;
    final t = ref.read(stringsProvider);
    state = state.copyWith(busy: true, signingInWith: provider, error: null, info: null);
    String? error;
    try {
      await ref.read(socialAuthRepositoryProvider).signIn(provider);
    } on AuthException catch (e) {
      error = _message(t, e);
    } catch (e) {
      error = t.socialSignInFailed(provider.label, e);
    }
    state = state.copyWith(busy: false, signingInWith: null, error: error);
  }

  String _message(AppStrings t, AuthException e) {
    // error ที่ติดมากับ URL ตอนกลับจากหน้าเว็บ รหัสของ Supabase อยู่ใน statusCode ไม่ใช่ code
    if (e.code == 'signup_disabled' || e.statusCode == 'signup_disabled') return t.signupDisabled;
    if (e.statusCode == 'provider_email_needs_verification') return t.emailNotConfirmed;
    return switch (e.code) {
      'invalid_credentials' => t.invalidCredentials,
      'email_not_confirmed' => t.emailNotConfirmed,
      'user_already_exists' => t.userAlreadyExists,
      'weak_password' => t.weakPassword,
      _ => e.message,
    };
  }
}
