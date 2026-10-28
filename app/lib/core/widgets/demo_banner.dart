import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Persistent banner shown on every screen in demo mode.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Material(
      color: SpColors.demoSoft,
      child: Padding(
        padding: EdgeInsets.fromLTRB(SpSpace.lg, top + 6, SpSpace.lg, 6),
        child: const Row(
          children: [
            Icon(Icons.science_outlined, size: 16, color: SpColors.demo),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'وضع العرض — بيانات تجريبية. نموذج أولي مستقل غير مرتبط بتطبيق صحتي.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: spFontFamily, fontSize: 12, fontWeight: FontWeight.w600, color: SpColors.demo),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Original Sukkar Plus mark: a droplet with a plus. Not derived from any
/// official logo.
class SukkarLogo extends StatelessWidget {
  const SukkarLogo({super.key, this.size = 34, this.withWordmark = false});
  final double size;
  final bool withWordmark;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(width: size, height: size, child: CustomPaint(painter: _LogoPainter()));
    if (!withWordmark) return Semantics(label: 'شعار سكر بلس', child: mark);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 8),
        const Text('سكر بلس', style: TextStyle(fontFamily: spFontFamily, fontSize: 17, fontWeight: FontWeight.w700, color: SpColors.tealDeep)),
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final drop = Path()
      ..moveTo(w * 0.5, h * 0.06)
      ..cubicTo(w * 0.78, h * 0.38, w * 0.9, h * 0.55, w * 0.9, h * 0.66)
      ..cubicTo(w * 0.9, h * 0.86, w * 0.72, h * 0.97, w * 0.5, h * 0.97)
      ..cubicTo(w * 0.28, h * 0.97, w * 0.1, h * 0.86, w * 0.1, h * 0.66)
      ..cubicTo(w * 0.1, h * 0.55, w * 0.22, h * 0.38, w * 0.5, h * 0.06)
      ..close();
    canvas.drawPath(drop, Paint()..color = SpColors.teal);
    final plus = Paint()
      ..color = Colors.white
      ..strokeWidth = w * 0.1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.5, h * 0.52), Offset(w * 0.5, h * 0.82), plus);
    canvas.drawLine(Offset(w * 0.35, h * 0.67), Offset(w * 0.65, h * 0.67), plus);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
