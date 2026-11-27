import 'package:flutter/material.dart';

import '../utils/markdown.dart';

/// แสดง markdown ชุดย่อย; checklist กดติ๊กได้ถ้าส่ง [onToggle]
class MarkdownView extends StatelessWidget {
  const MarkdownView(this.body, {super.key, this.onToggle, this.accent});
  final String body;
  final void Function(int index, bool done)? onToggle;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in parseMarkdown(body))
          switch (b) {
            MdParagraph(:final lines) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text.rich(_inline(lines.join('\n'), t.bodyMedium!.copyWith(color: muted))),
              ),
            MdHeading(:final text) => Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2),
                child: Text(text, style: t.titleSmall),
              ),
            MdBullet(:final text) => Padding(
                padding: const EdgeInsets.only(left: 4, top: 1, bottom: 1),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '•  ', style: TextStyle(color: muted)),
                  _inline(text, t.bodyMedium!.copyWith(color: muted)),
                ])),
              ),
            MdCheck(:final text, :final done, :final index) => Semantics(
                checked: done,
                child: InkWell(
                  onTap: onToggle == null ? null : () => onToggle!(index, !done),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    // แถวสูงพอให้นิ้วแตะติ๊กได้โดยไม่ไปโดนการ์ด
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                          size: 22, color: done ? (accent ?? Theme.of(context).colorScheme.primary) : muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(text,
                            style: t.bodyMedium!.copyWith(
                              color: done ? muted : null,
                              decoration: done ? TextDecoration.lineThrough : null,
                              decorationColor: muted,
                            )),
                      ),
                    ]),
                  ),
                ),
              ),
          },
      ],
    );
  }

  static InlineSpan _inline(String s, TextStyle style) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*|\[([^\]]+)\]\((https?://[^)\s]+)\)');
    var i = 0;
    for (final m in re.allMatches(s)) {
      if (m.start > i) spans.add(TextSpan(text: s.substring(i, m.start)));
      spans.add(m[1] != null
          ? TextSpan(text: m[1], style: const TextStyle(fontWeight: FontWeight.w600))
          : TextSpan(text: m[2], style: const TextStyle(decoration: TextDecoration.underline)));
      i = m.end;
    }
    if (i < s.length) spans.add(TextSpan(text: s.substring(i)));
    return TextSpan(style: style, children: spans);
  }
}
