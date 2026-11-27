import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

class SwipeAction {
  const SwipeAction({required this.label, required this.icon, required this.background, required this.foreground, required this.onPressed});
  final String label;
  final IconData icon;
  final Color background, foreground;
  final VoidCallback onPressed;
}

/// ปัดซ้ายเพื่อเผยปุ่มด้านขวา — ปัดอย่างเดียวไม่ทำอะไร ต้องแตะปุ่มอีกครั้ง
/// แตะที่อื่น (รวมถึงเริ่มปัดแถวอื่น) จะปิดเอง จึงเปิดค้างได้ทีละแถว
class SwipeActions extends StatefulWidget {
  const SwipeActions({super.key, required this.actions, required this.child});
  static const actionWidth = 80.0;

  final List<SwipeAction> actions;
  final Widget child;

  @override
  State<SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<SwipeActions> with SingleTickerProviderStateMixin {
  /// 0 = ปิด, 1 = เปิดสุด
  late final _open = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));

  double get _width => SwipeActions.actionWidth * widget.actions.length;

  /// ดูจากค่า ไม่ใช่ status: animateTo(0) จบด้วยสถานะ completed
  bool get _closed => _open.value == 0;

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  void _settle(bool open) => _open.animateTo(open ? 1 : 0, curve: Curves.easeOut);

  void _dragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    // ปัดเร็วตัดสินตามทิศ ปัดช้าตัดสินตามระยะที่ลากมา
    _settle(v.abs() > 300 ? v < 0 : _open.value > 0.5);
  }

  void _run(SwipeAction a) {
    _settle(false);
    a.onPressed();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        // โปรแกรมอ่านหน้าจอปัดแบบนี้ไม่ได้ จึงให้เลือกคำสั่งได้โดยตรง
        customSemanticsActions: {for (final a in widget.actions) CustomSemanticsAction(label: a.label): () => _run(a)},
        child: TapRegion(
          onTapOutside: (_) {
            if (!_closed) _settle(false);
          },
          child: AnimatedBuilder(
            animation: _open,
            builder: (context, _) {
              final closed = _closed;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) => _open.value -= d.primaryDelta! / _width,
                onHorizontalDragEnd: _dragEnd,
                onTap: closed ? null : () => _settle(false),
                child: Stack(
                  children: [
                    if (!closed)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: 0,
                        width: _width,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [for (final a in widget.actions) Expanded(child: _ActionButton(a, () => _run(a)))],
                        ),
                      ),
                    Transform.translate(
                      offset: Offset(-_width * _open.value, 0),
                      // ตอนเปิดอยู่ การแตะเนื้อหาคือการปิด ไม่ใช่เปิดรายการ
                      child: AbsorbPointer(
                        absorbing: !closed,
                        child: Material(color: Theme.of(context).scaffoldBackgroundColor, child: widget.child),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(this.action, this.onTap);
  final SwipeAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: action.background,
        child: InkWell(
          onTap: onTap,
          // แถวเตี้ยหรือตัวอักษรใหญ่: ย่อแทนการล้น
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(action.icon, color: action.foreground),
                  const SizedBox(height: 4),
                  Text(action.label, style: TextStyle(fontSize: 12, color: action.foreground)),
                ],
              ),
            ),
          ),
        ),
      );
}
