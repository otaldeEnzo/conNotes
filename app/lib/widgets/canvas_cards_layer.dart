import 'package:flutter/material.dart';
import '../models/canvas_card_model.dart';
import 'canvas_card_widget.dart';

/// Camada de Renderização e Viewport Culling dos Cards no Canvas Infinito.
class CanvasCardsLayer extends StatelessWidget {
  final List<CanvasCardModel> cards;
  final String? selectedCardId;
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
    required this.panNotifier,
    required this.zoomNotifier,
    required this.onUpdateCard,
    required this.onSelectCard,
    required this.onDeleteCard,
    required this.onDuplicateCard,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([panNotifier, zoomNotifier]),
      builder: (context, _) {
        final pan = panNotifier.value;
        final zoom = zoomNotifier.value;
        final size = MediaQuery.of(context).size;

        // Viewport Culling: limites da tela em coordenadas do mundo do canvas
        final viewportLeft = -pan.dx / zoom - 200;
        final viewportTop = -pan.dy / zoom - 200;
        final viewportRight = (size.width - pan.dx) / zoom + 200;
        final viewportBottom = (size.height - pan.dy) / zoom + 200;

        return Stack(
          clipBehavior: Clip.none,
          children: cards.map((card) {
            final isVisible = (card.x + card.width >= viewportLeft) &&
                (card.x <= viewportRight) &&
                (card.y + card.height >= viewportTop) &&
                (card.y <= viewportBottom);

            if (!isVisible) {
              return const SizedBox.shrink();
            }

            final isSelected = selectedCardId == card.id;
            const double pillReserve = 48.0;
            final screenX = card.x * zoom + pan.dx;
            final screenY = (card.y - pillReserve) * zoom + pan.dy;

            return Positioned(
              left: screenX,
              top: screenY,
              child: Transform.scale(
                scale: zoom,
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  key: ValueKey('card_${card.id}'),
                  child: CanvasCardWidget(
                    card: card,
                    isSelected: isSelected,
                    zoomScale: zoom,
                    onUpdateCard: onUpdateCard,
                    onSelectCard: () => onSelectCard(card.id),
                    onDeleteCard: () => onDeleteCard(card.id),
                    onDuplicateCard: () => onDuplicateCard(card),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
