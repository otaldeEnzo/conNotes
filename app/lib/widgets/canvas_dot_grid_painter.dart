import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';

enum CanvasBackgroundType { dotGrid, pautado, emBranco }

/// Engine de Renderização 2D do Canvas Infinito com o Dot Grid Glow e gradiente radial de iluminação ambiente no fundo.
/// Atualizado para introduzir o tom azul escuro profundo característico do Moscaro STEM no gradiente de fundo.
class CanvasDotGridPainter extends CustomPainter {
  final Offset panOffset;
  final double zoomScale;
  final Offset? mousePosition;
  final CanvasBackgroundType backgroundType;

  CanvasDotGridPainter({
    required this.panOffset,
    required this.zoomScale,
    required this.mousePosition,
    required this.backgroundType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fundo com gradiente radial puxando o tom Azul STEM Escuro Profundo (#09273C / 0xFF09273C) para dar vivacidade
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 1.4,
        colors: [
          Color(0xFF0C243B), // Azul STEM Escuro no centro para quebrar o cinza/preto chapado
          Color(0xFF060D14), // Preto azulado profundo nas bordas para contraste extremo
        ],
        stops: [0.0, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    if (backgroundType == CanvasBackgroundType.emBranco) {
      return;
    }

    final spacing = 30.0 * zoomScale;
    final startX = (panOffset.dx % spacing) - spacing;
    final startY = (panOffset.dy % spacing) - spacing;

    if (backgroundType == CanvasBackgroundType.dotGrid) {
      const double dotRadius = 1.2;
      final Paint dotPaint = Paint()..color = Colors.white.withOpacity(0.12);

      for (double x = startX; x < size.width + spacing; x += spacing) {
        for (double y = startY; y < size.height + spacing; y += spacing) {
          final pointCenter = Offset(x, y);
          double currentRadius = dotRadius;

          if (mousePosition != null) {
            final distance = (pointCenter - mousePosition!).distance;

            // Se o ponto estiver próximo ao mouse, ele ganha brilho e aumenta de tamanho (Efeito Glow)
            if (distance < MoscaroTokens.mouseGlowRadius) {
              final intensity = (1.0 - (distance / MoscaroTokens.mouseGlowRadius)).clamp(0.0, 1.0);

              // Desenha o halo de luz difusa azul (#3B82F6) ao redor do mouse
              final Paint glowPaint = Paint()
                ..color = MoscaroTokens.auroraBlue.withOpacity(intensity * 0.25)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
              canvas.drawCircle(pointCenter, 15 * intensity, glowPaint);

              // Aumenta o ponto principal e interpola com o roxo (#8B5CF6)
              currentRadius += intensity * 1.5;
              dotPaint.color = Color.lerp(
                Colors.white.withOpacity(0.12),
                MoscaroTokens.auroraPurple,
                intensity,
              )!;
            } else {
              dotPaint.color = Colors.white.withOpacity(0.12);
            }
          }

          canvas.drawCircle(pointCenter, currentRadius, dotPaint);
        }
      }
    } else if (backgroundType == CanvasBackgroundType.pautado) {
      // Renderiza as linhas horizontais discretas para cadernos/anotações
      final linePaint = Paint()
        ..color = const Color(0x22FFFFFF)
        ..strokeWidth = 1.0;

      for (double y = startY; y < size.height + spacing; y += spacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CanvasDotGridPainter oldDelegate) {
    return oldDelegate.panOffset != panOffset ||
        oldDelegate.zoomScale != zoomScale ||
        oldDelegate.mousePosition != mousePosition ||
        oldDelegate.backgroundType != backgroundType;
  }
}
