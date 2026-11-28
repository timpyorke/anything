import 'dart:async';

import 'package:anything/domain/billing.dart';
import 'package:anything/domain/repositories/billing_repository.dart';

class FakeBillingRepository implements BillingRepository {
  @override
  bool isAvailable = true;

  final users = <String?>[];
  final bought = <Offer>[];
  var plans = <Offer>[(id: 'monthly', title: 'Member รายเดือน', price: '฿99.00', period: 'P1M')];

  /// ผลของการซื้อ: [PurchaseOutcome] หรือ error
  Object outcome = PurchaseOutcome.bought;
  /// ตั้งเพื่อค้างการซื้อไว้
  Completer<void>? gate;
  var active = false;
  var restorable = false;
  Uri? manage = Uri.parse('https://store.example/manage');

  @override
  Future<void> identify(String? userId) async => users.add(userId);

  @override
  Future<List<Offer>> offers() async => plans;

  @override
  Future<PurchaseOutcome> buy(Offer offer) async {
    bought.add(offer);
    await gate?.future;
    final result = outcome;
    if (result is! PurchaseOutcome) throw result;
    return result;
  }

  @override
  Future<bool> restore() async => restorable;

  @override
  Future<bool> isActive() async => active;

  @override
  Future<Uri?> managementUrl() async => manage;
}
