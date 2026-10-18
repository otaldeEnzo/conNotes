import 'dart:io';
import 'package:flutter/material.dart';
import 'note_models.dart';
import '../models/canvas_card_model.dart';
import 'ink_models.dart';
import 'selection_models.dart';
import 'stem_ruler_model.dart';
import 'stem_protractor_model.dart';
import 'stem_ruler_widget.dart';
import 'stem_protractor_widget.dart';
import 'canvas_cards_layer.dart';
import 'canvas_layers.dart';
import 'canvas_dot_grid_painter.dart';
import 'selection_overlay_painter.dart';
import 'laser_pointer.dart';
import '../theme/moscaro_theme_controller.dart';
import 'settings_models.dart';
import '../models/theme_models.dart';
import '../theme/moscaro_v2_tokens.dart';
import 'interactive_dot_grid_glow_painter.dart';

class CanvasLayerStack extends StatelessWidget {
  final NoteDocument? note;
  final CanvasBackgroundType backgroundType;
  final bool isSettingsOpen;
  final AppSettingsState? settings;
  final ValueNotifier<Offset> panNotifier;
  final ValueNotifier<double> zoomNotifier;
  final ValueNotifier<Offset?> mousePosNotifier;
  final ValueNotifier<bool> isInteractingNotifier;
  final ValueNotifier<int> committedStrokesNotifier;
  final ValueNotifier<int> activeStrokeUpdateNotifier;
  final ValueNotifier<int> selectionUpdateNotifier;
  final ValueNotifier<int> transientUpdateNotifier;
  final ValueNotifier<int> rulerUpdateNotifier;
  final InkStroke? activeStroke;
  final InkStroke? Function()? getActiveStroke;
  final SelectionState selectionState;
  final SelectionState Function()? getSelectionState;
  final int strokesVersion;
  final TransientStrokesPictureCache transientPictureCache;
  final SelectedStrokesPictureCache dragPictureCache;
  final LaserPointerEngine laserEngine;
  final StemRulerState rulerState;
  final StemProtractorState protractorState;
  final String? selectedCardId;
  final String activeTool;
  final double eraserRadius;
  final ValueChanged<CanvasCardModel> onUpdateCard;
  final ValueChanged<String?> onSelectCard;
  final ValueChanged<String> onDeleteCard;
  final ValueChanged<CanvasCardModel> onDuplicateCard;
  final ValueChanged<CanvasCardModel>? onAddCard;
  final ValueChanged<StemRulerState> onRulerStateChanged;
  final ValueChanged<StemProtractorState> onProtractorStateChanged;
  final VoidCallback onCloseRuler;
  final VoidCallback onCloseProtractor;
  final ValueChanged<CanvasCardModel>? onSolveWithAi;
  final ValueChanged<String>? onAskAiText;
  final ValueChanged<CanvasCardModel>? onExtractLatex;
  final void Function(List<InkStroke> finalStrokes, String cardId)? onSyncCardStrokes;
  final void Function(String masterCardId, int pageNumber, String? text, [CanvasCardModel? sourceCard])? onJumpToPdfSource;

