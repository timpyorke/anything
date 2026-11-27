import 'package:material_ui/material_ui.dart';

/// จุดสีประจำหมวด
class CategoryDot extends StatelessWidget {
  const CategoryDot(this.color, {super.key, this.size = 8});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
