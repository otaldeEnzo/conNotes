import 'dart:math' as math;
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/canvas_card_model.dart';
import '../services/pdf_document_service.dart';
import '../services/pdf_search_engine.dart';
import '../services/settings_service.dart';
import '../theme/moscaro_theme_controller.dart';
import '../theme/moscaro_v2_tokens.dart';
import 'card_format_floating_pill.dart';
import 'ink_models.dart';
import 'pdf_search_pill_input.dart';
import 'svg_icon.dart';

/// Enum of AI STEM actions available for PDF cards.
enum PdfAiAction {
  summarizePage,
  extractLatex,
  explainDiagram,
  generateFlashcards,
}

enum _SubPillType {
  none,
  displayModes,
  ai,
}

/// Moscaro Floating Pill Toolbar for PDF Cards.
/// Features:
/// - 36px height, 30px pill radius, liquid glass styling with theme-reactive accents.
/// - Physical zoom-invariance: (1.0 / zoomScale).clamp(0.5, 3.0) with Alignment.bottomCenter.
/// - Dedicated drag handle button with grabbing cursor for moving document cards.
/// - Animated stacked sub-pills for Display Modes and STEM AI Actions.
/// - Conditional Display Mode toggle exclusively on master Page 1 (hidden on sister pages).
/// - Full privacy switch support respecting SettingsService.instance.currentSettings.
/// - 100% SVG iconography, zero emojis.
class PdfCardFloatingPill extends StatefulWidget {
  final CanvasCardModel card;
  final ValueChanged<CanvasCardModel> onUpdateCard;
  final double zoomScale;
  final ValueNotifier<double>? zoomNotifier;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<int>? onPageJump;
  final VoidCallback? onDeleteCard;
  final VoidCallback? onDuplicateCard;
  final VoidCallback? onExportAnnotatedPdf;
  final VoidCallback? onExportPdf;
  final List<InkStroke> Function(Set<String> ids)? getAttachedStrokes;
  final VoidCallback? onSolveWithAi;
  final VoidCallback? onExtractLatex;
  final VoidCallback? onExplainDiagram;
  final ValueChanged<PdfAiAction>? onAiAction;
  final VoidCallback? onDetachCurrentPage;
  final ValueChanged<int>? onReattachPage;
  final VoidCallback? onReattachToMaster;
  final PdfSearchEngine? searchEngine;
  final Widget? searchInputWidget;
  final bool isSearchExpanded;
  final VoidCallback? onToggleSearch;
  final bool isCardSelected;
  final int? totalPages;
  final int? activePageNumber;
  final List<int>? activePages;
  final bool isSisterPage;
  final GestureDragStartCallback? onPanStart;
  final GestureDragUpdateCallback? onPanUpdate;
  final GestureDragEndCallback? onPanEnd;
  final GestureDragCancelCallback? onPanCancel;
  final List<CanvasCardModel>? allCards;
  final Set<String>? selectedPageIds;
  final void Function(List<CanvasCardModel>)? onDuplicateMultipleCards;
  final void Function(List<String>)? onDeleteMultipleCards;

  const PdfCardFloatingPill({
    super.key,
    required this.card,
    required this.onUpdateCard,
    this.zoomScale = 1.0,
    this.zoomNotifier,
    this.onPageChanged,
    this.onPageJump,
    this.onDeleteCard,
    this.onDuplicateCard,
    this.onExportAnnotatedPdf,
    this.onExportPdf,
    this.getAttachedStrokes,
    this.onSolveWithAi,
    this.onExtractLatex,
    this.onExplainDiagram,
    this.onAiAction,
    this.onDetachCurrentPage,
    this.onReattachPage,
    this.onReattachToMaster,
    this.searchEngine,
    this.searchInputWidget,
    this.isSearchExpanded = false,
    this.onToggleSearch,
    this.isCardSelected = true,
    this.totalPages,
    this.activePageNumber,
    this.activePages,
    this.isSisterPage = false,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.onPanCancel,
    this.allCards,
    this.selectedPageIds,
    this.onDuplicateMultipleCards,
    this.onDeleteMultipleCards,
  });

  static const double pillHeight = 36.0;
  static const double pillRadius = 30.0;

  @override
  State<PdfCardFloatingPill> createState() => _PdfCardFloatingPillState();
}

