import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfTextMatch;
import '../models/pdf_text_search_models.dart';
import 'pdf_document_service.dart';

/// Interactive real-time search engine executing text queries across PDF document pages.
/// Key architectural characteristics:
/// - Asynchronous page text parsing via [PdfDocumentService.instance.loadPageText].
/// - 200ms input debounce preventing main thread and native Pdfium thrashing during rapid typing.
/// - Incremental search generation tokens (_searchGeneration) canceling obsolete background queries.
/// - Fragment character rect consolidation for clean, contiguous highlight boxes.
/// - Circular match navigation (nextMatch / prevMatch) with automatic active page synchronization.
/// - Skips excluded pages (e.g. detached pages).
/// - 100% pure Dart logic, easily testable via unit tests.
class PdfSearchEngine {
  final PdfDocumentService _documentService;

  /// Callback invoked when active match changes to a different page,
  /// requesting caller to synchronize card.currentPdfPage.
  ValueChanged<int>? onNavigateToPage;

  /// Reactive notifier emitting updated search results, match counts, and active index.
  final ValueNotifier<PdfSearchResult> resultsNotifier =
      ValueNotifier<PdfSearchResult>(PdfSearchResult.empty);

  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  Timer? _debounceTimer;
  int _searchGeneration = 0;
  String _currentQuery = '';

  PdfSearchEngine({
    PdfDocumentService? documentService,
    this.onNavigateToPage,
  }) : _documentService = documentService ?? PdfDocumentService.instance;

  /// Current search results snapshot.
  PdfSearchResult get currentResult =>
      _isDisposed ? PdfSearchResult.empty : resultsNotifier.value;

  /// Active query string.
  String get currentQuery => _currentQuery;

  /// Initiates or schedules an asynchronous search across active document pages.
  /// [filePath]: Local filesystem path to source PDF.
  /// [rawQuery]: Search query typed by user.
  /// [excludedPageIndices]: 1-based page numbers excluded from search (e.g. detached pages).
  /// [debounceDuration]: Duration to wait before starting search; defaults to 200ms.
  void search({
    required String filePath,
    required String rawQuery,
    List<int> excludedPageIndices = const <int>[],
    Duration debounceDuration = const Duration(milliseconds: 200),
  }) {
    if (_isDisposed) return;
    _debounceTimer?.cancel();
    final trimmed = rawQuery.trim();

    if (trimmed.isEmpty) {
      _currentQuery = '';
      _searchGeneration++;
      if (!_isDisposed) {
        resultsNotifier.value = PdfSearchResult.empty;
      }
      return;
    }

    _debounceTimer = Timer(debounceDuration, () {
      if (_isDisposed) return;
      _executeSearch(
        filePath: filePath,
        query: trimmed,
        excludedPageIndices: excludedPageIndices,
      );
    });
  }

  Future<void> _executeSearch({
    required String filePath,
    required String query,
    required List<int> excludedPageIndices,
  }) async {
    if (_isDisposed) return;
    final generation = ++_searchGeneration;
    _currentQuery = query;

    resultsNotifier.value = resultsNotifier.value.copyWith(
      query: query,
      isSearching: true,
    );

    try {
      final doc = await _documentService.loadDocument(filePath);
      if (_isDisposed || generation != _searchGeneration) return;

      final totalPages = doc.pages.length;
      final excludedSet = excludedPageIndices.toSet();
      final lowerQuery = query.toLowerCase();
      final allMatches = <PdfTextMatch>[];
      int globalIndexCounter = 0;

      for (int pageNum = 1; pageNum <= totalPages; pageNum++) {
        if (_isDisposed || generation != _searchGeneration) return;
        if (excludedSet.contains(pageNum)) continue;

        final pageText = await _documentService.loadPageText(filePath, pageNum);
        if (_isDisposed || generation != _searchGeneration) return;
        if (pageText == null || pageText.fullText.isEmpty) continue;

        final pageFullText = pageText.fullText;
        final lowerFullText = pageFullText.toLowerCase();
        int searchStartIndex = 0;

        while (true) {
          final matchStart = lowerFullText.indexOf(lowerQuery, searchStartIndex);
          if (matchStart == -1) break;

          final matchLength = query.length;
          final matchRects = _extractMatchRects(pageText, matchStart, matchLength);

          allMatches.add(
            PdfTextMatch(
              pageNumber: pageNum,
              charStartIndex: matchStart,
              charLength: matchLength,
              rects: matchRects,
              globalIndex: globalIndexCounter++,
            ),
          );

          searchStartIndex = matchStart + math.max(1, matchLength);
        }
      }

      if (_isDisposed || generation != _searchGeneration) return;

      final initialMatchIdx = allMatches.isNotEmpty ? 0 : -1;

      resultsNotifier.value = PdfSearchResult(
        query: query,
        matches: allMatches,
        currentMatchIndex: initialMatchIdx,
        isSearching: false,
      );

      if (initialMatchIdx >= 0 && !_isDisposed) {
        final targetPage = allMatches[initialMatchIdx].pageNumber;
        onNavigateToPage?.call(targetPage);
      }
    } catch (e) {
      if (_isDisposed || generation != _searchGeneration) return;
      debugPrint('[PdfSearchEngine] Error executing search for "$query": $e');
      resultsNotifier.value = PdfSearchResult(
        query: query,
        matches: const <PdfTextMatch>[],
        currentMatchIndex: -1,
        isSearching: false,
      );
    }
  }

