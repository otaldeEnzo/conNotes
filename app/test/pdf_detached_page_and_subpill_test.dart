import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/services/cards_telemetry_controller.dart';
import 'package:connotes_app/widgets/pdf_card_floating_pill.dart';
import 'package:connotes_app/widgets/card_format_floating_pill.dart';
import 'package:connotes_app/widgets/svg_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CanvasCardModel isDetached Tests', () {
    test('isDetached defaults to false', () {
      final card = CanvasCardModel(
        id: 'card_pdf_1',
        cardType: CardType.pdf,
        x: 100,
        y: 100,
        width: 400,
        height: 600,
      );
      expect(card.isDetached, isFalse);
    });

    test('calculateMinHeight includes 28px header when isDetached is true even with sourceMasterCardId', () {
      const double w = 400.0;
      const double ratio = 1.0 / 1.4142;
      final double expectedPageH = w / ratio;

      final attachedSisterCard = CanvasCardModel(
        id: 'sister_1',
        cardType: CardType.pdf,
        x: 100,
        y: 100,
        width: w,
        height: 500,
        sourceMasterCardId: 'master_1',
        isDetached: false,
      );
      // Sister page in continuous column has 0px header
      expect(attachedSisterCard.calculateMinHeight(), closeTo(expectedPageH, 0.1));

      final detachedCard = attachedSisterCard.copyWith(isDetached: true);
      // Detached page is an autonomous canvas card, so it has 28px header
      expect(detachedCard.calculateMinHeight(), closeTo(expectedPageH + 28.0, 0.1));
    });

    test('copyWith and json serialization preserve isDetached', () {
      final card = CanvasCardModel(
        id: 'card_det',
        cardType: CardType.pdf,
        x: 50,
        y: 60,
        isDetached: true,
        sourceMasterCardId: 'master_root',
      );
      expect(card.isDetached, isTrue);

      final copy = card.copyWith(title: 'Updated Detached');
      expect(copy.isDetached, isTrue);

      final json = card.toJson();
      expect(json['isDetached'], isTrue);

      final fromJson = CanvasCardModel.fromJson(json);
      expect(fromJson.isDetached, isTrue);
    });
  });

  group('CardsTelemetryController PDF Floating Pill Hitbox Tests', () {
    test('detectCardZone captures floating pill area above CardType.pdf', () {
      final card = CanvasCardModel(
        id: 'pdf_card_test',
        cardType: CardType.pdf,
        x: 200,
        y: 300,
        width: 500,
        height: 700,
      );

      final hitResult = CardsTelemetryController.detectCardZone(
        canvasPoint: const Offset(300, 260), // 40px above card top
        cards: [card],
        selectedCardId: card.id,
      );

      expect(hitResult.card?.id, equals(card.id));
      expect(hitResult.zone, equals(CardHoverZone.body));
    });
  });

  group('PdfCardFloatingPill Detach vs Reattach Button Logic', () {
    testWidgets('Master card shows detach button and hides reattach to master button', (tester) async {
      final masterCard = CanvasCardModel(
        id: 'master_pdf',
        cardType: CardType.pdf,
        x: 100,
        y: 100,
        width: 400,
        height: 600,
        totalPdfPages: 5,
        currentPdfPage: 1,
        sourceMasterCardId: null,
        isDetached: false,
      );

      bool detachedCalled = false;
      bool reattachCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfCardFloatingPill(
              card: masterCard,
              zoomScale: 1.0,
              onUpdateCard: (_) {},
              onDetachCurrentPage: () => detachedCalled = true,
              onReattachToMaster: () => reattachCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Detach button (icon 'share') should be found
      final shareFinder = find.byWidgetPredicate(
        (w) => w is SvgIcon && w.name == 'share',
      );
      expect(shareFinder, findsOneWidget);

      // Reattach to master button (icon 'link') should NOT be found
      final linkFinder = find.byWidgetPredicate(
        (w) => w is SvgIcon && w.name == 'link',
      );
      expect(linkFinder, findsNothing);
    });

    testWidgets('Detached card hides detach button and shows reattach to master button', (tester) async {
      final detachedCard = CanvasCardModel(
        id: 'detached_pdf_page_2',
        cardType: CardType.pdf,
        x: 600,
        y: 100,
        width: 400,
        height: 600,
        totalPdfPages: 5,
        currentPdfPage: 2,
        sourceMasterCardId: 'master_pdf',
        isDetached: true,
      );

      bool reattachCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfCardFloatingPill(
              card: detachedCard,
              zoomScale: 1.0,
              onUpdateCard: (_) {},
              onDetachCurrentPage: () {},
              onReattachToMaster: () => reattachCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Detach button (icon 'share') should NOT be found
      final shareFinder = find.byWidgetPredicate(
        (w) => w is SvgIcon && w.name == 'share',
      );
      expect(shareFinder, findsNothing);

      // Reattach button (icon 'link') SHOULD be found
      final linkFinder = find.byWidgetPredicate(
        (w) => w is SvgIcon && w.name == 'link',
      );
      expect(linkFinder, findsOneWidget);

      await tester.tap(linkFinder);
      await tester.pumpAndSettle();
      expect(reattachCalled, isTrue);
    });

    testWidgets('Sub-pill display modes options are tappable and trigger callback', (tester) async {
      PdfDisplayMode? selectedMode;
      final masterCard = CanvasCardModel(
        id: 'master_pdf_mode',
        cardType: CardType.pdf,
        x: 100,
        y: 100,
        width: 400,
        height: 600,
        totalPdfPages: 3,
        currentPdfPage: 1,
        pdfDisplayMode: PdfDisplayMode.singlePage,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfCardFloatingPill(
              card: masterCard,
              zoomScale: 1.0,
              onUpdateCard: (updated) {
                selectedMode = updated.pdfDisplayMode;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Display Modes trigger in main pill (icon 'layers')
      final layersTrigger = find.byWidgetPredicate(
        (w) => w is SvgIcon && w.name == 'layers',
      );
      expect(layersTrigger, findsOneWidget);
      await tester.tap(layersTrigger);
      await tester.pumpAndSettle();

      // Sub-pill options should now be visible: 'Coluna Contínua', 'Página Única', 'Grade / Mesa'
      expect(find.text('Coluna Contínua'), findsOneWidget);
      expect(find.text('Grade / Mesa'), findsOneWidget);

      // Tap 'Coluna Contínua'
      await tester.tap(find.text('Coluna Contínua'));
      await tester.pumpAndSettle();

      expect(selectedMode, equals(PdfDisplayMode.continuous));
    });
  });

  group('Zero Emojis Compliance', () {
    test('Zero emojis in modified source files', () {
      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]',
        unicode: true,
      );

      final files = [
        'lib/models/canvas_card_model.dart',
        'lib/services/cards_telemetry_controller.dart',
        'lib/widgets/pdf_card_floating_pill.dart',
        'lib/widgets/canvas_card_widget.dart',
      ];

      for (final relPath in files) {
        final file = File(relPath);
        if (file.existsSync()) {
          final content = file.readAsStringSync();
          expect(emojiRegex.hasMatch(content), isFalse,
              reason: 'File $relPath must contain zero emojis.');
        }
      }
    });
  });
}