class _PdfCardFloatingPillState extends State<PdfCardFloatingPill> {
  _SubPillType _activeSubPill = _SubPillType.none;
  bool _isExporting = false;
  bool _isDragging = false;
  final GlobalKey<PdfSearchPillInputState> _searchKey = GlobalKey<PdfSearchPillInputState>();

  int? _localTargetPage;

  int get _currentPage =>
      _localTargetPage ?? (widget.activePageNumber ?? widget.card.currentPdfPage);

  int get _totalPages =>
      widget.totalPages ?? math.max(1, widget.card.totalPdfPages);

  bool get _isEffectiveSisterPage =>
      widget.isSisterPage || widget.card.sourceMasterCardId != null;

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

  @override
  void didUpdateWidget(covariant PdfCardFloatingPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.card.currentPdfPage != oldWidget.card.currentPdfPage ||
        widget.activePageNumber != oldWidget.activePageNumber) {
      _localTargetPage = null;
    }
  }

  void _selectDisplayMode(PdfDisplayMode mode) {
    setState(() => _activeSubPill = _SubPillType.none);
    if (widget.card.pdfDisplayMode == mode) return;
    final updated = widget.card.copyWith(pdfDisplayMode: mode);
    final newHeight = updated.calculateMinHeight();
    widget.onUpdateCard(updated.copyWith(height: newHeight));
  }

  void _toggleInvertLuminance() {
    final nextLuminance = !widget.card.invertLuminance;
    if (widget.allCards != null) {
      final masterId = widget.card.sourceMasterCardId ?? widget.card.id;
      final familyMembers = widget.allCards!.where((c) =>
          c.cardType == CardType.pdf &&
          (c.id == masterId || c.sourceMasterCardId == masterId)).toList();
      for (final member in familyMembers) {
        widget.onUpdateCard(member.copyWith(invertLuminance: nextLuminance));
      }
    } else {
      widget.onUpdateCard(widget.card.copyWith(invertLuminance: nextLuminance));
    }
  }

  void _toggleLock() {
    final nextLocked = !widget.card.isPdfLocked;
    if (widget.allCards != null) {
      final masterId = widget.card.sourceMasterCardId ?? widget.card.id;
      final familyMembers = widget.allCards!.where((c) =>
          c.cardType == CardType.pdf &&
          (c.id == masterId || c.sourceMasterCardId == masterId)).toList();
      for (final member in familyMembers) {
        widget.onUpdateCard(member.copyWith(isPdfLocked: nextLocked));
      }
    } else {
      widget.onUpdateCard(widget.card.copyWith(isPdfLocked: nextLocked));
    }
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
    setState(() {
      _localTargetPage = clamped;
    });
    widget.onPageJump?.call(clamped);
    widget.onPageChanged?.call(clamped);
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
    final exportCallback = widget.onExportAnnotatedPdf ?? widget.onExportPdf;
    if (exportCallback != null) {
      exportCallback();
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

      final outputUri = await FilePickerPlatform.instance.saveFile(
        dialogTitle: 'Exportar PDF Anotado',
        fileName: defaultFileName,
        bytes: Uint8List(0),
        mimeType: 'application/pdf',
      );

      if (outputUri == null) {
        setState(() => _isExporting = false);
        return;
      }

      final outputPath = outputUri.toFilePath();
      if (outputPath.isEmpty) {
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
      listenable: Listenable.merge([
        MoscaroThemeController.instance,
        SettingsService.instance.settingsNotifier,
      ]),
      builder: (context, _) {
        final isLight = MoscaroTokens.isLight;
        final theme = MoscaroThemeController.instance.currentTheme;
        final themeAccent = theme.accentPrimary;
        final textPrimary = MoscaroTokens.textPrimary;
        final glassTint = widget.card.customGlassColor ?? MoscaroTokens.glassTint;
        final blur = (MoscaroTokens.enableToolbarBlur && MoscaroTokens.blurSigma > 0)
            ? MoscaroTokens.blurSigma
            : 0.0;
        final settings = SettingsService.instance.currentSettings;
        final isAiAvailable = settings.enableCloudAiFeatures && settings.enablePdfAiActions;

        Widget buildScaledPill(double currentZoom) {
          // Physical zoom invariance: scaleFactor = (1.0 / safeZoom).clamp(0.5, 3.0)
          final safeZoom = (currentZoom > 0) ? currentZoom : 1.0;
          final scaleFactor = (1.0 / safeZoom).clamp(0.5, 3.0);

          return MouseRegion(
            onEnter: (_) => globalIsHoveringFloatingPill = true,
            onExit: (_) => globalIsHoveringFloatingPill = false,
            child: Transform.scale(
              scale: scaleFactor,
              alignment: Alignment.bottomCenter,
              child: FocusScope(
                canRequestFocus: false,
                child: CallbackShortcuts(
                  bindings: <ShortcutActivator, VoidCallback>{
                    const SingleActivator(LogicalKeyboardKey.escape): () {
                      if (_activeSubPill != _SubPillType.none) {
                        setState(() => _activeSubPill = _SubPillType.none);
                      }
                      _searchKey.currentState?.collapse();
                    },
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1. Stacked Animated Sub-Pills (Display Modes or STEM AI)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.25),
                              end: Offset.zero,
                            ).animate(animation),
                            child: FadeTransition(opacity: animation, child: child),
                          );
                        },
                        child: _activeSubPill == _SubPillType.displayModes
                            ? Padding(
                                key: const ValueKey('subpill_display_modes'),
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: _buildDisplayModesSubPill(
                                  isLight: isLight,
                                  glassTint: glassTint,
                                  themeAccent: themeAccent,
                                  textPrimary: textPrimary,
                                  blur: blur,
                                ),
                              )
                            : (_activeSubPill == _SubPillType.ai && isAiAvailable
                                ? Padding(
                                    key: const ValueKey('subpill_ai'),
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: _buildAiSubPill(
                                      isLight: isLight,
                                      glassTint: glassTint,
                                      themeAccent: themeAccent,
                                      textPrimary: textPrimary,
                                      blur: blur,
                                    ),
                                  )
                                : const SizedBox.shrink(key: ValueKey('subpill_none'))),
                      ),

                      // 2. Main Pill Container (36px exact height)
                      _buildPillContainer(
                        isLight: isLight,
                        glassTint: glassTint,
                        themeAccent: themeAccent,
                        textPrimary: textPrimary,
                        blur: blur,
                        isAiAvailable: isAiAvailable,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (widget.zoomNotifier != null) {
          return ValueListenableBuilder<double>(
            valueListenable: widget.zoomNotifier!,
            builder: (context, currentZoom, _) => buildScaledPill(currentZoom),
          );
        }

        return buildScaledPill(widget.zoomScale);
      },
    );
  }

  /// Builds the horizontal Display Modes sub-pill (Continuous, Single Page, Grid).
  Widget _buildDisplayModesSubPill({
    required bool isLight,
    required Color glassTint,
    required Color themeAccent,
    required Color textPrimary,
    required double blur,
  }) {
    final currentMode = widget.card.pdfDisplayMode;

    final inner = Container(
      height: 32.0,
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: isLight
            ? const Color(0xFFF8FAFC).withValues(alpha: 0.95)
            : glassTint,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: themeAccent.withValues(alpha: 0.45),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14.0,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: themeAccent.withValues(alpha: 0.15),
            blurRadius: 10.0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0, right: 6.0),
            child: SvgIcon(name: 'layers', size: 13.0, color: themeAccent),
          ),
          _buildSubPillModeOption(
            title: 'Coluna Contínua',
            icon: 'layers',
            isSelected: currentMode == PdfDisplayMode.continuous,
            themeAccent: themeAccent,
            onTap: () => _selectDisplayMode(PdfDisplayMode.continuous),
          ),
          const SizedBox(width: 4.0),
          _buildSubPillModeOption(
            title: 'Página Única',
            icon: 'file',
            isSelected: currentMode == PdfDisplayMode.singlePage,
            themeAccent: themeAccent,
            onTap: () => _selectDisplayMode(PdfDisplayMode.singlePage),
          ),
          const SizedBox(width: 4.0),
          _buildSubPillModeOption(
            title: 'Grade / Mesa',
            icon: 'grid',
            isSelected: currentMode == PdfDisplayMode.grid,
            themeAccent: themeAccent,
            onTap: () => _selectDisplayMode(PdfDisplayMode.grid),
          ),
          const SizedBox(width: 4.0),
          _buildDivider(isLight ? Colors.black12 : Colors.white12),
          _PillActionButton(
            iconName: 'close',
            tooltip: 'Fechar modos (Esc)',
            size: 22.0,
            iconSize: 11.0,
            onPressed: () => setState(() => _activeSubPill = _SubPillType.none),
          ),
        ],
      ),
    );

    if (blur > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: inner,
        ),
      );
    }
    return inner;
  }

  Widget _buildSubPillModeOption({
    required String title,
    required String icon,
    required bool isSelected,
    required Color themeAccent,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
          decoration: BoxDecoration(
            color: isSelected
                ? themeAccent.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: isSelected
                  ? themeAccent.withValues(alpha: 0.55)
                  : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(
                name: icon,
                size: 12.0,
                color: isSelected ? themeAccent : MoscaroTokens.textSecondary,
              ),
              const SizedBox(width: 5.0),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.0,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? themeAccent : MoscaroTokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the horizontal STEM AI sub-pill (Resumir, Extrair LaTeX, Explicar Diagrama).
  Widget _buildAiSubPill({
    required bool isLight,
    required Color glassTint,
    required Color themeAccent,
    required Color textPrimary,
    required double blur,
  }) {
    final inner = Container(
      height: 32.0,
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: isLight
            ? const Color(0xFFF8FAFC).withValues(alpha: 0.95)
            : glassTint,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: themeAccent.withValues(alpha: 0.45),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14.0,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: themeAccent.withValues(alpha: 0.15),
            blurRadius: 10.0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0, right: 6.0),
            child: SvgIcon(name: 'sparkle', size: 13.0, color: themeAccent),
          ),
          _buildSubPillAiAction(
            title: 'Resumir Pág. $_currentPage',
            icon: 'file',
            themeAccent: themeAccent,
            onTap: () {
              setState(() => _activeSubPill = _SubPillType.none);
              if (widget.onAiAction != null) {
                widget.onAiAction!(PdfAiAction.summarizePage);
              } else {
                widget.onSolveWithAi?.call();
              }
            },
          ),
          const SizedBox(width: 4.0),
          _buildSubPillAiAction(
            title: 'Extrair LaTeX',
            icon: 'math',
            themeAccent: themeAccent,
            onTap: () {
              setState(() => _activeSubPill = _SubPillType.none);
              if (widget.onAiAction != null) {
                widget.onAiAction!(PdfAiAction.extractLatex);
              } else {
                widget.onExtractLatex?.call();
              }
            },
          ),
          const SizedBox(width: 4.0),
          _buildSubPillAiAction(
            title: 'Explicar Diagrama',
            icon: 'ai',
            themeAccent: themeAccent,
            onTap: () {
              setState(() => _activeSubPill = _SubPillType.none);
              if (widget.onAiAction != null) {
                widget.onAiAction!(PdfAiAction.explainDiagram);
              } else {
                widget.onExplainDiagram?.call();
              }
            },
          ),
          const SizedBox(width: 4.0),
          _buildDivider(isLight ? Colors.black12 : Colors.white12),
          _PillActionButton(
            iconName: 'close',
            tooltip: 'Fechar ações de IA (Esc)',
            size: 22.0,
            iconSize: 11.0,
            onPressed: () => setState(() => _activeSubPill = _SubPillType.none),
          ),
        ],
      ),
    );

    if (blur > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: inner,
        ),
      );
    }
    return inner;
  }

  Widget _buildSubPillAiAction({
    required String title,
    required String icon,
    required Color themeAccent,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
          decoration: BoxDecoration(
            color: themeAccent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: themeAccent.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(
                name: icon,
                size: 12.0,
                color: themeAccent,
              ),
              const SizedBox(width: 5.0),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.0,
                  fontWeight: FontWeight.w500,
                  color: MoscaroTokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillContainer({
    required bool isLight,
    required Color glassTint,
    required Color themeAccent,
    required Color textPrimary,
    required double blur,
    required bool isAiAvailable,
  }) {
    final innerBar = Container(
      height: PdfCardFloatingPill.pillHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: isLight
            ? const Color(0xFFF8FAFC).withValues(alpha: 0.95)
            : glassTint,
        borderRadius: BorderRadius.circular(PdfCardFloatingPill.pillRadius),
        border: Border.all(
          color: isLight
              ? MoscaroTokens.borderSubtle
              : MoscaroTokens.borderGlowActive.withValues(alpha: 0.35),
          width: MoscaroTokens.borderWidthSubtle,
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? const Color(0x180F172A)
                : Colors.black.withValues(alpha: 0.35),
            blurRadius: 18.0,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: themeAccent.withValues(alpha: 0.12),
            blurRadius: 14.0,
            spreadRadius: 0.0,
          ),
        ],
      ),
      child: _buildPillContent(isLight, themeAccent, textPrimary, isAiAvailable),
    );

    if (blur > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(PdfCardFloatingPill.pillRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: innerBar,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(PdfCardFloatingPill.pillRadius),
      child: innerBar,
    );
  }

  Widget _buildPillContent(
    bool isLight,
    Color themeAccent,
    Color textPrimary,
    bool isAiAvailable,
  ) {
    final dividerColor = isLight ? Colors.black12 : Colors.white12;
    final isSinglePage = widget.card.pdfDisplayMode == PdfDisplayMode.singlePage;
    final hasPrevPage = _currentPage > 1;
    final hasNextPage = _currentPage < _totalPages;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 0. Drag Handle Button (Move whole document on pan)
        if (widget.onPanStart != null || widget.onPanUpdate != null) ...[
          MouseRegion(
            cursor: _isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) {
                setState(() => _isDragging = true);
                widget.onPanStart?.call(d);
              },
              onPanUpdate: widget.onPanUpdate,
              onPanEnd: (d) {
                setState(() => _isDragging = false);
                widget.onPanEnd?.call(d);
              },
              onPanCancel: () {
                setState(() => _isDragging = false);
                widget.onPanCancel?.call();
              },
              child: Container(
                width: 28.0,
                height: 28.0,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _isDragging
                      ? themeAccent.withValues(alpha: 0.25)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Tooltip(
                  message: 'Arrastar documento pelo canvas',
                  child: SvgIcon(
                    name: 'move',
                    size: 14.0,
                    color: _isDragging ? themeAccent : MoscaroTokens.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          _buildDivider(dividerColor),
        ],

        // 1. Text Search Input (Expandable)
        if (widget.searchEngine != null) ...[
          PdfSearchPillInput(
            key: _searchKey,
            searchEngine: widget.searchEngine!,
            pdfPath: widget.card.pdfPath ?? '',
            excludedPageIndices: widget.card.excludedPageIndices,
            isCardSelected: widget.isCardSelected,
          ),
          _buildDivider(dividerColor),
        ] else if (widget.searchInputWidget != null) ...[
          widget.searchInputWidget!,
          _buildDivider(dividerColor),
        ] else if (widget.onToggleSearch != null) ...[
          _PillActionButton(
            iconName: 'search',
            tooltip: 'Buscar no documento (Ctrl+F)',
            isActive: widget.isSearchExpanded,
            onPressed: widget.onToggleSearch,
          ),
          _buildDivider(dividerColor),
        ],

        // 2. Display Modes Sub-Pill Trigger (Exclusively on Page 1 / Master Page)
        if (!_isEffectiveSisterPage) ...[
          _PillActionButton(
            iconName: 'layers',
            tooltip: 'Modos de Exibição (Coluna, Única, Grade)',
            isActive: _activeSubPill == _SubPillType.displayModes,
            onPressed: () {
              setState(() {
                _activeSubPill = _activeSubPill == _SubPillType.displayModes
                    ? _SubPillType.none
                    : _SubPillType.displayModes;
              });
            },
          ),
        ],

        // 3. Dark Mode / Invert Luminance
        _PillActionButton(
          iconName: 'contrast',
          tooltip: widget.card.invertLuminance
              ? 'Modo claro original'
              : 'Inverter cores (Dark Mode)',
          isActive: widget.card.invertLuminance,
          onPressed: _toggleInvertLuminance,
        ),

        // 4. Lock / Pin to Canvas
        _PillActionButton(
          iconName: widget.card.isPdfLocked ? 'lock' : 'unlock',
          tooltip: widget.card.isPdfLocked
              ? 'Bloqueado no canvas (Clique para desbloquear)'
              : 'Desbloqueado (Clique para travar no canvas)',
          isActive: widget.card.isPdfLocked,
          onPressed: _toggleLock,
        ),

        _buildDivider(dividerColor),

        // 5. Page Navigator: < 01 / 18 > (Apenas no Modo de Folha Única)
        if (isSinglePage) ...[
          _PillActionButton(
            iconName: 'chevron_left',
            tooltip: hasPrevPage ? 'Página anterior' : 'Primeira página',
            size: 26.0,
            iconSize: 13.0,
            isEnabled: hasPrevPage,
            onPressed: hasPrevPage ? _goToPreviousPage : null,
          ),
          Tooltip(
            message: 'Clique para ir diretamente a uma página',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _handleDirectPageJump(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    '${_currentPage.toString().padLeft(2, '0')} / ${_totalPages.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                      letterSpacing: 0.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _PillActionButton(
            iconName: 'chevron_right',
            tooltip: hasNextPage ? 'Próxima página' : 'Última página',
            size: 26.0,
            iconSize: 13.0,
            isEnabled: hasNextPage,
            onPressed: hasNextPage ? _goToNextPage : null,
          ),
          _buildDivider(dividerColor),
        ],

        // 6. STEM AI Hub Action (Only when master switch and PDF switch enabled)
        if (isAiAvailable) ...[
          _PillActionButton(
            iconName: 'sparkle',
            tooltip: 'Ações de IA STEM (Resumo, LaTeX, Diagramas)',
            iconColor: themeAccent,
            isActive: _activeSubPill == _SubPillType.ai,
            onPressed: () {
              setState(() {
                _activeSubPill = _activeSubPill == _SubPillType.ai
                    ? _SubPillType.none
                    : _SubPillType.ai;
              });
            },
          ),
        ],

        // 7. Export Annotated PDF
        _PillActionButton(
          iconName: 'download',
          tooltip: _isExporting
              ? 'Exportando PDF...'
              : 'Exportar PDF com anotações',
          isActive: _isExporting,
          onPressed: _isExporting ? null : () => _handleExportAnnotatedPdf(context),
        ),

        // 8. Desprender Página Atual (Standalone card)
        // Apenas para páginas pertencentes à coluna/documento mestre que ainda NÃO foram desprendidas
        if (!widget.card.isDetached && widget.card.sourceMasterCardId == null && widget.onDetachCurrentPage != null && _totalPages > 1) ...[
          _buildDivider(dividerColor),
          _PillActionButton(
            iconName: 'share',
            tooltip: 'Desprender página $_currentPage',
            onPressed: widget.onDetachCurrentPage,
          ),
        ],

        // 9. Prender Página(s) de Volta ao PDF
        if ((widget.card.isDetached || widget.card.sourceMasterCardId != null) && widget.onReattachToMaster != null) ...[
          _buildDivider(dividerColor),
          _PillActionButton(
            iconName: 'link',
            tooltip: 'Prender de volta ao PDF original',
            iconColor: themeAccent,
            onPressed: widget.onReattachToMaster,
          ),
        ] else if (widget.card.excludedPageIndices.isNotEmpty && widget.onReattachPage != null) ...[
          _buildDivider(dividerColor),
          _PillActionButton(
            iconName: 'link',
            tooltip: 'Prender páginas desprendidas (${widget.card.excludedPageIndices.length})',
            iconColor: themeAccent,
            onPressed: () => _handleReattachMenu(context),
          ),
        ],

        // Optional duplicate card
        if (widget.onDuplicateCard != null || widget.onDuplicateMultipleCards != null) ...[
          _buildDivider(dividerColor),
          _PillActionButton(
            iconName: 'plus',
            tooltip: (widget.selectedPageIds != null && widget.selectedPageIds!.length > 1)
                ? 'Duplicar páginas selecionadas (${widget.selectedPageIds!.length})'
                : 'Duplicar página',
            onPressed: () {
              if (widget.onDuplicateMultipleCards != null &&
                  widget.selectedPageIds != null &&
                  widget.selectedPageIds!.length > 1 &&
                  widget.allCards != null) {
                final selectedCards = widget.allCards!.where((c) => widget.selectedPageIds!.contains(c.id)).toList();
                widget.onDuplicateMultipleCards!(selectedCards);
              } else {
                widget.onDuplicateCard?.call();
              }
            },
          ),
        ],

        // Optional delete card
        if (widget.onDeleteCard != null || widget.onDeleteMultipleCards != null)
          _PillActionButton(
            iconName: 'trash',
            tooltip: (widget.selectedPageIds != null && widget.selectedPageIds!.length > 1)
                ? 'Excluir páginas selecionadas (${widget.selectedPageIds!.length})'
                : 'Excluir página',
            iconColor: const Color(0xFFFF5252),
            onPressed: () {
              if (widget.onDeleteMultipleCards != null &&
                  widget.selectedPageIds != null &&
                  widget.selectedPageIds!.length > 1) {
                widget.onDeleteMultipleCards!(widget.selectedPageIds!.toList());
              } else {
                widget.onDeleteCard?.call();
              }
            },
          ),
      ],
    );
  }

  void _handleReattachMenu(BuildContext context) {
    final excluded = List<int>.from(widget.card.excludedPageIndices);
    if (excluded.isEmpty) return;

    if (excluded.length == 1) {
      widget.onReattachPage?.call(excluded.first);
      return;
    }

    excluded.sort();
    showDialog<int>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: MoscaroTokens.backgroundSurface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16.0)),
            side: BorderSide(color: MoscaroTokens.borderGlow, width: 1.2),
          ),
          title: Row(
            children: [
              SvgIcon(name: 'link', size: 16, color: MoscaroTokens.auroraBlue),
              const SizedBox(width: 8),
              Text(
                'Prender Páginas ao Documento',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                  color: MoscaroTokens.textPrimary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final page in excluded)
                ListTile(
                  dense: true,
                  title: Text(
                    'Página $page',
                    style: TextStyle(color: MoscaroTokens.textPrimary, fontSize: 13),
                  ),
                  trailing: SvgIcon(name: 'link', size: 14, color: MoscaroTokens.auroraBlue),
                  onTap: () {
                    Navigator.of(dialogCtx).pop(page);
                  },
                ),
              const Divider(color: Colors.white12),
              ListTile(
                dense: true,
                title: Text(
                  'Prender Todas as Páginas (${excluded.length})',
                  style: TextStyle(
                    color: MoscaroTokens.auroraBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: SvgIcon(name: 'layers', size: 14, color: MoscaroTokens.auroraBlue),
                onTap: () {
                  Navigator.of(dialogCtx).pop(-1);
                },
              ),
            ],
          ),
        );
      },
    ).then((selectedPage) {
      if (selectedPage != null && mounted) {
        if (selectedPage == -1) {
          for (final p in List<int>.from(widget.card.excludedPageIndices)) {
            widget.onReattachPage?.call(p);
          }
        } else {
          widget.onReattachPage?.call(selectedPage);
        }
      }
    });
  }

  Widget _buildDivider(Color color) {
    return Container(
      width: 1.0,
      height: 16.0,
      color: color,
      margin: const EdgeInsets.symmetric(horizontal: 3.0),
    );
  }
}

