import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/canvas_card_model.dart';

/// Zonas de Hover e Interação com Cards no Canvas
enum CardHoverZone {
  none,
  body,
  header,
  rightEdge,
  bottomEdge,
  corner;

  String get label {
    switch (this) {
      case CardHoverZone.none:
        return 'NONE';
      case CardHoverZone.body:
        return 'BODY';
      case CardHoverZone.header:
        return 'HEADER';
      case CardHoverZone.rightEdge:
        return 'RIGHT_EDGE';
      case CardHoverZone.bottomEdge:
        return 'BOTTOM_EDGE';
      case CardHoverZone.corner:
        return 'CORNER';
    }
  }
}

/// Dados de Telemetria de Eventos em Tempo Real para Cards e Gestos
class CardsTelemetryData {
  final CardHoverZone hoverZone;
  final String? hoveredCardId;
  final String? selectedCardId;
  final CanvasCardModel? cardUnderPointer;

  final String lastEventType; // 'Down', 'Move', 'Up', 'Hover', 'Cancel', 'None'
  final PointerDeviceKind? deviceKind;
  final int buttons;
  final double pressure;
  final Offset? screenPosition;
  final Offset? canvasPosition;

  final bool isInteractingWithCard;
  final bool isDraggingCard;
  final bool isResizingCard;
  final CardHoverZone activeInteractionZone;
  final String activeTool;

  final Offset dragDelta;
  final Offset resizeDelta;
  final Size? currentResizeSize;

  const CardsTelemetryData({
    this.hoverZone = CardHoverZone.none,
    this.hoveredCardId,
    this.selectedCardId,
    this.cardUnderPointer,
    this.lastEventType = 'None',
    this.deviceKind,
    this.buttons = 0,
    this.pressure = 0.0,
    this.screenPosition,
    this.canvasPosition,
    this.isInteractingWithCard = false,
    this.isDraggingCard = false,
    this.isResizingCard = false,
    this.activeInteractionZone = CardHoverZone.none,
    this.activeTool = 'pen',
    this.dragDelta = Offset.zero,
    this.resizeDelta = Offset.zero,
    this.currentResizeSize,
  });

  CardsTelemetryData copyWith({
    CardHoverZone? hoverZone,
    String? hoveredCardId,
    bool clearHoveredCard = false,
    String? selectedCardId,
    bool clearSelectedCard = false,
    CanvasCardModel? cardUnderPointer,
    bool clearCardUnderPointer = false,
    String? lastEventType,
    PointerDeviceKind? deviceKind,
    int? buttons,
    double? pressure,
    Offset? screenPosition,
    bool clearScreenPosition = false,
    Offset? canvasPosition,
    bool clearCanvasPosition = false,
    bool? isInteractingWithCard,
    bool? isDraggingCard,
    bool? isResizingCard,
    CardHoverZone? activeInteractionZone,
    String? activeTool,
    Offset? dragDelta,
    Offset? resizeDelta,
    Size? currentResizeSize,
    bool clearResizeSize = false,
  }) {
    return CardsTelemetryData(
      hoverZone: hoverZone ?? this.hoverZone,
      hoveredCardId: clearHoveredCard ? null : (hoveredCardId ?? this.hoveredCardId),
      selectedCardId: clearSelectedCard ? null : (selectedCardId ?? this.selectedCardId),
      cardUnderPointer: clearCardUnderPointer ? null : (cardUnderPointer ?? this.cardUnderPointer),
      lastEventType: lastEventType ?? this.lastEventType,
      deviceKind: deviceKind ?? this.deviceKind,
      buttons: buttons ?? this.buttons,
      pressure: pressure ?? this.pressure,
      screenPosition: clearScreenPosition ? null : (screenPosition ?? this.screenPosition),
      canvasPosition: clearCanvasPosition ? null : (canvasPosition ?? this.canvasPosition),
      isInteractingWithCard: isInteractingWithCard ?? this.isInteractingWithCard,
      isDraggingCard: isDraggingCard ?? this.isDraggingCard,
      isResizingCard: isResizingCard ?? this.isResizingCard,
      activeInteractionZone: activeInteractionZone ?? this.activeInteractionZone,
      activeTool: activeTool ?? this.activeTool,
      dragDelta: dragDelta ?? this.dragDelta,
      resizeDelta: resizeDelta ?? this.resizeDelta,
      currentResizeSize: clearResizeSize ? null : (currentResizeSize ?? this.currentResizeSize),
    );
  }
}

