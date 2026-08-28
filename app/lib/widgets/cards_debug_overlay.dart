import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/canvas_card_model.dart';

/// Overlay de Diagnóstico Visual para Inspeção e Depuração de Cards no Canvas
class CardsDebugOverlay extends StatelessWidget {
  final List<CanvasCardModel> cards;
  final String? selectedCardId;
  final Offset panOffset;
  final double zoomScale;
  final Offset? mousePos;
  final bool isVisible;

  const CardsDebugOverlay({
    super.key,
    required this.cards,
    required this.selectedCardId,
    required this.panOffset,
    required this.zoomScale,
    required this.mousePos,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final rawCanvasPoint = mousePos != null ? (mousePos! - panOffset) / zoomScale : null;

    return IgnorePointer(
      child: Stack(
        children: [
          // 1. Pintor de Bounding Boxes e Alças no Espaço do Canvas
          Positioned.fill(
            child: CustomPaint(
              painter: _CardsDebugPainter(
                cards: cards,
                selectedCardId: selectedCardId,
                panOffset: panOffset,
                zoomScale: zoomScale,
                mousePos: mousePos,
                rawCanvasPoint: rawCanvasPoint,
              ),
            ),
          ),

          // 2. HUD Superior Direito com Métricas em Tempo Real
          Positioned(
            top: 60,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xE60A0D14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00E1FF), width: 1.2),
                boxShadow: const [
                  BoxShadow(color: Color(0x6600E1FF), blurRadius: 12, spreadRadius: 1),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bug_report, size: 14, color: Color(0xFF00E1FF)),
                      SizedBox(width: 6),
                      Text(
                        'DEBUG VISUAL DE CARDS [F2]',
                        style: TextStyle(
                          color: Color(0xFF00E1FF),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Mouse Tela: ${mousePos != null ? "${mousePos!.dx.toInt()}, ${mousePos!.dy.toInt()}" : "Fora"}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                  ),
                  Text(
                    'Mouse Canvas: ${rawCanvasPoint != null ? "${rawCanvasPoint.dx.toInt()}, ${rawCanvasPoint.dy.toInt()}" : "Fora"}',
                    style: const TextStyle(color: Color(0xFF39FF14), fontSize: 10, fontFamily: 'monospace'),
                  ),
                  Text(
                    'Total Cards: ${cards.length} | Selecionado: ${selectedCardId ?? "Nenhum"}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                  ),
                  Text(
                    'Pan: (${panOffset.dx.toInt()}, ${panOffset.dy.toInt()}) | Zoom: ${zoomScale.toStringAsFixed(2)}x',
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardsDebugPainter extends CustomPainter {
  final List<CanvasCardModel> cards;
  final String? selectedCardId;
  final Offset panOffset;
  final double zoomScale;
  final Offset? mousePos;
  final Offset? rawCanvasPoint;

  _CardsDebugPainter({
    required this.cards,
    required this.selectedCardId,
    required this.panOffset,
    required this.zoomScale,
    required this.mousePos,
    required this.rawCanvasPoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(zoomScale);

    for (int i = 0; i < cards.length; i++) {
      final card = cards[i];
      final isSelected = card.id == selectedCardId;
      final double minH = card.calculateMinHeight();
      final double cardH = card.isCollapsed ? 36.0 : math.max(card.height, minH);

      final cardRect = Rect.fromLTWH(card.x, card.y, card.width, cardH);
      final headerRect = Rect.fromLTWH(card.x, card.y, card.width, 36.0);

      // Preenchimento e Borda do Card
      final cardBorderPaint = Paint()
        ..color = isSelected ? const Color(0xFFFF0055) : const Color(0xFF00FF66)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.5 / zoomScale : 1.5 / zoomScale;

      final cardFillPaint = Paint()
        ..color = isSelected ? const Color(0x22FF0055) : const Color(0x1100FF66)
        ..style = PaintingStyle.fill;

      canvas.drawRect(cardRect, cardFillPaint);
      canvas.drawRect(cardRect, cardBorderPaint);

      // Destaque da Área de Arraste (Cabeçalho)
      final headerFillPaint = Paint()
        ..color = const Color(0x3300E1FF)
        ..style = PaintingStyle.fill;
      canvas.drawRect(headerRect, headerFillPaint);

      // Regiões de Borda de Redimensionamento se selecionado
      if (isSelected && !card.isPinned && !card.isCollapsed) {
        const edgeThickness = 12.0;
        const cornerSize = 24.0;

        // 1. Aresta Direita (Vermelho - Horizontal)
        final rightEdgeRect = Rect.fromLTWH(
          card.x + card.width - (edgeThickness / 2),
          card.y,
          edgeThickness,
          cardH - cornerSize,
        );
        final rightPaint = Paint()
          ..color = const Color(0x66FF0000)
          ..style = PaintingStyle.fill;
        canvas.drawRect(rightEdgeRect, rightPaint);

        // 2. Aresta Inferior (Verde - Vertical)
        final bottomEdgeRect = Rect.fromLTWH(
          card.x,
          card.y + cardH - (edgeThickness / 2),
          card.width - cornerSize,
          edgeThickness,
        );
        final bottomPaint = Paint()
          ..color = const Color(0x6600FF00)
          ..style = PaintingStyle.fill;
        canvas.drawRect(bottomEdgeRect, bottomPaint);

        // 3. Vértice Inferior Direito (Azul - Diagonal)
        final cornerDrawRect = Rect.fromLTWH(
          card.x + card.width - cornerSize,
          card.y + cardH - cornerSize,
          cornerSize + edgeThickness / 2,
          cornerSize + edgeThickness / 2,
        );
        final cornerPaint = Paint()
          ..color = const Color(0x660055FF)
          ..style = PaintingStyle.fill;
        canvas.drawRect(cornerDrawRect, cornerPaint);
      }

      // Etiqueta com Metadados Acima do Card
      final label = '[#$i] "${card.title}" | Pos: (${card.x.toInt()}, ${card.y.toInt()}) | Tam: ${card.width.toInt()}x${cardH.toInt()} | minH: ${minH.toInt()}${isSelected ? " [ATIVO]" : ""}';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: isSelected ? const Color(0xFFFF0055) : const Color(0xFF00FF66),
            fontSize: 11 / math.max(0.5, math.min(1.5, zoomScale)),
            fontWeight: FontWeight.bold,
            backgroundColor: const Color(0xDD000000),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(card.x, card.y - tp.height - 4 / zoomScale));
    }

    // Ponto do Mouse no Canvas
    if (rawCanvasPoint != null) {
      final mousePaint = Paint()
        ..color = const Color(0xFFFF0000)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(rawCanvasPoint!, 4.0 / zoomScale, mousePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CardsDebugPainter oldDelegate) {
    return true;
  }
}
