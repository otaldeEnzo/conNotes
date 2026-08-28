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
  final SelectionState Function()? getSelectionState;
  final ValueNotifier<int>? selectionUpdateNotifier;
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
    this.selectionState = const SelectionState(),
    this.getSelectionState,
    this.selectionUpdateNotifier,
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
            child: widget.selectionUpdateNotifier != null
                ? ListenableBuilder(
                    listenable: widget.selectionUpdateNotifier!,
                    builder: (context, _) => _buildCardsStack(),
                  )
                : _buildCardsStack(),
          ),
        ),
      ),
    );
  }

  Widget _buildCardsStack() {
    final currentSelectionState = widget.getSelectionState != null
        ? widget.getSelectionState!()
        : widget.selectionState;

    final unselectedCards = <CanvasCardModel>[];
    final selectedCards = <CanvasCardModel>[];
    for (final card in widget.cards) {
      final isSelected = widget.selectedCardId == card.id ||
          currentSelectionState.selectedCardIds.contains(card.id);
      if (isSelected) {
        selectedCards.add(card);
      } else {
        unselectedCards.add(card);
      }
    }
    final sortedCards = [...unselectedCards, ...selectedCards];

    return Stack(
      clipBehavior: Clip.none,
      children: sortedCards.map((card) {
        final isSelected = widget.selectedCardId == card.id ||
            currentSelectionState.selectedCardIds.contains(card.id);
        final bool isDragging = isSelected && currentSelectionState.isDraggingSelection;
        final Offset offset = isDragging ? currentSelectionState.dragOffset : Offset.zero;
        return Positioned(
          key: ValueKey('pos_${card.id}_${card.x}_${card.y}'),
          left: card.x + offset.dx,
          top: card.y + offset.dy,
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
    );
  }
}