/// Standardized action button for Moscaro floating pills.
class _PillActionButton extends StatefulWidget {
  final String iconName;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isActive;
  final bool isEnabled;
  final Color? iconColor;
  final double size;
  final double iconSize;

  const _PillActionButton({
    required this.iconName,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
    this.isEnabled = true,
    this.iconColor,
    this.size = 28.0,
    this.iconSize = 14.0,
  });

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
    final defaultColor = isLight
        ? (widget.isEnabled ? MoscaroTokens.textSecondary : Colors.black26)
        : (widget.isEnabled ? Colors.white70 : Colors.white24);

    final effectiveColor = widget.iconColor ??
        (widget.isActive
            ? themeAccent
            : (_isHovered && widget.isEnabled ? themeAccent : defaultColor));

    final double scale = _isPressed && widget.isEnabled
        ? 0.90
        : (_isHovered && widget.isEnabled ? 1.08 : 1.0);

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 250),
      child: MouseRegion(
        cursor: widget.isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
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
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              width: widget.size,
              height: widget.size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isActive
                    ? themeAccent.withValues(alpha: 0.25)
                    : (_isHovered && widget.isEnabled
                        ? (isLight
                            ? Colors.black.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.08))
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
              child: SvgIcon(
                name: widget.iconName,
                size: widget.iconSize,
                color: effectiveColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
