import 'package:flutter/material.dart';

import '../../core/theme/miyu_colors.dart';

/// Vector Miyu mark: a soft speech bubble holding a stylised "M" aperture.
class MiyuLogo extends StatelessWidget {
  const MiyuLogo({super.key, this.size = 72, this.showWordmark = false, this.inverse = false});

  final double size;
  final bool showWordmark;
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: MiyuColors.aurora,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: MiyuColors.accent.withValues(alpha: 0.45),
            blurRadius: size * 0.45,
            offset: Offset(0, size * 0.16),
          ),
        ],
      ),
      child: CustomPaint(painter: _MiyuMarkPainter()),
    );

    if (!showWordmark) return mark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(height: size * 0.22),
        Text(
          'Miyu',
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
            letterSpacing: size * 0.01,
            color: inverse ? Colors.white : null,
          ),
        ),
      ],
    );
  }
}

class _MiyuMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.24, size.height * 0.68)
      ..lineTo(size.width * 0.24, size.height * 0.36)
      ..quadraticBezierTo(
        size.width * 0.24,
        size.height * 0.3,
        size.width * 0.3,
        size.height * 0.36,
      )
      ..lineTo(size.width * 0.5, size.height * 0.58)
      ..lineTo(size.width * 0.7, size.height * 0.36)
      ..quadraticBezierTo(
        size.width * 0.76,
        size.height * 0.3,
        size.width * 0.76,
        size.height * 0.36,
      )
      ..lineTo(size.width * 0.76, size.height * 0.68);

    canvas.drawPath(path, paint);

    final dot = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.76),
      size.width * 0.035,
      dot,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
