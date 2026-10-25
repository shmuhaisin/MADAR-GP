import 'dart:math' as math;
import 'package:flutter/material.dart';

class MadarNavyHeaderClip extends StatelessWidget {
  final double headerHeight;
  final double overlap;
  final double sheetRadius;
  final Widget? child;

  const MadarNavyHeaderClip({
    super.key,
    this.headerHeight = 100,
    this.overlap = 15,
    this.sheetRadius = 28,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: headerHeight,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: headerHeight,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFF071634),
                  Color(0xFF123B7A),
                  Color(0xFF1D2B53),
                ],
                stops: [0.0, 0.48, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                  color: Colors.black.withOpacity(0.10),
                ),
              ],
            ),
          ),

          // Very subtle landing-style light
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.80, -0.75),
                    radius: 1.05,
                    colors: [
                      const Color(0xFF4E9BFF).withOpacity(0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Little soft particles only
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _TinyParticlesPainter(),
              ),
            ),
          ),

          // Soft top glass highlight
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerHeight * 0.45,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.055),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: overlap,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(sheetRadius),
                  topRight: Radius.circular(sheetRadius),
                ),
              ),
            ),
          ),

          if (child != null) SafeArea(bottom: false, child: child!),
        ],
      ),
    );
  }
}

class _TinyParticlesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(0.13);

    final softDotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF4E9BFF).withOpacity(0.12);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = Colors.white.withOpacity(0.028);

    final points = <Offset>[
      Offset(size.width * 0.12, size.height * 0.32),
      Offset(size.width * 0.25, size.height * 0.18),
      Offset(size.width * 0.39, size.height * 0.40),
      Offset(size.width * 0.62, size.height * 0.22),
      Offset(size.width * 0.76, size.height * 0.48),
      Offset(size.width * 0.88, size.height * 0.25),
      Offset(size.width * 0.18, size.height * 0.70),
      Offset(size.width * 0.52, size.height * 0.66),
      Offset(size.width * 0.82, size.height * 0.72),
    ];

    for (int i = 0; i < points.length; i++) {
      final p = points[i];

      canvas.drawCircle(
        p,
        i % 3 == 0 ? 1.45 : 1.05,
        i % 2 == 0 ? dotPaint : softDotPaint,
      );
    }

    for (int i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];

      if ((a - b).distance < size.width * 0.28) {
        canvas.drawLine(a, b, linePaint);
      }
    }

    final tinyGlowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(0.045);

    for (int i = 0; i < 5; i++) {
      final x = size.width * (0.18 + i * 0.16);
      final y = size.height * (0.20 + 0.12 * math.sin(i));

      canvas.drawCircle(
        Offset(x, y),
        0.75,
        tinyGlowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TinyParticlesPainter oldDelegate) {
    return false;
  }
}