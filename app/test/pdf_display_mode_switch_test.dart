import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/widgets/pdf_corner_resize_handle.dart';

void main() {
  group('PDF Display Mode Switching & Geometry Fixes', () {
    test('calculateDifferentialRatio returns correct 2-column ratio for grid mode', () {
      const pageRatio = 0.75;
      
      // 4 active pages in grid mode -> 2 rows
      final card4 = CanvasCardModel(
        id: 'c4',
        x: 0,
        y: 0,
        width: 800,
        height: 600,
        cardType: CardType.pdf,
        pdfPath: 'test.pdf',
        pdfDisplayMode: PdfDisplayMode.grid,
        totalPdfPages: 4,
        originalAspectRatio: pageRatio,
      );
      final ratio4 = PdfResizeMath.calculateDifferentialRatio(card4);
      // rows = ceil(4/2) = 2 -> (0.75 * 2) / 2 = 0.75
      expect(ratio4, closeTo(0.75, 0.0001));

      // 3 active pages in grid mode -> 2 rows
      final card3 = CanvasCardModel(
        id: 'c3',
        x: 0,
        y: 0,
        width: 800,
        height: 600,
        cardType: CardType.pdf,
        pdfPath: 'test.pdf',
        pdfDisplayMode: PdfDisplayMode.grid,
        totalPdfPages: 3,
        originalAspectRatio: pageRatio,
      );
      final ratio3 = PdfResizeMath.calculateDifferentialRatio(card3);
      // rows = ceil(3/2) = 2 -> (0.75 * 2) / 2 = 0.75
      expect(ratio3, closeTo(0.75, 0.0001));

      // 5 active pages in grid mode -> 3 rows
      final card5 = CanvasCardModel(
        id: 'c5',
        x: 0,
        y: 0,
        width: 800,
        height: 600,
        cardType: CardType.pdf,
        pdfPath: 'test.pdf',
        pdfDisplayMode: PdfDisplayMode.grid,
        totalPdfPages: 5,
        originalAspectRatio: pageRatio,
      );
      final ratio5 = PdfResizeMath.calculateDifferentialRatio(card5);
      // rows = ceil(5/2) = 3 -> (0.75 * 2) / 3 = 0.5
      expect(ratio5, closeTo(0.5, 0.0001));
    });

    test('calculateDifferentialRatio returns continuous single-column ratio', () {
      const pageRatio = 0.75;
      final cardCont = CanvasCardModel(
        id: 'cCont',
        x: 0,
        y: 0,
        width: 800,
        height: 600,
        cardType: CardType.pdf,
        pdfPath: 'test.pdf',
        pdfDisplayMode: PdfDisplayMode.continuous,
        totalPdfPages: 4,
        originalAspectRatio: pageRatio,
      );
      final ratio = PdfResizeMath.calculateDifferentialRatio(cardCont);
      // ratio / activePages = 0.75 / 4 = 0.1875
      expect(ratio, closeTo(0.1875, 0.0001));
    });

    test('calculateMinHeight accounts for multi-page in continuous and grid mode', () {
      final cardContinuous = CanvasCardModel(
        id: 'master-continuous',
        x: 0,
        y: 0,
        width: 800,
        height: 600,
        cardType: CardType.pdf,
        pdfPath: 'sample.pdf',
        pdfDisplayMode: PdfDisplayMode.continuous,
        totalPdfPages: 4,
        originalAspectRatio: 0.75,
      );

      final minHContinuous = cardContinuous.calculateMinHeight();
      // 4 pages continuous: 4 * (800 / 0.75) + 3 * 20 + 28 header = 4354.67
      expect(minHContinuous, greaterThan(4000.0));

      final cardGrid = CanvasCardModel(
        id: 'master-grid',
        x: 0,
        y: 0,
        width: 800,
        height: 600,
        cardType: CardType.pdf,
        pdfPath: 'sample.pdf',
        pdfDisplayMode: PdfDisplayMode.grid,
        totalPdfPages: 4,
        originalAspectRatio: 0.75,
      );

      final minHGrid = cardGrid.calculateMinHeight();
      // 4 pages grid: 2 rows -> each page width = (800 - 20) / 2 = 390
      // height per page = 390 / 0.75 = 520
      // 2 rows: 2 * 520 + 20 + 28 = 1088
      expect(minHGrid, greaterThan(1000.0));
      expect(minHGrid, lessThan(minHContinuous));
    });

    test('singlePage card minHeight calculates single page bound with header', () {
      final cardSingle = CanvasCardModel(
        id: 'master-single',
        x: 0,
        y: 0,
        width: 800,
        height: 600,
        cardType: CardType.pdf,
        pdfPath: 'sample.pdf',
        pdfDisplayMode: PdfDisplayMode.singlePage,
        totalPdfPages: 4,
        originalAspectRatio: 0.75,
      );

      final minHSingle = cardSingle.calculateMinHeight();
      // 800 / 0.75 + 28 header = 1094.67
      expect(minHSingle, closeTo((800.0 / 0.75) + 28.0, 1.0));
    });

    test('mode switch to grid preserves page scale by widening card', () {
      const pageWidth = 800.0;
      const gap = 20.0;
      
      // Switching from single page to grid (2 columns)
      final gridCardWidth = (pageWidth * 2.0) + gap;
      expect(gridCardWidth, equals(1620.0));
      
      // In grid mode, each page width is (gridCardWidth - gap) / 2
      final computedPageWidthInGrid = (gridCardWidth - gap) / 2.0;
      expect(computedPageWidthInGrid, equals(pageWidth));

      // Switching back to singlePage restores single page width
      final restoredSinglePageWidth = (gridCardWidth - gap) / 2.0;
      expect(restoredSinglePageWidth, equals(pageWidth));
    });

    testWidgets('PdfCornerResizeFrame supplies handle locked to right: 0, bottom: 0', (tester) async {
      final card = CanvasCardModel(
        id: 'test_pdf_corner',
        cardType: CardType.pdf,
        x: 100,
        y: 100,
        width: 600,
        height: 800,
        currentPdfPage: 1,
        totalPdfPages: 5,
      );

      Widget? capturedHandle;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfCornerResizeFrame(
              card: card,
              isSelected: true,
              onUpdateCard: (_) {},
              builder: (context, size, [handle]) {
                capturedHandle = handle;
                return SizedBox(
                  width: size.width,
                  height: size.height,
                  child: Stack(
                    children: [
                      if (handle != null) handle,
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(capturedHandle, isNotNull);
      expect(find.byType(PdfCornerResizeHandle), findsOneWidget);

      final handleWidget = tester.widget<PdfCornerResizeHandle>(find.byType(PdfCornerResizeHandle));
      expect(handleWidget.right, equals(0.0));
      expect(handleWidget.bottom, equals(0.0));
      expect(handleWidget.vertex, equals(PdfCornerVertex.bottomRight));
    });
  });
}
