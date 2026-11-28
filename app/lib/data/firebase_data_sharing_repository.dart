import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../domain/repositories/data_sharing_repository.dart';

/// Crashlytics, Analytics และ Cloud Messaging
///
/// ค่าเชื่อมต่อมาจาก google-services.json / GoogleService-Info.plist
/// การเก็บข้อมูลปิดไว้ใน AndroidManifest.xml และ Info.plist จนกว่าผู้ใช้จะเปิด
/// ห้ามส่งเนื้อหาของผู้ใช้ id บัญชี หรืออีเมล ไปที่ Firebase
class FirebaseDataSharingRepository implements DataSharingRepository {
  FirebaseDataSharingRepository._();

  static Future<DataSharingRepository> initialize() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('ไม่ได้ใช้ Firebase: $e');
      return const NoDataSharingRepository();
    }
    return FirebaseDataSharingRepository._().._catchErrors();
  }

  bool _reportCrashes = false;
  StreamSubscription<String>? _registrations;

  FirebaseCrashlytics get _crashlytics => FirebaseCrashlytics.instance;
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  bool get isAvailable => true;

  void _catchErrors() {
    final onFlutterError = FlutterError.onError;
    FlutterError.onError = (details) {
      onFlutterError?.call(details);
      if (!details.silent) _record(details.exception, details.stack, fatal: false);
    };
    final onPlatformError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      _record(error, stack, fatal: true);
      return onPlatformError?.call(error, stack) ?? false;
    };
  }

  /// ส่งเฉพาะชนิดของ error กับ stack trace — ข้อความของ error อาจมีเนื้อหาบันทึกติดมา
  /// (เช่น JSON ที่ AI ตอบ หรือแถวข้อมูลที่ฐานข้อมูลแจ้งว่าผิด)
  void _record(Object error, StackTrace? stack, {required bool fatal}) {
    if (!_reportCrashes) return;
    _crashlytics.recordError('${error.runtimeType}', stack, fatal: fatal, printDetails: false).ignore();
  }

  @override
  Future<Set<DataSharing>> restore(Set<DataSharing> enabled) async {
    final active = {...enabled};
    await _setCrashReports(enabled.contains(DataSharing.crashReports));
    await _setAnalytics(enabled.contains(DataSharing.analytics));
    final notify = enabled.contains(DataSharing.notifications) &&
        _allowed(await _messaging.getNotificationSettings());
    if (notify) {
      await _startNotifications();
    } else {
      active.remove(DataSharing.notifications);
      await _messaging.setAutoInitEnabled(false);
    }
    return active;
  }

  @override
  Future<bool> setEnabled(DataSharing kind, bool enabled) async {
    switch (kind) {
      case DataSharing.crashReports:
        // รายงานที่ค้างในเครื่องเกิดตอนยังไม่ได้อนุญาต จึงทิ้งก่อนเปิด
        if (enabled) await _crashlytics.deleteUnsentReports();
        await _setCrashReports(enabled);
      case DataSharing.analytics:
        await _setAnalytics(enabled);
        if (!enabled) await FirebaseAnalytics.instance.resetAnalyticsData();
      case DataSharing.notifications:
        if (enabled) {
          if (!_allowed(await _messaging.requestPermission())) return false;
          await _startNotifications();
        } else {
          await _messaging.setAutoInitEnabled(false);
          try {
            await _messaging.unregister();
          } catch (e) {
            // ออฟไลน์ หรือยังไม่เคยลงทะเบียนได้ — ปิดการลงทะเบียนอัตโนมัติแล้ว
            debugPrint('ยกเลิกการลงทะเบียน FCM ไม่ได้: $e');
          }
        }
    }
    return true;
  }

  Future<void> _setCrashReports(bool enabled) async {
    _reportCrashes = enabled;
    // การปิดมีผลกับ crash ฝั่ง native ตั้งแต่เปิดแอปครั้งถัดไป
    await _crashlytics.setCrashlyticsCollectionEnabled(enabled);
    if (!enabled) await _crashlytics.deleteUnsentReports();
  }

  Future<void> _setAnalytics(bool enabled) async {
    final analytics = FirebaseAnalytics.instance;
    await analytics.setConsent(
      analyticsStorageConsentGranted: enabled,
      adStorageConsentGranted: false,
      adUserDataConsentGranted: false,
      adPersonalizationSignalsConsentGranted: false,
    );
    await analytics.setAnalyticsCollectionEnabled(enabled);
  }

  bool _allowed(NotificationSettings settings) => switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized || AuthorizationStatus.provisional => true,
        _ => false,
      };

  Future<void> _startNotifications() async {
    await _messaging.setAutoInitEnabled(true);
    // iOS: ให้การแจ้งเตือนขึ้นแม้เปิดแอปอยู่
    await _messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    // id ของเครื่องใช้ส่งข้อความทดสอบจาก Firebase console (พิมพ์เฉพาะ debug build)
    if (kDebugMode) {
      _registrations ??= _messaging.onRegistered.listen((id) => debugPrint('FCM installation id: $id'));
    }
    // ไม่รอ: การลงทะเบียนต้องใช้เน็ต (และ APNs บน iOS) ไม่ควรหน่วงการเปิดแอป
    unawaited(_messaging.register().catchError((Object e) => debugPrint('ลงทะเบียน FCM ไม่ได้: $e')));
  }
}
