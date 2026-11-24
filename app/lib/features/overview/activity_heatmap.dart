import 'dart:math';
import 'package:flutter/material.dart';

import '../../core/utils/dates.dart';

class ActivityHeatmap extends StatefulWidget {
  const ActivityHeatmap({super.key, required this.year, required this.counts, required this.now, required this.onTapDay});
  final int year;
  final Map<DateTime, int> counts;
  final DateTime now;
  final void Function(DateTime) onTapDay;

  static const cell = 13.0, gap = 3.0, top = 16.0;

  @override
  State<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends State<ActivityHeatmap> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // เลื่อนให้เห็นสัปดาห์ปัจจุบัน
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients || widget.year != widget.now.year) return;
      final week = (daysBetween(DateTime.utc(widget.year), widget.now) + _offset) ~/ 7;
      final x = week * (ActivityHeatmap.cell + ActivityHeatmap.gap) - _scroll.position.viewportDimension / 2;
      _scroll.jumpTo(x.clamp(0, _scroll.position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int get _offset => DateTime.utc(widget.year).weekday % 7; // อาทิตย์ = แถวแรก

  @override
  Widget build(BuildContext context) {
    const step = ActivityHeatmap.cell + ActivityHeatmap.gap;
    final days = daysBetween(DateTime.utc(widget.year), DateTime.utc(widget.year + 1));
    final weeks = ((days + _offset) / 7).ceil();
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      child: GestureDetector(
        onTapUp: (d) {
          final col = (d.localPosition.dx / step).floor(), row = ((d.localPosition.dy - ActivityHeatmap.top) / step).floor();
          if (row < 0 || row > 6) return;
          final i = col * 7 + row - _offset;
          if (i < 0 || i >= days) return;
          final day = DateTime.utc(widget.year).add(Duration(days: i));
          if ((widget.counts[day] ?? 0) > 0) widget.onTapDay(day);
        },
        child: Semantics(
          label: 'ปฏิทินกิจกรรมปี ${widget.year}: มีบันทึก ${widget.counts.length} วัน',
          child: CustomPaint(
            size: Size(weeks * step, ActivityHeatmap.top + 7 * step),
            painter: _HeatmapPainter(
              year: widget.year,
              counts: widget.counts,
              now: widget.now,
              offset: _offset,
              days: days,
              on: scheme.primary,
              off: scheme.surfaceContainerHighest,
              text: scheme.onSurfaceVariant,
              todayBorder: scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.year,
    required this.counts,
    required this.now,
    required this.offset,
    required this.days,
    required this.on,
    required this.off,
    required this.text,
    required this.todayBorder,
  });
  final int year, offset, days;
  final Map<DateTime, int> counts;
  final DateTime now;
  final Color on, off, text, todayBorder;

  @override
  void paint(Canvas canvas, Size size) {
    const step = ActivityHeatmap.cell + ActivityHeatmap.gap;
    for (var m = 0; m < 12; m++) {
      final idx = daysBetween(DateTime.utc(year), DateTime.utc(year, m + 1)) + offset;
      final tp = TextPainter(
        text: TextSpan(text: thMonthsShort[m], style: TextStyle(fontSize: 10, color: text)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((idx ~/ 7) * step, 0));
    }
    for (var i = 0; i < days; i++) {
      final d = DateTime.utc(year).add(Duration(days: i));
      final idx = i + offset;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH((idx ~/ 7) * step, ActivityHeatmap.top + (idx % 7) * step, ActivityHeatmap.cell, ActivityHeatmap.cell),
        const Radius.circular(3),
      );
      final n = counts[d] ?? 0;
      final future = d.isAfter(now);
      final paint = Paint()
        ..color = n == 0 ? off : on.withValues(alpha: future ? 0.18 : [0.4, 0.6, 0.8, 1.0][min(n, 4) - 1]);
      canvas.drawRRect(rect, paint);
      if (n > 0 && future) {
        canvas.drawRRect(rect, Paint()
          ..style = PaintingStyle.stroke
          ..color = on
          ..strokeWidth = 1);
      }
      if (d == now) {
        canvas.drawRRect(rect, Paint()
          ..style = PaintingStyle.stroke
          ..color = todayBorder
          ..strokeWidth = 1.5);
      }
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) => old.year != year || old.counts != counts || old.on != on;
}
