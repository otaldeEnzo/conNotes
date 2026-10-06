import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/models/pdf_text_search_models.dart';
import 'package:connotes_app/services/pdf_document_service.dart';
import 'package:connotes_app/widgets/ink_models.dart';
import 'package:connotes_app/widgets/pdf_card_floating_pill.dart';
import 'package:connotes_app/widgets/pdf_search_highlight_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CanvasCardModel createTestCard({
    PdfDisplayMode displayMode = PdfDisplayMode.continuous,
    bool invertLuminance = false,
    bool isPdfLocked = false,
    int currentPdfPage = 1,
    int totalPdfPages = 10,
    String? pdfPath = 'test.pdf',
    double width = 400.0,
    double height = 600.0,
  }) {
    return CanvasCardModel(
      id: 'geom_card_test',
      title: 'Geometria e Zoom Test',
      cardType: CardType.pdf,
      x: 100.0,
      y: 100.0,
      width: width,
      height: height,
      pdfPath: pdfPath,
      pdfDisplayMode: displayMode,
      currentPdfPage: currentPdfPage,
      totalPdfPages: totalPdfPages,
      invertLuminance: invertLuminance,
      isPdfLocked: isPdfLocked,
    );
  }

  group('Adversarial Challenge 1: Zoom Invariance Scaling Math (0.01x to 10.0x & Extremes)', () {
    double computePillScale(double zoom) {
      final safeZoom = (zoom > 0) ? zoom : 1.0;
      return (1.0 / safeZoom).clamp(0.5, 3.0);
    }

    test('Formula evaluation across wide range (0.01x to 10.0x)', () {
      // Clamped to upper bound (3.0) for extreme zoom-out
      expect(computePillScale(0.001), equals(3.0));
      expect(computePillScale(0.01), equals(3.0));
      expect(computePillScale(0.05), equals(3.0));
      expect(computePillScale(0.1), equals(3.0));
      expect(computePillScale(0.25), equals(3.0));
      expect(computePillScale(1.0 / 3.0), closeTo(3.0, 1e-9));

      // Unclamped linear range (1.0 / zoomScale) between [0.3333333, 2.0]
      expect(computePillScale(0.5), equals(2.0));
      expect(computePillScale(0.8), closeTo(1.25, 1e-9));
      expect(computePillScale(1.0), equals(1.0));
      expect(computePillScale(1.25), closeTo(0.8, 1e-9));
      expect(computePillScale(1.5), closeTo(2.0 / 3.0, 1e-9));
      expect(computePillScale(2.0), equals(0.5));

      // Clamped to lower bound (0.5) for extreme zoom-in
      expect(computePillScale(2.5), equals(0.5));
      expect(computePillScale(4.0), equals(0.5));
      expect(computePillScale(10.0), equals(0.5));
      expect(computePillScale(100.0), equals(0.5));
    });

    test('Formula resilience against hostile inputs: zero, negative, NaN, infinity', () {
      // Zero zoom -> safeZoom = 1.0 -> scale = 1.0
      expect(computePillScale(0.0), equals(1.0));

      // Negative zoom -> safeZoom = 1.0 -> scale = 1.0
      expect(computePillScale(-0.5), equals(1.0));
      expect(computePillScale(-10.0), equals(1.0));

      // Infinity -> safeZoom = double.infinity -> 1.0 / inf = 0.0 -> clamped to 0.5
      expect(computePillScale(double.infinity), equals(0.5));

      // Negative Infinity -> (negInf > 0 is false) -> safeZoom = 1.0 -> scale = 1.0
      expect(computePillScale(double.negativeInfinity), equals(1.0));

      // NaN -> (NaN > 0 is false) -> safeZoom = 1.0 -> scale = 1.0
      expect(computePillScale(double.nan), equals(1.0));
    });

    testWidgets('PdfCardFloatingPill renders without error at zoom 0.01x (extreme zoom out)', (tester) async {
      final card = createTestCard();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: card,
                zoomScale: 0.01,
                onUpdateCard: (_) {},
              ),
            ),
          ),
        ),
      );

      final transformFinder = find.byType(Transform);
      expect(transformFinder, findsWidgets);

      final transform = tester.widget<Transform>(transformFinder.first);
      expect(transform.alignment, equals(Alignment.bottomCenter));
      expect(transform.transform.storage[0], closeTo(3.0, 1e-4));
      expect(transform.transform.storage[5], closeTo(3.0, 1e-4));
    });

    testWidgets('PdfCardFloatingPill renders without error at zoom 10.0x (extreme zoom in)', (tester) async {
      final card = createTestCard();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: card,
                zoomScale: 10.0,
                onUpdateCard: (_) {},
              ),
            ),
          ),
        ),
      );

      final transformFinder = find.byType(Transform);
      expect(transformFinder, findsWidgets);

      final transform = tester.widget<Transform>(transformFinder.first);
      expect(transform.alignment, equals(Alignment.bottomCenter));
      expect(transform.transform.storage[0], closeTo(0.5, 1e-4));
      expect(transform.transform.storage[5], closeTo(0.5, 1e-4));
    });

    testWidgets('Dynamic zoom sweep across 20 values from 0.01x to 10.0x does not throw or crash', (tester) async {
      final card = createTestCard();
      final zoomNotifier = ValueNotifier<double>(1.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: card,
                zoomNotifier: zoomNotifier,
                onUpdateCard: (_) {},
              ),
            ),
          ),
        ),
      );

      final zoomTestValues = [
        0.01, 0.02, 0.05, 0.1, 0.2, 0.33, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 4.0, 5.0, 7.5, 10.0
      ];

      for (final z in zoomTestValues) {
        zoomNotifier.value = z;
        await tester.pump();

        final transform = tester.widget<Transform>(find.byType(Transform).first);
        final expectedScale = computePillScale(z);
        expect(transform.transform.storage[0], closeTo(expectedScale, 1e-4),
            reason: 'Failed at zoom $z');
      }
    });
  });

  group('Adversarial Challenge 2: 72 DPI PDF Point to Canvas Pixel Transformation', () {
    test('Exact affine scale factor calculation and transformation', () {
      // Standard A4: 595.28 x 841.89 pt (72 DPI)
      const nativeA4Width = 595.28;
      const nativeA4Height = 841.89;

      // Card width on canvas = 400px
      const cardWidth = 400.0;
      final cardHeight = cardWidth * (nativeA4Height / nativeA4Width); // 565.71px

      final scaleX = cardWidth / nativeA4Width;
      final scaleY = cardHeight / nativeA4Height;

      expect(scaleX, closeTo(scaleY, 1e-5), reason: 'Aspect ratio preservation guarantees isotropic scaling');

      // A search match rect: 50pt from left, 100pt from top, 200pt wide, 14pt high
      const rawRect = Rect.fromLTWH(50.0, 100.0, 200.0, 14.0);

      final scaledRect = Rect.fromLTRB(
        rawRect.left * scaleX,
        rawRect.top * scaleY,
        rawRect.right * scaleX,
        rawRect.bottom * scaleY,
      );

      expect(scaledRect.left, closeTo(50.0 * scaleX, 1e-4));
      expect(scaledRect.top, closeTo(100.0 * scaleY, 1e-4));
      expect(scaledRect.width, closeTo(200.0 * scaleX, 1e-4));
      expect(scaledRect.height, closeTo(14.0 * scaleY, 1e-4));

      // Check boundary: A rect covering entire page should scale to exact card bounds
      const fullPageRect = Rect.fromLTWH(0.0, 0.0, nativeA4Width, nativeA4Height);
      final scaledFull = Rect.fromLTRB(
        fullPageRect.left * scaleX,
        fullPageRect.top * scaleY,
        fullPageRect.right * scaleX,
        fullPageRect.bottom * scaleY,
      );
      expect(scaledFull.left, equals(0.0));
      expect(scaledFull.top, equals(0.0));
      expect(scaledFull.right, closeTo(cardWidth, 1e-4));
      expect(scaledFull.bottom, closeTo(cardHeight, 1e-4));
    });

    test('Landscape orientation transformation retains correct proportions', () {
      // US Letter Landscape: 792 x 612 pt
      const nativeWidth = 792.0;
      const nativeHeight = 612.0;
      const cardWidth = 600.0;
      const cardHeight = cardWidth * (nativeHeight / nativeWidth); // ~463.636px

      final scaleX = cardWidth / nativeWidth;
      final scaleY = cardHeight / nativeHeight;

      expect(scaleX, closeTo(scaleY, 1e-5));
      expect(scaleX, closeTo(600.0 / 792.0, 1e-5));
    });

    test('PdfPageSearchHighlightPainter returns immediately on zero or negative native dimensions', () {
      final match = PdfTextMatch(
        pageNumber: 1,
        charStartIndex: 0,
        charLength: 5,
        rects: const [Rect.fromLTWH(10, 10, 100, 20)],
        globalIndex: 0,
      );

      // Verify shouldRepaint
      final painterA = PdfPageSearchHighlightPainter(
        matches: [match],
        pageWidth: 400.0,
        pageHeight: 600.0,
        pdfNativeWidth: 612.0,
        pdfNativeHeight: 792.0,
      );

      final painterB = PdfPageSearchHighlightPainter(
        matches: [match],
        pageWidth: 400.0,
        pageHeight: 600.0,
        pdfNativeWidth: 612.0,
        pdfNativeHeight: 792.0,
      );

      expect(painterA.shouldRepaint(painterB), isFalse);

      final painterC = PdfPageSearchHighlightPainter(
        matches: [match],
        pageWidth: 420.0, // changed width
        pageHeight: 600.0,
        pdfNativeWidth: 612.0,
        pdfNativeHeight: 792.0,
      );
      expect(painterA.shouldRepaint(painterC), isTrue);

      // Zero or negative native dimensions should not throw
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final zeroWidthPainter = PdfPageSearchHighlightPainter(
        matches: [match],
        pageWidth: 400.0,
        pageHeight: 600.0,
        pdfNativeWidth: 0.0,
        pdfNativeHeight: 792.0,
      );
      expect(() => zeroWidthPainter.paint(canvas, const Size(400, 600)), returnsNormally);

      final zeroHeightPainter = PdfPageSearchHighlightPainter(
        matches: [match],
        pageWidth: 400.0,
        pageHeight: 600.0,
        pdfNativeWidth: 612.0,
        pdfNativeHeight: 0.0,
      );
      expect(() => zeroHeightPainter.paint(canvas, const Size(400, 600)), returnsNormally);

      final negPainter = PdfPageSearchHighlightPainter(
        matches: [match],
        pageWidth: 400.0,
        pageHeight: 600.0,
        pdfNativeWidth: -100.0,
        pdfNativeHeight: -200.0,
      );
      expect(() => negPainter.paint(canvas, const Size(400, 600)), returnsNormally);
    });

    testWidgets('PdfPageSearchHighlightPainter draws inactive and active matches inside CustomPaint', (tester) async {
      final inactiveMatch = PdfTextMatch(
        pageNumber: 1,
        charStartIndex: 10,
        charLength: 4,
        rects: const [Rect.fromLTWH(50, 100, 100, 20)],
        globalIndex: 0,
      );
      final activeMatch = PdfTextMatch(
        pageNumber: 1,
        charStartIndex: 30,
        charLength: 4,
        rects: const [Rect.fromLTWH(50, 200, 100, 20)],
        globalIndex: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 600,
                child: CustomPaint(
                  painter: PdfPageSearchHighlightPainter(
                    matches: [inactiveMatch, activeMatch],
                    activeMatch: activeMatch,
                    pageWidth: 400.0,
                    pageHeight: 600.0,
                    pdfNativeWidth: 612.0,
                    pdfNativeHeight: 792.0,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('Adversarial Challenge 3: PDF Export Action & Annotation Pipeline', () {
    test('PdfDocumentService.shouldExcludePage correctly filters 1-based indices without off-by-one errors', () {
      final excluded = [2, 5, 8];

      expect(PdfDocumentService.shouldExcludePage(1, excluded), isFalse);
      expect(PdfDocumentService.shouldExcludePage(2, excluded), isTrue);
      expect(PdfDocumentService.shouldExcludePage(3, excluded), isFalse);
      expect(PdfDocumentService.shouldExcludePage(4, excluded), isFalse);
      expect(PdfDocumentService.shouldExcludePage(5, excluded), isTrue);
      expect(PdfDocumentService.shouldExcludePage(6, excluded), isFalse);
      expect(PdfDocumentService.shouldExcludePage(7, excluded), isFalse);
      expect(PdfDocumentService.shouldExcludePage(8, excluded), isTrue);
      expect(PdfDocumentService.shouldExcludePage(9, excluded), isFalse);
    });

    test('PdfDocumentService.getStrokesForPage retrieves page-local strokes with zero cross-page bleed', () {
      final strokeA = InkStroke(
        id: 's_p1_1',
        points: [StrokePoint(point: const Offset(10, 10), pressure: 1.0)],
        color: Colors.blue,
        strokeWidth: 2.0,
        toolType: InkToolType.technical,
      );
      final strokeB = InkStroke(
        id: 's_p3_1',
        points: [StrokePoint(point: const Offset(20, 20), pressure: 1.0)],
        color: Colors.red,
        strokeWidth: 4.0,
        toolType: InkToolType.highlighter,
      );

      final strokesMap = <int, List<InkStroke>>{
        1: [strokeA],
        3: [strokeB],
      };

      // Page 1 has strokeA
      final p1 = PdfDocumentService.getStrokesForPage(1, strokesMap);
      expect(p1.length, equals(1));
      expect(p1.first.id, equals('s_p1_1'));

      // Page 2 has NO strokes (must return empty list, NOT bleed from Page 1)
      final p2 = PdfDocumentService.getStrokesForPage(2, strokesMap);
      expect(p2, isEmpty);

      // Page 3 has strokeB
      final p3 = PdfDocumentService.getStrokesForPage(3, strokesMap);
      expect(p3.length, equals(1));
      expect(p3.first.id, equals('s_p3_1'));

      // Page 4 has NO strokes (must return empty list, NOT bleed from Page 3)
      final p4 = PdfDocumentService.getStrokesForPage(4, strokesMap);
      expect(p4, isEmpty);
    });

    testWidgets('Export button in PdfCardFloatingPill invokes callback when tapped', (tester) async {
      bool exported = false;
      final card = createTestCard();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: card,
                onUpdateCard: (_) {},
                onExportAnnotatedPdf: () {
                  exported = true;
                },
              ),
            ),
          ),
        ),
      );

      final downloadButton = find.byTooltip('Exportar PDF com anotacoes');
      expect(downloadButton, findsOneWidget);

      await tester.tap(downloadButton);
      await tester.pumpAndSettle();

      expect(exported, isTrue);
    });

    testWidgets('Export with empty pdfPath displays error feedback SnackBar and does not crash', (tester) async {
      final card = createTestCard(pdfPath: '');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: card,
                onUpdateCard: (_) {},
              ),
            ),
          ),
        ),
      );

      final downloadButton = find.byTooltip('Exportar PDF com anotacoes');
      expect(downloadButton, findsOneWidget);

      await tester.tap(downloadButton);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Nenhum documento PDF vinculado para exportacao.'), findsOneWidget);
    });
  });

  group('Adversarial Challenge 4: STRICT ZERO EMOJIS Across All Milestone 3 Files', () {
    test('Zero emojis in implementation source files', () {
      final targetFiles = [
        'lib/models/pdf_text_search_models.dart',
        'lib/services/pdf_search_engine.dart',
        'lib/services/pdf_document_service.dart',
        'lib/widgets/pdf_search_highlight_painter.dart',
        'lib/widgets/pdf_search_pill_input.dart',
        'lib/widgets/pdf_page_subcard_widget.dart',
        'lib/widgets/canvas_card_pdf_view.dart',
        'lib/widgets/pdf_card_floating_pill.dart',
        'lib/widgets/svg_icon.dart',
        'test/pdf_card_floating_pill_test.dart',
        'test/pdf_card_widget_test.dart',
      ];

      // Regex matching Unicode emoji ranges (emoticons, pictographs, transport/map, supplemental, dingbats)
      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}]',
        unicode: true,
      );

      for (final relPath in targetFiles) {
        final file = File(relPath);
        if (!file.existsSync()) continue;

        final content = file.readAsStringSync();
        final matches = emojiRegex.allMatches(content);

        expect(
          matches.isEmpty,
          isTrue,
          reason: 'File $relPath contains forbidden emoji: ${matches.map((m) => m.group(0)).toList()}',
        );
      }
    });
  });
}
