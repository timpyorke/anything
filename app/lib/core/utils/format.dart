import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';


final _numFmt = NumberFormat('#,##0.##');

String fmtNum(double v) => _numFmt.format(v);

/// ขนาดไฟล์แบบอ่านง่าย (1 KB = 1024 ไบต์ ตรงกับเพดานในฐานข้อมูล)
String fmtBytes(int bytes) {
  const mb = 1024 * 1024, gb = 1024 * mb;
  return bytes >= gb ? '${fmtNum(bytes / gb)} GB' : '${fmtNum(bytes / mb)} MB';
}

/// สีตัวอักษรบนพื้นสีของหมวด
Color onColor(Color c) => c.computeLuminance() > 0.45 ? Colors.black : Colors.white;