  const CanvasLayerStack({
    super.key,
    required this.note,
    required this.backgroundType,
    this.isSettingsOpen = false,
    this.settings,
    required this.panNotifier,
    required this.zoomNotifier,
    required this.mousePosNotifier,
    required this.isInteractingNotifier,
    required this.committedStrokesNotifier,
    required this.activeStrokeUpdateNotifier,
    required this.selectionUpdateNotifier,
    required this.transientUpdateNotifier,
    required this.rulerUpdateNotifier,
    this.activeStroke,
    this.getActiveStroke,
    this.selectionState = const SelectionState(),
    this.getSelectionState,
    required this.strokesVersion,
    required this.transientPictureCache,
    required this.dragPictureCache,
    required this.laserEngine,
    required this.rulerState,
    required this.protractorState,
    required this.selectedCardId,
    required this.activeTool,
    required this.eraserRadius,
    required this.onUpdateCard,
    required this.onSelectCard,
    required this.onDeleteCard,
    required this.onDuplicateCard,
    this.onAddCard,
    required this.onRulerStateChanged,
    required this.onProtractorStateChanged,
    required this.onCloseRuler,
    required this.onCloseProtractor,
    this.onSolveWithAi,
    this.onAskAiText,
    this.onExtractLatex,
    this.onSyncCardStrokes,
    this.onJumpToPdfSource,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Camada 0: Imagem de Fundo do Disco (Hardware Accelerated)
        ListenableBuilder(
          listenable: MoscaroThemeController.instance,
          builder: (context, _) {
              final themeCtrl = MoscaroThemeController.instance;
              final isImageMode = themeCtrl.backgroundMode == CanvasBackgroundMode.customImage ||
                  (themeCtrl.currentTheme.bgMode == CanvasBackgroundMode.customImage && themeCtrl.currentTheme.bgImagePath != null);
              final path = themeCtrl.customImagePath ?? themeCtrl.currentTheme.bgImagePath;
              final opacity = themeCtrl.customImageOpacity;

              if (isImageMode && path != null && path.isNotEmpty && File(path).existsSync()) {
                return Positioned.fill(
                  child: Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    opacity: AlwaysStoppedAnimation(opacity),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

        // Camada 1: Fundo (DotGrid / Linhas / Branco) com suporte a Temas e Texturas STEM
        ListenableBuilder(
          listenable: Listenable.merge([panNotifier, zoomNotifier, MoscaroThemeController.instance]),
          builder: (context, _) {
            final pan = panNotifier.value;
            final zoom = zoomNotifier.value;
            final themeCtrl = MoscaroThemeController.instance;

            return RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: CanvasDotGridPainter(
                  panOffset: pan,
                  zoomScale: zoom,
                  mousePosition: null, // Passado null para desativar o CPU loop lento
                  backgroundType: backgroundType,
                  gridSpacing: settings?.gridSpacing ?? 28.0,
                  enableMouseGlow: false,
                  mouseGlowRadius: settings?.mouseGlowRadius ?? 120.0,
                  theme: themeCtrl.currentTheme,
                  backgroundMode: themeCtrl.backgroundMode,
                  customSolidColor: themeCtrl.customSolidColor,
                  customGradientStart: themeCtrl.customGradientStart,
                  customGradientEnd: themeCtrl.customGradientEnd,
                  textureType: themeCtrl.textureType,
                ),
              ),
            );
          },
        ),

        // Camada 1.5: Efeito de Brilho Orgânico e Vivo dos Pontos do Dot Grid (O(K) acelerado)
        if ((settings?.enableMouseGlow ?? true) && backgroundType == CanvasBackgroundType.dotGrid)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: InteractiveDotGridGlowPainter(
                    mousePosNotifier: mousePosNotifier,
                    panNotifier: panNotifier,
                    zoomNotifier: zoomNotifier,
                    gridSpacing: settings?.gridSpacing ?? 28.0,
                    glowRadius: settings?.mouseGlowRadius ?? 140.0,
                    glowColor: MoscaroThemeController.instance.currentTheme.mouseGlowColor,
                    backgroundType: backgroundType,
                    isDark: !MoscaroTokens.isLight,
                    repaint: Listenable.merge([mousePosNotifier, panNotifier, zoomNotifier]),
                  ),
                ),
              ),
            ),
          ),


        // Camada 2: Traços Confirmados (Otimizada para 144 FPS constante com isolamento de drag)
        if (note != null)
          _OptimizedCommittedStrokesLayer(
            note: note!,
            panNotifier: panNotifier,
            zoomNotifier: zoomNotifier,
            committedStrokesNotifier: committedStrokesNotifier,
            isInteractingNotifier: isInteractingNotifier,
            selectionUpdateNotifier: selectionUpdateNotifier,
            getSelectionState: getSelectionState,
            selectionState: selectionState,
          ),

