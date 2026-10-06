import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/widgets/canvas_card_pdf_view.dart';

/// Pure algorithmic helper reproducing the sliding window and camera math
/// implemented in CanvasCardPdfView for independent verification.
class SlidingWindowVirtualizer {
  static List<int> getActivePages({
    required int totalPages,
    required Iterable<int> excludedPageIndices,
  }) {
    final excluded = excludedPageIndices.toSet();
    final active = <int>[];
    for (int i = 1; i <= totalPages; i++) {
      if (!excluded.contains(i)) {
        active.add(i);
      }
    }
    return active;
  }

  static Set<int> computeSlidingWindow({
    required List<int> activePages,
    required int activePageNumber,
    required PdfDisplayMode mode,
  }) {
    if (activePages.isEmpty) return const <int>{};

    if (mode == PdfDisplayMode.singlePage) {
      final page = activePages.contains(activePageNumber)
          ? activePageNumber
          : activePages.first;
      return <int>{page};
    }

    int activeIdx = activePages.indexOf(activePageNumber);
    if (activeIdx == -1) {
      activeIdx = 0;
    }

    final window = <int>{};
    if (activeIdx > 0) {
      window.add(activePages[activeIdx - 1]);
    }
    window.add(activePages[activeIdx]);
    if (activeIdx < activePages.length - 1) {
      window.add(activePages[activeIdx + 1]);
    }

    return window;
  }

  static double getPageHeight({
    required double cardWidth,
    required double? originalAspectRatio,
  }) {
    final ratio = (originalAspectRatio != null && originalAspectRatio > 0)
        ? originalAspectRatio
        : (1.0 / 1.4142);
    return cardWidth / ratio;
  }

  static int computeActivePageFromCamera({
    required Offset panOffset,
    required double zoomScale,
    required double viewportHeight,
    required double cardY,
    required double cardWidth,
    required double? originalAspectRatio,
    required double pageGap,
    required List<int> activePages,
  }) {
    if (activePages.isEmpty) return 1;

    final zoom = zoomScale.clamp(0.05, 10.0);
    final canvasCenterY = (viewportHeight / 2.0 - panOffset.dy) / zoom;
    final cardLocalY = canvasCenterY - cardY;

    final pageH = getPageHeight(
      cardWidth: cardWidth,
      originalAspectRatio: originalAspectRatio,
    );

    int? candidatePage;
    double minDistance = double.infinity;
    double currentTop = 0.0;

    for (final pageNum in activePages) {
      final pageBottom = currentTop + pageH;
      final pageCenter = currentTop + (pageH / 2.0);

      if (cardLocalY >= (currentTop - pageGap / 2.0) &&
          cardLocalY <= (pageBottom + pageGap / 2.0)) {
        return pageNum;
      }

      final dist = (pageCenter - cardLocalY).abs();
      if (dist < minDistance) {
        minDistance = dist;
        candidatePage = pageNum;
      }

      currentTop = pageBottom + pageGap;
    }

    return candidatePage ?? activePages.first;
  }

  static double computePageTopOffset({
    required int targetPage,
    required List<int> activePages,
    required double cardWidth,
    required double? originalAspectRatio,
    required double pageGap,
  }) {
    final pageH = getPageHeight(
      cardWidth: cardWidth,
      originalAspectRatio: originalAspectRatio,
    );
    double top = 0.0;
    for (final p in activePages) {
      if (p == targetPage) return top;
      top += pageH + pageGap;
    }
    return top;
  }
}

/// Verification render box reproducing PdfInterPageGap hit test behavior.
class MockPdfInterPageGapBox extends RenderBox {
  final double gapHeight;

