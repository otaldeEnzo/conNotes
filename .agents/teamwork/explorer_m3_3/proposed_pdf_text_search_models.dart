import 'package:flutter/material.dart';

/// Represents an individual text search match in a PDF document.
class PdfTextMatch {
  /// 1-based page number where this match occurs (1..totalPdfPages).
  final int pageNumber;

  /// Start character index within the page's fullText string.
  final int charStartIndex;

  /// Length of the matched character substring.
  final int charLength;

  /// Bounding boxes for the matched characters or lines in PDF point coordinates (72 DPI).
  final List<Rect> rects;

  /// 0-based global index across all matches found in the entire document.
  final int globalIndex;

  const PdfTextMatch({
    required this.pageNumber,
    required this.charStartIndex,
    required this.charLength,
    required this.rects,
    required this.globalIndex,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfTextMatch &&
          runtimeType == other.runtimeType &&
          pageNumber == other.pageNumber &&
          charStartIndex == other.charStartIndex &&
          charLength == other.charLength &&
          globalIndex == other.globalIndex;

  @override
  int get hashCode => Object.hash(pageNumber, charStartIndex, charLength, globalIndex);

  @override
  String toString() =>
      'PdfTextMatch(page: $pageNumber, charIndex: $charStartIndex, len: $charLength, globalIdx: $globalIndex, rectCount: ${rects.length})';
}

/// Immutable state container holding current document search results and navigation state.
class PdfSearchResult {
  /// The active search query string.
  final String query;

  /// Ordered list of all text matches discovered across active pages.
  final List<PdfTextMatch> matches;

  /// 0-based index of the currently active match, or -1 if no matches exist.
  final int currentMatchIndex;

  /// Whether asynchronous text extraction and search is currently in progress.
  final bool isSearching;

  const PdfSearchResult({
    this.query = '',
    this.matches = const <PdfTextMatch>[],
    this.currentMatchIndex = -1,
    this.isSearching = false,
  });

  /// Static constant representing an empty, idle search state.
  static const PdfSearchResult empty = PdfSearchResult();

  /// Total number of matches across the entire document.
  int get totalMatches => matches.length;

  /// Indicates if at least one match was found.
  bool get hasMatches => matches.isNotEmpty;

  /// The currently active match object, or null if no matches exist or index is invalid.
  PdfTextMatch? get currentMatch =>
      (currentMatchIndex >= 0 && currentMatchIndex < matches.length)
          ? matches[currentMatchIndex]
          : null;

  /// Formatted match counter string in the format "[ current / total ]", e.g. "[ 3 / 14 ]".
  /// If total is 0, returns "[ 0 / 0 ]".
  String get counterText {
    if (!hasMatches) return '[ 0 / 0 ]';
    final current1Based = currentMatchIndex >= 0 ? (currentMatchIndex + 1) : 0;
    return '[ $current1Based / $totalMatches ]';
  }

  /// Filters and returns only matches that belong to a specific 1-based [pageNumber].
  List<PdfTextMatch> matchesForPage(int pageNumber) {
    if (matches.isEmpty) return const <PdfTextMatch>[];
    return matches.where((m) => m.pageNumber == pageNumber).toList();
  }

  /// Creates a copy of this result with updated properties.
  PdfSearchResult copyWith({
    String? query,
    List<PdfTextMatch>? matches,
    int? currentMatchIndex,
    bool? isSearching,
  }) {
    return PdfSearchResult(
      query: query ?? this.query,
      matches: matches ?? this.matches,
      currentMatchIndex: currentMatchIndex ?? this.currentMatchIndex,
      isSearching: isSearching ?? this.isSearching,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfSearchResult &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          currentMatchIndex == other.currentMatchIndex &&
          isSearching == other.isSearching &&
          matches.length == other.matches.length;

  @override
  int get hashCode => Object.hash(query, currentMatchIndex, isSearching, matches.length);
}
