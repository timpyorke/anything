import 'package:flutter/material.dart';


const _seriesColors = [
  Color(0xff3e63dd), Color(0xff30a46c), Color(0xfff76b15), Color(0xff8e4ec6),
  Color(0xffd6409f), Color(0xff12a594), Color(0xffb7791f), Color(0xffe5484d),
];

/// สีผูกกับชื่อ metric — เพิ่ม metric ใหม่แล้วสีเดิมไม่เปลี่ยน
Color seriesColor(String key) => _seriesColors[key.codeUnits.fold(7, (a, c) => (a * 31 + c) & 0x7fffffff) % _seriesColors.length];
