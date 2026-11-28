import 'package:freezed_annotation/freezed_annotation.dart';

part 'usage.freezed.dart';

/// เพดานของแผนหนึ่ง (ตัวเลขอยู่ในฐานข้อมูล แก้ได้โดยไม่ต้องออกแอปใหม่)
typedef PlanLimits = ({int aiPerDay, int aiPerMonth, int storageBytes});

/// ใช้ไปเท่าไรจากเพดาน (จำนวนครั้ง หรือไบต์)
typedef Quota = ({int used, int limit});

/// การใช้งานของบัญชีนี้ตามแผน — ฐานข้อมูลเป็นคนนับและบังคับ แอปแค่แสดง
@freezed
abstract class UsageSummary with _$UsageSummary {
  const factory UsageSummary({
    required bool member,
    required Quota aiToday,
    required Quota aiMonth,
    required Quota storage,
  }) = _UsageSummary;
}
