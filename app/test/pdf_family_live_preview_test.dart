import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/widgets/canvas_cards_layer.dart';
import 'package:connotes_app/widgets/pdf_corner_resize_handle.dart';
import 'package:connotes_app/widgets/pdf_card_floating_pill.dart';
import 'package:connotes_app/controllers/pdf_family_live_preview_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDF Family Live Preview & Floating Pill Invariance Tests', () {
    testWidgets('Resizing Page 1 updates family live preview and commits to onUpdateCard', (tester) async {
      final updatedCards = <String, CanvasCardModel>{};

      final page1 = CanvasCardModel(
        id: 'doc_p1',
        title: 'Doc (Pag. 1)',
        cardType: CardType.pdf,
        pdfPath: 'test.pdf',
        pdfDisplayMode: PdfDisplayMode.singlePage,
        currentPdfPage: 1,
        totalPdfPages: 2,
        width: 300,
        height: 424.26,
        x: 100,
        y: 100,
        sourceMasterCardId: null,
      );

      final page2 = CanvasCardModel(
        id: 'doc_p2',
        title: 'Doc (Pag. 2)',
        cardType: CardType.pdf,
        pdfPath: 'test.pdf',
        pdfDisplayMode: PdfDisplayMode.singlePage,
        currentPdfPage: 2,
        totalPdfPages: 2,
        width: 300,
        height: 424.26,
        x: 100,
        y: 100 + 424.26 + 28.0 + 56.0,
        sourceMasterCardId: 'doc_p1',
      );

      final panNotifier = ValueNotifier<Offset>(Offset.zero);
      final zoomNotifier = ValueNotifier<double>(1.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasCardsLayer(
              cards: [page1, page2],
              selectedCardId: page1.id,
              panNotifier: panNotifier,
              zoomNotifier: zoomNotifier,
              onUpdateCard: (c) => updatedCards[c.id] = c,
              onSelectCard: (_) {},
              onDeleteCard: (_) {},
              onDuplicateCard: (_) {},
            ),
          ),
        ),
      );

      // Verify exactly 1 floating pill is rendered above Page 1
      expect(find.byType(PdfCardFloatingPill), findsOneWidget);

      // Verify Page 1 has 1 corner handle (exclusively bottom-right)
      expect(find.byType(PdfCornerResizeHandle), findsOneWidget);

      // Drag bottom-right corner of Page 1
      final brHandle = find.byType(PdfCornerResizeHandle);
      await tester.drag(brHandle, const Offset(60, 85));
      await tester.pump();

      // Check committed updates
      expect(updatedCards.containsKey('doc_p1'), isTrue);
      expect(updatedCards['doc_p1']!.width, greaterThan(300));
      expect(updatedCards['doc_p1']!.height, greaterThan(424));

      // Page 2 must also have been updated in lockstep!
      expect(updatedCards.containsKey('doc_p2'), isTrue);
      expect(updatedCards['doc_p2']!.width, equals(updatedCards['doc_p1']!.width));
      expect(updatedCards['doc_p2']!.height, equals(updatedCards['doc_p1']!.height));
    });

    testWidgets('Floating pill counter-scales during live preview to remain 1.0x visual size', (tester) async {
      final page1 = CanvasCardModel(
        id: 'doc_p1',
        title: 'Doc (Pag. 1)',
        cardType: CardType.pdf,
        pdfPath: 'test.pdf',
        pdfDisplayMode: PdfDisplayMode.singlePage,
        currentPdfPage: 1,
        totalPdfPages: 2,
        width: 300,
        height: 424.26,
        x: 100,
        y: 100,
        sourceMasterCardId: null,
      );

      final panNotifier = ValueNotifier<Offset>(Offset.zero);
      final zoomNotifier = ValueNotifier<double>(1.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasCardsLayer(
              cards: [page1],
              selectedCardId: page1.id,
              panNotifier: panNotifier,
              zoomNotifier: zoomNotifier,
              onUpdateCard: (_) {},
              onSelectCard: (_) {},
              onDeleteCard: (_) {},
              onDuplicateCard: (_) {},
            ),
          ),
        ),
      );

      // Inject 2.0x scale into live preview controller
      PdfFamilyLivePreviewController.instance.beginInteraction('doc_p1');
      PdfFamilyLivePreviewController.instance.updateInteraction({
        'doc_p1': const PdfCardLiveTransform(
          scale: 2.0,
          translation: Offset.zero,
          finalWidth: 600,
          finalHeight: 848.52,
          finalX: 100,
          finalY: 100,
        ),
      });

      await tester.pump();

      // Find the counter-scale Transform widget inside floating pill
      final transforms = tester.widgetList<Transform>(find.descendant(
        of: find.byKey(const ValueKey('floating_pill')),
        matching: find.byType(Transform),
      )).toList();

      // One of the transforms must apply counterScale: 0.5 (1.0 / 2.0)
      final hasCounterScale = transforms.any((t) {
        final matrix = t.transform;
        final scaleX = matrix.storage[0];
        final scaleY = matrix.storage[5];
        return (scaleX - 0.5).abs() < 0.01 && (scaleY - 0.5).abs() < 0.01;
      });

      expect(hasCounterScale, isTrue, reason: 'Floating pill must counter-scale by 1/scale (0.5)');

      // End interaction
      PdfFamilyLivePreviewController.instance.endInteraction();
      await tester.pump();
    });

    test('Inter-page gap between Page 1 and Page 2 remains exactly 56px after arbitrary resizes', () {
      final page1 = CanvasCardModel(
        id: 'doc_p1',
        title: 'Doc (Pag. 1)',
        cardType: CardType.pdf,
        pdfPath: 'test.pdf',
        pdfDisplayMode: PdfDisplayMode.singlePage,
        currentPdfPage: 1,
        totalPdfPages: 2,
        width: 300,
        height: 424.26,
        x: 100,
        y: 100,
        sourceMasterCardId: null,
      );

      final page2 = CanvasCardModel(
        id: 'doc_p2',
        title: 'Doc (Pag. 2)',
        cardType: CardType.pdf,
        pdfPath: 'test.pdf',
        pdfDisplayMode: PdfDisplayMode.singlePage,
        currentPdfPage: 2,
        totalPdfPages: 2,
        width: 300,
        height: 424.26,
        x: 100,
        y: 100 + 424.26 + 28.0 + 56.0,
        sourceMasterCardId: 'doc_p1',
      );

      // Initial gap
      final initialGap = page2.y - (page1.y + page1.height + 28.0);
      expect((initialGap - 56.0).abs(), lessThan(0.01));

      // After resize to width 600 (2.0x):
      final ratio = PdfResizeMath.calculatePageAspectRatio(page1);
      final newWidth = 600.0;
      final newPage1Height = newWidth / ratio;
      final expectedPage2Y = page1.y + newPage1Height + 28.0 + 56.0;

      final updatedGap = expectedPage2Y - (page1.y + newPage1Height + 28.0);
      expect((updatedGap - 56.0).abs(), lessThan(0.01));
    });
  });
}

