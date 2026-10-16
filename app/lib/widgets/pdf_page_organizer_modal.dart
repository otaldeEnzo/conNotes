import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/canvas_card_model.dart';
import '../services/pdf_document_service.dart';
import '../services/diagnostics_override_controller.dart';
import '../theme/moscaro_theme_controller.dart';
import '../theme/moscaro_v2_tokens.dart';
import 'moscaro_sleek_scrollbar.dart';
import 'pdf_page_subcard_widget.dart' show moscaroDarkLuminanceFilter;
import 'svg_icon.dart';

/// Modal dialog for structural PDF page management:
/// reordering, rotating by 90-degree steps, deleting/hiding, detaching to canvas,
/// and direct 1-click page jump with real rendered PDF thumbnails.
/// Adheres strictly to the Moscaro v2 design standard with zero emojis.
class PdfPageOrganizerModal extends StatefulWidget {
  final CanvasCardModel card;
  final ValueChanged<CanvasCardModel> onUpdateCard;
  final ValueChanged<int>? onPageJump;
  final ValueChanged<int>? onDetachPageToCanvas;
  final VoidCallback? onExportPdf;

  const PdfPageOrganizerModal({
    super.key,
    required this.card,
    required this.onUpdateCard,
    this.onPageJump,
    this.onDetachPageToCanvas,
    this.onExportPdf,
  });

  static Future<void> show(
    BuildContext context, {
    required CanvasCardModel card,
    required ValueChanged<CanvasCardModel> onUpdateCard,
    ValueChanged<int>? onPageJump,
    ValueChanged<int>? onDetachPageToCanvas,
    VoidCallback? onExportPdf,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.70),
      builder: (ctx) => PdfPageOrganizerModal(
        card: card,
        onUpdateCard: onUpdateCard,
        onPageJump: onPageJump,
        onDetachPageToCanvas: onDetachPageToCanvas,
        onExportPdf: onExportPdf,
      ),
    );
  }

  @override
  State<PdfPageOrganizerModal> createState() => _PdfPageOrganizerModalState();
}

class _PdfPageOrganizerModalState extends State<PdfPageOrganizerModal> {
  late List<int> _workingOrder;
  late Set<int> _excludedPages;
  late Map<int, int> _rotations;
  PdfDocument? _pdfDocument;

  @override
  void initState() {
    super.initState();
    final total = widget.card.totalPdfPages;
    if (widget.card.pageOrder.isNotEmpty) {
      _workingOrder = List<int>.from(widget.card.pageOrder);
      // Ensure all pages 1..total are present
      for (int i = 1; i <= total; i++) {
        if (!_workingOrder.contains(i)) _workingOrder.add(i);
      }
    } else {
      _workingOrder = List<int>.generate(total, (i) => i + 1);
    }
    _excludedPages = Set<int>.from(widget.card.excludedPageIndices);
    _rotations = Map<int, int>.from(widget.card.pageRotations);
    _loadPdfDocument();
  }

  Future<void> _loadPdfDocument() async {
    final path = widget.card.pdfPath;
    if (path != null && path.isNotEmpty) {
      try {
        final doc = await PdfDocumentService.instance.loadDocument(path);
        if (mounted) {
          setState(() {
            _pdfDocument = doc;
          });
        }
      } catch (e) {
        debugPrint('PdfPageOrganizerModal._loadPdfDocument error: $e');
      }
    }
  }

