import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfTextMatch;
import '../models/pdf_internal_object_models.dart';
import '../models/pdf_text_search_models.dart';
import '../models/pdf_text_selection_models.dart';
import '../services/pdf_image_bounds_service.dart';
import '../services/pdf_page_spatial_index.dart';
import '../theme/moscaro_theme_controller.dart';
import '../theme/moscaro_v2_tokens.dart';
import 'canvas_layers.dart';
import 'ink_models.dart';
import 'pdf_search_highlight_painter.dart';
import 'pdf_smart_cursor_overlay.dart';
import 'pdf_text_context_menu.dart';
import 'pdf_text_selection_painter.dart';
import 'svg_icon.dart';

/// Hardware-accelerated GPU color filter matrix for Moscaro Dark Mode.
/// Linearly transforms white background (255, 255, 255) into Moscaro deep surface #0e1018 (14, 16, 24),
/// and maps black ink (0, 0, 0) into crisp readable off-white (255, 255, 255).
/// Preserves the alpha channel intact to maintain layer transparency.
const List<double> moscaroDarkLuminanceMatrix = <double>[
  -0.945098,  0.0,        0.0,        0.0, 255.0, // Red: 255 * (-0.945098) + 255 = 14 (#0E)
   0.0,       -0.937255,  0.0,        0.0, 255.0, // Green: 255 * (-0.937255) + 255 = 16 (#10)
   0.0,        0.0,       -0.905882,  0.0, 255.0, // Blue: 255 * (-0.905882) + 255 = 24 (#18)
   0.0,        0.0,        0.0,        1.0,   0.0, // Alpha
];

/// Compiled ColorFilter instance ready for immediate GPU usage via ColorFiltered.
const ColorFilter moscaroDarkLuminanceFilter =
    ColorFilter.matrix(moscaroDarkLuminanceMatrix);

/// Widget representing an individual PDF page subcard on the infinite canvas.
/// Adheres strictly to the Moscaro v2 design system:
/// - 10.0px corner radius with ClipRRect clipping
/// - Subtle cyan glowing border (#00e1ff) overlaid crisp and unclipped
/// - Deep liquid glass shadow and dark surface tint
/// - Single-click selection for subcard and Ctrl+click for whole document
/// - Hardware-accelerated luminance inversion filter for dark mode (#0e1018)
/// - Hover quick action: "Desprender Pagina" (SVG icon share, zero emojis)
/// - Layered ink stroke rendering with highlighter-first blending
class PdfPageSubcardWidget extends StatefulWidget {
  /// The loaded PdfDocument instance from pdfrx engine.
  final PdfDocument? document;

  /// 1-based index identifying the page within the parent document (1..pages.length).
  final int pageNumber;

  /// Width of this page sheet on the infinite canvas.
  final double width;

  /// Explicit height of this page sheet. If null, computed proportionally from page aspect ratio.
  final double? height;

  /// Absolute X canvas coordinate of this page top-left (for ink stroke offset mapping).
  final double pageX;

  /// Absolute Y canvas coordinate of this page top-left (for ink stroke offset mapping).
  final double pageY;

  /// Whether this specific page subcard is selected (active page).
  final bool isPageSelected;

  /// Whether the parent document card as a whole is selected.
  final bool isDocumentSelected;

  /// Whether the dark mode luminance inversion filter is active.
  final bool invertLuminance;

  /// Whether the parent card is locked against dragging and detachment.
  final bool isPdfLocked;

  /// Current zoom scale of the infinite canvas camera.
  final double zoomScale;

  /// Callback when user clicks to select this individual page subcard.
  final ValueChanged<int>? onSelectPage;

  /// Callback when user Ctrl+clicks to select the entire document.
  final VoidCallback? onSelectWholeDocument;

  /// Callback when user clicks "Desprender Pagina" to extract page into standalone card.
  final ValueChanged<int>? onDetachPage;

  /// Optional callback on double-tap (e.g. text selection or word zoom).
  final VoidCallback? onDoubleTap;

  /// Pan start callback for card movement on canvas.
  final GestureDragStartCallback? onPanStart;

  /// Pan update callback for card movement on canvas.
  final GestureDragUpdateCallback? onPanUpdate;

  /// Pan end callback for card movement on canvas.
  final GestureDragEndCallback? onPanEnd;

  /// Pan cancel callback for card movement on canvas.
  final GestureDragCancelCallback? onPanCancel;

  /// Ink strokes anchored to this page.
  final List<InkStroke>? attachedStrokes;

  /// Optional resize handles overlay (e.g. 4-corner proportional resize handles).
  final Widget? resizeHandles;

