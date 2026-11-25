import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

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
    final email = rawEmail.trim();
    if (!email.contains('@') || password.length < 8) {
      state = state.copyWith(error: 'ใส่อีเมล และรหัสผ่านอย่างน้อย 8 ตัวอักษร');
      return;
    }
    state = state.copyWith(busy: true, error: null, info: null);
    final auth = ref.read(supabaseClientProvider).auth;
    String? error, info;
    try {
      if (state.signUp) {
        final res = await auth.signUp(email: email, password: password);
        if (res.session == null) info = 'ส่งอีเมลยืนยันไปที่ $email แล้ว — ยืนยันแล้วกลับมาเข้าสู่ระบบ';
      } else {
        await auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException catch (e) {
      error = switch (e.code) {
        'invalid_credentials' => 'อีเมลหรือรหัสผ่านไม่ถูกต้อง',
        'email_not_confirmed' => 'ยังไม่ได้ยืนยันอีเมล — ตรวจกล่องจดหมาย',
        'user_already_exists' => 'อีเมลนี้มีบัญชีแล้ว — เข้าสู่ระบบแทน',
        'weak_password' => 'รหัสผ่านง่ายเกินไป',
        _ => e.message,
      };
    } catch (e) {
      error = 'เชื่อมต่อไม่ได้: $e';
    }
    state = state.copyWith(busy: false, error: error, info: info);
  }
}
