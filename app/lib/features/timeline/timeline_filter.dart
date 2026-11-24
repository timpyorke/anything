import 'package:flutter/material.dart';


/// ตัวกรองของ Timeline — แชร์กับหน้าภาพรวม (คลิกวันใน heatmap / แถบหมวด)
class TimelineFilter extends ChangeNotifier {
  Set<String>? cats; // null = ทุกหมวด
  String query = '';
  DateTime? day;

  bool get active => cats != null || query.isNotEmpty || day != null;

  void set({Set<String>? cats, String? query, DateTime? day, bool clearDay = false, bool clearCats = false}) {
    if (cats != null || clearCats) this.cats = (cats == null || cats.isEmpty) ? null : cats;
    if (query != null) this.query = query;
    if (day != null || clearDay) this.day = day;
    notifyListeners();
  }

  void clear() {
    cats = null;
    query = '';
    day = null;
    notifyListeners();
  }
}