  /// Text search matches on this specific page sheet.
  final List<PdfTextMatch>? searchMatches;

  /// The active focused search match (if on this page sheet).
  final PdfTextMatch? activeSearchMatch;

  /// Active tool in canvas ('select', 'pen', 'highlighter', etc.).
  final String activeTool;

  /// Active text selection state on this page sheet (if any).
  final PdfTextSelectionState? textSelection;

  /// Callback when text selection changes, expands, or is cleared.
  final ValueChanged<PdfTextSelectionState?>? onTextSelectionChanged;

  /// Callback to instantiate a STEM card from the current text selection.
  final VoidCallback? onGenerateStemCardFromSelection;

  /// Callback to apply an aligned highlighter stroke over the selected text.
  final VoidCallback? onHighlightSelection;

  /// Clockwise rotation in quarter turns (0 = 0 deg, 1 = 90 deg, 2 = 180 deg, 3 = 270 deg).
  final int rotationQuarterTurns;

  /// Optional callback to instantiate a card for a detected object (image, formula, table).
  final ValueChanged<PdfInternalObject>? onSpawnCardForObject;

  /// Optional callback to send a detected object to AI.
  final ValueChanged<PdfInternalObject>? onAskAiObject;

  /// Optional callback to send the current text selection to AI.
  final VoidCallback? onAskAiSelection;

  const PdfPageSubcardWidget({
    super.key,
    required this.document,
    required this.pageNumber,
    required this.width,
    this.height,
    this.pageX = 0.0,
    this.pageY = 0.0,
    this.isPageSelected = false,
    this.isDocumentSelected = false,
    this.invertLuminance = false,
    this.isPdfLocked = false,
    this.zoomScale = 1.0,
    this.onSelectPage,
    this.onSelectWholeDocument,
    this.onDetachPage,
    this.onDoubleTap,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.onPanCancel,
    this.attachedStrokes,
    this.resizeHandles,
    this.searchMatches,
    this.activeSearchMatch,
    this.activeTool = 'pen',
    this.textSelection,
    this.onTextSelectionChanged,
    this.onGenerateStemCardFromSelection,
    this.onHighlightSelection,
    this.rotationQuarterTurns = 0,
    this.onSpawnCardForObject,
    this.onAskAiObject,
    this.onAskAiSelection,
  });

  /// Standard corner radius for PDF page sheets in conNotes.
  static const double borderRadius = 10.0;

  @override
  State<PdfPageSubcardWidget> createState() => _PdfPageSubcardWidgetState();
}

class _PdfPageSubcardWidgetState extends State<PdfPageSubcardWidget> {
  bool _isHovered = false;
  PdfPageText? _pageText;
  PdfPageSpatialIndex? _spatialIndex;

  @override
  void initState() {
    super.initState();
    _ensurePageTextLoaded();
  }