  void _handleJumpToPage(int pageNumber) {
    if (widget.onPageJump != null) {
      widget.onPageJump!(pageNumber);
    } else {
      widget.onUpdateCard(widget.card.copyWith(currentPdfPage: pageNumber));
    }
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _rotatePage(int pageNumber, {bool clockwise = true}) {
    setState(() {
      final current = _rotations[pageNumber] ?? 0;
      if (clockwise) {
        _rotations[pageNumber] = (current + 1) % 4; // 0, 90, 180, 270 degrees
      } else {
        _rotations[pageNumber] = (current - 1 + 4) % 4;
      }
    });
  }

  void _toggleExcludePage(int pageNumber) {
    setState(() {
      if (_excludedPages.contains(pageNumber)) {
        _excludedPages.remove(pageNumber);
      } else {
        _excludedPages.add(pageNumber);
      }
    });
  }

  void _movePage(int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return;
    setState(() {
      final item = _workingOrder.removeAt(fromIndex);
      _workingOrder.insert(toIndex, item);
    });
  }

  void _applyChanges() {
    final updated = widget.card.copyWith(
      pageOrder: _workingOrder,
      excludedPageIndices: _excludedPages.toList(),
      pageRotations: _rotations,
    );
    widget.onUpdateCard(updated);
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = MoscaroThemeController.instance.currentTheme;
    final themeAccent = theme.accentPrimary;
    final isLight = MoscaroTokens.isLight;
    final activeCount = _workingOrder.where((p) => !_excludedPages.contains(p)).length;
    final bool bypass = DiagnosticsOverrideController.instance.bypassBackdropFilter;
    final double blurSigma = (!bypass && MoscaroTokens.enableModalsBlur && MoscaroTokens.blurSigma > 0)
        ? MoscaroTokens.blurSigma
        : 0.0;
    final effectiveBgColor = MoscaroTokens.glassTint;

    final dialogContent = Container(
      constraints: const BoxConstraints(maxWidth: 860.0, maxHeight: 620.0),
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: BorderRadius.circular(MoscaroTokens.radiusPanel),
        border: Border.all(
          color: isLight
              ? MoscaroTokens.borderSubtle
              : themeAccent.withValues(alpha: 0.35),
          width: MoscaroTokens.borderWidthSubtle,
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? const Color(0x180F172A)
                : Colors.black.withValues(alpha: 0.50),
            blurRadius: isLight ? 20.0 : 28.0,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: themeAccent.withValues(alpha: isLight ? 0.08 : 0.15),
            blurRadius: 16.0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(themeAccent, isLight, activeCount),

          // Body Grid
          Expanded(
            child: _buildGridBody(themeAccent, isLight),
          ),

          // Footer
          _buildFooter(themeAccent, isLight),
        ],
      ),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 30.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MoscaroTokens.radiusPanel),
        child: blurSigma > 0
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: dialogContent,
              )
            : dialogContent,
      ),
    );
  }

  Widget _buildHeader(Color themeAccent, bool isLight, int activeCount) {
    return Container(
      height: 56.0,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
          SvgIcon(name: 'layers', size: 18.0, color: themeAccent),
          const SizedBox(width: 10.0),
          Flexible(
            child: Text(
              'Organizador de Páginas & Estrutura',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: MoscaroTokens.textPrimary,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
            decoration: BoxDecoration(
              color: themeAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Text(
              '$activeCount de ${widget.card.totalPdfPages} páginas ativas',
              style: TextStyle(
                fontSize: 11.0,
                fontWeight: FontWeight.w600,
                color: themeAccent,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            icon: SvgIcon(
              name: 'x',
              size: 16.0,
              color: MoscaroTokens.iconInactive,
            ),
            tooltip: 'Fechar',
          ),
        ],
      ),
    );
  }

  Widget _buildGridBody(Color themeAccent, bool isLight) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: MoscaroSleekScrollbar(
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 14.0,
            mainAxisSpacing: 14.0,
            childAspectRatio: 0.75,
          ),
          itemCount: _workingOrder.length,
          itemBuilder: (context, index) {
            final pageNum = _workingOrder[index];
            final isExcluded = _excludedPages.contains(pageNum);
            final rotTurns = _rotations[pageNum] ?? 0;
            final rotDegrees = rotTurns * 90;

            final isCurrent = pageNum == widget.card.currentPdfPage;

            return _PageCardItem(
              pageNumber: pageNum,
              index: index,
              totalItems: _workingOrder.length,
              isExcluded: isExcluded,
              rotationQuarterTurns: rotTurns,
              rotationDegrees: rotDegrees,
              themeAccent: themeAccent,
              isLight: isLight,
              pdfDocument: _pdfDocument,
              invertLuminance: widget.card.invertLuminance,
              isCurrentPage: isCurrent,
              onJumpToPage: () => _handleJumpToPage(pageNum),
              onRotateClockwise: () => _rotatePage(pageNum, clockwise: true),
              onRotateCounterClockwise: () => _rotatePage(pageNum, clockwise: false),
              onToggleExclude: () => _toggleExcludePage(pageNum),
              onMoveLeft: index > 0 ? () => _movePage(index, index - 1) : null,
              onMoveRight: index < _workingOrder.length - 1 ? () => _movePage(index, index + 1) : null,
              onDetach: widget.onDetachPageToCanvas != null
                  ? () {
                      widget.onDetachPageToCanvas!(pageNum);
                      if (mounted && Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    }
                  : null,
            );
          },
        ),
      ),
    );
  }

  Widget _buildFooter(Color themeAccent, bool isLight) {
    final onAccentColor = MoscaroTokens.isLight ? Colors.white : Colors.black;

    return Container(
      height: 60.0,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: MoscaroTokens.borderSubtle,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (widget.onExportPdf != null)
            TextButton.icon(
              onPressed: () {
                if (mounted && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                widget.onExportPdf!();
              },
              icon: SvgIcon(name: 'share', size: 14.0, color: themeAccent),
              label: Text(
                'Exportar PDF Consolidado',
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: themeAccent,
                ),
              ),
            )
          else
            const SizedBox.shrink(),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  if (mounted && Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    color: MoscaroTokens.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10.0),
              ElevatedButton.icon(
                onPressed: _applyChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeAccent,
                  foregroundColor: onAccentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MoscaroTokens.radiusButton),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                ),
                icon: SvgIcon(name: 'check', size: 14.0, color: onAccentColor),
                label: const Text(
                  'Aplicar Alterações',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageCardItem extends StatelessWidget {
  final int pageNumber;
  final int index;
  final int totalItems;
  final bool isExcluded;
  final int rotationQuarterTurns;
  final int rotationDegrees;
  final Color themeAccent;
  final bool isLight;
  final PdfDocument? pdfDocument;
  final bool invertLuminance;
  final bool isCurrentPage;
  final VoidCallback onJumpToPage;
  final VoidCallback onRotateClockwise;
  final VoidCallback onRotateCounterClockwise;
  final VoidCallback onToggleExclude;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;
  final VoidCallback? onDetach;

  const _PageCardItem({
    required this.pageNumber,
    required this.index,
    required this.totalItems,
    required this.isExcluded,
    required this.rotationQuarterTurns,
    required this.rotationDegrees,
    required this.themeAccent,
    required this.isLight,
    this.pdfDocument,
    this.invertLuminance = false,
    this.isCurrentPage = false,
    required this.onJumpToPage,
    required this.onRotateClockwise,
    required this.onRotateCounterClockwise,
    required this.onToggleExclude,
    required this.onMoveLeft,
    required this.onMoveRight,
    this.onDetach,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: isExcluded
            ? (isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.03))
            : MoscaroTokens.backgroundSurface.withValues(alpha: isLight ? 0.90 : 0.65),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: isExcluded
              ? MoscaroTokens.auroraPink.withValues(alpha: 0.40)
              : (isCurrentPage ? themeAccent : (isLight ? MoscaroTokens.borderSubtle : themeAccent.withValues(alpha: 0.25))),
          width: isCurrentPage ? 1.8 : 1.2,
        ),
        boxShadow: isExcluded
            ? []
            : [
                BoxShadow(
                  color: isCurrentPage
                      ? themeAccent.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.20),
                  blurRadius: isCurrentPage ? 12.0 : 8.0,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        children: [
          // Card Header: Page Number and Badges
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pág. $pageNumber',
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                    color: isExcluded
                        ? MoscaroTokens.textMuted
                        : (isCurrentPage ? themeAccent : MoscaroTokens.textPrimary),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      if (isCurrentPage) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                          margin: const EdgeInsets.only(right: 3.0),
                          decoration: BoxDecoration(
                            color: themeAccent.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(4.0),
                            border: Border.all(
                              color: themeAccent.withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'Atual',
                            style: TextStyle(
                              fontSize: 9.0,
                              fontWeight: FontWeight.w700,
                              color: themeAccent,
                            ),
                          ),
                        ),
                      ],
                      if (rotationDegrees > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                          decoration: BoxDecoration(
                            color: themeAccent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6.0),
                          ),
                          child: Text(
                            '$rotationDegrees°',
                            style: TextStyle(
                              fontSize: 9.0,
                              fontWeight: FontWeight.w700,
                              color: themeAccent,
                            ),
                          ),
                        ),
                      if (isExcluded) ...[
                        const SizedBox(width: 3.0),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                          decoration: BoxDecoration(
                            color: MoscaroTokens.auroraPink.withValues(alpha: 0.18),
                            borderRadius: const BorderRadius.all(Radius.circular(6.0)),
                          ),
                          child: const Text(
                            'Oculta',
                            style: TextStyle(
                              fontSize: 9.0,
                              fontWeight: FontWeight.w700,
                              color: MoscaroTokens.auroraPink,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              ],
            ),
          ),

          // Central Sheet Representation (Real Rendered PDF Page View)
          Expanded(
            child: Center(
              child: Tooltip(
                message: 'Clique para ir para a pág. $pageNumber',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onJumpToPage,
                    child: RotatedBox(
                      quarterTurns: rotationQuarterTurns,
                      child: Container(
                        width: 76.0,
                        height: 104.0,
                        decoration: BoxDecoration(
                          color: isExcluded
                              ? (isLight ? Colors.black12 : Colors.white10)
                              : (isLight ? const Color(0xFFF1F5F9) : MoscaroTokens.backgroundDeep),
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(
                            color: isCurrentPage
                                ? themeAccent
                                : (isExcluded
                                    ? Colors.transparent
                                    : MoscaroTokens.borderSubtle),
                            width: isCurrentPage ? 1.8 : 1.0,
                          ),
                          boxShadow: [
                            if (isCurrentPage)
                              BoxShadow(
                                color: themeAccent.withValues(alpha: 0.35),
                                blurRadius: 8.0,
                              ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5.0),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (pdfDocument != null &&
                                  pageNumber >= 1 &&
                                  pageNumber <= pdfDocument!.pages.length) ...[
                                if (invertLuminance)
                                  ColorFiltered(
                                    colorFilter: moscaroDarkLuminanceFilter,
                                    child: PdfPageView(
                                      key: ValueKey('organizer_thumb_$pageNumber'),
                                      document: pdfDocument!,
                                      pageNumber: pageNumber,
                                      maximumDpi: 120,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(color: Colors.white),
                                    ),
                                  )
                                else
                                  PdfPageView(
                                    key: ValueKey('organizer_thumb_$pageNumber'),
                                    document: pdfDocument!,
                                    pageNumber: pageNumber,
                                    maximumDpi: 120,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(color: Colors.white),
                                  ),
                              ] else ...[
                                Center(
                                  child: SvgIcon(
                                    name: 'file',
                                    size: 24.0,
                                    color: isExcluded
                                        ? MoscaroTokens.iconInactive
                                        : themeAccent.withValues(alpha: 0.60),
                                  ),
                                ),
                              ],
                              if (isExcluded)
                                Container(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  child: const Center(
                                    child: SvgIcon(
                                      name: 'close',
                                      size: 18.0,
                                      color: MoscaroTokens.auroraPink,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Action Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 3.0),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: MoscaroTokens.borderSubtle,
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildToolbarButton(
                    iconName: 'chevron-left',
                    color: onMoveLeft != null ? MoscaroTokens.textSecondary : MoscaroTokens.textMuted,
                    tooltip: 'Mover para trás',
                    onPressed: onMoveLeft,
                  ),
                  _buildToolbarButton(
                    iconName: 'rotate-cw',
                    color: themeAccent,
                    tooltip: 'Botão esquerdo: Girar 90° horário | Botão direito: Girar 90° anti-horário',
                    onPressed: onRotateClockwise,
                    onSecondaryPressed: onRotateCounterClockwise,
                  ),
                  _buildToolbarButton(
                    iconName: isExcluded ? 'eye' : 'eye-off',
                    color: isExcluded ? MoscaroTokens.auroraPink : MoscaroTokens.textSecondary,
                    tooltip: isExcluded ? 'Restaurar página' : 'Ocultar página',
                    onPressed: onToggleExclude,
                  ),
                  if (onDetach != null)
                    _buildToolbarButton(
                      iconName: 'external-link',
                      color: themeAccent,
                      tooltip: 'Destacar para o Canvas',
                      onPressed: onDetach,
                    ),
                  _buildToolbarButton(
                    iconName: 'chevron-right',
                    color: onMoveRight != null ? MoscaroTokens.textSecondary : MoscaroTokens.textMuted,
                    tooltip: 'Mover para frente',
                    onPressed: onMoveRight,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required String iconName,
    required Color color,
    required String tooltip,
    required VoidCallback? onPressed,
    VoidCallback? onSecondaryPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        onSecondaryTap: onSecondaryPressed,
        child: InkWell(
          onTap: onPressed,
          onSecondaryTap: onSecondaryPressed,
          borderRadius: BorderRadius.circular(6.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
            child: SvgIcon(
              name: iconName,
              size: 13.0,
              color: (onPressed != null || onSecondaryPressed != null) ? color : Colors.white24,
            ),
          ),
        ),
      ),
    );
  }
}
