import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/models/pdf_text_search_models.dart';
import 'package:connotes_app/services/pdf_document_service.dart';
import 'package:connotes_app/services/pdf_search_engine.dart';
import 'package:connotes_app/widgets/pdf_card_floating_pill.dart';
import 'package:connotes_app/widgets/pdf_search_pill_input.dart';
import 'package:connotes_app/widgets/svg_icon.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;

/// Mock implementation of PdfDocumentService for deterministic stress testing.
class MockPdfDocumentService implements PdfDocumentService {
  final Map<int, String> pageTexts;
  final int totalPages;
  final Duration delay;

  MockPdfDocumentService({
    this.pageTexts = const {},
    this.totalPages = 5,
    this.delay = Duration.zero,
  });

  @override
  bool get isInitialized => true;

  @override
  int get cachedDocumentCount => 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<pdfrx.PdfDocument> loadDocument(String filePath) async {
    if (delay > Duration.zero) await Future.delayed(delay);
    return MockPdfDocument(totalPages);
  }

  @override
  Future<pdfrx.PdfPageText?> loadPageText(String filePath, int pageNumber) async {
    if (delay > Duration.zero) await Future.delayed(delay);
    final text = pageTexts[pageNumber] ?? '';
    return MockPdfPageText(text);
  }

  @override
  Future<void> warmUp(String filePath, {int maxPages = 5}) async {}

  @override
  Future<void> exportAnnotatedPdf({
    required String originalPdfPath,
    required String outputPath,
    required dynamic strokesPerPage,
    required double cardWidth,
    required List<int> excludedPageIndices,
  }) async {}

  @override
  void disposeDocument(String filePath) {}

  @override
  void disposeAll() {}

  @override
  void invalidate(String filePath) {}

  @override
  void dispose() {}
}

class MockPdfDocument implements pdfrx.PdfDocument {
  final int pageCount;
  MockPdfDocument(this.pageCount);

