import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:connotes_app/services/pdf_document_service.dart';
import 'proposed_pdf_text_search_models.dart';
import 'proposed_pdf_search_engine.dart';

class MockPdfDocumentService extends PdfDocumentService {
  MockPdfDocumentService() : super.internal();

  final Map<int, PdfPageText> stubPageTexts = {};
  int stubTotalPages = 3;

  @override
  Future<PdfPageText?> loadPageText(String filePath, int pageNumber) async {
    return stubPageTexts[pageNumber];
  }
}

class FakePdfPageTextFragment implements PdfPageTextFragment {
  @override
  final int index;
  @override
  final int length;
  @override
  final PdfRect bounds;
  @override
  final List<PdfRect>? charRects;

  FakePdfPageTextFragment({
    required this.index,
    required this.length,
    required this.bounds,
    this.charRects,
  });

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePdfPageText implements PdfPageText {
  @override
  final String fullText;
  @override
  final List<PdfPageTextFragment> fragments;
  @override
  final int pageNumber;

  FakePdfPageText({
    required this.fullText,
    required this.fragments,
    this.pageNumber = 1,
  });

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('PdfSearchResult & PdfTextMatch Model Tests', () {
    test('PdfSearchResult.empty initializes with expected idle defaults', () {
      const empty = PdfSearchResult.empty;
      expect(empty.query, isEmpty);
      expect(empty.matches, isEmpty);
      expect(empty.currentMatchIndex, -1);
      expect(empty.isSearching, isFalse);
      expect(empty.totalMatches, 0);
      expect(empty.hasMatches, isFalse);
      expect(empty.currentMatch, isNull);
      expect(empty.counterText, '[ 0 / 0 ]');
    });

    test('counterText formats accurately with 1-based index and totals', () {
      final match1 = PdfTextMatch(
        pageNumber: 1,
        charStartIndex: 10,
        charLength: 4,
        rects: const [Rect.fromLTWH(10, 20, 30, 10)],
        globalIndex: 0,
      );
      final match2 = PdfTextMatch(
        pageNumber: 2,
        charStartIndex: 50,
        charLength: 4,
        rects: const [Rect.fromLTWH(15, 25, 30, 10)],
        globalIndex: 1,
      );
      final match3 = PdfTextMatch(
        pageNumber: 3,
        charStartIndex: 100,
        charLength: 4,
        rects: const [Rect.fromLTWH(20, 30, 30, 10)],
        globalIndex: 2,
      );

      final result = PdfSearchResult(
        query: 'test',
        matches: [match1, match2, match3],
        currentMatchIndex: 0,
        isSearching: false,
      );

      expect(result.totalMatches, 3);
      expect(result.hasMatches, isTrue);
      expect(result.counterText, '[ 1 / 3 ]');
      expect(result.currentMatch, match1);

      final secondMatchResult = result.copyWith(currentMatchIndex: 1);
      expect(secondMatchResult.counterText, '[ 2 / 3 ]');
      expect(secondMatchResult.currentMatch, match2);

      final thirdMatchResult = result.copyWith(currentMatchIndex: 2);
      expect(thirdMatchResult.counterText, '[ 3 / 3 ]');
      expect(thirdMatchResult.currentMatch, match3);
    });

    test('matchesForPage filters matches strictly by target pageNumber', () {
      final m1 = PdfTextMatch(pageNumber: 1, charStartIndex: 5, charLength: 3, rects: const [], globalIndex: 0);
      final m2 = PdfTextMatch(pageNumber: 2, charStartIndex: 12, charLength: 3, rects: const [], globalIndex: 1);
      final m3 = PdfTextMatch(pageNumber: 2, charStartIndex: 45, charLength: 3, rects: const [], globalIndex: 2);
      final m4 = PdfTextMatch(pageNumber: 5, charStartIndex: 80, charLength: 3, rects: const [], globalIndex: 3);

      final result = PdfSearchResult(
        query: 'pdf',
        matches: [m1, m2, m3, m4],
        currentMatchIndex: 0,
      );

      expect(result.matchesForPage(1), [m1]);
      expect(result.matchesForPage(2), [m2, m3]);
      expect(result.matchesForPage(3), isEmpty);
      expect(result.matchesForPage(5), [m4]);
    });

    test('Circular next/prev indexing logic', () {
      final matches = List.generate(
        5,
        (i) => PdfTextMatch(
          pageNumber: i + 1,
          charStartIndex: i * 10,
          charLength: 4,
          rects: const [],
          globalIndex: i,
        ),
      );

      int current = 0;
      final total = matches.length;

      // Next cycling: 0 -> 1 -> 2 -> 3 -> 4 -> 0
      current = (current + 1) % total;
      expect(current, 1);
      current = (current + 1) % total;
      expect(current, 2);
      current = (current + 1) % total;
      expect(current, 3);
      current = (current + 1) % total;
      expect(current, 4);
      current = (current + 1) % total;
      expect(current, 0);

      // Prev cycling: 0 -> 4 -> 3 -> 2 -> 1 -> 0
      current = (current - 1 + total) % total;
      expect(current, 4);
      current = (current - 1 + total) % total;
      expect(current, 3);
      current = (current - 1 + total) % total;
      expect(current, 2);
    });
  });
}
