import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/canvas_card_model.dart';
import '../services/pdf_document_service.dart';
import '../theme/moscaro_theme_controller.dart';
import '../theme/moscaro_v2_tokens.dart';
import 'ink_models.dart';
import 'svg_icon.dart';

/// Enumeração de Ações de Inteligência Artificial STEM disponíveis para o Card de PDF.
enum PdfAiAction {
  summarizePage,
  extractLatex,
  explainDiagram,
  generateFlashcards,
}

/// Pílula Flutuante Superior de Controles e Ações para o Card de PDF STEM.
///
/// Características Arquiteturais:
/// - 100% Vidro Líquido Moscaro v2 (`BackdropFilter` 16px, película translúcida e borda ciano com glow).
/// - ZERO EMOJIS: Ícones estritamente vetoriais via [SvgIcon].
/// - Suíte de Controles SVG:
///   1. Busca: [search] com expansão in-pill e suporte a `Ctrl + F`.
///   2. Alternador de Modo: [layers] vs [file] (`continuous` vs `singlePage`).
///   3. Inversão de Luminância (Modo Escuro): [contrast] (preserva cores e contraste sem ofuscamento).
///   4. Trava no Canvas (Pin): [lock] vs [unlock] (previne arrasto acidental durante anotações com caneta/stylus).
///   5. Navegador de Páginas: `< 01 / 18 >` com `chevron_left` e `chevron_right`.
///   6. Exportação Anotada: [download] (mescla tinta de traços vetoriais no PDF a 300 DPI).
///   7. Hub de IA STEM: [atom] (abre menu suspenso de síntese, OCR LaTeX e explicação de diagramas).
/// - Sockets e Callbacks reativos conectados a [CanvasCardModel] e [CanvasCardPdfView].
class PdfCardFloatingPill extends StatefulWidget {
  final CanvasCardModel card;
  final ValueChanged<CanvasCardModel> onUpdateCard;
  final double zoomScale;
  final ValueChanged<int>? onPageJump;
  final VoidCallback? onToggleSearch;
  final bool isSearchExpanded;
  final Widget? searchInputWidget;
  final VoidCallback? onExportPdf;
  final List<InkStroke> Function(Set<String> ids)? getAttachedStrokes;
  final VoidCallback? onSolveWithAi;
  final VoidCallback? onExtractLatex;
  final ValueChanged<PdfAiAction>? onAiAction;
  final VoidCallback? onDetachCurrentPage;
  final VoidCallback? onDeleteCard;
  final VoidCallback? onDuplicateCard;
  final int? totalPages;
  final int? activePageNumber;
  final List<int>? activePages;

  const PdfCardFloatingPill({
    super.key,
    required this.card,
    required this.onUpdateCard,
    this.zoomScale = 1.0,
    this.onPageJump,
    this.onToggleSearch,
    this.isSearchExpanded = false,
    this.searchInputWidget,
    this.onExportPdf,
    this.getAttachedStrokes,
    this.onSolveWithAi,
    this.onExtractLatex,
    this.onAiAction,
    this.onDetachCurrentPage,
    this.onDeleteCard,
    this.onDuplicateCard,
    this.totalPages,
    this.activePageNumber,
    this.activePages,
  });

  @override
  State<PdfCardFloatingPill> createState() => _PdfCardFloatingPillState();
}

class _PdfCardFloatingPillState extends State<PdfCardFloatingPill> {
  bool _isAiPopoverOpen = false;
  bool _isExporting = false;

  int get _currentPage =>
      widget.activePageNumber ?? widget.card.currentPdfPage;

  int get _totalPages =>
      widget.totalPages ?? math.max(1, widget.card.totalPdfPages);

  List<int> get _effectiveActivePages {
    if (widget.activePages != null && widget.activePages!.isNotEmpty) {
      return widget.activePages!;
    }
    final excluded = widget.card.excludedPageIndices.toSet();
    final list = <int>[];
    for (int i = 1; i <= _totalPages; i++) {
      if (!excluded.contains(i)) {
        list.add(i);
      }
    }
    return list.isEmpty ? [1] : list;
  }

  void _toggleDisplayMode() {
    final currentMode = widget.card.pdfDisplayMode;
    final newMode = currentMode == PdfDisplayMode.continuous
        ? PdfDisplayMode.singlePage
        : PdfDisplayMode.continuous;

    widget.onUpdateCard(widget.card.copyWith(pdfDisplayMode: newMode));
  }

  void _toggleInvertLuminance() {
    widget.onUpdateCard(widget.card.copyWith(
      invertLuminance: !widget.card.invertLuminance,
    ));
  }

