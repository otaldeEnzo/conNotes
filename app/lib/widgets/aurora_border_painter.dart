import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';

/// CustomPainter que desenha a Borda Aurora Animada com as cores e rotação ajustadas
class AuroraBorderPainter extends CustomPainter {
  final double animationValue;
  final double borderRadius;
  final double borderWidth;

  AuroraBorderPainter({
    required this.animationValue,
    this.borderRadius = MoscaroTokens.radiusInput,
    this.borderWidth = MoscaroTokens.borderWidthAurora,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final paint = Paint()
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke
      ..shader = SweepGradient(
          center: Alignment.center,
          transform: GradientRotation(animationValue * 2 * math.pi),
          colors: const [
            MoscaroTokens.auroraBlue,
            MoscaroTokens.auroraPurple,
            MoscaroTokens.auroraPink,
            MoscaroTokens.auroraBlue,
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant AuroraBorderPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
