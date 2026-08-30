import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/stem_ink_theme_adapter.dart';
import 'canvas_layers.dart';
import 'ink_models.dart';
import 'note_models.dart';
import 'selection_models.dart';

/// Gerenciador de Cache para o bloco de traços selecionados em movimento
class SelectedStrokesPictureCache {
  ui.Picture? _picture;
  Set<String>? _cachedIds;

  void update(NoteDocument note, Set<String> selectedIds) {
    if (_cachedIds != null &&
        _cachedIds!.length == selectedIds.length &&
        _cachedIds!.containsAll(selectedIds) &&
        _picture != null) {
      return;
    }

    _picture?.dispose();
    _picture = null;

    if (selectedIds.isEmpty) {
      _cachedIds = null;
      return;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final reusablePaint = Paint();

    for (final id in selectedIds) {
      final stroke = note.getStroke(id);
      if (stroke != null) {
        SelectionOverlayPainter._drawStrokeDirectFast(canvas, stroke, reusablePaint);
      }
    }

    _picture = recorder.endRecording();
    _cachedIds = Set<String>.from(selectedIds);
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
  }

  void dispose() {
    _picture?.dispose();
    _picture = null;
    _cachedIds = null;
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

    // 2. Se houver traços selecionados ou multi-seleção, desenhar a Bounding Box com 8 alças
    final hasStrokesOrMultiItems = activeState.selectedStrokeIds.isNotEmpty || activeState.selectedCardIds.length > 1;
    if (activeState.hasSelection && hasStrokesOrMultiItems) {
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
      final textSpan = TextSpan(
        text: '$deg°',
        style: TextStyle(
          color: MoscaroTokens.auroraBlue,
          fontSize: 12.0 / zoomScale,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

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

  static void _drawStrokeDirectFast(Canvas canvas, InkStroke stroke, Paint reusablePaint) {
    if (stroke.points.isEmpty) return;

    final bool hasTransform = stroke.transform != Offset.zero;
    if (hasTransform) {
      canvas.save();
      canvas.translate(stroke.transform.dx, stroke.transform.dy);
    }

    try {
      final adapted = StemInkThemeAdapter.adaptStrokeColor(stroke.color, isLightTheme: MoscaroTokens.isLight);
      
      if ((stroke.toolType == InkToolType.fountain || stroke.enablePressure) && !stroke.isShape) {
        reusablePaint
          ..color = adapted
          ..style = PaintingStyle.fill;

        if (stroke.cachedPath != null) {
          canvas.drawPath(stroke.cachedPath!, reusablePaint);
        } else {
          final path = FreehandOutlineRenderer.generateOutlinePath(
            stroke.points,
            baseWidth: stroke.strokeWidth,
            isTapered: stroke.toolType == InkToolType.fountain,
          );
          canvas.drawPath(path, reusablePaint);
        }
        return;
      }

      final color = stroke.toolType == InkToolType.highlighter
          ? adapted.withValues(alpha: 0.35)
          : (stroke.toolType == InkToolType.pencil ? adapted.withValues(alpha: 0.65) : adapted);

      reusablePaint
        ..color = color
        ..strokeWidth = stroke.strokeWidth * (stroke.toolType == InkToolType.highlighter ? 3.5 : 1.0)
        ..strokeCap = stroke.toolType == InkToolType.highlighter ? StrokeCap.square : StrokeCap.round
        ..strokeJoin = stroke.toolType == InkToolType.highlighter ? StrokeJoin.bevel : StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.cachedPath != null) {
        canvas.drawPath(stroke.cachedPath!, reusablePaint);
      } else if (stroke.toolType == InkToolType.technical && !stroke.enablePressure && stroke.points.length > 50) {
        final rawPoints = Float32List(stroke.points.length * 2);
        for (int i = 0; i < stroke.points.length; i++) {
          rawPoints[i * 2] = stroke.points[i].point.dx;
          rawPoints[i * 2 + 1] = stroke.points[i].point.dy;
        }
        canvas.drawRawPoints(ui.PointMode.polygon, rawPoints, reusablePaint);
      } else {
        final path = InkStroke.buildCatmullRomPath(stroke.points);
        canvas.drawPath(path, reusablePaint);
      }
    } finally {
      if (hasTransform) {
        canvas.restore();
      }
    }
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
    final double geomScale = math.sqrt(scaleX.abs() * scaleY.abs());
    final reusablePaint = Paint();

    for (final id in selectedIds) {
      final stroke = note.getStroke(id);
      if (stroke == null || stroke.points.isEmpty) continue;

      final mappedPoints = <StrokePoint>[];
      for (int i = 0; i < stroke.points.length; i++) {
        final p = stroke.points[i];
        final localP = p.point + stroke.transform;
        final u = (localP.dx - bounds.left) / bounds.width;
        final v = (localP.dy - bounds.top) / bounds.height;
        final newX = transformBounds.left + u * transformBounds.width;
        final newY = transformBounds.top + v * transformBounds.height;
        mappedPoints.add(StrokePoint(
          point: Offset(newX, newY),
          pressure: p.pressure,
          tilt: p.tilt,
        ));
      }

      final newStrokeWidth = (stroke.strokeWidth * geomScale).clamp(0.5, 50.0);
      final adapted = StemInkThemeAdapter.adaptStrokeColor(stroke.color, isLightTheme: MoscaroTokens.isLight);

      // Renderização direta 1:1 idêntica aos traços finais
      if (stroke.toolType == InkToolType.fountain || stroke.enablePressure) {
        reusablePaint
          ..color = adapted
          ..style = PaintingStyle.fill;
        final path = FreehandOutlineRenderer.generateOutlinePath(
          mappedPoints,
          baseWidth: newStrokeWidth,
          isTapered: stroke.toolType == InkToolType.fountain,
        );
        canvas.drawPath(path, reusablePaint);
      } else {
        final color = stroke.toolType == InkToolType.highlighter
            ? adapted.withValues(alpha: 0.35)
            : (stroke.toolType == InkToolType.pencil ? adapted.withValues(alpha: 0.65) : adapted);

        reusablePaint
          ..color = color
          ..strokeWidth = newStrokeWidth * (stroke.toolType == InkToolType.highlighter ? 3.5 : 1.0)
          ..strokeCap = stroke.toolType == InkToolType.highlighter ? StrokeCap.square : StrokeCap.round
          ..strokeJoin = stroke.toolType == InkToolType.highlighter ? StrokeJoin.bevel : StrokeJoin.round
          ..style = PaintingStyle.stroke;

        if (stroke.toolType == InkToolType.technical && !stroke.enablePressure && mappedPoints.length > 50) {
          final rawPoints = Float32List(mappedPoints.length * 2);
          for (int i = 0; i < mappedPoints.length; i++) {
            rawPoints[i * 2] = mappedPoints[i].point.dx;
            rawPoints[i * 2 + 1] = mappedPoints[i].point.dy;
          }
          canvas.drawRawPoints(ui.PointMode.polygon, rawPoints, reusablePaint);
        } else {
          final path = InkStroke.buildCatmullRomPath(mappedPoints);
          canvas.drawPath(path, reusablePaint);
        }
      }
    }
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
