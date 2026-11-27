import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';


final _numFmt = NumberFormat('#,##0.##');

String fmtNum(double v) => _numFmt.format(v);

/// สีตัวอักษรบนพื้นสีของหมวด
Color onColor(Color c) => c.computeLuminance() > 0.45 ? Colors.black : Colors.white;
