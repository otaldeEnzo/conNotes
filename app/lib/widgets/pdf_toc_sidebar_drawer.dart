import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/canvas_card_model.dart';
import '../services/pdf_document_service.dart';
import '../services/diagnostics_override_controller.dart';
import '../theme/moscaro_theme_controller.dart';
import '../theme/moscaro_v2_tokens.dart';
import 'moscaro_sleek_scrollbar.dart';
import 'svg_icon.dart';

enum PdfTocDrawerTab {
  outline,
  bookmarks,
}

/// A parsed sub-section from a printed PDF table of contents.
class SmartTocSection {
  final String title;
  final int pageNumber;
  final String? tag; // e.g. 'Box', 'Revisão', 'Exercícios', 'Desafios', 'Leitura'

  const SmartTocSection({
    required this.title,
    required this.pageNumber,
    this.tag,
  });
}

/// A parsed category (Chapter / Unit / Module) containing sub-sections.
class SmartTocCategory {
  final String title;
  final int pageNumber;
  final List<SmartTocSection> sections;
  final bool isChapter;

  const SmartTocCategory({
    required this.title,
    required this.pageNumber,
    required this.sections,
    this.isChapter = true,
  });
}

/// Moscaro Glassmorphic Drawer / Popover for PDF Table of Contents and Bookmarks.
/// Complies with:
/// - Strictly ZERO emojis (100% SVG iconography).
/// - Moscaro Modern glassmorphism with blur and active theme styling.
/// - Exact height synchronization with the PDF card body.
/// - Fallback smart TOC detection for scanned/textbook PDFs without embedded metadata.
class PdfTocSidebarDrawer extends StatefulWidget {
  final CanvasCardModel card;
  final ValueChanged<int> onPageJump;
  final ValueChanged<int> onToggleBookmark;
  final VoidCallback onClose;
  final double maxHeight;
  final double? exactHeight;
  final double width;

  const PdfTocSidebarDrawer({
    super.key,
    required this.card,
    required this.onPageJump,
    required this.onToggleBookmark,
    required this.onClose,
    this.maxHeight = 420.0,
    this.exactHeight,
    this.width = 280.0,
  });

  @override
  State<PdfTocSidebarDrawer> createState() => _PdfTocSidebarDrawerState();
}