/// Controlador Central de Telemetria e Roteamento de Gestos de Cards
class CardsTelemetryController extends ChangeNotifier {
  static final CardsTelemetryController instance = CardsTelemetryController._internal();
  CardsTelemetryController._internal();

  final ValueNotifier<CardsTelemetryData> telemetryNotifier = ValueNotifier(const CardsTelemetryData());

  CardsTelemetryData get current => telemetryNotifier.value;
  bool get isInteractingWithCard => current.isInteractingWithCard || current.isDraggingCard || current.isResizingCard;

  /// Hit-testing de precisão para zonas de cards e alças de redimensionamento
  static ({CardHoverZone zone, CanvasCardModel? card}) detectCardZone({
    required List<CanvasCardModel> cards,
    required String? selectedCardId,
    required Offset canvasPoint,
  }) {
    const edgeThickness = 12.0;
    const cornerSize = 24.0;

    // 1. Testa primeiro o card selecionado (cujas alças de redimensionamento têm prioridade)
    if (selectedCardId != null) {
      final selected = cards.where((c) => c.id == selectedCardId).firstOrNull;
      if (selected != null) {
        final double minH = selected.calculateMinHeight();
        final double cardH = selected.isCollapsed ? 36.0 : math.max(selected.height, minH);

        // Barra Flutuante Superior (quando selecionado)
        final floatingPillRect = Rect.fromLTWH(
          selected.x - 30.0,
          selected.y - 70.0,
          math.max(selected.width, 360.0) + 60.0,
          70.0,
        );
        if (floatingPillRect.contains(canvasPoint)) {
          return (zone: CardHoverZone.body, card: selected);
        }

        // Alças ativas apenas se não fixado e não recolhido
        if (!selected.isPinned && !selected.isCollapsed) {
          // Vértice Inferior Direito (Diagonal)
          final cornerRect = Rect.fromLTWH(
            selected.x + selected.width - cornerSize,
            selected.y + cardH - cornerSize,
            cornerSize + edgeThickness / 2,
            cornerSize + edgeThickness / 2,
          );
          if (cornerRect.contains(canvasPoint)) {
            return (zone: CardHoverZone.corner, card: selected);
          }

          // Aresta Direita (Vertical)
          final rightEdgeRect = Rect.fromLTWH(
            selected.x + selected.width - edgeThickness / 2,
            selected.y,
            edgeThickness,
            cardH - cornerSize,
          );
          if (rightEdgeRect.contains(canvasPoint)) {
            return (zone: CardHoverZone.rightEdge, card: selected);
          }

          // Aresta Inferior (Horizontal)
          final bottomEdgeRect = Rect.fromLTWH(
            selected.x,
            selected.y + cardH - edgeThickness / 2,
            selected.width - cornerSize,
            edgeThickness,
          );
          if (bottomEdgeRect.contains(canvasPoint)) {
            return (zone: CardHoverZone.bottomEdge, card: selected);
          }
        }

        // Cabeçalho de Arraste
        final headerRect = Rect.fromLTWH(selected.x, selected.y, selected.width, 36.0);
        if (headerRect.contains(canvasPoint)) {
          return (zone: CardHoverZone.header, card: selected);
        }

        // Corpo do Card
        final cardRect = Rect.fromLTWH(selected.x, selected.y, selected.width, cardH);
        if (cardRect.contains(canvasPoint)) {
          return (zone: CardHoverZone.body, card: selected);
        }
      }
    }

    // 2. Testa os demais cards em ordem reversa (topo para fundo)
    for (final card in cards.reversed) {
      if (card.id == selectedCardId) continue;
      final double minH = card.calculateMinHeight();
      final double cardH = card.isCollapsed ? 36.0 : math.max(card.height, minH);

      final headerRect = Rect.fromLTWH(card.x, card.y, card.width, 36.0);
      if (headerRect.contains(canvasPoint)) {
        return (zone: CardHoverZone.header, card: card);
      }

      final cardRect = Rect.fromLTWH(card.x, card.y, card.width, cardH);
      if (cardRect.contains(canvasPoint)) {
        return (zone: CardHoverZone.body, card: card);
      }
    }

    return (zone: CardHoverZone.none, card: null);
  }

