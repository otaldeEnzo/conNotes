import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/canvas_card_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adversarial Stress Testing: calculateMinHeight()', () {
    test('Zero aspect ratio falls back safely to A4 proportion (clamped >= 100)', () {
      final card = CanvasCardModel(
        id: 'test_zero_ar',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        width: 300.0,
        originalAspectRatio: 0.0,
        pdfDisplayMode: PdfDisplayMode.singlePage,
      );

      final height = card.calculateMinHeight();
      expect(height.isNaN, isFalse);
      expect(height.isInfinite, isFalse);
      // Effective ratio should be 1.0 / 1.4142 = 0.7071
      // Expected singlePageHeight = 300 / 0.707106 = 424.26
      expect(height, closeTo(300.0 * 1.4142, 0.1));
      expect(height, greaterThanOrEqualTo(100.0));
    });

    test('Negative aspect ratio falls back safely to A4 proportion', () {
      final card = CanvasCardModel(
        id: 'test_neg_ar',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        width: 300.0,
        originalAspectRatio: -1.5,
        pdfDisplayMode: PdfDisplayMode.singlePage,
      );

      final height = card.calculateMinHeight();
      expect(height.isNaN, isFalse);
      expect(height.isInfinite, isFalse);
      expect(height, closeTo(300.0 * 1.4142, 0.1));
      expect(height, greaterThanOrEqualTo(100.0));
    });

    test('NaN aspect ratio falls back safely without crashing', () {
      final card = CanvasCardModel(
        id: 'test_nan_ar',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        width: 300.0,
        originalAspectRatio: double.nan,
        pdfDisplayMode: PdfDisplayMode.singlePage,
      );

      final height = card.calculateMinHeight();
      expect(height.isNaN, isFalse);
      expect(height, closeTo(300.0 * 1.4142, 0.1));
    });

    test('Infinite aspect ratio clamped to minimum height 100.0', () {
      final card = CanvasCardModel(
        id: 'test_inf_ar',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        width: 300.0,
        originalAspectRatio: double.infinity,
        pdfDisplayMode: PdfDisplayMode.singlePage,
      );

      final height = card.calculateMinHeight();
      expect(height, equals(100.0));
    });

    test('Zero totalPdfPages is clamped to minimum 1 active page', () {
      final card = CanvasCardModel(
        id: 'test_zero_pages',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        width: 300.0,
        originalAspectRatio: 1.0,
        totalPdfPages: 0,
        pdfDisplayMode: PdfDisplayMode.continuous,
      );

      final height = card.calculateMinHeight();
      // activePages = math.max(1, 0 - 0) = 1
      // singlePageHeight = 300 / 1.0 = 300.0
      // totalGaps = 0
      expect(height, equals(300.0));
    });

    test('Negative totalPdfPages is clamped to minimum 1 active page', () {
      final card = CanvasCardModel(
        id: 'test_neg_pages',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        width: 300.0,
        originalAspectRatio: 1.0,
        totalPdfPages: -10,
        pdfDisplayMode: PdfDisplayMode.continuous,
      );

      final height = card.calculateMinHeight();
      // activePages = math.max(1, -10 - 0) = 1
      expect(height, equals(300.0));
    });

    test('excludedPageIndices greater than or equal to totalPdfPages clamps activePages to 1', () {
      final card = CanvasCardModel(
        id: 'test_excluded_exceeds',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        width: 200.0,
        originalAspectRatio: 1.0,
        totalPdfPages: 2,
        excludedPageIndices: [0, 1, 2, 3, 4], // 5 excluded pages
        pdfDisplayMode: PdfDisplayMode.continuous,
      );

      final height = card.calculateMinHeight();
      // excludedCount = 5
      // activePages = math.max(1, 2 - 5) = 1
      // totalGaps = 0
      // height = 200.0
      expect(height, equals(200.0));
    });

    test('excludedPageIndices with duplicate indices handles deduplication correctly', () {
      final card = CanvasCardModel(
        id: 'test_excluded_duplicates',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        width: 200.0,
        originalAspectRatio: 1.0,
        totalPdfPages: 4,
        excludedPageIndices: [1, 1, 1, 1], // effectively 1 page excluded
        pdfPageGap: 20.0,
        pdfDisplayMode: PdfDisplayMode.continuous,
      );

      final height = card.calculateMinHeight();
      // excludedCount = 1 (toSet)
      // activePages = 4 - 1 = 3
      // singlePageHeight = 200
      // totalGaps = (3 - 1) * 20 = 40
      // totalHeight = 3 * 200 + 40 = 640.0
      expect(height, equals(640.0));
    });

    test('Zero width and negative width clamped to minimum 100.0', () {
      final cardZero = CanvasCardModel(
        id: 'test_zero_width',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        width: 0.0,
        pdfDisplayMode: PdfDisplayMode.continuous,
      );
      expect(cardZero.calculateMinHeight(), equals(100.0));

      final cardNeg = CanvasCardModel(
        id: 'test_neg_width',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        width: -400.0,
        pdfDisplayMode: PdfDisplayMode.continuous,
      );
      expect(cardNeg.calculateMinHeight(), equals(100.0));
    });

    test('isCollapsed returns exactly 36.0 regardless of PDF page count or dimensions', () {
      final card = CanvasCardModel(
        id: 'test_collapsed_priority',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        width: 800.0,
        totalPdfPages: 100,
        isCollapsed: true,
        pdfDisplayMode: PdfDisplayMode.continuous,
      );

      expect(card.calculateMinHeight(), equals(36.0));
    });

    test('Negative pdfPageGap does not reduce height below 100.0 clamp', () {
      final card = CanvasCardModel(
        id: 'test_neg_gap',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        width: 100.0,
        originalAspectRatio: 1.0,
        totalPdfPages: 5,
        pdfPageGap: -1000.0, // Adversarial negative gap
        pdfDisplayMode: PdfDisplayMode.continuous,
      );

      expect(card.calculateMinHeight(), greaterThanOrEqualTo(100.0));
    });

    test('Continuous mode with 1000 pages scales linearly without overflow', () {
      final card = CanvasCardModel(
        id: 'test_large_pages',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        width: 100.0,
        originalAspectRatio: 1.0,
        totalPdfPages: 1000,
        pdfPageGap: 10.0,
        pdfDisplayMode: PdfDisplayMode.continuous,
      );

      final height = card.calculateMinHeight();
      // 1000 * 100 + 999 * 10 = 100000 + 9990 = 109990.0
      expect(height, equals(109990.0));
    });
  });

  group('Adversarial Stress Testing: Stroke Indexing & Attached Strokes', () {
    test('pageAttachedStrokeIds supports negative and zero page numbers', () {
      final card = CanvasCardModel(
        id: 'test_neg_stroke_page',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        pageAttachedStrokeIds: {
          -1: ['neg_stroke_1'],
          0: ['zero_stroke_1'],
          10: ['pos_stroke_1'],
        },
      );

      expect(card.getStrokesForPage(-1), equals(['neg_stroke_1']));
      expect(card.getStrokesForPage(0), equals(['zero_stroke_1']));
      expect(card.getStrokesForPage(10), equals(['pos_stroke_1']));
      expect(card.getStrokesForPage(999), isEmpty);
    });

    test('allAttachedStrokeIds consolidates and deduplicates attachedStrokeIds and pageAttachedStrokeIds', () {
      final card = CanvasCardModel(
        id: 'test_consolidate_strokes',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        attachedStrokeIds: ['global_1', 'shared_stroke'],
        pageAttachedStrokeIds: {
          1: ['page1_stroke', 'shared_stroke'],
          2: ['page2_stroke'],
        },
      );

      final all = card.allAttachedStrokeIds;
      expect(all, containsAll(['global_1', 'shared_stroke', 'page1_stroke', 'page2_stroke']));
      expect(all.length, equals(4)); // shared_stroke deduplicated in Set
    });

    test('Serialization and Deserialization with stringified negative and non-consecutive keys', () {
      final rawMap = <String, dynamic>{
        'id': 'test_str_neg_keys',
        'cardType': 'pdf',
        'x': 0.0,
        'y': 0.0,
        'pageAttachedStrokeIds': <String, dynamic>{
          '-2': ['s_minus_2'],
          '0': ['s_zero'],
          '42': ['s_answer'],
          'invalid_non_numeric': ['ignored'],
        },
      };

      final card = CanvasCardModel.fromMap(rawMap);
      expect(card.pageAttachedStrokeIds.containsKey(-2), isTrue);
      expect(card.pageAttachedStrokeIds[-2], equals(['s_minus_2']));
      expect(card.pageAttachedStrokeIds.containsKey(0), isTrue);
      expect(card.pageAttachedStrokeIds[0], equals(['s_zero']));
      expect(card.pageAttachedStrokeIds.containsKey(42), isTrue);
      expect(card.pageAttachedStrokeIds[42], equals(['s_answer']));
      // non-numeric key ignored safely
      expect(card.pageAttachedStrokeIds.containsKey(null), isFalse);
      expect(card.pageAttachedStrokeIds.length, equals(3));
    });

    test('Deserialization of excludedPageIndices with string representations of numbers', () {
      final rawMap = <String, dynamic>{
        'id': 'test_str_excluded',
        'cardType': 'pdf',
        'x': 0.0,
        'y': 0.0,
        'excludedPageIndices': ['1', '5', 10, 'invalid', null],
      };

      final card = CanvasCardModel.fromMap(rawMap);
      expect(card.excludedPageIndices, equals([1, 5, 10]));
    });
  });

  group('exportAnnotatedPdf Geometry, Exclusion & Stroke Mapping Algorithms', () {
    test('Demonstration of page exclusion logic flaw in dual-index matching', () {
      // Simulating the exact loop condition from pdf_document_service.dart line 103:
      // if (excludedPageIndices.contains(pageNum) || excludedPageIndices.contains(pageNum - 1))
      bool isPageExcluded(int pageNum, List<int> excludedPageIndices) {
        return excludedPageIndices.contains(pageNum) || excludedPageIndices.contains(pageNum - 1);
      }

      // Scenario: A 4-page PDF, user wants to exclude page 2 using 1-based indexing [2]
      final excluded = [2];
      final excludedPagesResult = <int>[];
      final includedPagesResult = <int>[];

      for (int pageNum = 1; pageNum <= 4; pageNum++) {
        if (isPageExcluded(pageNum, excluded)) {
          excludedPagesResult.add(pageNum);
        } else {
          includedPagesResult.add(pageNum);
        }
      }

      // VULNERABILITY CONFIRMED:
      // When pageNum = 2: excluded.contains(2) is true -> Page 2 is excluded.
      // When pageNum = 3: excluded.contains(3-1) -> contains(2) is true -> Page 3 is UNINTENTIONALLY EXCLUDED!
      expect(excludedPagesResult, equals([2, 3]),
          reason: 'Dual 1-based/0-based check unintentionally excludes page 3 when page 2 was excluded!');
      expect(includedPagesResult, equals([1, 4]));
    });

    test('Demonstration of stroke bleed logic flaw in dual-index stroke lookup', () {
      // Simulating the exact stroke lookup from pdf_document_service.dart line 124:
      // final List<InkStroke> pageStrokes = strokesPerPage[pageNum] ??
      //     strokesPerPage[pageNum - 1] ??
      //     const <InkStroke>[];
      List<String> getStrokes(int pageNum, Map<int, List<String>> strokesPerPage) {
        return strokesPerPage[pageNum] ?? strokesPerPage[pageNum - 1] ?? const <String>[];
      }

      // Scenario: User has strokes on Page 1 (1-based: key 1), but NO strokes on Page 2
      final strokesPerPage = {
        1: ['stroke_on_page_1'],
        // Page 2 has NO strokes!
      };

      final page1Strokes = getStrokes(1, strokesPerPage);
      final page2Strokes = getStrokes(2, strokesPerPage);

      expect(page1Strokes, equals(['stroke_on_page_1']));
      // VULNERABILITY CONFIRMED:
      // Page 2 inherits page 1 strokes because strokesPerPage[2] is null and strokesPerPage[2 - 1] is key 1!
      expect(page2Strokes, equals(['stroke_on_page_1']),
          reason: 'Stroke on page 1 bleeds onto page 2 if page 2 has no strokes entry!');
    });

    test('Scale transform calculation with zero and negative cardWidth', () {
      const double targetDpi = 300.0;
      const double pdfPointsDpi = 72.0;
      const double dpiScale = targetDpi / pdfPointsDpi; // 4.166667
      const int targetPixelWidth = 2480;

      double calculateStrokeScale(double cardWidth) {
        return cardWidth > 0.0 ? (targetPixelWidth / cardWidth) : dpiScale;
      }

      // Normal card width
      expect(calculateStrokeScale(600.0), closeTo(2480 / 600.0, 0.001));

      // Zero card width falls back to dpiScale safely
      expect(calculateStrokeScale(0.0), equals(dpiScale));

      // Negative card width falls back to dpiScale safely
      expect(calculateStrokeScale(-200.0), equals(dpiScale));

      // NaN card width falls back to dpiScale safely
      expect(calculateStrokeScale(double.nan), equals(dpiScale));
    });
  });
}
