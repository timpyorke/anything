import 'package:material_ui/material_ui.dart';

import '../../app/app_theme.dart';
import '../../core/l10n/app_strings.dart';
import '../../domain/repositories/social_auth_repository.dart';

/// ปุ่มเข้าสู่ระบบด้วยบริการภายนอก — ทุกปุ่มหน้าตาและขนาดเท่ากัน (Apple กำหนดว่าปุ่มของตนต้องเด่นไม่น้อยกว่าเจ้าอื่น)
class SocialSignInButtons extends StatelessWidget {
  const SocialSignInButtons({
    super.key,
    required this.strings,
    required this.enabled,
    required this.signingInWith,
    required this.onPressed,
  });

  final AppStrings strings;
  final bool enabled;

  /// ปุ่มที่กำลังรอผล (null = ไม่มี)
  final SocialProvider? signingInWith;
  final ValueChanged<SocialProvider> onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final provider in SocialProvider.values)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              foregroundColor: scheme.onSurface,
              backgroundColor: scheme.surfaceContainerLow,
              side: BorderSide(color: scheme.outlineVariant),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Corners.control)),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: enabled ? () => onPressed(provider) : null,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox.square(
                dimension: 20,
                child: signingInWith == provider
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : ExcludeSemantics(child: _logo(provider, scheme)),
              ),
              const SizedBox(width: 10),
              Flexible(child: Text(strings.continueWith(provider.label), overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ),
    ]);
  }

  Widget _logo(SocialProvider provider, ColorScheme scheme) => switch (provider) {
        SocialProvider.google => const CustomPaint(painter: _GoogleLogoPainter()),
        SocialProvider.apple => Icon(Icons.apple, size: 22, color: scheme.onSurface),
        SocialProvider.facebook => const Icon(Icons.facebook, size: 20, color: Color(0xff1877f2)),
      };
}

/// โลโก้ "G" สีมาตรฐานของ Google (พิกัดบนกรอบ 48×48) — ข้อกำหนดแบรนด์ห้ามใช้โลโก้สีเดียว
class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48, size.height / 48);
    void fill(Color color, Path path) => canvas.drawPath(path, Paint()..color = color);

    fill(
      const Color(0xffea4335),
      Path()
        ..moveTo(24, 9.5)
        ..cubicTo(27.54, 9.5, 30.71, 10.72, 33.21, 13.1)
        ..lineTo(40.06, 6.25)
        ..cubicTo(35.9, 2.38, 30.47, 0, 24, 0)
        ..cubicTo(14.62, 0, 6.51, 5.38, 2.56, 13.22)
        ..lineTo(10.54, 19.41)
        ..cubicTo(12.43, 13.72, 17.74, 9.5, 24, 9.5)
        ..close(),
    );
    fill(
      const Color(0xff4285f4),
      Path()
        ..moveTo(46.98, 24.55)
        ..cubicTo(46.98, 22.98, 46.83, 21.46, 46.6, 20)
        ..lineTo(24, 20)
        ..lineTo(24, 29.02)
        ..lineTo(36.94, 29.02)
        ..cubicTo(36.36, 31.98, 34.68, 34.5, 32.16, 36.2)
        ..lineTo(39.89, 42.2)
        ..cubicTo(44.4, 38.02, 46.98, 31.84, 46.98, 24.55)
        ..close(),
    );
    fill(
      const Color(0xfffbbc05),
      Path()
        ..moveTo(10.53, 28.59)
        ..cubicTo(10.05, 27.14, 9.77, 25.6, 9.77, 24)
        ..cubicTo(9.77, 22.4, 10.04, 20.86, 10.53, 19.41)
        ..lineTo(2.55, 13.22)
        ..cubicTo(0.92, 16.46, 0, 20.12, 0, 24)
        ..cubicTo(0, 27.88, 0.92, 31.54, 2.56, 34.78)
        ..close(),
    );
    fill(
      const Color(0xff34a853),
      Path()
        ..moveTo(24, 48)
        ..cubicTo(30.48, 48, 35.93, 45.87, 39.89, 42.19)
        ..lineTo(32.16, 36.19)
        ..cubicTo(30.01, 37.64, 27.24, 38.49, 24, 38.49)
        ..cubicTo(17.74, 38.49, 12.43, 34.27, 10.53, 28.58)
        ..lineTo(2.55, 34.77)
        ..cubicTo(6.51, 42.62, 14.62, 48, 24, 48)
        ..close(),
    );
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter oldDelegate) => false;
}