  @override
  List<pdfrx.PdfPage> get pages => List.generate(
        pageCount,
        (i) => MockPdfPage(i + 1),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPdfPage implements pdfrx.PdfPage {
  @override
  final int pageNumber;
  MockPdfPage(this.pageNumber);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPdfPageText implements pdfrx.PdfPageText {
  @override
  final String fullText;

  MockPdfPageText(this.fullText);

  @override
  List<pdfrx.PdfPageTextFragment> get fragments => [
        MockPdfPageTextFragment(
          index: 0,
          length: fullText.length,
          bounds: pdfrx.PdfRect(0, 0, 100, 20),
          charRects: List.generate(
            fullText.length,
            (i) => pdfrx.PdfRect(i * 10.0, 0, (i + 1) * 10.0, 20.0),
          ),
        ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPdfPageTextFragment implements pdfrx.PdfPageTextFragment {
  @override
  final int index;
  @override
  final int length;
  @override
  final pdfrx.PdfRect bounds;
  @override
  final List<pdfrx.PdfRect> charRects;

  MockPdfPageTextFragment({
    required this.index,
    required this.length,
    required this.bounds,
    required this.charRects,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CHALLENGER 1: counterText Edge Cases & Formatting Oracles', () {
    test('Empty results produces strictly [ 0 / 0 ] under all index conditions', () {
      const emptyResult1 = PdfSearchResult.empty;
      expect(emptyResult1.counterText, equals('[ 0 / 0 ]'));

      const emptyResult2 = PdfSearchResult(
        query: 'test',
        matches: [],
        currentMatchIndex: -1,
      );
      expect(emptyResult2.counterText, equals('[ 0 / 0 ]'));

      const emptyResult3 = PdfSearchResult(
        query: 'test',
        matches: [],
        currentMatchIndex: 0, // Inconsistent state simulation
      );
      expect(emptyResult3.counterText, equals('[ 0 / 0 ]'));

      const emptyResult4 = PdfSearchResult(
        query: 'test',
        matches: [],
        currentMatchIndex: 99999, // Wild index with no matches
      );
      expect(emptyResult4.counterText, equals('[ 0 / 0 ]'));
    });

    test('Single result produces strictly [ 1 / 1 ] when active', () {
      final singleMatch = PdfSearchResult(
        query: 'single',
        matches: [
          const PdfTextMatch(
            pageNumber: 1,
            charStartIndex: 0,
            charLength: 6,
            rects: [Rect.fromLTWH(0, 0, 10, 10)],
            globalIndex: 0,
          ),
        ],
        currentMatchIndex: 0,
      );
      expect(singleMatch.counterText, equals('[ 1 / 1 ]'));
      expect(singleMatch.currentMatch, isNotNull);
      expect(singleMatch.currentMatch!.charLength, equals(6));
    });

    test('Single result with unselected index (-1) formats cleanly as [ 0 / 1 ]', () {
      final unselectedSingle = PdfSearchResult(
        query: 'single',
        matches: [
          const PdfTextMatch(
            pageNumber: 1,
            charStartIndex: 0,
            charLength: 6,
            rects: [Rect.fromLTWH(0, 0, 10, 10)],
            globalIndex: 0,
          ),
        ],
        currentMatchIndex: -1,
      );
      expect(unselectedSingle.counterText, equals('[ 0 / 1 ]'));
      expect(unselectedSingle.currentMatch, isNull);
    });

    test('Large number scaling: 100,000 matches format correctly without truncation or crash', () {
      final largeMatches = List.generate(
        100000,
        (i) => PdfTextMatch(
          pageNumber: (i ~/ 100) + 1,
          charStartIndex: (i % 100) * 10,
          charLength: 5,
          rects: const [Rect.fromLTWH(0, 0, 10, 10)],
          globalIndex: i,
        ),
      );

      final largeResult = PdfSearchResult(
        query: 'corpus',
        matches: largeMatches,
        currentMatchIndex: 99999,
      );

      expect(largeResult.totalMatches, equals(100000));
      expect(largeResult.counterText, equals('[ 100000 / 100000 ]'));

      final largeResultFirst = largeResult.copyWith(currentMatchIndex: 0);
      expect(largeResultFirst.counterText, equals('[ 1 / 100000 ]'));
    });

    test('Boundary match indices for 14 matches', () {
      final matches14 = List.generate(
        14,
        (i) => PdfTextMatch(
          pageNumber: 1,
          charStartIndex: i * 10,
          charLength: 4,
          rects: const [Rect.fromLTWH(0, 0, 10, 10)],
          globalIndex: i,
        ),
      );

      final first = PdfSearchResult(matches: matches14, currentMatchIndex: 0);
      expect(first.counterText, equals('[ 1 / 14 ]'));

      final middle = PdfSearchResult(matches: matches14, currentMatchIndex: 7);
      expect(middle.counterText, equals('[ 8 / 14 ]'));

      final last = PdfSearchResult(matches: matches14, currentMatchIndex: 13);
      expect(last.counterText, equals('[ 14 / 14 ]'));
    });
  });

  group('CHALLENGER 2: Circular Match Navigation & Boundary Wrapping Oracles', () {
    test('1-match circular navigation wraps continuously to itself', () {
      int? navigatedPage;
      final engine = PdfSearchEngine();
      engine.onNavigateToPage = (p) => navigatedPage = p;

      engine.resultsNotifier.value = PdfSearchResult(
        query: 'lone',
        matches: [
          const PdfTextMatch(
            pageNumber: 3,
            charStartIndex: 0,
            charLength: 4,
            rects: [Rect.fromLTWH(0, 0, 10, 10)],
            globalIndex: 0,
          ),
        ],
        currentMatchIndex: 0,
      );

      // nextMatch
      engine.nextMatch();
      expect(engine.currentResult.currentMatchIndex, equals(0));
      expect(navigatedPage, equals(3));

      // prevMatch
      engine.prevMatch();
      expect(engine.currentResult.currentMatchIndex, equals(0));
      expect(navigatedPage, equals(3));

      engine.dispose();
    });

    test('Multi-match circular navigation forward wrapping (last -> first)', () {
      final pagesVisited = <int>[];
      final engine = PdfSearchEngine();
      engine.onNavigateToPage = (p) => pagesVisited.add(p);

      final matches = List.generate(
        3,
        (i) => PdfTextMatch(
          pageNumber: i + 1,
          charStartIndex: 0,
          charLength: 4,
          rects: const [Rect.fromLTWH(0, 0, 10, 10)],
          globalIndex: i,
        ),
      );

      engine.resultsNotifier.value = PdfSearchResult(
        query: 'wrap',
        matches: matches,
        currentMatchIndex: 2, // At last match (page 3)
      );

      // Step forward -> should wrap to index 0 (page 1)
      engine.nextMatch();
      expect(engine.currentResult.currentMatchIndex, equals(0));
      expect(pagesVisited.last, equals(1));

      // Step forward -> index 1 (page 2)
      engine.nextMatch();
      expect(engine.currentResult.currentMatchIndex, equals(1));
      expect(pagesVisited.last, equals(2));

      // Step forward -> index 2 (page 3)
      engine.nextMatch();
      expect(engine.currentResult.currentMatchIndex, equals(2));
      expect(pagesVisited.last, equals(3));

      engine.dispose();
    });

    test('Multi-match circular navigation backward wrapping (first -> last)', () {
      final pagesVisited = <int>[];
      final engine = PdfSearchEngine();
      engine.onNavigateToPage = (p) => pagesVisited.add(p);

      final matches = List.generate(
        5,
        (i) => PdfTextMatch(
          pageNumber: i + 1,
          charStartIndex: 0,
          charLength: 4,
          rects: const [Rect.fromLTWH(0, 0, 10, 10)],
          globalIndex: i,
        ),
      );

      engine.resultsNotifier.value = PdfSearchResult(
        query: 'wrap',
        matches: matches,
        currentMatchIndex: 0, // At first match (page 1)
      );

      // Step backward -> should wrap to index 4 (page 5)
      engine.prevMatch();
      expect(engine.currentResult.currentMatchIndex, equals(4));
      expect(pagesVisited.last, equals(5));

      // Step backward again -> index 3 (page 4)
      engine.prevMatch();
      expect(engine.currentResult.currentMatchIndex, equals(3));
      expect(pagesVisited.last, equals(4));

      engine.dispose();
    });

    test('Stress invariant: 1,000 alternating next/prev operations maintain valid index range [0, total-1]', () {
      final engine = PdfSearchEngine();
      const matchCount = 17;
      final matches = List.generate(
        matchCount,
        (i) => PdfTextMatch(
          pageNumber: (i % 4) + 1,
          charStartIndex: i * 5,
          charLength: 3,
          rects: const [Rect.fromLTWH(0, 0, 10, 10)],
          globalIndex: i,
        ),
      );

      engine.resultsNotifier.value = PdfSearchResult(
        query: 'stress',
        matches: matches,
        currentMatchIndex: 0,
      );

      final rng = math.Random(1337);
      for (int step = 0; step < 1000; step++) {
        if (rng.nextBool()) {
          engine.nextMatch();
        } else {
          engine.prevMatch();
        }
        final idx = engine.currentResult.currentMatchIndex;
        expect(idx >= 0 && idx < matchCount, isTrue,
            reason: 'Step $step produced invalid index $idx for match count $matchCount');
      }

      engine.dispose();
    });

    test('jumpToMatch bounds validation: invalid indices are safely rejected without state corruption', () {
      final engine = PdfSearchEngine();
      final matches = List.generate(
        3,
        (i) => PdfTextMatch(
          pageNumber: i + 1,
          charStartIndex: 0,
          charLength: 3,
          rects: const [Rect.fromLTWH(0, 0, 10, 10)],
          globalIndex: i,
        ),
      );

      engine.resultsNotifier.value = PdfSearchResult(
        query: 'jump',
        matches: matches,
        currentMatchIndex: 1,
      );

      // Attempt invalid jumps
      engine.jumpToMatch(-1);
      expect(engine.currentResult.currentMatchIndex, equals(1));

      engine.jumpToMatch(3); // Out of bounds
      expect(engine.currentResult.currentMatchIndex, equals(1));

      engine.jumpToMatch(999);
      expect(engine.currentResult.currentMatchIndex, equals(1));

      // Valid jump
      engine.jumpToMatch(2);
      expect(engine.currentResult.currentMatchIndex, equals(2));

      engine.dispose();
    });

    test('Navigating on empty results is safe no-op', () {
      final engine = PdfSearchEngine();
      expect(engine.currentResult.hasMatches, isFalse);

      expect(() => engine.nextMatch(), returnsNormally);
      expect(() => engine.prevMatch(), returnsNormally);
      expect(() => engine.jumpToMatch(0), returnsNormally);

      expect(engine.currentResult.currentMatchIndex, equals(-1));
      engine.dispose();
    });
  });

  group('CHALLENGER 3: Regex Symbols, Whitespace, Rapid Queries & Concurrency Stress', () {
    test('Special regex characters do NOT cause FormatException in search query matching', () async {
      final mockService = MockPdfDocumentService(
        pageTexts: {
          1: r'Function f(x) = [a + b] * {c \ d} ^ e $ ? + * . | \',
          2: r'Regular (text) with [brackets] and \backslashes\',
        },
        totalPages: 2,
      );

      final engine = PdfSearchEngine(documentService: mockService);

      // Test symbols that typically break naive RegExp construction:
      final adversarialQueries = [
        '(',
        ')',
        '[]',
        '[',
        ']',
        '*',
        '+',
        '\\',
        r'\',
        '?',
        '^',
        r'$',
        '|',
        '{',
        '}',
        'f(x)',
        '[a + b]',
        '{c \\ d}',
        '\\backslashes\\',
      ];

      for (final rawQuery in adversarialQueries) {
        engine.search(
          filePath: 'mock.pdf',
          rawQuery: rawQuery,
          debounceDuration: Duration.zero,
        );

        // Wait for search execution to complete
        await Future.delayed(const Duration(milliseconds: 20));

        final res = engine.currentResult;
        expect(res.query, equals(rawQuery.trim()));
        expect(res.isSearching, isFalse);
        expect(res.totalMatches >= 0, isTrue);
      }

      engine.dispose();
    });

    test('Empty and whitespace-only queries immediately clear search without background dispatch', () async {
      final mockService = MockPdfDocumentService(
        pageTexts: {1: 'Sample text for search'},
        totalPages: 1,
      );

      final engine = PdfSearchEngine(documentService: mockService);

      // Prime with an initial search
      engine.search(
        filePath: 'mock.pdf',
        rawQuery: 'Sample',
        debounceDuration: Duration.zero,
      );
      await Future.delayed(const Duration(milliseconds: 20));
      expect(engine.currentResult.totalMatches, equals(1));

      // Test blank queries
      const blankQueries = ['', ' ', '   ', '\t', '\n', '   \t  \n  '];
      for (final blank in blankQueries) {
        engine.search(
          filePath: 'mock.pdf',
          rawQuery: blank,
          debounceDuration: Duration.zero,
        );

        expect(engine.currentResult, equals(PdfSearchResult.empty));
        expect(engine.currentQuery, isEmpty);
        expect(engine.currentResult.hasMatches, isFalse);
        expect(engine.currentResult.counterText, equals('[ 0 / 0 ]'));
      }

      engine.dispose();
    });

    test('Rapid consecutive queries: Debounce and generation token discard stale results', () async {
      final mockService = MockPdfDocumentService(
        pageTexts: {
          1: 'alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi',
        },
        totalPages: 1,
        delay: const Duration(milliseconds: 50),
      );

      final engine = PdfSearchEngine(documentService: mockService);

      // Fire 20 queries rapidly
      final words = ['alpha', 'beta', 'gamma', 'delta', 'epsilon', 'zeta', 'theta', 'lambda'];
      for (final word in words) {
        engine.search(
          filePath: 'mock.pdf',
          rawQuery: word,
          debounceDuration: const Duration(milliseconds: 10),
        );
      }

      // Final query
      engine.search(
        filePath: 'mock.pdf',
        rawQuery: 'lambda',
        debounceDuration: const Duration(milliseconds: 10),
      );

      // Wait enough for debounce + simulated network delay
      await Future.delayed(const Duration(milliseconds: 200));

      final res = engine.currentResult;
      expect(res.query, equals('lambda'));
      expect(res.totalMatches, equals(1));
      expect(res.matches.first.charStartIndex, greaterThan(0));

      engine.dispose();
    });

    test('Excluded pages are strictly omitted from search results', () async {
      final mockService = MockPdfDocumentService(
        pageTexts: {
          1: 'target word on page 1',
          2: 'target word on page 2 (excluded)',
          3: 'target word on page 3',
        },
        totalPages: 3,
      );

      final engine = PdfSearchEngine(documentService: mockService);

      engine.search(
        filePath: 'mock.pdf',
        rawQuery: 'target',
        excludedPageIndices: const [2], // Page 2 is excluded (e.g. detached)
        debounceDuration: Duration.zero,
      );

      await Future.delayed(const Duration(milliseconds: 20));

      final res = engine.currentResult;
      expect(res.totalMatches, equals(2));
      expect(res.matches.any((m) => m.pageNumber == 2), isFalse);
      expect(res.matches[0].pageNumber, equals(1));
      expect(res.matches[1].pageNumber, equals(3));

      engine.dispose();
    });

    test('Disposing engine during in-flight async search does not throw FlutterError or crash', () async {
      final mockService = MockPdfDocumentService(
        pageTexts: {1: 'async text'},
        totalPages: 1,
        delay: const Duration(milliseconds: 100),
      );

      final engine = PdfSearchEngine(documentService: mockService);

      engine.search(
        filePath: 'mock.pdf',
        rawQuery: 'async',
        debounceDuration: Duration.zero,
      );

      // Let search start...
      await Future.delayed(const Duration(milliseconds: 20));
      // Dispose immediately while async search is in-flight
      expect(() => engine.dispose(), returnsNormally);

      // Wait past the simulated delay to ensure no unhandled exceptions occurred
      await Future.delayed(const Duration(milliseconds: 150));
    });
  });

  group('CHALLENGER 4: Widget Integration & Hardware Key Navigation Stress', () {
    testWidgets('Enter and Shift+Enter trigger nextMatch and prevMatch respectively', (tester) async {
      final engine = PdfSearchEngine();
      final matches = List.generate(
        5,
        (i) => PdfTextMatch(
          pageNumber: i + 1,
          charStartIndex: 0,
          charLength: 4,
          rects: const [Rect.fromLTWH(0, 0, 10, 10)],
          globalIndex: i,
        ),
      );

      engine.resultsNotifier.value = PdfSearchResult(
        query: 'cycle',
        matches: matches,
        currentMatchIndex: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfSearchPillInput(
                searchEngine: engine,
                pdfPath: 'test.pdf',
                isCardSelected: true,
              ),
            ),
          ),
        ),
      );

      // Expand search
      await tester.tap(find.byWidgetPredicate((w) => w is SvgIcon && w.name == 'search'));
      await tester.pumpAndSettle();

      expect(find.text('[ 1 / 5 ]'), findsOneWidget);

      // Press Enter -> should advance to match 2
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(engine.currentResult.currentMatchIndex, equals(1));
      expect(find.text('[ 2 / 5 ]'), findsOneWidget);

      // Press Enter again -> match 3
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(engine.currentResult.currentMatchIndex, equals(2));
      expect(find.text('[ 3 / 5 ]'), findsOneWidget);

      // Press Shift + Enter -> back to match 2
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(engine.currentResult.currentMatchIndex, equals(1));
      expect(find.text('[ 2 / 5 ]'), findsOneWidget);

      engine.dispose();
    });

    testWidgets('Auto-collapse when card loses selection', (tester) async {
      final engine = PdfSearchEngine();
      final isSelectedNotifier = ValueNotifier<bool>(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: isSelectedNotifier,
                builder: (context, selected, _) {
                  return PdfSearchPillInput(
                    searchEngine: engine,
                    pdfPath: 'test.pdf',
                    isCardSelected: selected,
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Expand
      await tester.tap(find.byWidgetPredicate((w) => w is SvgIcon && w.name == 'search'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      // Card loses selection
      isSelectedNotifier.value = false;
      await tester.pumpAndSettle();

      // Should automatically collapse
      expect(find.byType(TextField), findsNothing);

      engine.dispose();
    });
  });

  group('CHALLENGER 5: Exhaustive Zero-Emoji & SVG Vector Audit', () {
    test('Exhaustive regex audit proves zero emojis in all source and test files', () {
      final targetDirs = [
        'lib/models',
        'lib/services',
        'lib/widgets',
        'test',
      ];

      final emojiPattern = RegExp(
        r'[\u{1F300}-\u{1F5FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
        unicode: true,
      );

      final inspectedFiles = <String>[];
      final emojiViolations = <String>[];

      for (final dirPath in targetDirs) {
        final dir = Directory(dirPath);
        if (!dir.existsSync()) continue;

        for (final entity in dir.listSync(recursive: true)) {
          if (entity is File && entity.path.endsWith('.dart')) {
            inspectedFiles.add(entity.path);
            final content = entity.readAsStringSync();
            final matches = emojiPattern.allMatches(content).toList();
            if (matches.isNotEmpty) {
              emojiViolations.add('${entity.path}: ${matches.map((m) => m.group(0)).join(', ')}');
            }
          }
        }
      }

      expect(inspectedFiles, isNotEmpty, reason: 'Should have inspected Dart files');
      expect(
        emojiViolations,
        isEmpty,
        reason: 'STRICT ZERO EMOJI VIOLATIONS FOUND: ${emojiViolations.join('; ')}',
      );
    });

    testWidgets('Floating pill and search pill UI only render SvgIcon and no emoji text spans', (tester) async {
      final card = CanvasCardModel(
        id: 'test_card',
        title: 'STEM Test',
        cardType: CardType.pdf,
        x: 0,
        y: 0,
        width: 400,
        height: 600,
        pdfPath: 'test.pdf',
      );
      final engine = PdfSearchEngine();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: card,
                searchEngine: engine,
                isCardSelected: true,
                onUpdateCard: (_) {},
              ),
            ),
          ),
        ),
      );

      // Expand search
      await tester.tap(find.byWidgetPredicate((w) => w is SvgIcon && w.name == 'search'));
      await tester.pumpAndSettle();

      // Check all Text widgets
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final emojiPattern = RegExp(
        r'[\u{1F300}-\u{1F5FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
        unicode: true,
      );

      for (final textWidget in textWidgets) {
        final textData = textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
        final matches = emojiPattern.allMatches(textData);
        expect(matches, isEmpty, reason: 'Emoji found in UI Text: "$textData"');
      }

      // Check SvgIcons count
      final svgIcons = tester.widgetList<SvgIcon>(find.byType(SvgIcon));
      expect(svgIcons, isNotEmpty);
      for (final icon in svgIcons) {
        expect(icon.name, isNotEmpty);
      }

      engine.dispose();
    });
  });
}