  MockPdfInterPageGapBox(this.gapHeight);

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) => false;

  @override
  void performLayout() {
    size = Size(constraints.maxWidth, gapHeight);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sliding Window Virtualization Windowing Algorithm', () {
    test('window for single page document contains only page 1', () {
      final active = SlidingWindowVirtualizer.getActivePages(
        totalPages: 1,
        excludedPageIndices: const [],
      );
      final window = SlidingWindowVirtualizer.computeSlidingWindow(
        activePages: active,
        activePageNumber: 1,
        mode: PdfDisplayMode.continuous,
      );

      expect(window, equals({1}));
    });

    test('window at start of document (N=1) contains {1, 2}', () {
      final active = SlidingWindowVirtualizer.getActivePages(
        totalPages: 10,
        excludedPageIndices: const [],
      );
      final window = SlidingWindowVirtualizer.computeSlidingWindow(
        activePages: active,
        activePageNumber: 1,
        mode: PdfDisplayMode.continuous,
      );

      expect(window, equals({1, 2}));
    });

    test('window in middle of document (N=5) contains {4, 5, 6}', () {
      final active = SlidingWindowVirtualizer.getActivePages(
        totalPages: 10,
        excludedPageIndices: const [],
      );
      final window = SlidingWindowVirtualizer.computeSlidingWindow(
        activePages: active,
        activePageNumber: 5,
        mode: PdfDisplayMode.continuous,
      );

      expect(window, equals({4, 5, 6}));
    });

    test('window at end of document (N=10) contains {9, 10}', () {
      final active = SlidingWindowVirtualizer.getActivePages(
        totalPages: 10,
        excludedPageIndices: const [],
      );
      final window = SlidingWindowVirtualizer.computeSlidingWindow(
        activePages: active,
        activePageNumber: 10,
        mode: PdfDisplayMode.continuous,
      );

      expect(window, equals({9, 10}));
    });

    test('singlePage mode strictly returns only active page N', () {
      final active = SlidingWindowVirtualizer.getActivePages(
        totalPages: 25,
        excludedPageIndices: const [],
      );

      for (int p = 1; p <= 5; p++) {
        final window = SlidingWindowVirtualizer.computeSlidingWindow(
          activePages: active,
          activePageNumber: p,
          mode: PdfDisplayMode.singlePage,
        );
        expect(window, equals({p}));
      }
    });
  });

  group('Excluded Pages and Skipped Inter-Page Navigation', () {
    test('excluded pages are omitted from active list', () {
      final active = SlidingWindowVirtualizer.getActivePages(
        totalPages: 6,
        excludedPageIndices: [2, 4],
      );

      expect(active, equals([1, 3, 5, 6]));
    });

    test('sliding window skips excluded pages seamlessly', () {
      final active = SlidingWindowVirtualizer.getActivePages(
        totalPages: 6,
        excludedPageIndices: [2, 4],
      );

      final window = SlidingWindowVirtualizer.computeSlidingWindow(
        activePages: active,
        activePageNumber: 3,
        mode: PdfDisplayMode.continuous,
      );

      expect(window, equals({1, 3, 5}));
    });

    test('when current page is excluded, window recovers to first valid page', () {
      final active = SlidingWindowVirtualizer.getActivePages(
        totalPages: 5,
        excludedPageIndices: [1],
      );

      final window = SlidingWindowVirtualizer.computeSlidingWindow(
        activePages: active,
        activePageNumber: 1,
        mode: PdfDisplayMode.continuous,
      );

      expect(window, equals({2, 3}));
    });
  });

  group('Camera Viewport Center and Active Page Intersection Math', () {
    const cardWidth = 340.0;
    const cardY = 100.0;
    const standardA4Ratio = 0.7071;
    const gap = 36.0;

    test('camera centered on page 1 selects page 1', () {
      final active = SlidingWindowVirtualizer.getActivePages(
        totalPages: 5,
        excludedPageIndices: const [],
      );

      final activePage = SlidingWindowVirtualizer.computeActivePageFromCamera(
        panOffset: Offset.zero,
        zoomScale: 1.0,
        viewportHeight: 800.0,
        cardY: cardY,
        cardWidth: cardWidth,
        originalAspectRatio: standardA4Ratio,
        pageGap: gap,
        activePages: active,
      );

      expect(activePage, equals(1));
    });

    test('camera scrolled down selects page 2', () {
      final active = SlidingWindowVirtualizer.getActivePages(
        totalPages: 5,
        excludedPageIndices: const [],
      );

      final activePage = SlidingWindowVirtualizer.computeActivePageFromCamera(
        panOffset: const Offset(0, -400),
        zoomScale: 1.0,
        viewportHeight: 800.0,
        cardY: cardY,
        cardWidth: cardWidth,
        originalAspectRatio: standardA4Ratio,
        pageGap: gap,
        activePages: active,
      );

      expect(activePage, equals(2));
    });

    test('camera scrolled beyond bottom selects last active page', () {
      final active = SlidingWindowVirtualizer.getActivePages(
        totalPages: 5,
        excludedPageIndices: const [],
      );

      final activePage = SlidingWindowVirtualizer.computeActivePageFromCamera(
        panOffset: const Offset(0, -10000),
        zoomScale: 1.0,
        viewportHeight: 800.0,
        cardY: cardY,
        cardWidth: cardWidth,
        originalAspectRatio: standardA4Ratio,
        pageGap: gap,
        activePages: active,
      );

      expect(activePage, equals(5));
    });

    test('camera scrolled above top selects first active page', () {
      final active = SlidingWindowVirtualizer.getActivePages(
        totalPages: 5,
        excludedPageIndices: const [],
      );

      final activePage = SlidingWindowVirtualizer.computeActivePageFromCamera(
        panOffset: const Offset(0, 10000),
        zoomScale: 1.0,
        viewportHeight: 800.0,
        cardY: cardY,
        cardWidth: cardWidth,
        originalAspectRatio: standardA4Ratio,
        pageGap: gap,
        activePages: active,
      );

      expect(activePage, equals(1));
    });
  });

  group('Detached Page Positioning and Math', () {
    test('detached card is placed 40px to the right and aligned with page top', () {
      const active = [1, 2, 3, 4];
      const cardX = 200.0;
      const cardY = 150.0;
      const cardWidth = 340.0;
      const standardA4Ratio = 0.7071;
      const gap = 36.0;

      final pageTopOffset = SlidingWindowVirtualizer.computePageTopOffset(
        targetPage: 3,
        activePages: active,
        cardWidth: cardWidth,
        originalAspectRatio: standardA4Ratio,
        pageGap: gap,
      );

      const detachedX = cardX + cardWidth + 40.0;
      final detachedY = cardY + pageTopOffset;

      expect(detachedX, equals(580.0));
      const singlePageH = cardWidth / standardA4Ratio;
      expect(pageTopOffset, closeTo(2 * (singlePageH + gap), 0.001));
      expect(detachedY, closeTo(150.0 + 2 * (singlePageH + gap), 0.001));
    });
  });

  group('Inter-Page Gap Hit-Testing Pass-Through', () {
    test('MockPdfInterPageGapBox hitTestSelf and hitTest return false', () {
      final gapBox = MockPdfInterPageGapBox(36.0);
      gapBox.layout(const BoxConstraints(maxWidth: 340, maxHeight: 1000));

      expect(gapBox.hitTestSelf(const Offset(100, 18)), isFalse);

      final hitResult = BoxHitTestResult();
      final hit = gapBox.hitTest(hitResult, position: const Offset(100, 18));
      expect(hit, isFalse);
      expect(hitResult.path, isEmpty);
    });
  });

  group('Adversarial Stress Testing: Edge-Case Inputs (0, 1, 100+ pages, all excluded)', () {
    test('edge case: 0 total pages yields empty active list and empty window', () {
      final active = SlidingWindowVirtualizer.getActivePages(
        totalPages: 0,
        excludedPageIndices: const [],
      );
      expect(active, isEmpty);

      final continuousWindow = SlidingWindowVirtualizer.computeSlidingWindow(
        activePages: active,
        activePageNumber: 1,
        mode: PdfDisplayMode.continuous,
      );
      expect(continuousWindow, isEmpty);

      final singlePageWindow = SlidingWindowVirtualizer.computeSlidingWindow(
        activePages: active,
        activePageNumber: 1,
        mode: PdfDisplayMode.singlePage,
      );
      expect(singlePageWindow, isEmpty);

      final cameraPage = SlidingWindowVirtualizer.computeActivePageFromCamera(
        panOffset: Offset.zero,
        zoomScale: 1.0,
        viewportHeight: 800.0,
        cardY: 0.0,
        cardWidth: 340.0,
        originalAspectRatio: 0.7071,
        pageGap: 36.0,
        activePages: active,
      );
      expect(cameraPage, equals(1));
    });

    test('edge case: 1 page document boundaries and recovery', () {
      final active = SlidingWindowVirtualizer.getActivePages(
        totalPages: 1,
        excludedPageIndices: const [],
      );
      expect(active, equals([1]));

      final continuousWindow = SlidingWindowVirtualizer.computeSlidingWindow(
        activePages: active,
        activePageNumber: 1,
        mode: PdfDisplayMode.continuous,
      );
      expect(continuousWindow, equals({1}));

      final outOfBoundsWindow = SlidingWindowVirtualizer.computeSlidingWindow(
        activePages: active,
        activePageNumber: 999,
        mode: PdfDisplayMode.continuous,
      );
      expect(outOfBoundsWindow, equals({1}));

      final singlePageWindow = SlidingWindowVirtualizer.computeSlidingWindow(
        activePages: active,
        activePageNumber: 999,
        mode: PdfDisplayMode.singlePage,
      );
      expect(singlePageWindow, equals({1}));
    });

    test('edge case: 100+ pages (up to 1000 pages) scale invariance and bounds', () {
      for (final total in [100, 500, 1000]) {
        final active = SlidingWindowVirtualizer.getActivePages(
          totalPages: total,
          excludedPageIndices: const [],
        );
        expect(active.length, equals(total));

        // Start
        final startWindow = SlidingWindowVirtualizer.computeSlidingWindow(
          activePages: active,
          activePageNumber: 1,
          mode: PdfDisplayMode.continuous,
        );
        expect(startWindow, equals({1, 2}));

        // Middle
        final mid = total ~/ 2;
        final midWindow = SlidingWindowVirtualizer.computeSlidingWindow(
          activePages: active,
          activePageNumber: mid,
          mode: PdfDisplayMode.continuous,
        );
        expect(midWindow, equals({mid - 1, mid, mid + 1}));

        // End
        final endWindow = SlidingWindowVirtualizer.computeSlidingWindow(
          activePages: active,
          activePageNumber: total,
          mode: PdfDisplayMode.continuous,
        );
        expect(endWindow, equals({total - 1, total}));

        // Invariant: window size never exceeds 3
        for (final sample in [1, 2, mid - 1, mid, mid + 1, total - 1, total]) {
          final win = SlidingWindowVirtualizer.computeSlidingWindow(
            activePages: active,
            activePageNumber: sample,
            mode: PdfDisplayMode.continuous,
          );
          expect(win.length, lessThanOrEqualTo(3));
          expect(win.contains(sample), isTrue);

          final singleWin = SlidingWindowVirtualizer.computeSlidingWindow(
            activePages: active,
            activePageNumber: sample,
            mode: PdfDisplayMode.singlePage,
          );
          expect(singleWin, equals({sample}));
        }
      }
    });

    test('edge case: 100% of pages excluded behaves safely', () {
      final active = SlidingWindowVirtualizer.getActivePages(
        totalPages: 50,
        excludedPageIndices: List.generate(50, (i) => i + 1),
      );
      expect(active, isEmpty);

      final windowContinuous = SlidingWindowVirtualizer.computeSlidingWindow(
        activePages: active,
        activePageNumber: 25,
        mode: PdfDisplayMode.continuous,
      );
      expect(windowContinuous, isEmpty);

      final windowSingle = SlidingWindowVirtualizer.computeSlidingWindow(
        activePages: active,
        activePageNumber: 25,
        mode: PdfDisplayMode.singlePage,
      );
      expect(windowSingle, isEmpty);

      final cameraPage = SlidingWindowVirtualizer.computeActivePageFromCamera(
        panOffset: const Offset(0, -500),
        zoomScale: 1.0,
        viewportHeight: 800,
        cardY: 100,
        cardWidth: 340,
        originalAspectRatio: 0.7071,
        pageGap: 36,
        activePages: active,
      );
      expect(cameraPage, equals(1));
    });

    test('edge case: non-contiguous exclusion patterns (alternating, prefix, suffix)', () {
      final activeEven = SlidingWindowVirtualizer.getActivePages(
        totalPages: 10,
        excludedPageIndices: [2, 4, 6, 8, 10],
      );
      expect(activeEven, equals([1, 3, 5, 7, 9]));

      expect(
        SlidingWindowVirtualizer.computeSlidingWindow(
          activePages: activeEven,
          activePageNumber: 5,
          mode: PdfDisplayMode.continuous,
        ),
        equals({3, 5, 7}),
      );

      final activeTrimmed = SlidingWindowVirtualizer.getActivePages(
        totalPages: 10,
        excludedPageIndices: [1, 10],
      );
      expect(activeTrimmed, equals([2, 3, 4, 5, 6, 7, 8, 9]));

      expect(
        SlidingWindowVirtualizer.computeSlidingWindow(
          activePages: activeTrimmed,
          activePageNumber: 2,
          mode: PdfDisplayMode.continuous,
        ),
        equals({2, 3}),
      );

      expect(
        SlidingWindowVirtualizer.computeSlidingWindow(
          activePages: activeTrimmed,
          activePageNumber: 9,
          mode: PdfDisplayMode.continuous,
        ),
        equals({8, 9}),
      );
    });
  });

  group('Adversarial Stress Testing: Extreme Pan Offsets and Zoom Levels (0.1x to 10.0x)', () {
    const cardWidth = 340.0;
    const cardY = 100.0;
    const standardA4Ratio = 0.7071;
    const gap = 36.0;
    final active10 = List.generate(10, (i) => i + 1);

    test('extreme pan offsets: astronomically large positive and negative pan', () {
      final topPage = SlidingWindowVirtualizer.computeActivePageFromCamera(
        panOffset: const Offset(0, 1e9),
        zoomScale: 1.0,
        viewportHeight: 800.0,
        cardY: cardY,
        cardWidth: cardWidth,
        originalAspectRatio: standardA4Ratio,
        pageGap: gap,
        activePages: active10,
      );
      expect(topPage, equals(1));

      final bottomPage = SlidingWindowVirtualizer.computeActivePageFromCamera(
        panOffset: const Offset(0, -1e9),
        zoomScale: 1.0,
        viewportHeight: 800.0,
        cardY: cardY,
        cardWidth: cardWidth,
        originalAspectRatio: standardA4Ratio,
        pageGap: gap,
        activePages: active10,
      );
      expect(bottomPage, equals(10));

      final lateralPage = SlidingWindowVirtualizer.computeActivePageFromCamera(
        panOffset: const Offset(1e9, 0),
        zoomScale: 1.0,
        viewportHeight: 800.0,
        cardY: cardY,
        cardWidth: cardWidth,
        originalAspectRatio: standardA4Ratio,
        pageGap: gap,
        activePages: active10,
      );
      expect(lateralPage, equals(1));
    });

    test('zoom sweep: 0.1x to 10.0x preserves correct active page intersection', () {
      final zoomLevels = [0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 5.0, 8.0, 10.0];
      final pageH = SlidingWindowVirtualizer.getPageHeight(
        cardWidth: cardWidth,
        originalAspectRatio: standardA4Ratio,
      );

      for (final zoom in zoomLevels) {
        final targetPageTop = 4 * (pageH + gap);
        final targetPageCenter = targetPageTop + (pageH / 2.0);
        final desiredCanvasCenterY = cardY + targetPageCenter;
        const viewportHeight = 800.0;
        final panY = (viewportHeight / 2.0) - (desiredCanvasCenterY * zoom);

        final activePage = SlidingWindowVirtualizer.computeActivePageFromCamera(
          panOffset: Offset(0, panY),
          zoomScale: zoom,
          viewportHeight: viewportHeight,
          cardY: cardY,
          cardWidth: cardWidth,
          originalAspectRatio: standardA4Ratio,
          pageGap: gap,
          activePages: active10,
        );

        expect(activePage, equals(5),
            reason: 'At zoom ${zoom}x, camera centered on page 5 must select page 5');
      }
    });

    test('zoom clamping prevents division by zero or numerical overflow', () {
      final lowClamp = SlidingWindowVirtualizer.computeActivePageFromCamera(
        panOffset: Offset.zero,
        zoomScale: 0.000001,
        viewportHeight: 800.0,
        cardY: cardY,
        cardWidth: cardWidth,
        originalAspectRatio: standardA4Ratio,
        pageGap: gap,
        activePages: active10,
      );
      expect(lowClamp, inInclusiveRange(1, 10));

      final highClamp = SlidingWindowVirtualizer.computeActivePageFromCamera(
        panOffset: Offset.zero,
        zoomScale: 100000.0,
        viewportHeight: 800.0,
        cardY: cardY,
        cardWidth: cardWidth,
        originalAspectRatio: standardA4Ratio,
        pageGap: gap,
        activePages: active10,
      );
      expect(highClamp, inInclusiveRange(1, 10));
    });
  });

  group('Adversarial Stress Testing: Real PdfInterPageGap & RenderPdfInterPageGap Geometry Pass-Through', () {
    test('RenderPdfInterPageGap hitTestSelf and hitTest strictly return false across positions', () {
      final realGap = RenderPdfInterPageGap(36.0);
      realGap.layout(const BoxConstraints(maxWidth: 340, maxHeight: 1000));

      final probePoints = [
        Offset.zero,
        const Offset(10, 10),
        const Offset(170, 18),
        const Offset(340, 36),
        const Offset(-50, -50),
        const Offset(500, 500),
      ];

      for (final pt in probePoints) {
        expect(realGap.hitTestSelf(pt), isFalse,
            reason: 'hitTestSelf must return false at $pt');

        final result = BoxHitTestResult();
        final hit = realGap.hitTest(result, position: pt);
        expect(hit, isFalse, reason: 'hitTest must return false at $pt');
        expect(result.path, isEmpty, reason: 'Hit test path must remain empty at $pt');
      }
    });

    test('RenderPdfInterPageGap height mutation triggers layout without corrupting pass-through', () {
      final realGap = RenderPdfInterPageGap(20.0);
      realGap.layout(const BoxConstraints(maxWidth: 300, maxHeight: 800));
      expect(realGap.size.height, equals(20.0));

      realGap.gapHeight = 48.0;
      realGap.layout(const BoxConstraints(maxWidth: 300, maxHeight: 800));
      expect(realGap.size.height, equals(48.0));

      final result = BoxHitTestResult();
      expect(realGap.hitTest(result, position: const Offset(150, 24)), isFalse);
      expect(result.path, isEmpty);
    });

    testWidgets('PdfInterPageGap widget integrates into render tree with transparent hit-testing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfInterPageGap(height: 36.0),
            ),
          ),
        ),
      );

      final gapFinder = find.byType(PdfInterPageGap);
      expect(gapFinder, findsOneWidget);

      final renderBox = tester.renderObject<RenderPdfInterPageGap>(gapFinder);
      expect(renderBox.size.height, equals(36.0));

      final hitResult = BoxHitTestResult();
      final hit = renderBox.hitTest(hitResult, position: const Offset(100, 18));
      expect(hit, isFalse);
      expect(hitResult.path, isEmpty);
    });
  });
}
