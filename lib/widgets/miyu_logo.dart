import 'package:flutter/material.dart';

/// Original Miyu logo — rounded geometric M logogram with integrated play symbol
/// (MASTER TASK: minimal, premium, vector).
class MiyuLogo extends StatelessWidget {
  final double size;
  final Color color;

  const MiyuLogo({super.key, this.size = 40, this.color = const Color(0xFFA855F7)});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _MiyuLogoPainter(color),
    );
  }
}

class _MiyuLogoPainter extends CustomPainter {
  final Color color;

  const _MiyuLogoPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = w * 0.5;
    final accent = Color(0xFFA855F7);
    final accent2 = Color(0xFF7C3AED);

    // Gradient rounded square background
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1, -1),
        end: Alignment(1, 1),
        colors: [accent, accent2],
      ).createShader(Rect.fromLTWH(0, 0, w, w));
    canvas.drawRRect(RRect.fromLTRBR(0, 0, w, w, r), bg);

    // White "M" logogram
    final mPaint = Paint()..color = Colors.white.withOpacity(0.97);
    final d = w * 0.08; // leg thickness
    final topY = w * 0.28;
    final midY = w * 0.50;
    final botY = w * 0.72;
    canvas.drawPath(PathBuilder(_mPath(w, topY, midY, botY, d)).build(), mPaint);

    // Integrated play symbol inside M (right-bottom notch)
    final play = Paint()..color = Colors.white;
    final cx = w * 0.72, cy = w * 0.68, s = w * 0.14;
    canvas.drawPath(Path()
      ..moveTo(cx, cy - s * 0.55)
      ..lineTo(cx + s, cy)
      ..lineTo(cx - s, cy)
      ..close(), play);
  }

  Path _mPath(double w, double topY, double midY, double botY, double d) {
    final left = w * 0.18;
    final right = w * 0.82;
    final midTop = (topY + midY) / 2;
    final midBot = (midY + botY) / 2;
    return Path()
      ..moveTo(left, w * 0.18) // top-left
      ..lineTo(left, midTop) // left leg up to M junction
      ..lineTo(left + d, midTop) // left leg thickness
      ..lineTo(left + d, midY)
      ..lineTo(w * 0.58, midY) // middle diagonal
      ..lineTo(right, midBot)
      ..lineTo(right - d, midBot)
      ..lineTo(right - d, botY + d) // right leg down
      ..lineTo(right - 2 * d, botY + d)
      ..lineTo(right - 2 * d, botY)
      ..lineTo(left, botY)
      ..lineTo(left, topY + d)
      ..close();
  }
}

/// Small helper to let the path be built fluently.
class PathBuilder {
  final Path path = Path();
  PathBuilder(this.path);
  Path build() => path;
  PathBuilder moveTo(double x, double y) => PathBuilder(path..moveTo(x, y));
  PathBuilder lineTo(double x, double y) => PathBuilder(path..lineTo(x, y));
  PathBuilder close() => PathBuilder(path..close());
}
