import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/stem_ink_theme_adapter.dart';
import 'canvas_layers.dart';
import 'note_models.dart';
import 'selection_models.dart';

/// Gerenciador de Cache para o bloco de traços selecionados em movimento
class SelectedStrokesPictureCache {
  ui.Picture? _picture;
  Set<String>? _cachedIds;
  int? _cachedStrokesVersion;
  bool? _cachedIsLight;

  void update(NoteDocument note, Set<String> selectedIds) {
    final isLight = MoscaroTokens.isLight;
    final strokesVersion = note.strokesVersion;

    if (_cachedIds != null &&
        _cachedStrokesVersion == strokesVersion &&
        _cachedIsLight == isLight &&
        _cachedIds!.length == selectedIds.length &&
        _cachedIds!.containsAll(selectedIds) &&
        _picture != null) {
      return;
    }

    _picture?.dispose();
    _picture = null;

    if (selectedIds.isEmpty) {
      _cachedIds = null;
      _cachedStrokesVersion = null;
      _cachedIsLight = null;
      return;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final reusablePaint = Paint();

    for (final id in selectedIds) {
      final stroke = note.getStroke(id);
      if (stroke != null) {
        StrokePictureCache.drawSingleStroke(canvas, stroke, reusablePaint);
      }
    }

    _picture = recorder.endRecording();
    _cachedIds = Set<String>.from(selectedIds);
    _cachedStrokesVersion = strokesVersion;
    _cachedIsLight = isLight;
  }

  void draw(Canvas canvas) {
    if (_picture != null) {
      canvas.drawPicture(_picture!);
    }
  }

  void invalidate() {
    _picture?.dispose();
    _picture = null;
    _cachedIds = null;
    _cachedStrokesVersion = null;
    _cachedIsLight = null;
  }

  void dispose() {
    _picture?.dispose();
    _picture = null;
    _cachedIds = null;
    _cachedStrokesVersion = null;
    _cachedIsLight = null;
  }
}

/// Painter isolado de alta performance para desenhar o Overlay de Seleção
/// (Caixa delimitadora, Laço dinâmico, Traços em arraste e Alças Moscaro v2).
class SelectionOverlayPainter extends CustomPainter {
  final SelectionState? selectionState;
  final SelectionState Function()? getSelectionState;
  final NoteDocument note;
  final Offset panOffset;
  final double zoomScale;
  final ValueNotifier<int>? repaintNotifier;
  final SelectedStrokesPictureCache dragCache;

  SelectionOverlayPainter({
    this.selectionState,
    this.getSelectionState,
    required this.note,
    required this.panOffset,
    required this.zoomScale,
    this.repaintNotifier,
    required this.dragCache,
  }) : super(repaint: repaintNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    final activeState = getSelectionState != null ? getSelectionState!() : (selectionState ?? const SelectionState());

    canvas.save();
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(zoomScale);

    // 1. Desenhar a área de seleção em andamento (Retângulo ou Laço)
    if (activeState.isSelectingArea) {
      if (activeState.type == SelectionType.rectangle &&
          activeState.startPoint != null &&
          activeState.currentPoint != null) {
        _drawSelectingRect(canvas, Rect.fromPoints(activeState.startPoint!, activeState.currentPoint!));
      } else if (activeState.type == SelectionType.lasso && activeState.lassoPoints.length > 1) {
        _drawSelectingLasso(canvas, activeState.lassoPoints);
      }
    }

    // 2. Se houver traços selecionados ou cards selecionados, desenhar a Bounding Box com 8 alças
    final hasSelectableItems = activeState.selectedStrokeIds.isNotEmpty || activeState.selectedCardIds.isNotEmpty;
    if (activeState.hasSelection && hasSelectableItems && activeState.bounds != null) {
      final bounds = activeState.bounds!;
      final dragOffset = activeState.dragOffset;
      final transformBounds = activeState.transformBounds;
      final isResizing = transformBounds != null &&
          activeState.activeHandle != SelectionHandleType.rotation &&
          activeState.activeHandle != SelectionHandleType.none;
      final activeBox = isResizing ? transformBounds : bounds.shift(dragOffset);
      final pivot = activeBox.center;
      final rotation = activeState.rotationAngle;

      // 2.1 Zero-Lag: Desenhar traços selecionados deslocados / rotacionados / escalados
      if (activeState.isDraggingSelection || activeState.isTransforming) {
        if (isResizing) {
          _drawResizedStrokesPreview(canvas, note, activeState.selectedStrokeIds, bounds, transformBounds);
        } else {
          canvas.save();
          canvas.translate(dragOffset.dx, dragOffset.dy);
          if (rotation != 0.0) {
            canvas.translate(bounds.center.dx, bounds.center.dy);
            canvas.rotate(rotation);
            canvas.translate(-bounds.center.dx, -bounds.center.dy);
          }

          dragCache.update(note, activeState.selectedStrokeIds);
          dragCache.draw(canvas);
          canvas.restore();
        }
      }

      // 2.2 Moldura da Bounding Box com 8 Alças e Alça Superior de Rotação
      _drawSelectionBox(
        canvas,
        activeBox,
        rotation: isResizing ? 0.0 : rotation,
        pivot: pivot,
        activeHandle: activeState.activeHandle,
      );
    }

    canvas.restore();
  }

  void _drawSelectingRect(Canvas canvas, Rect rect) {
    final fillPaint = Paint()
      ..color = MoscaroTokens.auroraBlue.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fillPaint);

