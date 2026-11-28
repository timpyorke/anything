import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../domain/billing.dart';
import '../domain/repositories/billing_repository.dart';

/// การซื้อผ่าน RevenueCat — ส่งไปแค่ id บัญชี (UUID) ไม่ตั้งอีเมล ชื่อ หรือ attribute อื่น
class RevenueCatBillingRepository implements BillingRepository {
  RevenueCatBillingRepository({required this.apiKey, this.entitlement = 'pro'});

  /// public SDK key ของแพลตฟอร์มนี้ (ว่าง = ไม่ขาย)
  final String apiKey;

  /// ต้องตรงกับ REVENUECAT_ENTITLEMENT ของ Edge Function
  final String entitlement;

  String? _wanted, _current;
  Future<void> _queue = Future.value();
  final _packages = <String, Package>{};

  @override
  bool get isAvailable => apiKey.isNotEmpty;

  @override
  Future<void> identify(String? userId) {
    _wanted = userId;
    return _apply();
  }

  // ทำทีละคำสั่ง: สลับบัญชีเร็วๆ ต้องจบที่บัญชีล่าสุด
  Future<void> _apply() => _queue = _queue.catchError((_) {}).then((_) async {
        final target = _wanted;
        if (!isAvailable || target == _current) return;
        if (!await Purchases.isConfigured) {
          if (target != null) await Purchases.configure(PurchasesConfiguration(apiKey)..appUserID = target);
        } else if (target != null) {
          await Purchases.logIn(target);
        } else if (!await Purchases.isAnonymous) {
          await Purchases.logOut();
        }
        _packages.clear();
        _current = target;
      });

  /// รัน [action] เมื่อ SDK ผูกกับบัญชีปัจจุบันแล้ว (ครั้งก่อนพังจะลองผูกใหม่) กันการซื้อไปเข้าบัญชีอื่น
  Future<T> _signedIn<T>(Future<T> Function() action) async {
    try {
      await _apply();
      if (_current == null || _current != _wanted) throw BillingException('not signed in');
      return await action();
    } on PlatformException catch (e) {
      throw BillingException(e.message ?? e.code);
    }
  }

  @override
  Future<List<Offer>> offers() => _signedIn(() async {
        final packages = (await Purchases.getOfferings()).current?.availablePackages ?? const <Package>[];
        _packages
          ..clear()
          ..addEntries([for (final p in packages) MapEntry(p.identifier, p)]);
        return [
          for (final p in packages)
            (
              id: p.identifier,
              title: p.storeProduct.title,
              price: p.storeProduct.priceString,
              period: p.storeProduct.subscriptionPeriod,
            ),
        ];
      });

  @override
  Future<PurchaseOutcome> buy(Offer offer) => _signedIn(() async {
        final package = _packages[offer.id];
        if (package == null) throw BillingException('unknown offer ${offer.id}');
        try {
          await Purchases.purchase(PurchaseParams.package(package));
          return PurchaseOutcome.bought;
        } on PlatformException catch (e) {
          return switch (PurchasesErrorHelper.getErrorCode(e)) {
            PurchasesErrorCode.purchaseCancelledError => PurchaseOutcome.cancelled,
            PurchasesErrorCode.paymentPendingError => PurchaseOutcome.pending,
            _ => throw e,
          };
        }
      });

  bool _active(CustomerInfo info) => info.entitlements.active.containsKey(entitlement);

  @override
  Future<bool> restore() => _signedIn(() async => _active(await Purchases.restorePurchases()));

  @override
  Future<bool> isActive() => _signedIn(() async => _active(await Purchases.getCustomerInfo()));

  @override
  Future<Uri?> managementUrl() => _signedIn(() async {
        final url = (await Purchases.getCustomerInfo()).managementURL;
        return url == null ? null : Uri.tryParse(url);
      });
}
