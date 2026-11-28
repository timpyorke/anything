import 'package:freezed_annotation/freezed_annotation.dart';

part 'usage.freezed.dart';

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
