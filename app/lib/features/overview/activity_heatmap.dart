import 'dart:math';
import 'package:flutter/material.dart';

import '../../core/utils/dates.dart';

class ActivityHeatmap extends StatefulWidget {
  const ActivityHeatmap({super.key, required this.year, required this.counts, required this.now, required this.onTapDay});
  final int year;
  final Map<DateTime, int> counts;
  final DateTime now;
  final void Function(DateTime) onTapDay;

  static const cell = 16.0, gap = 3.0, top = 20.0;

  /// ความกว้างคอลัมน์ชื่อวันด้านซ้าย (อยู่กับที่ ไม่เลื่อนตามปฏิทิน)
  static const labelWidth = 22.0;

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
      const step = ActivityHeatmap.cell + ActivityHeatmap.gap;
      _scroll.jumpTo(((x / step).floor() * step).clamp(0, _scroll.position.maxScrollExtent));
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
    final labelStyle = Theme.of(context).textTheme.labelSmall!.copyWith(color: scheme.onSurfaceVariant);
    Widget grid(double viewport) => SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      // เติมท้ายให้ระยะเลื่อนสุดลงตัวพอดีสัปดาห์ ขอบซ้ายจะไม่เห็นช่องถูกตัดครึ่ง
      padding: EdgeInsets.only(right: weeks * step > viewport ? (viewport - weeks * step) % step : 0),
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
              labelStyle: labelStyle,
              todayBorder: scheme.onSurface,
            ),
          ),
        ),
      ),
    );
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ExcludeSemantics(
        child: SizedBox(
          width: ActivityHeatmap.labelWidth,
          child: Column(children: [
            const SizedBox(height: ActivityHeatmap.top),
            // แถวเรียงจากอาทิตย์ แสดงเว้นแถวพอให้อ่านตำแหน่งได้
            for (final name in const ['', 'จ', '', 'พ', '', 'ศ', ''])
              SizedBox(
                height: step,
                child: Text(name, style: labelStyle.copyWith(height: 1.2), textScaler: TextScaler.noScaling),
              ),
          ]),
        ),
      ),
      Expanded(child: LayoutBuilder(builder: (context, box) => grid(box.maxWidth))),
    ]);
  }
}

/// อธิบายสัญลักษณ์ของปฏิทิน — ต้องตรงกับที่ [_HeatmapPainter] วาด
class HeatmapLegend extends StatelessWidget {
  const HeatmapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget item(String label, Color fill, [Color? border]) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(3),
              border: border == null ? null : Border.all(color: border),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: theme.textTheme.bodySmall)),
        ]);
    return Wrap(spacing: 16, runSpacing: 4, children: [
      item('มีบันทึก', scheme.primary),
      item('แผนล่วงหน้า', scheme.primary.withValues(alpha: 0.18), scheme.primary),
      item('วันนี้', scheme.surfaceContainerHighest, scheme.onSurface),
    ]);
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
    required this.labelStyle,
    required this.todayBorder,
  });
  final int year, offset, days;
  final Map<DateTime, int> counts;
  final DateTime now;
  final Color on, off, todayBorder;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const step = ActivityHeatmap.cell + ActivityHeatmap.gap;
    for (var m = 0; m < 12; m++) {
      final idx = daysBetween(DateTime.utc(year), DateTime.utc(year, m + 1)) + offset;
      final tp = TextPainter(
        text: TextSpan(text: thMonthsShort[m], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((idx ~/ 7) * step, 0));
    }
    for (var i = 0; i < days; i++) {
      final d = DateTime.utc(year).add(Duration(days: i));
      final idx = i + offset;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH((idx ~/ 7) * step, ActivityHeatmap.top + (idx % 7) * step, ActivityHeatmap.cell, ActivityHeatmap.cell),
        const Radius.circular(4),
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
  bool shouldRepaint(_HeatmapPainter old) =>
      old.year != year || old.counts != counts || old.now != now || old.on != on || old.labelStyle != labelStyle;
}
