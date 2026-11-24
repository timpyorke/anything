import 'package:flutter/material.dart';


const _seriesColors = [
  Color(0xff2f62e0), Color(0xff17825a), Color(0xffb05a0c), Color(0xff7c3aed),
  Color(0xffc0306a), Color(0xff3a7682), Color(0xff846400), Color(0xffc0392b),
];

/// สีผูกกับชื่อ metric — เพิ่ม metric ใหม่แล้วสีเดิมไม่เปลี่ยน
Color seriesColor(String key) => _seriesColors[key.codeUnits.fold(7, (a, c) => (a * 31 + c) & 0x7fffffff) % _seriesColors.length];