        // Camada 2.5: Traços Transitórios
        ListenableBuilder(
            listenable: Listenable.merge([panNotifier, zoomNotifier, transientUpdateNotifier]),
            builder: (context, _) {
              final pan = panNotifier.value;
              final zoom = zoomNotifier.value;
              return IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: TransientStrokesPainter(
                      cache: transientPictureCache,
                      panOffset: pan,
                      zoomScale: zoom,
                      updateNotifier: transientUpdateNotifier,
                    ),
                  ),
                ),
              );
            },
          ),


        // Camada 4: Overlay de Seleção
        if (!isSettingsOpen && note != null)
          ListenableBuilder(
            listenable: Listenable.merge([panNotifier, zoomNotifier, selectionUpdateNotifier]),
            builder: (context, _) {
              final pan = panNotifier.value;
              final zoom = zoomNotifier.value;
              return IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: SelectionOverlayPainter(
                      selectionState: selectionState,
                      getSelectionState: getSelectionState ?? (() => selectionState),
                      note: note!,
                      panOffset: pan,
                      zoomScale: zoom,
                      repaintNotifier: selectionUpdateNotifier,
                      dragCache: dragPictureCache,
                    ),
                  ),
                ),
              );
            },
          ),

        // Camada 5: Cursor Halo da Borracha (Sub-camada isolada ultra-fluida sem widget rebuilds)
        if (!isSettingsOpen && activeTool == 'eraser')
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _EraserHaloPainter(
                    mousePosNotifier: mousePosNotifier,
                    radius: eraserRadius,
                  ),
                ),
              ),
            ),
          ),

        // Camada 6: Laser Pointer
        if (!isSettingsOpen)
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: LaserPointerPainter(
                  engine: laserEngine,
                  panNotifier: panNotifier,
                  zoomNotifier: zoomNotifier,
                  repaint: Listenable.merge([laserEngine.repaintNotifier, panNotifier, zoomNotifier]),
                ),
              ),
            ),
          ),

        // Camada 7: Régua STEM
        if (!isSettingsOpen && rulerState.isVisible)
          ListenableBuilder(
            listenable: Listenable.merge([panNotifier, zoomNotifier, rulerUpdateNotifier]),
            builder: (context, _) {
              final pan = panNotifier.value;
              final zoom = zoomNotifier.value;
              return TweenAnimationBuilder<double>(
                key: const ValueKey('ruler_fade_entrance'),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                builder: (context, opacity, child) => Opacity(
                  opacity: opacity,
                  child: child,
                ),
                child: StemRulerWidget(
                  state: rulerState,
                  panOffset: pan,
                  zoomScale: zoom,
                  onStateChanged: onRulerStateChanged,
                  onClose: onCloseRuler,
                ),
              );
            },
          ),

        // Camada 7.1: Transferidor STEM
        if (protractorState.isVisible)
          ListenableBuilder(
            listenable: Listenable.merge([panNotifier, zoomNotifier, rulerUpdateNotifier]),
            builder: (context, _) {
              final pan = panNotifier.value;
              final zoom = zoomNotifier.value;
              return TweenAnimationBuilder<double>(
                key: const ValueKey('protractor_fade_entrance'),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                builder: (context, opacity, child) => Opacity(
                  opacity: opacity,
                  child: child,
                ),
                child: StemProtractorWidget(
                  state: protractorState,
                  panOffset: pan,
                  zoomScale: zoom,
                  onStateChanged: onProtractorStateChanged,
                  onClose: onCloseProtractor,
                ),
              );
            },
          ),

        if (note != null)
          CanvasCardsLayer(
            cards: note!.cards,
            getAttachedStrokes: (ids) => ids.map((id) => note!.getStroke(id)).whereType<InkStroke>().toList(),
            activeTool: activeTool,
            selectedCardId: selectedCardId,
            selectionState: selectionState,
            getSelectionState: getSelectionState ?? (() => selectionState),
            selectionUpdateNotifier: selectionUpdateNotifier,
            panNotifier: panNotifier,
            zoomNotifier: zoomNotifier,
            onUpdateCard: onUpdateCard,
            onSelectCard: onSelectCard,
            onDeleteCard: onDeleteCard,
            onDuplicateCard: onDuplicateCard,
            onAddCard: onAddCard,
            onSolveWithAi: onSolveWithAi,
            onAskAiText: onAskAiText,
            onExtractLatex: onExtractLatex,
            onSyncCardStrokes: onSyncCardStrokes,
            onJumpToPdfSource: onJumpToPdfSource,
          ),

        // Camada 8.5: Traço Ativo da Caneta (Zero Widget Rebuild — repinta direto no RenderObject a 180+ FPS)
        if (!isSettingsOpen && note != null)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  willChange: true,
                  painter: ActiveStrokePainter(
                    activeStroke: activeStroke,
                    getActiveStroke: getActiveStroke,
                    updateNotifier: activeStrokeUpdateNotifier,
                    panOffset: panNotifier.value,
                    zoomScale: zoomNotifier.value,
                    panNotifier: panNotifier,
                    zoomNotifier: zoomNotifier,
                    repaint: Listenable.merge([panNotifier, zoomNotifier, activeStrokeUpdateNotifier]),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EraserHaloPainter extends CustomPainter {
  final ValueNotifier<Offset?> mousePosNotifier;
  final double radius;
  final Paint _fillPaint = Paint()
    ..color = const Color(0x2200E1FF)
    ..style = PaintingStyle.fill;
  final Paint _strokePaint = Paint()
    ..color = const Color(0x8800E1FF)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;

  _EraserHaloPainter({required this.mousePosNotifier, required this.radius})
      : super(repaint: mousePosNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    final pos = mousePosNotifier.value;
    if (pos == null) return;
    canvas.drawCircle(pos, radius, _fillPaint);
    canvas.drawCircle(pos, radius, _strokePaint);
  }

  @override
  bool shouldRepaint(covariant _EraserHaloPainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.mousePosNotifier != mousePosNotifier;
  }
}

class _OptimizedCommittedStrokesLayer extends StatefulWidget {
  final NoteDocument note;
  final ValueNotifier<Offset> panNotifier;
  final ValueNotifier<double> zoomNotifier;
  final ValueNotifier<int> committedStrokesNotifier;
  final ValueNotifier<bool> isInteractingNotifier;
  final ValueNotifier<int>? selectionUpdateNotifier;
  final SelectionState Function()? getSelectionState;
  final SelectionState selectionState;

  const _OptimizedCommittedStrokesLayer({
    required this.note,
    required this.panNotifier,
    required this.zoomNotifier,
    required this.committedStrokesNotifier,
    required this.isInteractingNotifier,
    this.selectionUpdateNotifier,
    this.getSelectionState,
    required this.selectionState,
  });

  @override
  State<_OptimizedCommittedStrokesLayer> createState() => _OptimizedCommittedStrokesLayerState();
}

class _OptimizedCommittedStrokesLayerState extends State<_OptimizedCommittedStrokesLayer> {
  final ValueNotifier<int> _hideStateNotifier = ValueNotifier<int>(0);
  bool _lastHideSelected = false;
  Set<String>? _lastSelectedIds;
  Set<String>? _cachedHiddenIds;
  int _lastCachedStrokesVersion = -1;
  int _lastCachedHideVersion = -1;

  @override
  void initState() {
    super.initState();
    widget.selectionUpdateNotifier?.addListener(_onSelectionUpdate);
  }

  @override
  void didUpdateWidget(covariant _OptimizedCommittedStrokesLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectionUpdateNotifier != widget.selectionUpdateNotifier) {
      oldWidget.selectionUpdateNotifier?.removeListener(_onSelectionUpdate);
      widget.selectionUpdateNotifier?.addListener(_onSelectionUpdate);
    }
    if (oldWidget.note != widget.note) {
      _lastCachedStrokesVersion = -1;
    }
  }

  @override
  void dispose() {
    widget.selectionUpdateNotifier?.removeListener(_onSelectionUpdate);
    _hideStateNotifier.dispose();
    super.dispose();
  }

  void _onSelectionUpdate() {
    final activeSel = widget.getSelectionState?.call() ?? widget.selectionState;
    final hideSelected = activeSel.isDraggingSelection || activeSel.isTransforming;
    final selectedIds = activeSel.selectedStrokeIds;

    // Só dispara rebuild da Camada 2 se o status de ocultação mudou ou os IDs selecionados mudaram,
    // garantindo ZERO rebuilds da lista inteira de traços durante o arrasto contínuo do mouse.
    if (hideSelected != _lastHideSelected ||
        (_lastSelectedIds?.length != selectedIds.length) ||
        (_lastSelectedIds != null && !_lastSelectedIds!.containsAll(selectedIds))) {
      _lastHideSelected = hideSelected;
      _lastSelectedIds = Set<String>.from(selectedIds);
      _hideStateNotifier.value++;
    }
  }

  Set<String>? _resolveHiddenStrokeIds(SelectionState activeSel, bool hideSelected) {
    final currentStrokesVer = widget.committedStrokesNotifier.value;
    final currentHideVer = _hideStateNotifier.value;
    if (_lastCachedStrokesVersion == currentStrokesVer && _lastCachedHideVersion == currentHideVer) {
      return _cachedHiddenIds;
    }
    _lastCachedStrokesVersion = currentStrokesVer;
    _lastCachedHideVersion = currentHideVer;

    final attachedIds = <String>{};
    for (final card in widget.note.cards) {
      if (card.attachedStrokeIds.isNotEmpty) {
        attachedIds.addAll(card.attachedStrokeIds);
      }
    }
    if (hideSelected) {
      _cachedHiddenIds = {...activeSel.selectedStrokeIds, ...attachedIds};
    } else {
      _cachedHiddenIds = attachedIds.isNotEmpty ? attachedIds : null;
    }
    return _cachedHiddenIds;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.panNotifier,
        widget.zoomNotifier,
        widget.committedStrokesNotifier,
        _hideStateNotifier,
      ]),
      builder: (context, _) {
        final pan = widget.panNotifier.value;
        final zoom = widget.zoomNotifier.value;
        final activeSel = widget.getSelectionState?.call() ?? widget.selectionState;
        final hideSelected = activeSel.isDraggingSelection || activeSel.isTransforming;

        return IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              isComplex: true,
              willChange: false,
              painter: CommittedStrokesPainter(
                strokes: widget.note.strokes,
                strokesCount: widget.note.strokes.length,
                strokesVersion: widget.committedStrokesNotifier.value,
                hiddenStrokeIds: _resolveHiddenStrokeIds(activeSel, hideSelected),
                panOffset: pan,
                zoomScale: zoom,
                pictureCache: widget.note.pictureCache,
                isInteracting: false,
                repaint: widget.committedStrokesNotifier,
              ),
            ),
          ),
        );
      },
    );
  }
}