    final borderPaint = Paint()
      ..color = MoscaroTokens.auroraBlue
      ..strokeWidth = 1.5 / zoomScale
      ..style = PaintingStyle.stroke;

    _drawDashedRect(canvas, rect, borderPaint);
  }

  void _drawSelectingLasso(Canvas canvas, List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final fillPaint = Paint()
      ..color = MoscaroTokens.auroraBlue.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..color = MoscaroTokens.auroraBlue
      ..strokeWidth = 1.5 / zoomScale
      ..style = PaintingStyle.stroke;

    _drawDashedPath(canvas, path, borderPaint);
  }

  static final Map<int, TextPainter> _degTextPainters = {};
  static double _degCachedZoom = 1.0;

  void _drawSelectionBox(
    Canvas canvas,
    Rect bounds, {
    double rotation = 0.0,
    Offset? pivot,
    SelectionHandleType activeHandle = SelectionHandleType.none,
  }) {
    final center = pivot ?? bounds.center;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (rotation != 0.0) canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    final inflated = bounds.inflate(6.0 / zoomScale);
    final rrect = RRect.fromRectAndRadius(inflated, Radius.circular(8.0 / zoomScale));

    // Halo Glow de Seleção Adaptado ao Tema Ativo
    final themeAccent = StemInkThemeAdapter.adaptStrokeColor(
      MoscaroTokens.auroraBlue,
      isLightTheme: MoscaroTokens.isLight,
    );
    final glowPaint = Paint()
      ..color = themeAccent.withValues(alpha: MoscaroTokens.isLight ? 0.35 : 0.25)
      ..strokeWidth = 3.0 / zoomScale
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6.0 / zoomScale);
    canvas.drawRRect(rrect, glowPaint);

    // Borda Neon Principal
    final borderPaint = Paint()
      ..color = themeAccent
      ..strokeWidth = 1.6 / zoomScale
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, borderPaint);


    // HUD Moscaro de Graus em Rotação (Exibido no topo da seleção durante rotação ativa)
    if (rotation != 0.0 || activeHandle == SelectionHandleType.rotation) {
      final deg = ((rotation * 180.0 / math.pi) % 360.0).round();
      if (_degCachedZoom != zoomScale) {
        _degTextPainters.clear();
        _degCachedZoom = zoomScale;
      }
      final textPainter = _degTextPainters.putIfAbsent(deg, () {
        final textSpan = TextSpan(
          text: '$deg°',
          style: TextStyle(
            color: MoscaroTokens.auroraBlue,
            fontSize: 12.0 / zoomScale,
            fontWeight: FontWeight.bold,
          ),
        );
        return TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();
      });

      final hudCenter = Offset(inflated.center.dx, inflated.top - (20.0 / zoomScale));
      final hudRect = Rect.fromCenter(
        center: hudCenter,
        width: textPainter.width + 12.0 / zoomScale,
        height: textPainter.height + 6.0 / zoomScale,
      );

      final hudBgPaint = Paint()
        ..color = MoscaroTokens.backgroundSurface.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill;
      final hudBorderPaint = Paint()
        ..color = MoscaroTokens.auroraBlue.withValues(alpha: 0.5)
        ..strokeWidth = 1.0 / zoomScale
        ..style = PaintingStyle.stroke;

      final hudRRect = RRect.fromRectAndRadius(hudRect, Radius.circular(6.0 / zoomScale));
      canvas.drawRRect(hudRRect, hudBgPaint);
      canvas.drawRRect(hudRRect, hudBorderPaint);

      textPainter.paint(
        canvas,
        Offset(hudCenter.dx - textPainter.width / 2, hudCenter.dy - textPainter.height / 2),
      );
    }

    canvas.restore();
  }


  void _drawResizedStrokesPreview(
    Canvas canvas,
    NoteDocument note,
    Set<String> selectedIds,
    Rect bounds,
    Rect transformBounds,
  ) {
    if (bounds.width <= 0 || bounds.height <= 0) return;

    final double scaleX = transformBounds.width / bounds.width;
    final double scaleY = transformBounds.height / bounds.height;

    canvas.save();
    canvas.translate(transformBounds.left, transformBounds.top);
    canvas.scale(scaleX, scaleY);
    canvas.translate(-bounds.left, -bounds.top);

    dragCache.update(note, selectedIds);
    dragCache.draw(canvas);

    canvas.restore();
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    final path = Path()..addRect(rect);
    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final double dashWidth = 6.0 / zoomScale;
    final double dashSpace = 4.0 / zoomScale;
    final double step = dashWidth + dashSpace;

    // Otimização: Se houverem muitos dashes (excesso de drawPath calls), cai para linha sólida
    for (final metric in path.computeMetrics()) {
      if (metric.length / step > 300) {
        canvas.drawPath(path, paint);
        continue;
      }
      
      double distance = 0.0;
      while (distance < metric.length) {
        final double nextDistance = math.min(distance + dashWidth, metric.length);
        final extractPath = metric.extractPath(distance, nextDistance);
        canvas.drawPath(extractPath, paint);
        distance += step;
      }
    }
  }

  @override
  bool shouldRepaint(covariant SelectionOverlayPainter oldDelegate) {
    return oldDelegate.panOffset != panOffset ||
           oldDelegate.zoomScale != zoomScale ||
           oldDelegate.selectionState != selectionState;
  }
}
