import 'dart:io';
import 'dart:math' as math;
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
  final ValueChanged<StemRulerState> onRulerStateChanged;
  final ValueChanged<StemProtractorState> onProtractorStateChanged;
  final VoidCallback onCloseRuler;
  final VoidCallback onCloseProtractor;

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
    required this.onRulerStateChanged,
    required this.onProtractorStateChanged,
    required this.onCloseRuler,
    required this.onCloseProtractor,
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
          listenable: Listenable.merge([panNotifier, zoomNotifier, mousePosNotifier, MoscaroThemeController.instance]),
          builder: (context, _) {
            final pan = panNotifier.value;
            final zoom = zoomNotifier.value;
            final mousePos = mousePosNotifier.value;
            final themeCtrl = MoscaroThemeController.instance;

            return RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: CanvasDotGridPainter(
                  panOffset: pan,
                  zoomScale: zoom,
                  mousePosition: mousePos,
                  backgroundType: isSettingsOpen ? CanvasBackgroundType.emBranco : backgroundType,
                  gridSpacing: settings?.gridSpacing ?? 28.0,
                  enableMouseGlow: settings?.enableMouseGlow ?? true,
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

        // Camada 2: Traços Confirmados
        if (!isSettingsOpen && note != null)
          ListenableBuilder(
            listenable: Listenable.merge([panNotifier, zoomNotifier, committedStrokesNotifier, isInteractingNotifier]),
            builder: (context, _) {
              final pan = panNotifier.value;
              final zoom = zoomNotifier.value;
              final isInteracting = isInteractingNotifier.value;
              final hideSelected = selectionState.isDraggingSelection || selectionState.isTransforming;

              return RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  isComplex: true,
                  willChange: false,
                  painter: CommittedStrokesPainter(
                    strokes: note!.strokes,
                    strokesCount: note!.strokes.length,
                    strokesVersion: committedStrokesNotifier.value,
                    hiddenStrokeIds: hideSelected ? selectionState.selectedStrokeIds : null,
                    panOffset: pan,
                    zoomScale: zoom,
                    pictureCache: note!.pictureCache,
                    isInteracting: isInteracting,
                    repaint: committedStrokesNotifier,
                  ),
                ),
              );
            },
          ),

        // Camada 2.5: Traços Transitórios
        if (!isSettingsOpen)
          ListenableBuilder(
            listenable: Listenable.merge([panNotifier, zoomNotifier, transientUpdateNotifier]),
            builder: (context, _) {
              final pan = panNotifier.value;
              final zoom = zoomNotifier.value;
              return RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: TransientStrokesPainter(
                    cache: transientPictureCache,
                    panOffset: pan,
                    zoomScale: zoom,
                    updateNotifier: transientUpdateNotifier,
                  ),
                ),
              );
            },
          ),

        // Camada 3: Traço Ativo da Caneta
        if (!isSettingsOpen && note != null)
          ListenableBuilder(
            listenable: Listenable.merge([panNotifier, zoomNotifier, activeStrokeUpdateNotifier]),
            builder: (context, _) {
              final pan = panNotifier.value;
              final zoom = zoomNotifier.value;
              return RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: ActiveStrokePainter(
                    activeStroke: getActiveStroke?.call() ?? activeStroke,
                    updateNotifier: activeStrokeUpdateNotifier,
                    panOffset: pan,
                    zoomScale: zoom,
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
              return RepaintBoundary(
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
              );
            },
          ),

        // Camada 5: Cursor Halo da Borracha (Sub-camada isolada ultra-fluida)
        if (!isSettingsOpen && activeTool == 'eraser')
          ListenableBuilder(
            listenable: mousePosNotifier,
            builder: (context, _) {
              final mousePos = mousePosNotifier.value;
              if (mousePos == null) return const SizedBox.shrink();
              return RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _EraserHaloPainter(
                    mousePosition: mousePos,
                    radius: eraserRadius,
                  ),
                ),
              );
            },
          ),

        // Camada 6: Laser Pointer
        if (!isSettingsOpen)
          RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              painter: LaserPointerPainter(
                engine: laserEngine,
                panOffset: panNotifier.value,
                zoomScale: zoomNotifier.value,
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
              return StemRulerWidget(
                state: rulerState,
                panOffset: pan,
                zoomScale: zoom,
                onStateChanged: onRulerStateChanged,
                onClose: onCloseRuler,
              );
            },
          ),

        // Camada 7.1: Transferidor STEM
        if (!isSettingsOpen && protractorState.isVisible)
          ListenableBuilder(
            listenable: Listenable.merge([panNotifier, zoomNotifier, rulerUpdateNotifier]),
            builder: (context, _) {
              final pan = panNotifier.value;
              final zoom = zoomNotifier.value;
              return StemProtractorWidget(
                state: protractorState,
                panOffset: pan,
                zoomScale: zoom,
                onStateChanged: onProtractorStateChanged,
                onClose: onCloseProtractor,
              );
            },
          ),

        // Camada 8: Cards Interativos no Canvas
        if (!isSettingsOpen && note != null)
          CanvasCardsLayer(
            cards: note!.cards,
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
          ),
      ],
    );
  }
}

class _EraserHaloPainter extends CustomPainter {
  final Offset mousePosition;
  final double radius;
  final Paint _fillPaint = Paint()
    ..color = const Color(0x2200E1FF)
    ..style = PaintingStyle.fill;
  final Paint _strokePaint = Paint()
    ..color = const Color(0x8800E1FF)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;

  _EraserHaloPainter({required this.mousePosition, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(mousePosition, radius, _fillPaint);
    canvas.drawCircle(mousePosition, radius, _strokePaint);
  }

  @override
  bool shouldRepaint(covariant _EraserHaloPainter oldDelegate) {
    return oldDelegate.mousePosition != mousePosition || oldDelegate.radius != radius;
  }
}
