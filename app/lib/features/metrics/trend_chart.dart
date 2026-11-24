import 'dart:math';
import 'package:flutter/material.dart';

import '../../core/utils/dates.dart';
import '../../core/utils/format.dart';

class TrendLinePainter extends CustomPainter {
  TrendLinePainter({required this.pts, required this.color, required this.grid, required this.text});
  final List<(DateTime, double, String)> pts;
  final Color color, grid, text;

  @override
  void paint(Canvas canvas, Size size) {
    const l = 44.0, r = 8.0, t = 8.0, b = 22.0;
    final xs = pts.map((p) => p.$1.millisecondsSinceEpoch.toDouble()).toList();
    final ys = pts.map((p) => p.$2).toList();
    var x0 = xs.reduce(min), x1 = xs.reduce(max), y0 = ys.reduce(min), y1 = ys.reduce(max);
    if (x0 == x1) {
      x0 -= 864e5;
      x1 += 864e5;
    }
    if (y0 == y1) {
      y0 -= 1;
      y1 += 1;
    }
    final pad = (y1 - y0) * 0.12;
    y0 -= pad;
    y1 += pad;
    double px(double x) => l + (x - x0) / (x1 - x0) * (size.width - l - r);
    double py(double y) => t + (1 - (y - y0) / (y1 - y0)) * (size.height - t - b);

    void label(String s, Offset o, {TextAlign align = TextAlign.left}) {
      final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(fontSize: 10, color: text)), textDirection: TextDirection.ltr)
        ..layout();
      final dx = switch (align) { TextAlign.right => o.dx - tp.width, _ => o.dx };
      tp.paint(canvas, Offset(dx, o.dy - tp.height / 2));
    }

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final v = y0 + (y1 - y0) * f, y = py(v);
      canvas.drawLine(Offset(l, y), Offset(size.width - r, y), gridPaint);
      label(fmtNum(double.parse(v.toStringAsFixed(1))), Offset(l - 6, y), align: TextAlign.right);
    }
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final o = Offset(px(xs[i]), py(ys[i]));
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    if (pts.length > 1) {
      final area = Path.from(path)
        ..lineTo(px(xs.last), size.height - b)
        ..lineTo(px(xs.first), size.height - b)
        ..close();
      canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.08));
    }
    canvas.drawPath(path, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    for (var i = 0; i < pts.length; i++) {
      canvas.drawCircle(Offset(px(xs[i]), py(ys[i])), 3.5, Paint()..color = color);
    }
    label(fmtDate(pts.first.$1), Offset(l, size.height - 8));
    label(fmtDate(pts.last.$1), Offset(size.width - r, size.height - 8), align: TextAlign.right);
  }

  @override
  bool shouldRepaint(TrendLinePainter old) => old.pts != pts || old.color != color;
}