  /// Extracts and consolidates bounding rectangles for a text match from page fragments.
  List<Rect> _extractMatchRects(PdfPageText pageText, int matchStart, int matchLength) {
    final matchEnd = matchStart + matchLength;
    final rawRects = <Rect>[];

    for (final fragment in pageText.fragments) {
      final fragStart = fragment.index;
      final fragEnd = fragment.index + fragment.length;

      // Check overlap between [matchStart, matchEnd) and [fragStart, fragEnd)
      final overlapStart = math.max(matchStart, fragStart);
      final overlapEnd = math.min(matchEnd, fragEnd);

      if (overlapStart < overlapEnd) {
        final charRects = fragment.charRects;
        if (charRects.isNotEmpty) {
          for (int c = overlapStart; c < overlapEnd; c++) {
            final charIdxInFrag = c - fragStart;
            if (charIdxInFrag >= 0 && charIdxInFrag < charRects.length) {
              final r = charRects[charIdxInFrag];
              rawRects.add(Rect.fromLTRB(r.left, r.top, r.right, r.bottom));
            }
          }
        } else {
          final b = fragment.bounds;
          rawRects.add(Rect.fromLTRB(b.left, b.top, b.right, b.bottom));
        }
      }
    }

    return _consolidateLineRects(rawRects);
  }

  /// Consolidates individual character bounding boxes on the same horizontal line into unified line rects.
  List<Rect> _consolidateLineRects(List<Rect> rects) {
    if (rects.length <= 1) return rects;

    final sorted = List<Rect>.from(rects)
      ..sort((a, b) {
        final topDiff = a.top.compareTo(b.top);
        if (topDiff.abs() > 3.0) return topDiff;
        return a.left.compareTo(b.left);
      });

    final consolidated = <Rect>[];
    Rect? currentLineRect;

    for (final r in sorted) {
      if (currentLineRect == null) {
        currentLineRect = r;
      } else {
        // Same line heuristic: vertical centers within 4 points
        final isSameLine = (currentLineRect.center.dy - r.center.dy).abs() < 4.0;
        final isHorizontalNeighbor = r.left <= (currentLineRect.right + 8.0);

        if (isSameLine && isHorizontalNeighbor) {
          currentLineRect = Rect.fromLTRB(
            math.min(currentLineRect.left, r.left),
            math.min(currentLineRect.top, r.top),
            math.max(currentLineRect.right, r.right),
            math.max(currentLineRect.bottom, r.bottom),
          );
        } else {
          consolidated.add(currentLineRect);
          currentLineRect = r;
        }
      }
    }

    if (currentLineRect != null) {
      consolidated.add(currentLineRect);
    }

    return consolidated;
  }

  /// Cycles to the next match in the document.
  void nextMatch() {
    if (_isDisposed) return;
    final res = resultsNotifier.value;
    if (!res.hasMatches) return;

    final nextIdx = (res.currentMatchIndex + 1) % res.totalMatches;
    final match = res.matches[nextIdx];

    resultsNotifier.value = res.copyWith(currentMatchIndex: nextIdx);
    onNavigateToPage?.call(match.pageNumber);
  }

  /// Cycles to the previous match in the document.
  void prevMatch() {
    if (_isDisposed) return;
    final res = resultsNotifier.value;
    if (!res.hasMatches) return;

    final prevIdx = (res.currentMatchIndex - 1 + res.totalMatches) % res.totalMatches;
    final match = res.matches[prevIdx];

    resultsNotifier.value = res.copyWith(currentMatchIndex: prevIdx);
    onNavigateToPage?.call(match.pageNumber);
  }

  /// Jumps directly to a specific 0-based match index.
  void jumpToMatch(int index) {
    if (_isDisposed) return;
    final res = resultsNotifier.value;
    if (!res.hasMatches || index < 0 || index >= res.totalMatches) return;

    final match = res.matches[index];
    resultsNotifier.value = res.copyWith(currentMatchIndex: index);
    onNavigateToPage?.call(match.pageNumber);
  }

  /// Clears active search state, canceling any pending timers and clearing highlights.
  void clearSearch() {
    if (_isDisposed) return;
    _debounceTimer?.cancel();
    _searchGeneration++;
    _currentQuery = '';
    resultsNotifier.value = PdfSearchResult.empty;
  }

  /// Disposes resources held by the search engine.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _debounceTimer?.cancel();
    _searchGeneration++;
    resultsNotifier.dispose();
  }
}
