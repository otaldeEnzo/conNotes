import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/canvas_card_model.dart';
import '../services/cards_telemetry_controller.dart';

/// Overlay de Diagnóstico Visual e Telemetria em Tempo Real dos Cards no Canvas (F2).
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

    return ValueListenableBuilder<CardsTelemetryData>(
      valueListenable: CardsTelemetryController.instance.telemetryNotifier,
      builder: (context, telemetry, _) {
        return IgnorePointer(
          child: Stack(
            children: [
              // 1. Pintor de Bounding Boxes, Hitboxes Dinâmicas e Alças no Espaço do Canvas
              Positioned.fill(
                child: CustomPaint(
                  painter: _CardsDebugPainter(
                    cards: cards,
                    selectedCardId: selectedCardId,
                    panOffset: panOffset,
                    zoomScale: zoomScale,
                    mousePos: mousePos,
                    rawCanvasPoint: rawCanvasPoint,
                    telemetry: telemetry,
                  ),
                ),
              ),

              // 2. HUD Superior Direito com Painel Moscaro de Telemetria em Tempo Real
              Positioned(
                top: 56,
                right: 16,
                child: _CardsTelemetryHudPanel(
                  telemetry: telemetry,
                  cardsCount: cards.length,
                  selectedCardId: selectedCardId,
                  panOffset: panOffset,
                  zoomScale: zoomScale,
                  mousePos: mousePos,
                  canvasPoint: rawCanvasPoint,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Painel Flutuante Moscaro STEM de Telemetria de Cards e Roteamento de Gestos
class _CardsTelemetryHudPanel extends StatelessWidget {
  final CardsTelemetryData telemetry;
  final int cardsCount;
  final String? selectedCardId;
  final Offset panOffset;
  final double zoomScale;
  final Offset? mousePos;
  final Offset? canvasPoint;

  const _CardsTelemetryHudPanel({
    required this.telemetry,
    required this.cardsCount,
    required this.selectedCardId,
    required this.panOffset,
    required this.zoomScale,
    required this.mousePos,
    required this.canvasPoint,
  });

  @override
  Widget build(BuildContext context) {
    final activeHoverZone = telemetry.hoverZone;
    final isHoveringAny = activeHoverZone != CardHoverZone.none;
    final targetCard = telemetry.cardUnderPointer;

    return Container(
      width: 320,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xF20A0E17),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHoveringAny ? const Color(0xFF00E1FF) : const Color(0x6600E1FF),
          width: isHoveringAny ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isHoveringAny ? const Color(0x5500E1FF) : const Color(0x3300E1FF),
            blurRadius: isHoveringAny ? 16 : 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cabeçalho do HUD
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: telemetry.isInteractingWithCard
                      ? const Color(0xFFFF0055)
                      : (isHoveringAny ? const Color(0xFF00E1FF) : const Color(0xFF39FF14)),
                  boxShadow: [
                    BoxShadow(
                      color: telemetry.isInteractingWithCard
                          ? const Color(0xFFFF0055)
                          : const Color(0xFF00E1FF),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'CARDS TELEMETRY HUD [F2]',
                  style: TextStyle(
                    color: Color(0xFF00E1FF),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x3300E1FF),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0x6600E1FF), width: 0.8),
                ),
                child: Text(
                  'TOOL: ${telemetry.activeTool.toUpperCase()}',
                  style: const TextStyle(
                    color: Color(0xFF00E1FF),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0x3300E1FF), height: 1, thickness: 0.8),
          const SizedBox(height: 8),

          // Seção 1: Ponteiro e Dispositivo
          _buildRow('Ponteiro Evento', '${telemetry.lastEventType} | Dev: ${_formatDeviceKind(telemetry.deviceKind)}'),
          _buildRow(
            'Botões / Pressão',
            '0x${telemetry.buttons.toRadixString(16).padLeft(2, '0')} | ${(telemetry.pressure * 100).toInt()}%',
          ),
          _buildRow(
            'Tela / Canvas',
            '(${mousePos?.dx.toInt() ?? "-"}, ${mousePos?.dy.toInt() ?? "-"}) -> (${canvasPoint?.dx.toInt() ?? "-"}, ${canvasPoint?.dy.toInt() ?? "-"})',
            valueColor: const Color(0xFF39FF14),
          ),
          _buildRow(
            'Pan / Zoom',
            '(${panOffset.dx.toInt()}, ${panOffset.dy.toInt()}) | ${zoomScale.toStringAsFixed(2)}x',
          ),

          const SizedBox(height: 6),
          const Divider(color: Color(0x3300E1FF), height: 1, thickness: 0.8),
          const SizedBox(height: 6),

          // Seção 2: Hover Zone & Hit Test
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Hover Zone:', style: TextStyle(color: Colors.white70, fontSize: 9.5, fontFamily: 'monospace')),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getZoneBackgroundColor(activeHoverZone),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _getZoneBorderColor(activeHoverZone), width: 0.8),
                ),
                child: Text(
                  activeHoverZone.label,
                  style: TextStyle(
                    color: _getZoneTextColor(activeHoverZone),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildRow(
            'Alvo HitTest',
            targetCard != null ? '#${targetCard.id.substring(0, math.min(6, targetCard.id.length))} "${targetCard.title}"' : 'NENHUM',
            valueColor: targetCard != null ? const Color(0xFF00E1FF) : Colors.white54,
          ),
          _buildRow(
            'Card Selecionado',
            selectedCardId != null ? '#${selectedCardId!.substring(0, math.min(6, selectedCardId!.length))}' : 'NENHUM',
            valueColor: selectedCardId != null ? const Color(0xFFFF0055) : Colors.white54,
          ),

          const SizedBox(height: 6),
          const Divider(color: Color(0x3300E1FF), height: 1, thickness: 0.8),
          const SizedBox(height: 6),

          // Seção 3: Estado de Interação e Deltas
          _buildRow(
            'Interagindo Card',
            telemetry.isInteractingWithCard ? 'SIM [BLOQUEANDO INK]' : 'NAO [CANVAS LIVRE]',
            valueColor: telemetry.isInteractingWithCard ? const Color(0xFFFF9900) : const Color(0xFF39FF14),
          ),
          if (telemetry.isDraggingCard)
            _buildRow(
              'Arraste Delta',
              'dx: ${telemetry.dragDelta.dx.toStringAsFixed(1)}, dy: ${telemetry.dragDelta.dy.toStringAsFixed(1)}',
              valueColor: const Color(0xFF00E1FF),
            ),
          if (telemetry.isResizingCard) ...[
            _buildRow(
              'Resize Delta',
              'dx: ${telemetry.resizeDelta.dx.toStringAsFixed(1)}, dy: ${telemetry.resizeDelta.dy.toStringAsFixed(1)}',
              valueColor: const Color(0xFF00E1FF),
            ),
            if (telemetry.currentResizeSize != null)
              _buildRow(
                'Tam. Alvo',
                '${telemetry.currentResizeSize!.width.toInt()} x ${telemetry.currentResizeSize!.height.toInt()}',
                valueColor: const Color(0xFF39FF14),
              ),
          ],
          _buildRow('Total de Cards', '$cardsCount'),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontFamily: 'monospace')),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDeviceKind(PointerDeviceKind? kind) {
    if (kind == null) return 'none';
    switch (kind) {
      case PointerDeviceKind.mouse:
        return 'mouse';
      case PointerDeviceKind.stylus:
        return 'stylus';
      case PointerDeviceKind.touch:
        return 'touch';
      case PointerDeviceKind.invertedStylus:
        return 'inverted';
      case PointerDeviceKind.trackpad:
        return 'trackpad';
      case PointerDeviceKind.unknown:
        return 'unknown';
    }
  }

  Color _getZoneBackgroundColor(CardHoverZone zone) {
    switch (zone) {
      case CardHoverZone.none:
        return const Color(0x22FFFFFF);
      case CardHoverZone.body:
        return const Color(0x3300FF66);
      case CardHoverZone.header:
        return const Color(0x4400E1FF);
      case CardHoverZone.rightEdge:
        return const Color(0x44FF0055);
      case CardHoverZone.bottomEdge:
        return const Color(0x4400FF66);
      case CardHoverZone.corner:
        return const Color(0x440055FF);
    }
  }

  Color _getZoneBorderColor(CardHoverZone zone) {
    switch (zone) {
      case CardHoverZone.none:
        return Colors.white24;
      case CardHoverZone.body:
        return const Color(0xFF00FF66);
      case CardHoverZone.header:
        return const Color(0xFF00E1FF);
      case CardHoverZone.rightEdge:
        return const Color(0xFFFF0055);
      case CardHoverZone.bottomEdge:
        return const Color(0xFF00FF66);
      case CardHoverZone.corner:
        return const Color(0xFF0055FF);
    }
  }

  Color _getZoneTextColor(CardHoverZone zone) {
    switch (zone) {
      case CardHoverZone.none:
        return Colors.white70;
      case CardHoverZone.body:
        return const Color(0xFF00FF66);
      case CardHoverZone.header:
        return const Color(0xFF00E1FF);
      case CardHoverZone.rightEdge:
        return const Color(0xFFFF5588);
      case CardHoverZone.bottomEdge:
        return const Color(0xFF39FF14);
      case CardHoverZone.corner:
        return const Color(0xFF66AAFF);
    }
  }
}

/// Pintor Canvas que desenha as hitboxes exatas e destaques visuais em tempo real
class _CardsDebugPainter extends CustomPainter {
  final List<CanvasCardModel> cards;
  final String? selectedCardId;
  final Offset panOffset;
  final double zoomScale;
  final Offset? mousePos;
  final Offset? rawCanvasPoint;
  final CardsTelemetryData telemetry;

  _CardsDebugPainter({
    required this.cards,
    required this.selectedCardId,
    required this.panOffset,
    required this.zoomScale,
    required this.mousePos,
    required this.rawCanvasPoint,
    required this.telemetry,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(zoomScale);

    final activeCardId = telemetry.hoveredCardId ?? telemetry.cardUnderPointer?.id;
    final activeHoverZone = telemetry.hoverZone;

    for (int i = 0; i < cards.length; i++) {
      final card = cards[i];
      final isSelected = card.id == selectedCardId;
      final isCardHovered = card.id == activeCardId;
      final double minH = card.calculateMinHeight();
      final double cardH = card.isCollapsed ? 36.0 : math.max(card.height, minH);

      final cardRect = Rect.fromLTWH(card.x, card.y, card.width, cardH);
      final headerRect = Rect.fromLTWH(card.x, card.y, card.width, 36.0);

      // 1. Preenchimento e Borda do Card
      final isBodyHovered = isCardHovered && activeHoverZone == CardHoverZone.body;
      final cardBorderPaint = Paint()
        ..color = isSelected
            ? const Color(0xFFFF0055)
            : (isBodyHovered ? const Color(0xFF00E1FF) : const Color(0xFF00FF66))
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.5 / zoomScale : (isBodyHovered ? 2.0 / zoomScale : 1.2 / zoomScale);

      final cardFillPaint = Paint()
        ..color = isSelected
            ? const Color(0x22FF0055)
            : (isBodyHovered ? const Color(0x3300E1FF) : const Color(0x1100FF66))
        ..style = PaintingStyle.fill;

      canvas.drawRect(cardRect, cardFillPaint);
      canvas.drawRect(cardRect, cardBorderPaint);

      // 2. Destaque da Área de Arraste (Cabeçalho)
      final isHeaderHovered = isCardHovered &&
          (activeHoverZone == CardHoverZone.header || telemetry.activeInteractionZone == CardHoverZone.header);
      final headerFillPaint = Paint()
        ..color = isHeaderHovered ? const Color(0x6600E1FF) : const Color(0x2A00E1FF)
        ..style = PaintingStyle.fill;
      canvas.drawRect(headerRect, headerFillPaint);

      final headerBorderPaint = Paint()
        ..color = isHeaderHovered ? const Color(0xFF00E1FF) : const Color(0x5500E1FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHeaderHovered ? 2.0 / zoomScale : 1.0 / zoomScale;
      canvas.drawRect(headerRect, headerBorderPaint);

      // 3. Regiões Dinâmicas de Redimensionamento (se selecionado, não fixado e não recolhido)
      if (isSelected && !card.isPinned && !card.isCollapsed) {
        const edgeThickness = 12.0;
        const cornerSize = 24.0;

        final isRightHovered = isCardHovered &&
            (activeHoverZone == CardHoverZone.rightEdge ||
                telemetry.activeInteractionZone == CardHoverZone.rightEdge);
        final isBottomHovered = isCardHovered &&
            (activeHoverZone == CardHoverZone.bottomEdge ||
                telemetry.activeInteractionZone == CardHoverZone.bottomEdge);
        final isCornerHovered = isCardHovered &&
            (activeHoverZone == CardHoverZone.corner ||
                telemetry.activeInteractionZone == CardHoverZone.corner);

        // A. Aresta Direita (Vertical)
        final rightEdgeRect = Rect.fromLTWH(
          card.x + card.width - (edgeThickness / 2),
          card.y,
          edgeThickness,
          cardH - cornerSize,
        );
        final rightPaint = Paint()
          ..color = isRightHovered ? const Color(0xAAFF0055) : const Color(0x55FF0055)
          ..style = PaintingStyle.fill;
        canvas.drawRect(rightEdgeRect, rightPaint);

        final rightBorderPaint = Paint()
          ..color = isRightHovered ? const Color(0xFFFF0055) : const Color(0x88FF0055)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isRightHovered ? 2.0 / zoomScale : 1.0 / zoomScale;
        canvas.drawRect(rightEdgeRect, rightBorderPaint);

        // B. Aresta Inferior (Horizontal)
        final bottomEdgeRect = Rect.fromLTWH(
          card.x,
          card.y + cardH - (edgeThickness / 2),
          card.width - cornerSize,
          edgeThickness,
        );
        final bottomPaint = Paint()
          ..color = isBottomHovered ? const Color(0xAA00FF66) : const Color(0x5500FF66)
          ..style = PaintingStyle.fill;
        canvas.drawRect(bottomEdgeRect, bottomPaint);

        final bottomBorderPaint = Paint()
          ..color = isBottomHovered ? const Color(0xFF00FF66) : const Color(0x8800FF66)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isBottomHovered ? 2.0 / zoomScale : 1.0 / zoomScale;
        canvas.drawRect(bottomEdgeRect, bottomBorderPaint);

        // C. Vértice Inferior Direito (Diagonal)
        final cornerDrawRect = Rect.fromLTWH(
          card.x + card.width - cornerSize,
          card.y + cardH - cornerSize,
          cornerSize + edgeThickness / 2,
          cornerSize + edgeThickness / 2,
        );
        final cornerPaint = Paint()
          ..color = isCornerHovered ? const Color(0xCC0055FF) : const Color(0x660055FF)
          ..style = PaintingStyle.fill;
        canvas.drawRect(cornerDrawRect, cornerPaint);

        final cornerBorderPaint = Paint()
          ..color = isCornerHovered ? const Color(0xFF00E1FF) : const Color(0xAA0055FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isCornerHovered ? 2.2 / zoomScale : 1.2 / zoomScale;
        canvas.drawRect(cornerDrawRect, cornerBorderPaint);
      }

      // 4. Etiqueta com Metadados Acima do Card
      final label =
          '[#$i] "${card.title}" | Pos: (${card.x.toInt()}, ${card.y.toInt()}) | Tam: ${card.width.toInt()}x${cardH.toInt()} | minH: ${minH.toInt()}${isSelected ? " [ATIVO]" : ""}';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: isSelected ? const Color(0xFFFF0055) : const Color(0xFF00FF66),
            fontSize: 11 / math.max(0.5, math.min(1.5, zoomScale)),
            fontWeight: FontWeight.bold,
            backgroundColor: const Color(0xEE0A0E17),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(card.x, card.y - tp.height - 4 / zoomScale));
    }

    // 5. Retículo STEM de Alta Precisão Moscaro
    if (rawCanvasPoint != null) {
      final center = rawCanvasPoint!;
      final s = 1.0 / zoomScale;

      final glowPaint = Paint()
        ..color = const Color(0x6600E1FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * s
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * s);
      canvas.drawCircle(center, 6.0 * s, glowPaint);

      final ringPaint = Paint()
        ..color = const Color(0xCC00E1FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 * s;
      canvas.drawCircle(center, 6.0 * s, ringPaint);

      final tickPaint = Paint()
        ..color = const Color(0xFF00E1FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * s;
      const tickStart = 8.0;
      const tickEnd = 12.0;
      canvas.drawLine(Offset(center.dx - tickEnd * s, center.dy), Offset(center.dx - tickStart * s, center.dy), tickPaint);
      canvas.drawLine(Offset(center.dx + tickStart * s, center.dy), Offset(center.dx + tickEnd * s, center.dy), tickPaint);
      canvas.drawLine(Offset(center.dx, center.dy - tickEnd * s), Offset(center.dx, center.dy - tickStart * s), tickPaint);
      canvas.drawLine(Offset(center.dx, center.dy + tickStart * s), Offset(center.dx, center.dy + tickEnd * s), tickPaint);

      final corePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 1.2 * s, corePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CardsDebugPainter oldDelegate) {
    return true;
  }
}