  @override
  void didUpdateWidget(covariant PdfPageSubcardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document ||
        oldWidget.pageNumber != widget.pageNumber ||
        oldWidget.rotationQuarterTurns != widget.rotationQuarterTurns ||
        oldWidget.width != widget.width ||
        oldWidget.height != widget.height) {
      if (oldWidget.document != widget.document || oldWidget.pageNumber != widget.pageNumber) {
        _pageText = null;
        _spatialIndex = null;
        _ensurePageTextLoaded();
      } else {
        _rebuildSpatialIndex();
      }
    }
  }

  void _rebuildSpatialIndex() {
    if (_pageText != null) {
      final docPath = widget.document?.sourceName ?? '';
      final imageRects = docPath.isNotEmpty
          ? PdfImageBoundsService.instance.getImageRectsForPageSync(
              pdfPath: docPath,
              pageNumber: widget.pageNumber,
              nativePageWidth: _nativePageWidth,
              nativePageHeight: _nativePageHeight,
            )
          : <Rect>[];
      _spatialIndex = PdfPageSpatialIndex.fromPageText(
        pageText: _pageText!,
        pageNumber: widget.pageNumber,
        nativeWidth: _nativePageWidth,
        nativeHeight: _nativePageHeight,
        excludedImageRects: imageRects,
      );
    } else {
      _spatialIndex = null;
    }
  }

  Future<void> _ensurePageTextLoaded() async {
    if (_pageText != null || widget.document == null) return;
    if (widget.pageNumber < 1 || widget.pageNumber > widget.document!.pages.length) return;
    try {
      final page = widget.document!.pages[widget.pageNumber - 1];
      final loaded = await page.loadText();
      if (mounted) {
        setState(() {
          _pageText = loaded;
          _rebuildSpatialIndex();
        });
      }
    } catch (e) {
      debugPrint('[PdfPageSubcardWidget] Error loading text for page ${widget.pageNumber}: $e');
    }
  }

  /// Resolves the effective height of the page sheet based on intrinsic aspect ratio and rotation.
  double get _effectiveHeight {
    if (widget.height != null && widget.height! > 0) {
      return widget.height!;
    }

    final isTransposed = (widget.rotationQuarterTurns % 2) != 0;
    final doc = widget.document;
    if (doc != null &&
        widget.pageNumber >= 1 &&
        widget.pageNumber <= doc.pages.length) {
      final page = doc.pages[widget.pageNumber - 1];
      if (page.width > 0 && page.height > 0) {
        final ratio = isTransposed ? (page.width / page.height) : (page.height / page.width);
        return widget.width * ratio;
      }
    }

    // Default to standard A4 ratio (1 : sqrt(2) ~ 1.4142) while loading
    final defaultRatio = isTransposed ? (1.0 / 1.4142) : 1.4142;
    return widget.width * defaultRatio;
  }

  double get _nativePageWidth {
    final isTransposed = (widget.rotationQuarterTurns % 2) != 0;
    final doc = widget.document;
    if (doc != null &&
        widget.pageNumber >= 1 &&
        widget.pageNumber <= doc.pages.length) {
      final page = doc.pages[widget.pageNumber - 1];
      if (page.width > 0 && page.height > 0) {
        return isTransposed ? page.height : page.width;
      }
    }
    return widget.width;
  }

  double get _nativePageHeight {
    final isTransposed = (widget.rotationQuarterTurns % 2) != 0;
    final doc = widget.document;
    if (doc != null &&
        widget.pageNumber >= 1 &&
        widget.pageNumber <= doc.pages.length) {
      final page = doc.pages[widget.pageNumber - 1];
      if (page.width > 0 && page.height > 0) {
        return isTransposed ? page.width : page.height;
      }
    }
    return _effectiveHeight;
  }

  void _handleTap() {
    if (widget.textSelection != null && widget.textSelection!.isNotEmpty) {
      widget.onTextSelectionChanged?.call(null);
      return;
    }
    final isCtrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (isCtrl) {
      widget.onSelectWholeDocument?.call();
    } else {
      widget.onSelectPage?.call(widget.pageNumber);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = _effectiveHeight;
    final isSelected = widget.isPageSelected;
    final isDocSelected = widget.isDocumentSelected;

    final theme = MoscaroThemeController.instance.currentTheme;
    final themeAccent = theme.accentPrimary;

    // Moscaro Glowing Border & Shadow Tokens
    final borderColor = isSelected
        ? themeAccent
        : (isDocSelected
            ? themeAccent.withValues(alpha: 0.60)
            : MoscaroTokens.borderGlowActive.withValues(alpha: 0.30));

    final borderWidth = isSelected ? 1.8 : 1.0;

    final boxShadow = [
      if (isSelected)
        BoxShadow(
          color: themeAccent.withValues(alpha: 0.38),
          blurRadius: 18.0,
          spreadRadius: 1.0,
        )
      else if (isDocSelected)
        BoxShadow(
          color: themeAccent.withValues(alpha: 0.18),
          blurRadius: 12.0,
          spreadRadius: 0.5,
        ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isSelected ? 0.42 : 0.35),
        blurRadius: isSelected ? 14.0 : 12.0,
        offset: const Offset(0, 5),
      ),
    ];

    final strokes = widget.attachedStrokes ?? const <InkStroke>[];
    final canDrag = widget.onPanUpdate != null;
    final hasTextSelection = widget.textSelection != null &&
        widget.textSelection!.isNotEmpty &&
        widget.textSelection!.pageNumber == widget.pageNumber;

    return MouseRegion(
      cursor: _pageText != null
          ? SystemMouseCursors.text
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _pageText != null ? null : _handleTap,
        onDoubleTap: _pageText != null ? null : widget.onDoubleTap,
        onPanStart: (_pageText != null || !canDrag) ? null : widget.onPanStart,
        onPanUpdate: (_pageText != null || !canDrag) ? null : widget.onPanUpdate,
        onPanEnd: (_pageText != null || !canDrag) ? null : widget.onPanEnd,
        onPanCancel: (_pageText != null || !canDrag) ? null : widget.onPanCancel,
        child: Focus(
          autofocus: hasTextSelection,
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.keyC, control: true): () {
                if (hasTextSelection) {
                  Clipboard.setData(ClipboardData(text: widget.textSelection!.selectedText));
                }
              },
              const SingleActivator(LogicalKeyboardKey.keyC, meta: true): () {
                if (hasTextSelection) {
                  Clipboard.setData(ClipboardData(text: widget.textSelection!.selectedText));
                }
              },
              const SingleActivator(LogicalKeyboardKey.escape): () {
                if (hasTextSelection) {
                  widget.onTextSelectionChanged?.call(null);
                }
              },
            },
            child: Container(
            width: widget.width,
            height: effectiveHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PdfPageSubcardWidget.borderRadius),
              boxShadow: boxShadow,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Clipped Page Sheet Body
                ClipRRect(
                  borderRadius: BorderRadius.circular(PdfPageSubcardWidget.borderRadius),
                  child: Stack(
                    children: [
                      // A. Base PDF Document Page Sheet
                      Positioned.fill(
                        child: _buildPageSheet(widget.width, effectiveHeight),
                      ),

                      // A.2 Search Highlights Overlay
                      if (widget.searchMatches != null && widget.searchMatches!.isNotEmpty)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: PdfPageSearchHighlightPainter(
                                  matches: widget.searchMatches!,
                                  activeMatch: widget.activeSearchMatch,
                                  pageWidth: widget.width,
                                  pageHeight: effectiveHeight,
                                  pdfNativeWidth: _nativePageWidth,
                                  pdfNativeHeight: _nativePageHeight,
                                  accentColor: themeAccent,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // A.3 Native Text Selection Highlight Overlay (estável na árvore para preservar State do Cursor)
                      Positioned.fill(
                        key: ValueKey('pdf_text_selection_highlight_${widget.pageNumber}'),
                        child: IgnorePointer(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: PdfTextSelectionPainter(
                                rects: hasTextSelection ? widget.textSelection!.rects : const [],
                                isSelecting: hasTextSelection ? widget.textSelection!.isSelecting : false,
                                accentColor: themeAccent,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // B. Anchored Ink Strokes Overlay
                      if (strokes.isNotEmpty)
                        Positioned.fill(
                          key: ValueKey('pdf_page_strokes_${widget.pageNumber}'),
                          child: IgnorePointer(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: _PdfPageStrokesPainter(
                                  strokes: strokes,
                                  pageX: widget.pageX,
                                  pageY: widget.pageY,
                                  pageWidth: widget.width,
                                  pageHeight: effectiveHeight,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // B.2 Universal Smart Cursor & Text Selection Overlay (preserva _clickCount e foco através de Key persistente)
                      if (_pageText != null)
                        Positioned.fill(
                          key: ValueKey('pdf_smart_cursor_overlay_pos_${widget.pageNumber}'),
                          child: PdfSmartCursorOverlay(
                            key: ValueKey('pdf_smart_cursor_overlay_${widget.pageNumber}'),
                            pageNumber: widget.pageNumber,
                            pageWidth: widget.width,
                            pageHeight: effectiveHeight,
                            nativeWidth: _nativePageWidth,
                            nativeHeight: _nativePageHeight,
                            spatialIndex: _spatialIndex,
                            activeTextSelection: widget.textSelection,
                            onTextSelectionChanged: widget.onTextSelectionChanged,
                            onHighlightText: widget.onHighlightSelection,
                            onDismissSelection: () {
                              widget.onTextSelectionChanged?.call(null);
                            },
                            onSelectPage: widget.onSelectPage,
                            onGenerateStemCard: widget.onGenerateStemCardFromSelection,
                            onAskAi: widget.onAskAiSelection,
                          ),
                        ),

                      // C. Hover Badge: Page Number Indicator (Top-Left)
                      _buildPageIndexBadge(),
                    ],
                  ),
                ),

                // 2. Crisp Moscaro Cyan Border Overlay (Guaranteed top-layer anti-aliased edge)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(PdfPageSubcardWidget.borderRadius),
                        border: Border.all(
                          color: borderColor,
                          width: borderWidth,
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. External Corner Resize Handles Layer
                if (widget.resizeHandles != null && (isSelected || isDocSelected))
                  Positioned.fill(
                    child: widget.resizeHandles!,
                  ),

                // 4. Contextual Mini-Pill fallback (only if SmartCursorOverlay is not active)
                if (hasTextSelection && !widget.textSelection!.isSelecting && _pageText == null)
                  _buildContextMenu(widget.textSelection!),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildContextMenu(PdfTextSelectionState selection) {
    final bounds = selection.bounds;
    const double menuWidth = 240.0;

    double top = bounds.top - 40.0;
    if (top < 10.0) {
      top = bounds.bottom + 8.0;
    }
    final double left = (bounds.left + bounds.width / 2.0 - (menuWidth / 2.0))
        .clamp(8.0, math.max(8.0, widget.width - menuWidth - 8.0));

    return Positioned(
      left: left,
      top: top,
      child: PdfTextContextMenu(
        onGenerateStemCard: () {
          widget.onGenerateStemCardFromSelection?.call();
          widget.onTextSelectionChanged?.call(null);
        },
        onHighlight: () {
          widget.onHighlightSelection?.call();
          widget.onTextSelectionChanged?.call(null);
        },
        onDismiss: () => widget.onTextSelectionChanged?.call(null),
      ),
    );
  }

  /// Builds the underlying PDF page view with optional Moscaro luminance inversion.
  Widget _buildPageSheet(double width, double height) {
    final doc = widget.document;
    if (doc == null ||
        widget.pageNumber < 1 ||
        widget.pageNumber > doc.pages.length) {
      return _buildPlaceholder(width, height);
    }

    Widget pageView = SizedBox(
      width: width,
      height: height,
      child: PdfPageView(
        key: ValueKey('pdfrx_page_${widget.pageNumber}_w${width.round()}'),
        document: doc,
        pageNumber: widget.pageNumber,
        maximumDpi: 300,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
      ),
    );

    if (widget.invertLuminance) {
      pageView = ColorFiltered(
        colorFilter: moscaroDarkLuminanceFilter,
        child: pageView,
      );
    }

    if (widget.rotationQuarterTurns != 0) {
      pageView = RotatedBox(
        quarterTurns: widget.rotationQuarterTurns,
        child: pageView,
      );
    }

    return RepaintBoundary(
      child: pageView,
    );
  }

  /// Builds a placeholder container while document or page textures are loading.
  Widget _buildPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: widget.invertLuminance
          ? const Color(0xFF0E1018)
          : MoscaroTokens.backgroundSurface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgIcon(
              name: 'layers',
              size: 26,
              color: MoscaroTokens.auroraBlue.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 10),
            Text(
              'Carregando Pagina ${widget.pageNumber}...',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: MoscaroTokens.textMuted,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the page number indicator badge at top-left.
  Widget _buildPageIndexBadge() {
    final totalPages = widget.document?.pages.length;
    final badgeText = totalPages != null && totalPages > 0
        ? 'Pag. ${widget.pageNumber} / $totalPages'
        : 'Pag. ${widget.pageNumber}';

    return Positioned(
      top: 10.0,
      left: 10.0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _isHovered ? 1.0 : 0.0,
        curve: Curves.easeOut,
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: MoscaroTokens.glassTint,
              borderRadius: BorderRadius.circular(MoscaroTokens.radiusButton),
              border: Border.all(
                color: MoscaroTokens.borderGlow,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 6.0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: MoscaroTokens.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter rendering anchored ink strokes over a specific PDF page.
class _PdfPageStrokesPainter extends CustomPainter {
  final List<InkStroke> strokes;
  final double pageX;
  final double pageY;
  final double pageWidth;
  final double pageHeight;
  final Paint _paint = Paint();

  _PdfPageStrokesPainter({
    required this.strokes,
    required this.pageX,
    required this.pageY,
    required this.pageWidth,
    required this.pageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;

    final scaleX = (pageWidth > 0 && size.width > 0) ? (size.width / pageWidth) : 1.0;
    final scaleY = (pageHeight > 0 && size.height > 0) ? (size.height / pageHeight) : 1.0;

    canvas.save();
    if (scaleX != 1.0 || scaleY != 1.0) {
      canvas.scale(scaleX, scaleY);
    }

    // Offset coordinates from absolute canvas origin to page top-left origin
    canvas.translate(-pageX, -pageY);

    // 1. Highlighters painted first (blended under pen strokes)
    for (final s in strokes) {
      if (s.toolType == InkToolType.highlighter) {
        StrokePictureCache.drawSingleStroke(canvas, s, _paint);
      }
    }

    // 2. Regular pen and pencil strokes painted on top
    for (final s in strokes) {
      if (s.toolType != InkToolType.highlighter) {
        StrokePictureCache.drawSingleStroke(canvas, s, _paint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PdfPageStrokesPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.strokes.length != strokes.length ||
        oldDelegate.pageX != pageX ||
        oldDelegate.pageY != pageY ||
        oldDelegate.pageWidth != pageWidth ||
        oldDelegate.pageHeight != pageHeight;
  }
}
