import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../ai/ai_settings.dart';
import '../../app/language.dart';
import '../../app/providers.dart';

part 'delete_account_view_model.freezed.dart';

@freezed
abstract class DeleteAccountState with _$DeleteAccountState {
  const factory DeleteAccountState({
    @Default(false) bool member, // ต้องเตือนเรื่องการสมัครที่ยังเก็บเงิน
    @Default(false) bool agreed,
    @Default(false) bool busy,
    @Default(false) bool deleted, // View ฟังแล้วกลับหน้าแรก
    String? error,
  }) = _DeleteAccountState;
}

final deleteAccountViewModelProvider =
    NotifierProvider.autoDispose<DeleteAccountViewModel, DeleteAccountState>(DeleteAccountViewModel.new);

class DeleteAccountViewModel extends Notifier<DeleteAccountState> {
  @override
  DeleteAccountState build() {
    Future.microtask(_checkMembership);
    return const DeleteAccountState();
  }

  /// เป็นสมาชิกตาม server หรือตามสโตร์ ก็ต้องเตือน (ถามไม่ได้ไม่ขวางการลบ)
  Future<void> _checkMembership() async {
    if (!ref.mounted) return;
    final usage = ref.read(usageRepositoryProvider);
    final billing = ref.read(billingRepositoryProvider);
    for (final ask in [
      () async => (await usage.mine()).member,
      () async => billing.isAvailable && await billing.isActive(),
    ]) {
      try {
        if (await ask()) {
          if (ref.mounted) state = state.copyWith(member: true);
          return;
        }
      } catch (_) {}
    }
  }

  void setAgreed(bool value) => state = state.copyWith(agreed: value);

  /// หน้ายกเลิกการสมัครของสโตร์
  Future<Uri> subscriptionsUrl() async {
    final billing = ref.read(billingRepositoryProvider);
    final fallback = Uri.parse(defaultTargetPlatform == TargetPlatform.iOS
        ? 'https://apps.apple.com/account/subscriptions'
        : 'https://play.google.com/store/account/subscriptions');
    try {
      return (billing.isAvailable ? await billing.managementUrl() : null) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> delete() async {
    if (!state.agreed || state.busy) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    // งานทำต่อจนจบแม้หน้าถูกปิด
    final link = ref.keepAlive();
    final accounts = ref.read(accountRepositoryProvider);
    final ai = ref.read(aiSettingsProvider.notifier);
    final signOut = ref.read(signOutProvider);
    final t = ref.read(stringsProvider);
    state = state.copyWith(busy: true, error: null);
    try {
      await accounts.delete();
    } catch (e) {
      if (ref.mounted) state = state.copyWith(busy: false, error: t.deleteAccountFailed(e));
      link.close();
      return;
    }
    // บัญชีถูกลบแล้ว ขั้นเก็บกวาดในเครื่องพังก็ยังต้องออกจากระบบ
    try {
      await ai.forgetAccount(userId);
    } catch (_) {}
    if (ref.mounted) state = state.copyWith(deleted: true);
    try {
      await signOut();
    } catch (_) {}
    link.close();
  }
}
