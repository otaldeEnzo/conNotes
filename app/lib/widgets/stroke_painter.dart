import 'package:flutter/material.dart';
import 'ink_models.dart';

/// CustomPainter dedicado a renderizar os traços vetoriais com suavização por curvas Bézier.
class StrokePainter extends CustomPainter {
  final List<InkStroke> strokes;
  final InkStroke? activeStroke;
  final Offset panOffset;
  final double zoomScale;

  StrokePainter({
    required this.strokes,
    this.activeStroke,
    required this.panOffset,
    required this.zoomScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Aplica a transformação de Pan e Zoom nas coordenadas locais
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(zoomScale);

    // 1. Desenha os traços já concluídos
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // 2. Desenha o traço ativo atual (desenho em tempo real)
    if (activeStroke != null) {
      _drawStroke(canvas, activeStroke!);
    }

    canvas.restore();
  }

  void _drawStroke(Canvas canvas, InkStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    if (stroke.points.length == 1) {
      // Ponto único
      canvas.drawCircle(stroke.points.first.point, stroke.strokeWidth / 2, paint..style = PaintingStyle.fill);
      return;
    }

    path.moveTo(stroke.points.first.point.dx, stroke.points.first.point.dy);

    // Implementação de curvas Bézier quadráticas para suavização dos traços
    for (int i = 0; i < stroke.points.length - 1; i++) {
      final p1 = stroke.points[i].point;
      final p2 = stroke.points[i + 1].point;
      
      // Calcula o ponto médio entre o ponto atual e o próximo para servir de controle Bézier
      final midPoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);

      if (i == 0) {
        path.lineTo(midPoint.dx, midPoint.dy);
      } else {
        path.quadraticBezierTo(p1.dx, p1.dy, midPoint.dx, midPoint.dy);
      }
    }

    // Liga o último segmento de reta
    path.lineTo(stroke.points.last.point.dx, stroke.points.last.point.dy);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.activeStroke != activeStroke ||
        oldDelegate.panOffset != panOffset ||
        oldDelegate.zoomScale != zoomScale;
  }
}
