import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/services/cards_telemetry_controller.dart';
import 'package:connotes_app/widgets/cards_debug_overlay.dart';

void main() {
  group('CardsTelemetryController Tests', () {
    final testCard = CanvasCardModel(
      id: 'card_1',
      x: 100,
      y: 100,
      width: 400,
      height: 300,
      title: 'STEM Note Card',
      content: 'Calculus and Physics formulas',
    );

    setUp(() {
      CardsTelemetryController.instance.telemetryNotifier.value = const CardsTelemetryData();
    });

    test('detectCardZone accurately identifies header, body, and unhit space', () {
      final cards = [testCard];

      // 1. Outside
      final outsideMatch = CardsTelemetryController.detectCardZone(
        cards: cards,
        selectedCardId: null,
        canvasPoint: const Offset(50, 50),
      );
      expect(outsideMatch.zone, equals(CardHoverZone.none));
      expect(outsideMatch.card, isNull);

      // 2. Header (top 36px: y from 100 to 136)
      final headerMatch = CardsTelemetryController.detectCardZone(
        cards: cards,
        selectedCardId: null,
        canvasPoint: const Offset(150, 115),
      );
      expect(headerMatch.zone, equals(CardHoverZone.header));
      expect(headerMatch.card?.id, equals('card_1'));

      // 3. Body (below header: y from 136 to 400)
      final bodyMatch = CardsTelemetryController.detectCardZone(
        cards: cards,
        selectedCardId: null,
        canvasPoint: const Offset(200, 200),
      );
      expect(bodyMatch.zone, equals(CardHoverZone.body));
      expect(bodyMatch.card?.id, equals('card_1'));
    });

    test('detectCardZone accurately detects resize handles for selected cards', () {
      final cards = [testCard];
      const selectedCardId = 'card_1';

      // 1. Corner handle: bottom-right at (x: 500, y: 400) with cornerSize = 24.0
      final cornerMatch = CardsTelemetryController.detectCardZone(
        cards: cards,
        selectedCardId: selectedCardId,
        canvasPoint: const Offset(490, 390),
      );
      expect(cornerMatch.zone, equals(CardHoverZone.corner));
      expect(cornerMatch.card?.id, equals('card_1'));

      // 2. Right edge handle: x around 500, y at middle (200)
      final rightEdgeMatch = CardsTelemetryController.detectCardZone(
        cards: cards,
        selectedCardId: selectedCardId,
        canvasPoint: const Offset(500, 200),
      );
      expect(rightEdgeMatch.zone, equals(CardHoverZone.rightEdge));
      expect(rightEdgeMatch.card?.id, equals('card_1'));

      // 3. Bottom edge handle: x at middle (250), y around 400
      final bottomEdgeMatch = CardsTelemetryController.detectCardZone(
        cards: cards,
        selectedCardId: selectedCardId,
        canvasPoint: const Offset(250, 400),
      );
      expect(bottomEdgeMatch.zone, equals(CardHoverZone.bottomEdge));
      expect(bottomEdgeMatch.card?.id, equals('card_1'));
    });

    test('Drag and Resize lifecycle updates telemetry data and interaction flags', () {
      final ctrl = CardsTelemetryController.instance;

      // Start drag
      ctrl.startCardDrag(cardId: 'card_1');
      expect(ctrl.current.isDraggingCard, isTrue);
      expect(ctrl.current.isInteractingWithCard, isTrue);
      expect(ctrl.current.activeInteractionZone, equals(CardHoverZone.header));

      // Update drag delta
      ctrl.updateCardDragDelta(const Offset(45.5, -20.0));
      expect(ctrl.current.dragDelta, equals(const Offset(45.5, -20.0)));

      // End drag
      ctrl.endCardDrag();
      expect(ctrl.current.isDraggingCard, isFalse);
      expect(ctrl.current.isInteractingWithCard, isFalse);
      expect(ctrl.current.dragDelta, equals(Offset.zero));

      // Start resize
      ctrl.startCardResize(cardId: 'card_1', handle: CardHoverZone.corner);
      expect(ctrl.current.isResizingCard, isTrue);
      expect(ctrl.current.isInteractingWithCard, isTrue);
      expect(ctrl.current.activeInteractionZone, equals(CardHoverZone.corner));

      // Update resize delta and target size
      ctrl.updateCardResize(delta: const Offset(100, 80), currentSize: const Size(500, 380));
      expect(ctrl.current.resizeDelta, equals(const Offset(100, 80)));
      expect(ctrl.current.currentResizeSize, equals(const Size(500, 380)));

      // End resize
      ctrl.endCardResize();
      expect(ctrl.current.isResizingCard, isFalse);
      expect(ctrl.current.isInteractingWithCard, isFalse);
    });

    testWidgets('CardsDebugOverlay renders HUD and Painter cleanly without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardsDebugOverlay(
              cards: [testCard],
              selectedCardId: 'card_1',
              panOffset: Offset.zero,
              zoomScale: 1.0,
              mousePos: const Offset(150, 120),
              isVisible: true,
            ),
          ),
        ),
      );

      // Verify HUD exists
      expect(find.textContaining('CARDS TELEMETRY HUD [F2]'), findsOneWidget);
      expect(find.textContaining('Hover Zone:'), findsOneWidget);
      expect(find.textContaining('Alvo HitTest'), findsOneWidget);
    });
  });
}
