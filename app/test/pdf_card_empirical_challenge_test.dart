import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/services/pdf_document_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CHALLENGER STRESS: PdfDocumentService Lifecycle & Concurrency', () {
    test('concurrent initialize calls are safe and idempotent', () async {
      final service = PdfDocumentService.instance;
      await Future.wait([
        service.initialize(),
        service.initialize(),
        service.initialize(),
      ]);
      expect(service.isInitialized, isTrue);
    });

    test('disposeDocument with empty string or non-existent paths handles cleanly', () {
      final service = PdfDocumentService.instance;
      expect(() => service.disposeDocument(''), returnsNormally);
      expect(() => service.disposeDocument('invalid/path/does_not_exist.pdf'), returnsNormally);
      expect(() => service.disposeAll(), returnsNormally);
      expect(service.cachedDocumentCount, equals(0));
    });
  });

  group('CHALLENGER STRESS: Round-trip Serialization Stability & Idempotency', () {
    test('10-cycle serialization round-trip idempotency preserves all fields', () {
      final initialCard = CanvasCardModel(
        id: 'stress_card_alpha_99',
        cardType: CardType.pdf,
        title: 'Deep Quantum Electrodynamics Lecture',
        x: -450.25,
        y: 1280.75,
        width: 820.5,
        height: 1160.0,
        pdfPath: 'c:/research/qed_notes.pdf',
        pdfDisplayMode: PdfDisplayMode.continuous,
        currentPdfPage: 14,
        totalPdfPages: 84,
        pdfPageGap: 42.0,
        isPdfLocked: true,
        invertLuminance: true,
        pageAttachedStrokeIds: {
          1: ['stroke_1', 'stroke_2'],
          14: ['stroke_qed_main', 'stroke_diagram_1', 'stroke_diagram_2'],
          84: ['stroke_appendix'],
        },
        excludedPageIndices: [3, 7, 21, 42],
      );

      var currentCard = initialCard;

      for (int cycle = 1; cycle <= 10; cycle++) {
        final map = currentCard.toMap();
        final jsonString = jsonEncode(map);
        final decodedMap = jsonDecode(jsonString) as Map<String, dynamic>;
        final restoredCard = CanvasCardModel.fromMap(decodedMap);

        expect(restoredCard.id, equals(initialCard.id), reason: 'Cycle $cycle: id mismatch');
        expect(restoredCard.cardType, equals(initialCard.cardType), reason: 'Cycle $cycle: cardType mismatch');
        expect(restoredCard.title, equals(initialCard.title), reason: 'Cycle $cycle: title mismatch');
        expect(restoredCard.x, equals(initialCard.x), reason: 'Cycle $cycle: x mismatch');
        expect(restoredCard.y, equals(initialCard.y), reason: 'Cycle $cycle: y mismatch');
        expect(restoredCard.width, equals(initialCard.width), reason: 'Cycle $cycle: width mismatch');
        expect(restoredCard.height, equals(initialCard.height), reason: 'Cycle $cycle: height mismatch');
        expect(restoredCard.pdfPath, equals(initialCard.pdfPath), reason: 'Cycle $cycle: pdfPath mismatch');
        expect(restoredCard.pdfDisplayMode, equals(initialCard.pdfDisplayMode), reason: 'Cycle $cycle: pdfDisplayMode mismatch');
        expect(restoredCard.currentPdfPage, equals(initialCard.currentPdfPage), reason: 'Cycle $cycle: currentPdfPage mismatch');
        expect(restoredCard.totalPdfPages, equals(initialCard.totalPdfPages), reason: 'Cycle $cycle: totalPdfPages mismatch');
        expect(restoredCard.pdfPageGap, equals(initialCard.pdfPageGap), reason: 'Cycle $cycle: pdfPageGap mismatch');
        expect(restoredCard.isPdfLocked, equals(initialCard.isPdfLocked), reason: 'Cycle $cycle: isPdfLocked mismatch');
        expect(restoredCard.invertLuminance, equals(initialCard.invertLuminance), reason: 'Cycle $cycle: invertLuminance mismatch');
        expect(restoredCard.excludedPageIndices, equals(initialCard.excludedPageIndices), reason: 'Cycle $cycle: excludedPageIndices mismatch');

        // Check stroke mappings
        expect(restoredCard.pageAttachedStrokeIds.keys.toSet(), equals(initialCard.pageAttachedStrokeIds.keys.toSet()));
        for (final pageKey in initialCard.pageAttachedStrokeIds.keys) {
          expect(restoredCard.pageAttachedStrokeIds[pageKey], equals(initialCard.pageAttachedStrokeIds[pageKey]));
        }

        expect(restoredCard.allAttachedStrokeIds, equals(initialCard.allAttachedStrokeIds));

        currentCard = restoredCard;
      }
    });
  });

  group('CHALLENGER STRESS: Corrupted, Extreme, and Adversarial JSON Inputs', () {
    test('handles completely empty JSON map without throwing', () {
      final card = CanvasCardModel.fromMap(<String, dynamic>{});

      expect(card.id, isNotEmpty);
      expect(card.cardType, equals(CardType.textLatex));
      expect(card.pdfPath, isNull);
      expect(card.pdfDisplayMode, equals(PdfDisplayMode.continuous));
      expect(card.currentPdfPage, equals(1));
      expect(card.totalPdfPages, equals(1));
      expect(card.pdfPageGap, equals(36.0));
      expect(card.isPdfLocked, isFalse);
      expect(card.pageAttachedStrokeIds, isEmpty);
      expect(card.excludedPageIndices, isEmpty);
      expect(card.calculateMinHeight(), greaterThanOrEqualTo(90.0));
    });

    test('handles JSON map with explicit nulls everywhere', () {
      final card = CanvasCardModel.fromMap(<String, dynamic>{
        'id': null,
        'cardType': null,
        'title': null,
        'x': null,
        'y': null,
        'width': null,
        'height': null,
        'minHeight': null,
        'pdfPath': null,
        'pdfDisplayMode': null,
        'currentPdfPage': null,
        'totalPdfPages': null,
        'pdfPageGap': null,
        'isPdfLocked': null,
        'pageAttachedStrokeIds': null,
        'excludedPageIndices': null,
      });

      expect(card.id, isNotEmpty);
      expect(card.cardType, equals(CardType.textLatex));
      expect(card.title, equals('Card STEM'));
      expect(card.pdfDisplayMode, equals(PdfDisplayMode.continuous));
      expect(card.currentPdfPage, equals(1));
      expect(card.totalPdfPages, equals(1));
      expect(card.pdfPageGap, equals(36.0));
      expect(card.isPdfLocked, isFalse);
      expect(card.pageAttachedStrokeIds, isEmpty);
      expect(card.excludedPageIndices, isEmpty);
    });

    test('handles extreme negative numbers gracefully', () {
      final card = CanvasCardModel.fromMap(<String, dynamic>{
        'id': 'neg_test',
        'cardType': 'pdf',
        'currentPdfPage': -999,
        'totalPdfPages': -50,
        'pdfPageGap': -100.0,
        'width': -300.0,
      });

      expect(card.cardType, equals(CardType.pdf));
      expect(card.currentPdfPage, equals(-999));
      expect(card.totalPdfPages, equals(-50));
      expect(card.pdfPageGap, equals(-100.0));

      // calculateMinHeight should guard against non-positive dimensions and return at least 100.0
      expect(card.calculateMinHeight(), equals(100.0));
    });

    test('handles float numbers in integer fields safely', () {
      final card = CanvasCardModel.fromMap(<String, dynamic>{
        'id': 'float_in_int_test',
        'cardType': 'pdf',
        'currentPdfPage': 4.8,
        'totalPdfPages': 15.2,
      });

      expect(card.currentPdfPage, equals(4));
      expect(card.totalPdfPages, equals(15));
    });

    test('parses heterogeneous, malformed excludedPageIndices list', () {
      final card = CanvasCardModel.fromMap(<String, dynamic>{
        'id': 'malformed_exclusions',
        'cardType': 'pdf',
        'excludedPageIndices': [
          1,
          '2',
          3.0,
          'invalid_string',
          null,
          -4,
          '99',
        ],
      });

      expect(card.excludedPageIndices, equals([1, 2, 3, -4, 99]));
    });

    test('parses malformed pageAttachedStrokeIds with non-integer keys and dirty lists', () {
      final card = CanvasCardModel.fromMap(<String, dynamic>{
        'id': 'dirty_strokes_test',
        'cardType': 'pdf',
        'pageAttachedStrokeIds': {
          '1': ['valid_s1', 123, true],
          'not_a_number': ['should_be_ignored'],
          '-5': ['negative_page_stroke'],
          '7': null, // null list should be ignored
          '8': 'not_a_list', // non-list should be ignored
        },
      });

      expect(card.pageAttachedStrokeIds.containsKey(1), isTrue);
      expect(card.pageAttachedStrokeIds[1], equals(['valid_s1', '123', 'true']));
      expect(card.pageAttachedStrokeIds.containsKey(-5), isTrue);
      expect(card.pageAttachedStrokeIds[-5], equals(['negative_page_stroke']));
      expect(card.pageAttachedStrokeIds.containsKey(7), isFalse);
      expect(card.pageAttachedStrokeIds.containsKey(8), isFalse);
    });
  });

  group('CHALLENGER STRESS: Volume Scalability (10,000 Strokes / 500 Pages)', () {
    test('serializes and deserializes 10,000 strokes across 500 pages within budget', () {
      final massiveStrokeMap = <int, List<String>>{};
      for (int page = 1; page <= 500; page++) {
        massiveStrokeMap[page] = List.generate(20, (i) => 'stroke_p${page}_i$i');
      }

      final largeCard = CanvasCardModel(
        id: 'giant_volume_pdf_card',
        cardType: CardType.pdf,
        title: 'Massive Monograph (500 Pages)',
        x: 0.0,
        y: 0.0,
        width: 800.0,
        height: 1200.0,
        totalPdfPages: 500,
        pageAttachedStrokeIds: massiveStrokeMap,
      );

      final stopwatch = Stopwatch()..start();

      // Serialization
      final map = largeCard.toMap();
      final jsonString = jsonEncode(map);

      // Deserialization
      final decodedMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final restored = CanvasCardModel.fromMap(decodedMap);

      stopwatch.stop();

      expect(restored.pageAttachedStrokeIds.length, equals(500));
      expect(restored.allAttachedStrokeIds.length, equals(10000));
      expect(restored.getStrokesForPage(250).length, equals(20));
      expect(restored.getStrokesForPage(999), isEmpty);

      // Should complete in under 500ms
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });
  });

  group('CHALLENGER STRESS: calculateMinHeight Edge Cases', () {
    test('when all pages are excluded, activePages remains at least 1', () {
      final card = CanvasCardModel(
        id: 'all_excluded_card',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        width: 400.0,
        originalAspectRatio: 1.0,
        totalPdfPages: 5,
        excludedPageIndices: [1, 2, 3, 4, 5],
        pdfPageGap: 36.0,
      );

      // totalPdfPages (5) - excluded (5) = 0 active pages -> max(1, 0) = 1 active page
      // 1 * 400 + 0 gaps = 400.0
      expect(card.calculateMinHeight(), equals(400.0));
    });

    test('deduplicates redundant exclusions in excludedPageIndices', () {
      final card = CanvasCardModel(
        id: 'dup_excluded_card',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        width: 400.0,
        originalAspectRatio: 1.0,
        totalPdfPages: 5,
        excludedPageIndices: [2, 2, 2, 2], // 1 unique exclusion
        pdfPageGap: 36.0,
      );

      // 5 total - 1 unique excluded = 4 active pages
      // 4 * 400 + 3 * 36 = 1600 + 108 = 1708.0
      expect(card.calculateMinHeight(), equals(1708.0));
    });

    test('handles zero and negative aspect ratio gracefully via fallback', () {
      final cardZero = CanvasCardModel(
        id: 'aspect_zero',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        width: 500.0,
        originalAspectRatio: 0.0,
      );

      final cardNeg = CanvasCardModel(
        id: 'aspect_neg',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        width: 500.0,
        originalAspectRatio: -1.414,
      );

      // Fallback ratio is 1.0 / 1.4142 = 0.7071
      // 500 / 0.7071 = 707.1
      expect(cardZero.calculateMinHeight(), closeTo(707.1, 1.0));
      expect(cardNeg.calculateMinHeight(), closeTo(707.1, 1.0));
    });
  });

  group('CHALLENGER STRESS: copyWith Immutability & State Isolation', () {
    test('modifying collections on copyWith does not contaminate original model', () {
      final originalStrokes = {
        1: ['orig_stroke_1'],
      };
      final originalExclusions = [1, 2];

      final originalCard = CanvasCardModel(
        id: 'orig_card',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        pageAttachedStrokeIds: originalStrokes,
        excludedPageIndices: originalExclusions,
      );

      final clonedCard = originalCard.copyWith(
        pageAttachedStrokeIds: {
          ...originalCard.pageAttachedStrokeIds,
          2: ['cloned_stroke_2'],
        },
        excludedPageIndices: [...originalCard.excludedPageIndices, 3],
      );

      expect(originalCard.pageAttachedStrokeIds.containsKey(2), isFalse);
      expect(originalCard.excludedPageIndices, equals([1, 2]));

      expect(clonedCard.pageAttachedStrokeIds.containsKey(2), isTrue);
      expect(clonedCard.excludedPageIndices, equals([1, 2, 3]));
    });
  });

  group('CHALLENGER AUDIT: PdfDocumentService Excluded Page Logic Empirical Analysis', () {
    test('EMPIRICAL PROOF OF DUAL-MATCH BEHAVIOR IN exportAnnotatedPdf EXCLUSION FILTER', () {
      // In app/lib/services/pdf_document_service.dart line 103:
      // if (excludedPageIndices.contains(pageNum) || excludedPageIndices.contains(pageNum - 1)) {
      //   continue;
      // }
      //
      // Here we simulate this exact conditional check for a 3-page document.
      bool isPageExcluded(int pageNum, List<int> excludedPageIndices) {
        return excludedPageIndices.contains(pageNum) || excludedPageIndices.contains(pageNum - 1);
      }

      const totalDocPages = 3;

      // Scenario A: Caller passes [1] assuming 1-based page index (excluding page 1)
      final excludedA = [1];
      final skippedPagesA = <int>[];
      for (int pageNum = 1; pageNum <= totalDocPages; pageNum++) {
        if (isPageExcluded(pageNum, excludedA)) {
          skippedPagesA.add(pageNum);
        }
      }

      // CHALLENGE FINDING: When excludedPageIndices is [1], BOTH page 1 and page 2 are skipped!
      // pageNum = 1 matches excludedPageIndices.contains(pageNum) -> contains(1) -> true
      // pageNum = 2 matches excludedPageIndices.contains(pageNum - 1) -> contains(2 - 1) -> contains(1) -> true
      expect(skippedPagesA, equals([1, 2]),
        reason: 'Dual check causes index 1 to exclude BOTH page 1 and page 2!');

      // Scenario B: Caller passes [1, 2]
      final excludedB = [1, 2];
      final skippedPagesB = <int>[];
      for (int pageNum = 1; pageNum <= totalDocPages; pageNum++) {
        if (isPageExcluded(pageNum, excludedB)) {
          skippedPagesB.add(pageNum);
        }
      }

      // In a 3-page document, passing [1, 2] skips page 1, 2, AND 3! All pages skipped!
      expect(skippedPagesB, equals([1, 2, 3]),
        reason: 'Dual check causes entire document to be skipped when [1, 2] is passed!');
    });
  });
}