  /// Atualiza o fluxo de eventos de ponteiro recebidos pelo CanvasInputRouter
  void updatePointerEvent({
    required String eventType,
    required PointerDeviceKind? deviceKind,
    required int buttons,
    required double pressure,
    required Offset? screenPosition,
    required Offset? canvasPosition,
    required String activeTool,
    String? selectedCardId,
    List<CanvasCardModel>? cards,
    bool? isInteractingWithCard,
  }) {
    CardHoverZone detectedZone = current.hoverZone;
    CanvasCardModel? detectedCard = current.cardUnderPointer;

    if (canvasPosition != null && cards != null) {
      final match = detectCardZone(
        cards: cards,
        selectedCardId: selectedCardId ?? current.selectedCardId,
        canvasPoint: canvasPosition,
      );
      detectedZone = match.zone;
      detectedCard = match.card;
    }

    final bool interacting = isInteractingWithCard ??
        (current.isDraggingCard ||
            current.isResizingCard ||
            (eventType == 'Down' && detectedZone != CardHoverZone.none));

    telemetryNotifier.value = current.copyWith(
      lastEventType: eventType,
      deviceKind: deviceKind,
      buttons: buttons,
      pressure: pressure,
      screenPosition: screenPosition,
      canvasPosition: canvasPosition,
      activeTool: activeTool,
      selectedCardId: selectedCardId,
      hoverZone: detectedZone,
      hoveredCardId: detectedCard?.id,
      cardUnderPointer: detectedCard,
      clearCardUnderPointer: detectedCard == null,
      clearHoveredCard: detectedCard == null,
      isInteractingWithCard: interacting,
    );
    notifyListeners();
  }

  void startCardDrag({required String cardId}) {
    telemetryNotifier.value = current.copyWith(
      isDraggingCard: true,
      isInteractingWithCard: true,
      activeInteractionZone: CardHoverZone.header,
      hoveredCardId: cardId,
      dragDelta: Offset.zero,
    );
    notifyListeners();
  }

  void updateCardDragDelta(Offset delta) {
    telemetryNotifier.value = current.copyWith(
      dragDelta: delta,
      isDraggingCard: true,
      isInteractingWithCard: true,
    );
    notifyListeners();
  }

  void endCardDrag() {
    telemetryNotifier.value = current.copyWith(
      isDraggingCard: false,
      isInteractingWithCard: current.isResizingCard,
      activeInteractionZone: CardHoverZone.none,
      dragDelta: Offset.zero,
    );
    notifyListeners();
  }

  void startCardResize({required String cardId, required CardHoverZone handle}) {
    telemetryNotifier.value = current.copyWith(
      isResizingCard: true,
      isInteractingWithCard: true,
      activeInteractionZone: handle,
      hoveredCardId: cardId,
      resizeDelta: Offset.zero,
    );
    notifyListeners();
  }

  void updateCardResize({required Offset delta, Size? currentSize}) {
    telemetryNotifier.value = current.copyWith(
      resizeDelta: delta,
      currentResizeSize: currentSize,
      isResizingCard: true,
      isInteractingWithCard: true,
    );
    notifyListeners();
  }

  void endCardResize() {
    telemetryNotifier.value = current.copyWith(
      isResizingCard: false,
      isInteractingWithCard: current.isDraggingCard,
      activeInteractionZone: CardHoverZone.none,
      resizeDelta: Offset.zero,
      clearResizeSize: true,
    );
    notifyListeners();
  }

  void setInteractingWithCard(bool interacting) {
    telemetryNotifier.value = current.copyWith(
      isInteractingWithCard: interacting,
    );
    notifyListeners();
  }

  void updateHoverZone(CardHoverZone zone, {CanvasCardModel? card}) {
    telemetryNotifier.value = current.copyWith(
      hoverZone: zone,
      hoveredCardId: card?.id,
      cardUnderPointer: card,
      clearCardUnderPointer: card == null,
      clearHoveredCard: card == null,
    );
    notifyListeners();
  }
}
