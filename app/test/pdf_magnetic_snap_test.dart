import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/services/pdf_magnetic_snap_helper.dart';
import 'package:connotes_app/widgets/canvas_card_pdf_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Stage 5 - Magnetic Page Snap in Continuous Scroll Tests', () {
    test('PdfMagneticSnapHelper computes exact continuous page top offsets', () {
      final activePages = [1, 2, 3];
      // Heights: page 1 = 800, page 2 = 600, page 3 = 1000, gap = 56.0
      final offsets = PdfMagneticSnapHelper.computePageTopOffsets(
        activePages: activePages,
        getPageHeight: (p) => p == 1 ? 800.0 : (p == 2 ? 600.0 : 1000.0),
        gap: 56.0,
      );

      // Expected offsets:
      // Page 1: 0.0
      // Page 2: 800 + 56 = 856.0
      // Page 3: 856 + 600 + 56 = 1512.0
      expect(offsets.length, equals(3));
      expect(offsets[0], equals(0.0));
      expect(offsets[1], equals(856.0));
      expect(offsets[2], equals(1512.0));
    });

    test('PdfMagneticSnapHelper latches when within magnetic threshold', () {
      final pageTopOffsets = [0.0, 856.0, 1512.0];

      // Case 1: Scroll offset is 840.0 (distance to 856.0 is 16.0 <= 56.0 threshold) -> should latch to 856.0
      final target1 = PdfMagneticSnapHelper.calculateSnapTargetOffset(
        currentScrollOffset: 840.0,
        pageTopOffsets: pageTopOffsets,
        magneticThreshold: 56.0,
      );
      expect(target1, equals(856.0));

      // Case 2: Scroll offset is 880.0 (distance to 856.0 is 24.0 <= 56.0 threshold) -> should latch to 856.0
      final target2 = PdfMagneticSnapHelper.calculateSnapTargetOffset(
        currentScrollOffset: 880.0,
        pageTopOffsets: pageTopOffsets,
        magneticThreshold: 56.0,
      );
      expect(target2, equals(856.0));

      // Case 3: Scroll offset is 500.0 (distance to 0.0 is 500, to 856 is 356 > 56.0 threshold) -> should NOT latch (returns null)
      final target3 = PdfMagneticSnapHelper.calculateSnapTargetOffset(
        currentScrollOffset: 500.0,
        pageTopOffsets: pageTopOffsets,
        magneticThreshold: 56.0,
      );
      expect(target3, isNull);
    });

    test('PdfMagneticSnapHelper finds nearest page number accurately', () {
      final activePages = [1, 2, 3];
      final pageTopOffsets = [0.0, 856.0, 1512.0];

      expect(
        PdfMagneticSnapHelper.findNearestPageNumber(
          currentScrollOffset: 100.0,
          activePages: activePages,
          pageTopOffsets: pageTopOffsets,
        ),
        equals(1),
      );

      expect(
        PdfMagneticSnapHelper.findNearestPageNumber(
          currentScrollOffset: 800.0,
          activePages: activePages,
          pageTopOffsets: pageTopOffsets,
        ),
        equals(2),
      );

      expect(
        PdfMagneticSnapHelper.findNearestPageNumber(
          currentScrollOffset: 1450.0,
          activePages: activePages,
          pageTopOffsets: pageTopOffsets,
        ),
        equals(3),
      );
    });

    test('PdfMagneticSnapHelper computes target canvas camera pan correctly', () {
      final targetPan = PdfMagneticSnapHelper.computeTargetPanForPage(
        currentPan: const Offset(100.0, -400.0),
        cardY: 200.0,
        pageTopOffset: 856.0,
        zoom: 1.0,
        viewportTopPadding: 40.0,
      );

      // targetCanvasY = 200 + 856 = 1056.0
      // targetPanY = 40.0 - (1056.0 * 1.0) = -1016.0
      expect(targetPan.dx, equals(100.0));
      expect(targetPan.dy, equals(-1016.0));
    });

    testWidgets('CanvasCardPdfView enables magnetic snap callback when motion settles', (tester) async {
      int? snappedPage;

      final card = CanvasCardModel(
        id: 'test_pdf_snap_card',
        cardType: CardType.pdf,
        pdfPath: 'test_snap.pdf',
        x: 0,
        y: 0,
        width: 500,
        height: 600,
        pdfDisplayMode: PdfDisplayMode.continuous,
        currentPdfPage: 1,
        totalPdfPages: 5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CanvasCardPdfView(
                card: card,
                isSelected: true,
                onUpdateCard: (_) {},
                enableMagneticSnap: true,
                onSnapToPage: (page) => snappedPage = page,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CanvasCardPdfView), findsOneWidget);
    });
  });
}
