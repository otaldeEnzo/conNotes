import 'package:flutter/material.dart';
import '../models/canvas_card_model.dart';
import 'canvas_card_widget.dart';
import 'selection_models.dart';

/// Camada de Renderização e Viewport Culling dos Cards no Canvas Infinito.
/// 
/// Estratégia de Performance: Frozen Blur (O(0) durante interações)
/// 
/// Em vez de usar BackdropFilter (que recaptura e desfoca o framebuffer a cada frame),
/// usamos um glassTint semi-transparente escuro que simula o efeito de vidro líquido
/// sem custo de GPU. O blur real é aplicado apenas quando os cards estão parados
/// (idle), via snapshot congelado do fundo.
class CanvasCardsLayer extends StatefulWidget {
  final List<CanvasCardModel> cards;
  final String? selectedCardId;
  final SelectionState selectionState;
  final ValueNotifier<Offset> panNotifier;
  final ValueNotifier<double> zoomNotifier;
  final ValueChanged<CanvasCardModel> onUpdateCard;
  final ValueChanged<String?> onSelectCard;
  final ValueChanged<String> onDeleteCard;
  final ValueChanged<CanvasCardModel> onDuplicateCard;

  const CanvasCardsLayer({
    super.key,
    required this.cards,
    required this.selectedCardId,
    required this.selectionState,
    required this.panNotifier,
    required this.zoomNotifier,
    required this.onUpdateCard,
    required this.onSelectCard,
    required this.onDeleteCard,
    required this.onDuplicateCard,
  });

  @override
  State<CanvasCardsLayer> createState() => _CanvasCardsLayerState();
}

class _CanvasCardsLayerState extends State<CanvasCardsLayer> {

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ClipRect(
        child: ValueListenableBuilder<Offset>(
          valueListenable: widget.panNotifier,
          builder: (context, pan, child) {
            return Transform.translate(
              offset: pan,
              child: child,
            );
          },
          child: ValueListenableBuilder<double>(
            valueListenable: widget.zoomNotifier,
            builder: (context, zoom, child) {
              return Transform.scale(
                scale: zoom,
                alignment: Alignment.topLeft,
                child: child,
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: widget.cards.map((card) {
                final isSelected = widget.selectedCardId == card.id || widget.selectionState.selectedCardIds.contains(card.id);
                final bool isDragging = isSelected && widget.selectionState.isDraggingSelection;
                final Offset offset = isDragging ? widget.selectionState.dragOffset : Offset.zero;
                const double pillReserve = 48.0;

                return Positioned(
                  key: ValueKey('pos_${card.id}_${card.x}_${card.y}'),
                  left: card.x + offset.dx,
                  top: card.y - pillReserve + offset.dy,
                  child: RepaintBoundary(
                    key: ValueKey('card_${card.id}'),
                    child: CanvasCardWidget(
                      card: card,
                      isSelected: isSelected,
                      zoomNotifier: widget.zoomNotifier,
                      onUpdateCard: widget.onUpdateCard,
                      onSelectCard: widget.onSelectCard,
                      onDeleteCard: widget.onDeleteCard,
                      onDuplicateCard: widget.onDuplicateCard,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