  void _togglePdfLock() {
    widget.onUpdateCard(widget.card.copyWith(
      isPdfLocked: !widget.card.isPdfLocked,
    ));
  }

  void _goToPreviousPage() {
    final pages = _effectiveActivePages;
    final currentIndex = pages.indexOf(_currentPage);

    if (currentIndex > 0) {
      final prevPage = pages[currentIndex - 1];
      _navigateToPage(prevPage);
    } else if (_currentPage > 1) {
      _navigateToPage(_currentPage - 1);
    }
  }

  void _goToNextPage() {
    final pages = _effectiveActivePages;
    final currentIndex = pages.indexOf(_currentPage);

    if (currentIndex != -1 && currentIndex < pages.length - 1) {
      final nextPage = pages[currentIndex + 1];
      _navigateToPage(nextPage);
    } else if (_currentPage < _totalPages) {
      _navigateToPage(_currentPage + 1);
    }
  }

  void _navigateToPage(int targetPage) {
    final clamped = targetPage.clamp(1, _totalPages);
    widget.onPageJump?.call(clamped);
    widget.onUpdateCard(widget.card.copyWith(currentPdfPage: clamped));
  }

  Future<void> _handleDirectPageJump(BuildContext context) async {
    final textController = TextEditingController(text: _currentPage.toString());
    final isLight = MoscaroTokens.isLight;

    final result = await showDialog<int>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: MoscaroTokens.backgroundSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(
              color: MoscaroTokens.borderGlowActive.withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          title: Row(
            children: [
              SvgIcon(
                name: 'layers',
                size: 18,
                color: MoscaroTokens.auroraBlue,
              ),
              const SizedBox(width: 8),
              Text(
                'Ir para Página',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isLight ? Colors.black : Colors.white,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Digite um número entre 1 e $_totalPages:',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: MoscaroTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: isLight ? Colors.black : Colors.white,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isLight
                      ? Colors.black.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.07),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(
                      color: MoscaroTokens.borderSubtle,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(
                      color: MoscaroTokens.auroraBlue,
                      width: 1.4,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onSubmitted: (val) {
                  final parsed = int.tryParse(val.trim());
                  if (parsed != null && parsed >= 1 && parsed <= _totalPages) {
                    Navigator.of(dialogCtx).pop(parsed);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(
                'Cancelar',
                style: TextStyle(color: MoscaroTokens.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: MoscaroTokens.auroraBlue,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onPressed: () {
                final parsed = int.tryParse(textController.text.trim());
                if (parsed != null && parsed >= 1 && parsed <= _totalPages) {
                  Navigator.of(dialogCtx).pop(parsed);
                }
              },
              child: const Text('Ir', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      _navigateToPage(result);
    }
  }

  Future<void> _handleExportAnnotatedPdf(BuildContext context) async {
    if (widget.onExportPdf != null) {
      widget.onExportPdf!();
      return;
    }

    final pdfPath = widget.card.pdfPath;
    if (pdfPath == null || pdfPath.isEmpty) {
      _showFeedbackSnackBar(
        context,
        message: 'Nenhum documento PDF vinculado para exportação.',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final sanitizedTitle = widget.card.title
          .replaceAll(RegExp(r'[^\w\s\.-]'), '_')
          .trim();
      final defaultFileName = sanitizedTitle.isNotEmpty
          ? '${sanitizedTitle}_anotado.pdf'
          : 'documento_anotado.pdf';

      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Exportar PDF Anotado com Tinta',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputPath == null || outputPath.isEmpty) {
        setState(() => _isExporting = false);
        return;
      }

      final strokesPerPage = <int, List<InkStroke>>{};
      if (widget.getAttachedStrokes != null) {
        for (final entry in widget.card.pageAttachedStrokeIds.entries) {
          final strokeList = widget.getAttachedStrokes!(entry.value.toSet());
          if (strokeList.isNotEmpty) {
            strokesPerPage[entry.key] = strokeList;
          }
        }
      }

      await PdfDocumentService.instance.exportAnnotatedPdf(
        originalPdfPath: pdfPath,
        outputPath: outputPath,
        strokesPerPage: strokesPerPage,
        cardWidth: widget.card.width,
        excludedPageIndices: widget.card.excludedPageIndices,
      );

      if (context.mounted) {
        _showFeedbackSnackBar(
          context,
          message: 'PDF anotado exportado com sucesso: $outputPath',
          isSuccess: true,
        );
      }
    } catch (e) {
      debugPrint('[PdfCardFloatingPill] Falha na exportação do PDF: $e');
      if (context.mounted) {
        _showFeedbackSnackBar(
          context,
          message: 'Erro ao exportar PDF: $e',
          isSuccess: false,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _showFeedbackSnackBar(
    BuildContext context, {
    required String message,
    required bool isSuccess,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SvgIcon(
              name: isSuccess ? 'check' : 'close',
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess
            ? MoscaroTokens.auroraGreen.withValues(alpha: 0.92)
            : Colors.redAccent.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MoscaroThemeController.instance,
      builder: (context, _) {
        final isLight = MoscaroTokens.isLight;
        final theme = MoscaroThemeController.instance.currentTheme;
        final themeAccent = theme.accentPrimary;
        final isContinuous =
            widget.card.pdfDisplayMode == PdfDisplayMode.continuous;

        final hasPrevPage = _currentPage > 1;
        final hasNextPage = _currentPage < _totalPages;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Popover Suspenso de Inteligência Artificial STEM
            if (_isAiPopoverOpen)
              Positioned(
                bottom: 44.0,
                child: _PdfStemAiPopover(
                  currentPage: _currentPage,
                  onClose: () => setState(() => _isAiPopoverOpen = false),
                  onSummarizePage: () {
                    setState(() => _isAiPopoverOpen = false);
                    if (widget.onAiAction != null) {
                      widget.onAiAction!(PdfAiAction.summarizePage);
                    } else if (widget.onSolveWithAi != null) {
                      widget.onSolveWithAi!();
                    }
                  },
                  onExtractLatex: () {
                    setState(() => _isAiPopoverOpen = false);
                    if (widget.onAiAction != null) {
                      widget.onAiAction!(PdfAiAction.extractLatex);
                    } else if (widget.onExtractLatex != null) {
                      widget.onExtractLatex!();
                    }
                  },
                  onExplainDiagram: () {
                    setState(() => _isAiPopoverOpen = false);
                    widget.onAiAction?.call(PdfAiAction.explainDiagram);
                  },
                  onDetachPage: widget.onDetachCurrentPage != null
                      ? () {
                          setState(() => _isAiPopoverOpen = false);
                          widget.onDetachCurrentPage!();
                        }
                      : null,
                ),
              ),

            // Pílula Principal em Vidro Líquido Moscaro v2
            ClipRRect(
              borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: MoscaroTokens.blurSigma,
                  sigmaY: MoscaroTokens.blurSigma,
                ),
                child: Container(
                  height: 36.0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 3.0,
                  ),
                  decoration: BoxDecoration(
                    color: MoscaroTokens.glassTint,
                    borderRadius:
                        BorderRadius.circular(MoscaroTokens.radiusPill),
                    border: Border.all(
                      color: MoscaroTokens.borderGlowActive
                          .withValues(alpha: 0.35),
                      width: MoscaroTokens.borderWidthSubtle,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 18.0,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: themeAccent.withValues(alpha: 0.12),
                        blurRadius: 14.0,
                        spreadRadius: 0.0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Grupo 1: Busca no Documento (com suporte ao socket de input de Explorer 3)
                      if (widget.isSearchExpanded &&
                          widget.searchInputWidget != null) ...[
                        widget.searchInputWidget!,
                        _buildDivider(isLight),
                      ] else ...[
                        _PillActionButton(
                          iconName: 'search',
                          tooltip: 'Pesquisar texto no PDF (Ctrl+F)',
                          isActive: widget.isSearchExpanded,
                          onPressed: widget.onToggleSearch ?? () {},
                        ),
                        _buildDivider(isLight),
                      ],

                      // Grupo 2: Modos de Exibição e Trava
                      // Alternador de Modo: Contínuo vs Página Única
                      _PillActionButton(
                        iconName: isContinuous ? 'layers' : 'file',
                        tooltip: isContinuous
                            ? 'Modo Contínuo ativo (clique para Página Única)'
                            : 'Página Única ativa (clique para Modo Contínuo)',
                        isActive: isContinuous,
                        onPressed: _toggleDisplayMode,
                      ),

                      // Inversão de Luminância (Modo Escuro Moscaro)
                      _PillActionButton(
                        iconName: 'contrast',
                        tooltip: widget.card.invertLuminance
                            ? 'Modo Escuro ativo (restaurar original)'
                            : 'Inverter luminância (Modo Escuro Moscaro)',
                        isActive: widget.card.invertLuminance,
                        onPressed: _toggleInvertLuminance,
                      ),

                      // Travar PDF no Canvas (Pin / Lock)
                      _PillActionButton(
                        iconName: widget.card.isPdfLocked ? 'lock' : 'unlock',
                        tooltip: widget.card.isPdfLocked
                            ? 'PDF travado no canvas (clique para destravar)'
                            : 'Travar PDF no canvas (evitar arrasto ao escrever)',
                        isActive: widget.card.isPdfLocked,
                        onPressed: _togglePdfLock,
                      ),

                      _buildDivider(isLight),

                      // Grupo 3: Navegador de Páginas < 01 / 18 >
                      _PillActionButton(
                        iconBuilder: (effectiveColor) => Transform.flip(
                          flipX: true,
                          child: SvgIcon(
                            name: 'chevron_right',
                            size: 14,
                            color: effectiveColor,
                          ),
                        ),
                        tooltip: hasPrevPage
                            ? 'Página anterior'
                            : 'Primeira página do documento',
                        isEnabled: hasPrevPage,
                        onPressed: hasPrevPage ? _goToPreviousPage : null,
                      ),

                      // Indicador de Página Clicável
                      Tooltip(
                        message: 'Clique para ir diretamente a uma página',
                        waitDuration: const Duration(milliseconds: 300),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => _handleDirectPageJump(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                                vertical: 2.0,
                              ),
                              decoration: BoxDecoration(
                                color: isLight
                                    ? Colors.black.withValues(alpha: 0.05)
                                    : Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6.0),
                                border: Border.all(
                                  color: isLight
                                      ? Colors.black12
                                      : Colors.white12,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '${_currentPage.toString().padLeft(2, '0')} / ${_totalPages.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                  color: isLight
                                      ? MoscaroTokens.textPrimary
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      _PillActionButton(
                        iconName: 'chevron_right',
                        tooltip: hasNextPage
                            ? 'Próxima página'
                            : 'Última página do documento',
                        isEnabled: hasNextPage,
                        onPressed: hasNextPage ? _goToNextPage : null,
                      ),

                      _buildDivider(isLight),

                      // Grupo 4: Ferramentas STEM & Exportação
                      // Exportar PDF Anotado
                      _PillActionButton(
                        iconName: 'download',
                        tooltip: _isExporting
                            ? 'Exportando PDF...'
                            : 'Exportar PDF com anotações e traços mesclados',
                        isActive: _isExporting,
                        onPressed: _isExporting
                            ? null
                            : () => _handleExportAnnotatedPdf(context),
                      ),

                      // IA STEM Hub (Menu Popover)
                      _PillActionButton(
                        iconName: 'atom',
                        tooltip: 'Inteligência Artificial STEM',
                        isActive: _isAiPopoverOpen,
                        iconColor: themeAccent,
                        onPressed: () {
                          setState(() {
                            _isAiPopoverOpen = !_isAiPopoverOpen;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDivider(bool isLight) {
    return Container(
      width: 1.0,
      height: 16.0,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      color: isLight ? Colors.black12 : Colors.white12,
    );
  }
}

/// Botão de Ação Cirúrgico Padronizado para Pílulas Moscaro v2.
/// Emojis estritamente banidos. Suporta estados de hover, clique, ativo e desabilitado.
class _PillActionButton extends StatefulWidget {
  final String? iconName;
  final Widget Function(Color color)? iconBuilder;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isActive;
  final bool isEnabled;
  final Color? iconColor;

  const _PillActionButton({
    this.iconName,
    this.iconBuilder,
    required this.tooltip,
    this.onPressed,
    this.isActive = false,
    this.isEnabled = true,
    this.iconColor,
  }) : assert(iconName != null || iconBuilder != null);

  @override
  State<_PillActionButton> createState() => _PillActionButtonState();
}

class _PillActionButtonState extends State<_PillActionButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = MoscaroThemeController.instance.currentTheme;
    final themeAccent = theme.accentPrimary;
    final isLight = MoscaroTokens.isLight;
    final defaultColor =
        isLight ? MoscaroTokens.textSecondary : Colors.white70;

    final effectiveColor = !widget.isEnabled
        ? (isLight ? Colors.black26 : Colors.white24)
        : (widget.iconColor ??
            (widget.isActive
                ? themeAccent
                : (_isHovered ? themeAccent : defaultColor)));

    final double scale =
        _isPressed ? 0.92 : (_isHovered && widget.isEnabled ? 1.08 : 1.0);

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: widget.isEnabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) {
          if (widget.isEnabled) setState(() => _isHovered = true);
        },
        onExit: (_) {
          if (widget.isEnabled) setState(() => _isHovered = false);
        },
        child: GestureDetector(
          onTapDown: (_) {
            if (widget.isEnabled) setState(() => _isPressed = true);
          },
          onTapUp: (_) {
            if (widget.isEnabled) setState(() => _isPressed = false);
          },
          onTapCancel: () {
            if (_isPressed) setState(() => _isPressed = false);
          },
          onTap: widget.isEnabled ? widget.onPressed : null,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 28.0,
              height: 28.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isActive
                    ? themeAccent.withValues(alpha: 0.22)
                    : (_isHovered && widget.isEnabled
                        ? (isLight
                            ? Colors.black.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.10))
                        : Colors.transparent),
                border: widget.isActive
                    ? Border.all(
                        color: themeAccent.withValues(alpha: 0.45),
                        width: 1.0,
                      )
                    : null,
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: themeAccent.withValues(alpha: 0.35),
                          blurRadius: 6.0,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: widget.iconBuilder != null
                    ? widget.iconBuilder!(effectiveColor)
                    : SvgIcon(
                        name: widget.iconName,
                        size: 15.0,
                        color: effectiveColor,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Popover de Ações de Inteligência Artificial STEM (Vidro Líquido Moscaro v2).
/// Totalmente estilizado sem emojis, com ícones vetoriais padronizados.
class _PdfStemAiPopover extends StatelessWidget {
  final int currentPage;
  final VoidCallback onClose;
  final VoidCallback onSummarizePage;
  final VoidCallback onExtractLatex;
  final VoidCallback onExplainDiagram;
  final VoidCallback? onDetachPage;

  const _PdfStemAiPopover({
    required this.currentPage,
    required this.onClose,
    required this.onSummarizePage,
    required this.onExtractLatex,
    required this.onExplainDiagram,
    this.onDetachPage,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = MoscaroTokens.isLight;
    final theme = MoscaroThemeController.instance.currentTheme;
    final themeAccent = theme.accentPrimary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
        child: Container(
          width: 250.0,
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
          decoration: BoxDecoration(
            color: MoscaroTokens.backgroundSurface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(
              color: MoscaroTokens.borderGlowActive.withValues(alpha: 0.35),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 20.0,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: themeAccent.withValues(alpha: 0.15),
                blurRadius: 14.0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho do Popover
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    SvgIcon(
                      name: 'atom',
                      size: 15,
                      color: themeAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ações de IA STEM (Pág. $currentPage)',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.0,
                          fontWeight: FontWeight.w700,
                          color: isLight ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: onClose,
                        child: SvgIcon(
                          name: 'close',
                          size: 13,
                          color: MoscaroTokens.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 10, thickness: 0.8),

              // Item 1: Resumir Página
              _PopoverActionTile(
                iconName: 'file',
                title: 'Resumir Página Atual',
                subtitle: 'Gera síntese conceitual e teoremas da pág. $currentPage',
                onTap: onSummarizePage,
              ),

              // Item 2: Extrair Fórmulas LaTeX
              _PopoverActionTile(
                iconName: 'math',
                title: 'Extrair Fórmulas LaTeX',
                subtitle: 'Converte equações em novo card editável',
                onTap: onExtractLatex,
              ),

              // Item 3: Explicar Diagrama
              _PopoverActionTile(
                iconName: 'ai',
                title: 'Explicar Diagrama / Gráfico',
                subtitle: 'Análise geométrica e física de figuras',
                onTap: onExplainDiagram,
              ),

              // Item 4: Desprender Página Atual
              if (onDetachPage != null) ...[
                const Divider(height: 8, thickness: 0.8),
                _PopoverActionTile(
                  iconName: 'share',
                  title: 'Desprender Página $currentPage',
                  subtitle: 'Extrai para card independente no canvas',
                  onTap: onDetachPage!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PopoverActionTile extends StatefulWidget {
  final String iconName;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PopoverActionTile({
    required this.iconName,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_PopoverActionTile> createState() => _PopoverActionTileState();
}

class _PopoverActionTileState extends State<_PopoverActionTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isLight = MoscaroTokens.isLight;
    final theme = MoscaroThemeController.instance.currentTheme;
    final themeAccent = theme.accentPrimary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 2.0),
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: _isHovered
                ? themeAccent.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8.0),
            border: _isHovered
                ? Border.all(
                    color: themeAccent.withValues(alpha: 0.3),
                    width: 0.8,
                  )
                : Border.all(color: Colors.transparent, width: 0.8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: _isHovered
                      ? themeAccent.withValues(alpha: 0.22)
                      : (isLight
                          ? Colors.black.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.07)),
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Center(
                  child: SvgIcon(
                    name: widget.iconName,
                    size: 14,
                    color: _isHovered ? themeAccent : MoscaroTokens.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                        color: _isHovered
                            ? themeAccent
                            : (isLight ? Colors.black : Colors.white),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.0,
                        color: MoscaroTokens.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
