import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../app/language.dart';
import '../../app/providers.dart';

part 'auth_view_model.freezed.dart';

@freezed
abstract class AuthFormState with _$AuthFormState {
  const factory AuthFormState({
    @Default(false) bool signUp,
    @Default(false) bool busy,
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
      error = switch (e.code) {
        'invalid_credentials' => t.invalidCredentials,
        'email_not_confirmed' => t.emailNotConfirmed,
        'user_already_exists' => t.userAlreadyExists,
        'weak_password' => t.weakPassword,
        _ => e.message,
      };
    } catch (e) {
      error = t.connectionFailed(e);
    }
    state = state.copyWith(busy: false, error: error, info: info);
  }
}