class _PdfTocSidebarDrawerState extends State<PdfTocSidebarDrawer> {
  PdfTocDrawerTab _activeTab = PdfTocDrawerTab.outline;
  bool _isLoadingOutline = true;
  List<PdfOutlineNode> _outline = const [];
  List<SmartTocCategory> _smartTocCategories = const [];
  List<int> _detectedTocPages = const [];
  int _pageOffset = 0;
  bool _isAutoOffsetDetected = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<int> _expandedCategoryIndices = <int>{};
  final Set<String> _collapsedNodeKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _loadDocumentOutline();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PdfTocSidebarDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.pdfPath != widget.card.pdfPath) {
      _loadDocumentOutline();
    }
  }

  Future<void> _loadDocumentOutline() async {
    final path = widget.card.pdfPath;
    if (path == null || path.isEmpty) {
      if (mounted) {
        setState(() {
          _outline = const [];
          _smartTocCategories = const [];
          _detectedTocPages = const [];
          _isLoadingOutline = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingOutline = true;
      _outline = const [];
      _smartTocCategories = const [];
      _detectedTocPages = const [];
    });

    try {
      final outlineNodes = await PdfDocumentService.instance.loadOutline(path);
      if (outlineNodes.isNotEmpty) {
        if (mounted) {
          setState(() {
            _outline = outlineNodes;
            _isLoadingOutline = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('PdfTocSidebarDrawer.loadOutline error: $e');
    }

    // Fallback: If native PDF outline catalog is empty, detect printed TOC
    await _detectAndExtractPrintedToc(path);
  }

  Future<void> _detectAndExtractPrintedToc(String path) async {
    final totalPages = widget.card.totalPdfPages;
    final maxPagesToScan = math.min(30, totalPages);
    final detectedPages = <int>[];
    final pagesText = <MapEntry<int, String>>[];

    try {
      for (int p = 1; p <= maxPagesToScan; p++) {
        final pageText = await PdfDocumentService.instance.loadPageText(path, p);
        if (pageText == null || pageText.fullText.trim().isEmpty) continue;

        final rawText = pageText.fullText;
        final upper = rawText.toUpperCase();

        final hasTocHeader = upper.contains('SUMÁRIO') ||
            upper.contains('SUMARIO') ||
            upper.contains('ÍNDICE GERAL') ||
            upper.contains('INDICE GERAL') ||
            upper.contains('ÍNDICE') ||
            upper.contains('INDICE') ||
            upper.contains('TABLE OF CONTENTS') ||
            upper.contains('CONTENTS') ||
            upper.contains('CONTEÚDO') ||
            upper.contains('CONTEUDO');

        if (hasTocHeader) {
          detectedPages.add(p);
          pagesText.add(MapEntry(p, rawText));
        }
      }

      // Check subsequent continuous pages (up to 5 pages after the last detected TOC page)
      if (detectedPages.isNotEmpty) {
        final lastDetected = detectedPages.last;
        for (int nextP = lastDetected + 1; nextP <= math.min(lastDetected + 6, maxPagesToScan); nextP++) {
          if (!detectedPages.contains(nextP)) {
            final pageText = await PdfDocumentService.instance.loadPageText(path, nextP);
            if (pageText != null && pageText.fullText.trim().isNotEmpty) {
              final raw = pageText.fullText;
              final commaNumbers = RegExp(r',\s*\d{1,4}\b').allMatches(raw).length;
              final dotLeaders = RegExp(r'[\.·]{2,}\s*\d{1,4}\b').allMatches(raw).length;
              if (commaNumbers >= 3 || dotLeaders >= 3) {
                detectedPages.add(nextP);
                pagesText.add(MapEntry(nextP, raw));
              } else {
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('PdfTocSidebarDrawer._detectAndExtractPrintedToc error: $e');
    }

    final categories = _parsePrintedTocCategories(pagesText, totalPages);

    int detectedOffset = detectedPages.isNotEmpty ? detectedPages.last : 0;
    bool isAuto = false;

    if (detectedPages.isNotEmpty) {
      final autoOffset = await _calculateAutomaticPageOffset(
        path,
        detectedPages,
        categories,
        totalPages,
      );
      if (autoOffset != null) {
        detectedOffset = autoOffset;
        isAuto = true;
      }
    }

    if (mounted) {
      setState(() {
        _detectedTocPages = detectedPages;
        _smartTocCategories = categories;
        if (_pageOffset == 0) {
          _pageOffset = detectedOffset;
          _isAutoOffsetDetected = isAuto;
        }
        if (categories.isNotEmpty) {
          _expandedCategoryIndices.add(0);
        }
        _isLoadingOutline = false;
      });
    }
  }

  Future<int?> _calculateAutomaticPageOffset(
    String path,
    List<int> detectedTocPages,
    List<SmartTocCategory> categories,
    int totalPages,
  ) async {
    if (detectedTocPages.isEmpty) return null;
    final lastTocPage = detectedTocPages.last;
    final candidateOffsets = <int, int>{};

    final probeMax = math.min(lastTocPage + 12, totalPages);

    // 1. Probe headers and footers for printed page numbers
    for (int physPage = lastTocPage + 1; physPage <= probeMax; physPage++) {
      try {
        final pageText = await PdfDocumentService.instance.loadPageText(path, physPage);
        if (pageText == null || pageText.fullText.trim().isEmpty) continue;

        final rawLines = pageText.fullText
            .split(RegExp(r'\r?\n'))
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        if (rawLines.isEmpty) continue;

        final edgeLines = <String>[
          ...rawLines.take(3),
          if (rawLines.length > 3) ...rawLines.skip(math.max(3, rawLines.length - 3)),
        ];

        for (final line in edgeLines) {
          final match = RegExp(
            r'^(?:p[aá]g\.?\s*)?[—\-–\s]*(\d{1,4})[—\-–\s]*$',
            caseSensitive: false,
          ).firstMatch(line);

          if (match != null) {
            final printedPage = int.tryParse(match.group(1)!);
            if (printedPage != null && printedPage > 0 && printedPage < totalPages) {
              final offset = physPage - printedPage;
              if (offset >= 0 && offset <= 60) {
                candidateOffsets[offset] = (candidateOffsets[offset] ?? 0) + 2;
              }
            }
          }
        }
      } catch (_) {}
    }

    // 2. Probe for distinctive keywords from the first category or section
    if (categories.isNotEmpty) {
      final firstCat = categories.first;
      final words = firstCat.title
          .replaceAll(RegExp(r'^(CAP[ÍI]TULO|UNIDADE|M[ÓO]DULO|PARTE)\s+\d+[\s\-—:]*', caseSensitive: false), '')
          .split(RegExp(r'[\s\-—,;:\.]+'))
          .map((w) => w.trim().toLowerCase())
          .where((w) => w.length >= 4 && !['para', 'como', 'sobre', 'estudo', 'geral', 'introducao', 'introdução'].contains(w))
          .toList();

      if (words.isNotEmpty) {
        final searchWord = words.first;
        for (int physPage = lastTocPage + 1; physPage <= probeMax; physPage++) {
          try {
            final pageText = await PdfDocumentService.instance.loadPageText(path, physPage);
            if (pageText != null && pageText.fullText.toLowerCase().contains(searchWord)) {
              final offset = physPage - firstCat.pageNumber;
              if (offset >= 0 && offset <= 60) {
                candidateOffsets[offset] = (candidateOffsets[offset] ?? 0) + 3;
              }
              break;
            }
          } catch (_) {}
        }
      }
    }

    if (candidateOffsets.isNotEmpty) {
      var bestOffset = candidateOffsets.keys.first;
      var bestScore = candidateOffsets[bestOffset]!;
      for (final entry in candidateOffsets.entries) {
        if (entry.value > bestScore) {
          bestOffset = entry.key;
          bestScore = entry.value;
        }
      }
      return bestOffset;
    }

    return lastTocPage;
  }

  List<SmartTocCategory> _parsePrintedTocCategories(
    List<MapEntry<int, String>> pagesText,
    int totalPages,
  ) {
    final categories = <SmartTocCategory>[];
    SmartTocCategory? currentCategory;
    final currentSections = <SmartTocSection>[];

    void commitCurrentCategory() {
      if (currentCategory != null) {
        categories.add(SmartTocCategory(
          title: currentCategory!.title,
          pageNumber: currentCategory!.pageNumber,
          sections: List.unmodifiable(currentSections),
          isChapter: currentCategory!.isChapter,
        ));
        currentSections.clear();
        currentCategory = null;
      }
    }

    final itemRegex = RegExp(
      r'([^,;\t\n\r]+?)(?:[\.·\s]{2,}|,\s*|\t+)(\d{1,4})(?=$|\s{2,}|;)',
    );

    final chapterExplicitRegex = RegExp(
      r'^(CAP[ÍI]TULO|UNIDADE|M[ÓO]DULO|PARTE)\s+([0-9IVXLCDM]+)[\s\-—:]*(.*)$',
      caseSensitive: false,
    );

    final chapterNumericRegex = RegExp(
      r'^([0-9IVXLCDM]+)\s+([A-ZÁÉÍÓÚÂÊÎÔÛÃÕÇ\s]{4,})$',
    );

    for (final pageEntry in pagesText) {
      final tocPageNum = pageEntry.key;
      final text = pageEntry.value;
      final lines = text.split(RegExp(r'\r?\n'));

      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;

        final upper = line.toUpperCase();
        if (upper == 'SUMÁRIO' ||
            upper == 'SUMARIO' ||
            upper == 'ÍNDICE' ||
            upper == 'INDICE' ||
            upper.startsWith('SUMÁRIO -') ||
            upper.startsWith('SUMARIO -') ||
            upper.startsWith('ÍNDICE -') ||
            upper.startsWith('INDICE -') ||
            upper.contains('REPRODUÇÃO PROIBIDA') ||
            upper.contains('CÓDIGO PENAL')) {
          continue;
        }

        // 1. Check for explicit Chapter / Category
        final explicitMatch = chapterExplicitRegex.firstMatch(line);
        if (explicitMatch != null) {
          commitCurrentCategory();
          final type = explicitMatch.group(1);
          final num = explicitMatch.group(2);
          final rest = explicitMatch.group(3)?.trim() ?? '';
          final title = rest.isNotEmpty ? '$type $num - $rest' : '$type $num';

          int startPage = tocPageNum;
          final endPageMatch = RegExp(r',\s*(\d{1,4})$').firstMatch(rest);
          if (endPageMatch != null) {
            startPage = int.tryParse(endPageMatch.group(1)!) ?? tocPageNum;
          }

          currentCategory = SmartTocCategory(
            title: title,
            pageNumber: startPage,
            sections: [],
            isChapter: true,
          );
          continue;
        }

        // 2. Check for numeric uppercase Chapter header (e.g. "5 EQUILÍBRIOS QUÍMICOS HOMOGÊNEOS")
        final numericMatch = chapterNumericRegex.firstMatch(line);
        if (numericMatch != null && !line.contains(',')) {
          commitCurrentCategory();
          final chNum = numericMatch.group(1);
          final chTitle = numericMatch.group(2)!.trim();
          currentCategory = SmartTocCategory(
            title: 'Capítulo $chNum - $chTitle',
            pageNumber: tocPageNum,
            sections: [],
            isChapter: true,
          );
          continue;
        }

        // 3. Extract items/sections from the line
        final matches = itemRegex.allMatches(line);
        if (matches.isNotEmpty) {
          for (final m in matches) {
            var rawTitle = m.group(1)!.trim();
            final pStr = m.group(2)!;
            final pageNum = int.tryParse(pStr);

            if (pageNum != null && pageNum > 0 && pageNum <= totalPages + 100) {
              rawTitle = rawTitle.replaceAll(RegExp(r'^[\s\-\*\•\.\,]+|[\s\-\*\•\.\,]+$'), '').trim();
              if (rawTitle.isEmpty) continue;

              String? tag;
              final lower = rawTitle.toLowerCase();
              if (lower.startsWith('box:')) {
                tag = 'Box';
                rawTitle = rawTitle.substring(4).trim();
              } else if (lower.startsWith('revisão') || lower.startsWith('revisao')) {
                tag = 'Revisão';
              } else if (lower.startsWith('exercícios') || lower.startsWith('exercicios')) {
                tag = 'Exercícios';
              } else if (lower.startsWith('leitura')) {
                tag = 'Leitura';
              } else if (lower.startsWith('desafios')) {
                tag = 'Desafios';
              } else if (lower.startsWith('atividades práticas') || lower.startsWith('atividades praticas')) {
                tag = 'Prática';
              }

              currentCategory ??= SmartTocCategory(
                title: 'Seções Iniciais',
                pageNumber: pageNum,
                sections: [],
                isChapter: false,
              );

              currentSections.add(SmartTocSection(
                title: rawTitle,
                pageNumber: pageNum,
                tag: tag,
              ));
            }
          }
        }
      }
    }

    commitCurrentCategory();
    return categories;
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = MoscaroThemeController.instance.currentTheme;
    final accentColor = activeTheme.accentPrimary;
    final bookmarkedSet = widget.card.bookmarkedPages.toSet();
    final effectiveHeight = widget.exactHeight ?? widget.maxHeight;
    final isLight = MoscaroTokens.isLight;
    final bool bypass = DiagnosticsOverrideController.instance.bypassBackdropFilter;
    final double blurSigma = (!bypass && MoscaroTokens.enableSidebarBlur && MoscaroTokens.blurSigma > 0)
        ? MoscaroTokens.blurSigma
        : 0.0;
    final effectiveBgColor = widget.card.customGlassColor ?? MoscaroTokens.glassTint;

    final content = Container(
      width: widget.width,
      height: effectiveHeight,
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isLight
              ? MoscaroTokens.borderSubtle
              : accentColor.withValues(alpha: 0.35),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? const Color(0x180F172A)
                : Colors.black.withValues(alpha: 0.45),
            blurRadius: 24.0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: accentColor.withValues(alpha: isLight ? 0.08 : 0.12),
            blurRadius: 16.0,
            spreadRadius: 1.0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(accentColor),
          _buildTabBar(accentColor, bookmarkedSet.length),
          Expanded(
            child: _activeTab == PdfTocDrawerTab.outline
                ? _buildOutlineView(accentColor)
                : _buildBookmarksView(accentColor, bookmarkedSet),
          ),
        ],
      ),
    );

    if (blurSigma > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: content,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: content,
    );
  }

  Widget _buildHeader(Color accentColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14.0, 10.0, 8.0, 8.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: MoscaroTokens.borderSubtle,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          SvgIcon(
            name: 'list',
            size: 15.0,
            color: accentColor,
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              'Sumário & Marcadores',
              style: TextStyle(
                color: MoscaroTokens.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14.0),
              onTap: widget.onClose,
              child: Container(
                padding: const EdgeInsets.all(5.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14.0),
                ),
                child: SvgIcon(
                  name: 'close',
                  size: 14.0,
                  color: MoscaroTokens.iconInactive,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(Color accentColor, int bookmarkCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: MoscaroTokens.borderSubtle,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              tab: PdfTocDrawerTab.outline,
              label: 'Sumário',
              iconName: 'list',
              accentColor: accentColor,
            ),
          ),
          const SizedBox(width: 6.0),
          Expanded(
            child: _buildTabButton(
              tab: PdfTocDrawerTab.bookmarks,
              label: bookmarkCount > 0 ? 'Marcadores ($bookmarkCount)' : 'Marcadores',
              iconName: 'star',
              accentColor: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required PdfTocDrawerTab tab,
    required String label,
    required String iconName,
    required Color accentColor,
  }) {
    final isSelected = _activeTab == tab;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: () => setState(() => _activeTab = tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: 0.15)
                : MoscaroTokens.borderSubtle,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.4)
                  : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgIcon(
                name: iconName,
                size: 12.0,
                color: isSelected ? accentColor : MoscaroTokens.iconInactive,
              ),
              const SizedBox(width: 5.0),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? MoscaroTokens.textPrimary : MoscaroTokens.textSecondary,
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutlineView(Color accentColor) {
    if (_isLoadingOutline) {
      return Center(
        child: SizedBox(
          width: 22.0,
          height: 22.0,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            color: accentColor,
          ),
        ),
      );
    }

    final hasContent = _outline.isNotEmpty || _smartTocCategories.isNotEmpty;

    return Column(
      children: [
        if (hasContent) _buildSearchBar(accentColor),
        Expanded(
          child: _buildOutlineBody(accentColor),
        ),
      ],
    );
  }

  Widget _buildSearchBar(Color accentColor) {
    final isSearching = _searchQuery.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(10.0, 6.0, 10.0, 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: MoscaroTokens.backgroundSurface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: isSearching
              ? accentColor.withValues(alpha: 0.6)
              : MoscaroTokens.borderSubtle,
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          SvgIcon(
            name: 'search',
            size: 13.0,
            color: isSearching ? accentColor : MoscaroTokens.iconInactive,
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: MoscaroTokens.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: 'Pesquisar no sumário...',
                hintStyle: TextStyle(
                  color: MoscaroTokens.textMuted,
                  fontSize: 11.0,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6.0),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
            ),
          ),
          if (isSearching)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10.0),
                onTap: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: SvgIcon(
                    name: 'close',
                    size: 11.0,
                    color: MoscaroTokens.iconInactive,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOutlineBody(Color accentColor) {
    // 1. If embedded PDF outline is present, render it
    if (_outline.isNotEmpty) {
      final flattenedItems = <_FlattenedOutlineItem>[];
      for (int i = 0; i < _outline.length; i++) {
        _flattenNode(_outline[i], 0, '$i', flattenedItems);
      }

      final isSearching = _searchQuery.isNotEmpty;
      final q = _searchQuery.toLowerCase();
      final filteredItems = isSearching
          ? flattenedItems.where((item) => item.node.title.toLowerCase().contains(q)).toList()
          : flattenedItems;

      if (isSearching && filteredItems.isEmpty) {
        return _buildEmptySearchResults(accentColor);
      }

      return MoscaroSleekScrollbar(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            final node = item.node;
            final depth = item.depth;
            final key = item.key;
            final hasChildren = node.children.isNotEmpty;
            final isCollapsed = _collapsedNodeKeys.contains(key);
            final pageNum = node.dest?.pageNumber;
            final isCurrentPage = pageNum == widget.card.currentPdfPage;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (pageNum != null) {
                    widget.onPageJump(pageNum);
                  }
                },
                child: Container(
                  padding: EdgeInsets.only(
                    left: 10.0 + (depth * 14.0),
                    right: 10.0,
                    top: 5.0,
                    bottom: 5.0,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrentPage
                        ? accentColor.withValues(alpha: 0.12)
                        : Colors.transparent,
                    border: isCurrentPage
                        ? Border(
                            left: BorderSide(
                              color: accentColor,
                              width: 2.5,
                            ),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      if (hasChildren)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isCollapsed) {
                                _collapsedNodeKeys.remove(key);
                              } else {
                                _collapsedNodeKeys.add(key);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: SvgIcon(
                              name: isCollapsed ? 'chevron_right' : 'chevron_down',
                              size: 11.0,
                              color: isCollapsed ? MoscaroTokens.iconInactive : accentColor,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 15.0),
                      Expanded(
                        child: Text(
                          node.title.trim().isEmpty ? 'Sem título' : node.title.trim(),
                          style: TextStyle(
                            color: isCurrentPage ? MoscaroTokens.textPrimary : MoscaroTokens.textSecondary,
                            fontSize: 11.5,
                            fontWeight: isCurrentPage ? FontWeight.w600 : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (pageNum != null) ...[
                        const SizedBox(width: 6.0),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: MoscaroTokens.backgroundSurface.withValues(alpha: 0.70),
                            borderRadius: BorderRadius.circular(4.0),
                            border: Border.all(
                              color: MoscaroTokens.borderSubtle,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            '$pageNum',
                            style: TextStyle(
                              color: isCurrentPage ? accentColor : MoscaroTokens.textMuted,
                              fontSize: 10.0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    // 2. If smart TOC categories were extracted from printed summary
    if (_smartTocCategories.isNotEmpty) {
      final isSearching = _searchQuery.isNotEmpty;
      final q = _searchQuery.toLowerCase();
      final displayedCategories = <SmartTocCategory>[];

      if (isSearching) {
        for (final cat in _smartTocCategories) {
          final catMatches = cat.title.toLowerCase().contains(q);
          final matchingSections = cat.sections.where((s) {
            return s.title.toLowerCase().contains(q) ||
                (s.tag != null && s.tag!.toLowerCase().contains(q));
          }).toList();

          if (catMatches) {
            displayedCategories.add(cat);
          } else if (matchingSections.isNotEmpty) {
            displayedCategories.add(SmartTocCategory(
              title: cat.title,
              pageNumber: cat.pageNumber,
              sections: matchingSections,
              isChapter: cat.isChapter,
            ));
          }
        }
      } else {
        displayedCategories.addAll(_smartTocCategories);
      }

      if (isSearching && displayedCategories.isEmpty) {
        return _buildEmptySearchResults(accentColor);
      }

      return Column(
        children: [
          if (_detectedTocPages.isNotEmpty && !isSearching)
            _buildPrintedTocHeaderBanner(accentColor),
          _buildOffsetCalibrationBar(accentColor),
          Expanded(
            child: MoscaroSleekScrollbar(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                itemCount: displayedCategories.length,
                itemBuilder: (context, catIndex) {
                  final category = displayedCategories[catIndex];
                  final isExpanded = isSearching || _expandedCategoryIndices.contains(catIndex);
                  final targetCatPage = (category.pageNumber + _pageOffset).clamp(1, widget.card.totalPdfPages);
                  final isCurrentCatPage = targetCatPage == widget.card.currentPdfPage;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 3.5),
                    decoration: BoxDecoration(
                      color: isExpanded
                          ? accentColor.withValues(alpha: 0.08)
                          : MoscaroTokens.backgroundSurface.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(
                        color: isExpanded
                            ? accentColor.withValues(alpha: 0.35)
                            : MoscaroTokens.borderSubtle,
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Category Header Button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9.0),
                            onTap: () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedCategoryIndices.remove(catIndex);
                                } else {
                                  _expandedCategoryIndices.add(catIndex);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                              child: Row(
                                children: [
                                  SvgIcon(
                                    name: isExpanded ? 'chevron_down' : 'chevron_right',
                                    size: 13.0,
                                    color: isExpanded ? accentColor : MoscaroTokens.iconInactive,
                                  ),
                                  const SizedBox(width: 8.0),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          category.title,
                                          style: TextStyle(
                                            color: MoscaroTokens.textPrimary,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.2,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (category.sections.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2.0),
                                            child: Text(
                                              '${category.sections.length} seções/tópicos',
                                              style: TextStyle(
                                                color: accentColor.withValues(alpha: 0.8),
                                                fontSize: 10.0,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6.0),
                                  // Direct Jump Button
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(6.0),
                                      onTap: () => widget.onPageJump(targetCatPage),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.5),
                                        decoration: BoxDecoration(
                                          color: isCurrentCatPage
                                              ? accentColor
                                              : accentColor.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6.0),
                                          border: Border.all(
                                            color: accentColor.withValues(alpha: 0.4),
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Text(
                                          'Pág. $targetCatPage',
                                          style: TextStyle(
                                            color: isCurrentCatPage ? (MoscaroTokens.isLight ? Colors.white : Colors.black) : accentColor,
                                            fontSize: 10.0,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Expanded Sections List
                        if (isExpanded && category.sections.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: MoscaroTokens.borderSubtle,
                                  width: 1.0,
                                ),
                              ),
                            ),
                            child: Column(
                              children: category.sections.map((section) {
                                final targetSecPage = (section.pageNumber + _pageOffset).clamp(1, widget.card.totalPdfPages);
                                final isCurrentSec = targetSecPage == widget.card.currentPdfPage;

                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => widget.onPageJump(targetSecPage),
                                    child: Container(
                                      padding: const EdgeInsets.only(
                                        left: 24.0,
                                        right: 10.0,
                                        top: 5.0,
                                        bottom: 5.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isCurrentSec
                                            ? accentColor.withValues(alpha: 0.15)
                                            : Colors.transparent,
                                        border: isCurrentSec
                                            ? Border(
                                                left: BorderSide(
                                                  color: accentColor,
                                                  width: 2.5,
                                                ),
                                              )
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          if (section.tag != null) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.0),
                                              margin: const EdgeInsets.only(right: 6.0),
                                              decoration: BoxDecoration(
                                                color: accentColor.withValues(alpha: 0.18),
                                                borderRadius: BorderRadius.circular(4.0),
                                                border: Border.all(
                                                  color: accentColor.withValues(alpha: 0.35),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                section.tag!,
                                                style: TextStyle(
                                                  color: accentColor,
                                                  fontSize: 9.0,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ] else ...[
                                            Container(
                                              width: 4.0,
                                              height: 4.0,
                                              margin: const EdgeInsets.only(right: 7.0),
                                              decoration: BoxDecoration(
                                                color: isCurrentSec ? accentColor : MoscaroTokens.textMuted,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                          Expanded(
                                            child: Text(
                                              section.title,
                                              style: TextStyle(
                                                color: isCurrentSec ? MoscaroTokens.textPrimary : MoscaroTokens.textSecondary,
                                                fontSize: 11.0,
                                                fontWeight: isCurrentSec ? FontWeight.w600 : FontWeight.w400,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6.0),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: isCurrentSec
                                                  ? accentColor.withValues(alpha: 0.25)
                                                  : MoscaroTokens.backgroundSurface.withValues(alpha: 0.70),
                                              borderRadius: BorderRadius.circular(4.0),
                                              border: Border.all(
                                                color: MoscaroTokens.borderSubtle,
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              _pageOffset != 0
                                                  ? '$targetSecPage (${section.pageNumber})'
                                                  : '$targetSecPage',
                                              style: TextStyle(
                                                color: isCurrentSec ? accentColor : MoscaroTokens.textMuted,
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      );
    }

    // 3. If a printed TOC page was detected but individual lines could not be split
    if (_detectedTocPages.isNotEmpty) {
      final firstTocPage = _detectedTocPages.first;
      final isCurrentOnToc = widget.card.currentPdfPage == firstTocPage;

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42.0,
                height: 42.0,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                ),
                child: Center(
                  child: SvgIcon(
                    name: 'file_text',
                    size: 20.0,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(height: 12.0),
              const Text(
                'Sumário Impresso Detectado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6.0),
              Text(
                'Página ${_detectedTocPages.join(', ')} identificada como o sumário do livro.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16.0),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8.0),
                  onTap: () => widget.onPageJump(firstTocPage),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: isCurrentOnToc
                          ? Colors.white.withValues(alpha: 0.1)
                          : accentColor,
                      borderRadius: BorderRadius.circular(8.0),
                      boxShadow: isCurrentOnToc
                          ? null
                          : [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.3),
                                blurRadius: 10.0,
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    child: Text(
                      isCurrentOnToc ? 'Você já está no Sumário' : 'Ir para o Sumário (Pág. $firstTocPage)',
                      style: TextStyle(
                        color: isCurrentOnToc ? Colors.white70 : Colors.black,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 4. Default empty state
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgIcon(
              name: 'file_text',
              size: 28.0,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 10.0),
            const Text(
              'Nenhum sumário estruturado encontrado neste documento.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14.0),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8.0),
                onTap: () => setState(() => _activeTab = PdfTocDrawerTab.bookmarks),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1.0,
                    ),
                  ),
                  child: const Text(
                    'Ver Marcadores',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintedTocHeaderBanner(Color accentColor) {
    final firstToc = _detectedTocPages.first;
    final isCurrent = widget.card.currentPdfPage == firstToc;

    return Container(
      margin: const EdgeInsets.fromLTRB(10.0, 8.0, 10.0, 6.0),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          SvgIcon(
            name: 'file_text',
            size: 13.0,
            color: accentColor,
          ),
          const SizedBox(width: 7.0),
          Expanded(
            child: Text(
              'Sumário impresso na pág. ${_detectedTocPages.join(', ')}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.0,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(5.0),
              onTap: () => widget.onPageJump(firstToc),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: isCurrent ? Colors.white.withValues(alpha: 0.15) : accentColor,
                  borderRadius: BorderRadius.circular(5.0),
                ),
                child: Text(
                  isCurrent ? 'Na pág.' : 'Ver Pág.',
                  style: TextStyle(
                    color: isCurrent ? Colors.white : Colors.black,
                    fontSize: 10.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffsetCalibrationBar(Color accentColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 6.0),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          SvgIcon(
            name: 'book',
            size: 12.0,
            color: accentColor,
          ),
          const SizedBox(width: 6.0),
          Expanded(
            child: Row(
              children: [
                const Text(
                  'Ajuste Pág.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_isAutoOffsetDetected) ...[
                  const SizedBox(width: 5.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.0),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3.5),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      'Auto',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(4.0),
              onTap: () {
                setState(() {
                  _pageOffset--;
                  _isAutoOffsetDetected = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: const SvgIcon(
                  name: 'minus',
                  size: 10.0,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 42.0),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              _pageOffset >= 0 ? '+$_pageOffset' : '$_pageOffset',
              style: TextStyle(
                color: accentColor,
                fontSize: 11.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(4.0),
              onTap: () {
                setState(() {
                  _pageOffset++;
                  _isAutoOffsetDetected = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: const SvgIcon(
                  name: 'plus',
                  size: 10.0,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySearchResults(Color accentColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgIcon(
              name: 'search',
              size: 26.0,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 10.0),
            Text(
              'Nenhum resultado para "$_searchQuery"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12.0),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(6.0),
                onTap: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1.0,
                    ),
                  ),
                  child: const Text(
                    'Limpar pesquisa',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _flattenNode(
    PdfOutlineNode node,
    int depth,
    String key,
    List<_FlattenedOutlineItem> result,
  ) {
    result.add(_FlattenedOutlineItem(node: node, depth: depth, key: key));
    final isCollapsed = _collapsedNodeKeys.contains(key);
    if (!isCollapsed && node.children.isNotEmpty) {
      for (int i = 0; i < node.children.length; i++) {
        _flattenNode(node.children[i], depth + 1, '$key.$i', result);
      }
    }
  }

  Widget _buildBookmarksView(Color accentColor, Set<int> bookmarkedSet) {
    final sortedBookmarks = bookmarkedSet.toList()..sort();

    if (sortedBookmarks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(
                name: 'star',
                size: 28.0,
                color: MoscaroTokens.iconInactive.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 10.0),
              Text(
                'Nenhum marcador adicionado ainda.\nClique no ícone de estrela da barra de ferramentas para marcar uma página.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MoscaroTokens.textMuted,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return MoscaroSleekScrollbar(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        itemCount: sortedBookmarks.length,
        itemBuilder: (context, index) {
          final pageNum = sortedBookmarks[index];
          final isCurrentPage = pageNum == widget.card.currentPdfPage;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => widget.onPageJump(pageNum),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
                decoration: BoxDecoration(
                  color: isCurrentPage
                      ? accentColor.withValues(alpha: 0.12)
                      : Colors.transparent,
                  border: isCurrentPage
                      ? Border(
                          left: BorderSide(
                            color: accentColor,
                            width: 2.5,
                          ),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    const SvgIcon(
                      name: 'star_filled',
                      size: 14.0,
                      color: MoscaroTokens.auroraAmber,
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        'Pagina $pageNum',
                        style: TextStyle(
                          color: isCurrentPage ? MoscaroTokens.textPrimary : MoscaroTokens.textSecondary,
                          fontSize: 12.0,
                          fontWeight: isCurrentPage ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: SvgIcon(
                        name: 'trash',
                        size: 13.0,
                        color: MoscaroTokens.iconInactive,
                      ),
                      splashRadius: 14.0,
                      tooltip: 'Remover marcador',
                      onPressed: () => widget.onToggleBookmark(pageNum),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FlattenedOutlineItem {
  final PdfOutlineNode node;
  final int depth;
  final String key;

  const _FlattenedOutlineItem({
    required this.node,
    required this.depth,
    required this.key,
  });
}
