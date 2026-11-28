import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../app/language.dart';
import '../../app/providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../domain/billing.dart';
import '../../domain/usage.dart';
import '../settings/usage_section.dart';

part 'paywall_view_model.freezed.dart';

@freezed
abstract class PaywallState with _$PaywallState {
  const factory PaywallState({
    @Default(true) bool loading,
    @Default(false) bool member,
    PlanLimits? benefits,
    @Default(<Offer>[]) List<Offer> offers,
    @Default(false) bool busy, // กำลังซื้อหรือกู้การซื้อ
    String? message,
    @Default(false) bool failed, // [message] เป็นข้อผิดพลาด
  }) = _PaywallState;
}

/// เว้นช่วงก่อนถาม server ซ้ำหลังซื้อ (นานกว่าที่ server จำกัดความถี่)
final syncRetryDelayProvider = Provider<Duration>((ref) => const Duration(seconds: 6));

final paywallViewModelProvider = NotifierProvider.autoDispose<PaywallViewModel, PaywallState>(PaywallViewModel.new);

class PaywallViewModel extends Notifier<PaywallState> {
  @override
  PaywallState build() {
    ref.watch(currentUserIdProvider);
    Future.microtask(load);
    return const PaywallState();
  }

  // ผู้ใช้ปิดหน้าได้ระหว่างรอ: หลัง await เช็ก ref.mounted ก่อนแตะ state
  Future<void> load() async {
    if (!ref.mounted) return;
    final usage = ref.read(usageRepositoryProvider);
    final billing = ref.read(billingRepositoryProvider);
    final t = ref.read(stringsProvider);
    state = state.copyWith(loading: true, message: null, failed: false);
    try {
      var member = (await usage.mine()).member;
      final benefits = await usage.memberPlan();
      // สโตร์บอกว่าเป็นสมาชิกแต่ server ยังไม่รู้ (webhook ตกหล่น) → ให้ server ถามใหม่
      if (!member && billing.isAvailable && await _quietly(billing.isActive)) {
        member = await _quietly(usage.syncSubscription);
      }
      final offers = member || !billing.isAvailable ? const <Offer>[] : await billing.offers();
      if (ref.mounted) state = state.copyWith(loading: false, member: member, benefits: benefits, offers: offers);
    } catch (e) {
      if (ref.mounted) state = state.copyWith(loading: false, message: t.billingFailed(e), failed: true);
    }
  }

  static Future<bool> _quietly(Future<bool> Function() ask) async {
    try {
      return await ask();
    } catch (_) {
      return false;
    }
  }

  Future<void> buy(Offer offer) => _transaction((t) async {
        switch (await ref.read(billingRepositoryProvider).buy(offer)) {
          case PurchaseOutcome.bought:
            await _confirm();
          case PurchaseOutcome.pending:
            _show(t.purchasePending);
          case PurchaseOutcome.cancelled:
            break;
        }
      });

  Future<void> restore() => _transaction((t) async {
        if (await ref.read(billingRepositoryProvider).restore()) {
          await _confirm();
        } else {
          _show(t.nothingToRestore);
        }
      });

  /// หน้าจัดการการสมัครของสโตร์ (null = เปิดไม่ได้ จะตั้ง message)
  Future<Uri?> managementUrl() async {
    final t = ref.read(stringsProvider);
    try {
      final url = await ref.read(billingRepositoryProvider).managementUrl();
      if (url == null) _show(t.cannotOpenLink, failed: true);
      return url;
    } catch (e) {
      _show(t.billingFailed(e), failed: true);
      return null;
    }
  }

  void linkFailed() => _show(ref.read(stringsProvider).cannotOpenLink, failed: true);

  /// งานซื้อ/กู้ทำต่อจนจบแม้ปิดหน้า ผู้ใช้จ่ายเงินแล้วสิทธิ์ต้องถูกบันทึก
  Future<void> _transaction(Future<void> Function(AppStrings t) run) async {
    if (state.busy) return;
    final link = ref.keepAlive();
    final t = ref.read(stringsProvider);
    state = state.copyWith(busy: true, message: null, failed: false);
    try {
      await run(t);
    } catch (e) {
      _show(t.billingFailed(e), failed: true);
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
      link.close();
    }
  }

  /// ให้ server ยืนยันสิทธิ์กับ RevenueCat — ลองซ้ำเพราะรายการอาจยังไปไม่ถึง
  Future<void> _confirm() async {
    final usage = ref.read(usageRepositoryProvider);
    final delay = ref.read(syncRetryDelayProvider);
    final t = ref.read(stringsProvider);
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) await Future<void>.delayed(delay);
      if (await _quietly(usage.syncSubscription)) {
        if (!ref.mounted) return;
        ref.invalidate(usageProvider);
        state = state.copyWith(member: true, offers: const [], message: t.purchaseActivated, failed: false);
        return;
      }
    }
    _show(t.purchaseNotYetActive);
  }

  void _show(String message, {bool failed = false}) {
    if (ref.mounted) state = state.copyWith(message: message, failed: failed);
  }
}
