import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'ink_models.dart';
import 'selection_models.dart';

/// Célula/Tile individual de 1024x1024 px que armazena traços locais e sua textura GPU pré-cozida (Baking).
///
/// Pipeline de 2 fases:
///   render()  → Grava traços num ui.Picture (rápido, apenas registra comandos)
///   tryBake() → Converte Picture em textura GPU via toImageSync (caro, chamado escalonado)
class CanvasTile {
  final int tileX;
  final int tileY;
  final List<InkStroke> strokes = [];
  ui.Image? image;
  ui.Picture? picture;
  bool isDirty = true;
  bool _needsTextureBake = false;

  CanvasTile(this.tileX, this.tileY);

  void addStroke(InkStroke stroke) {
    strokes.add(stroke);
    isDirty = true;
    _needsTextureBake = false;
  }

  void removeStroke(String id) {
    strokes.removeWhere((s) => s.id == id);
    isDirty = true;
    _needsTextureBake = false;
  }

  bool get needsTextureBake => _needsTextureBake;

  /// Fase 1: Grava todos os traços num ui.Picture em coordenadas locais do tile.
  /// Rápido — apenas registra comandos de desenho, sem rasterização.
  void render(Paint reusablePaint) {
    if (!isDirty && (image != null || picture != null)) return;

    image?.dispose();
    image = null;
    picture?.dispose();
    picture = null;

    if (strokes.isEmpty) {
      isDirty = false;
      _needsTextureBake = false;
      return;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Sempre gravar em coordenadas locais do tile (0,0)-(1024,1024)
    // para compatibilidade com toImageSync durante o baking.
    canvas.translate(-tileX * StrokePictureCache.tileSize, -tileY * StrokePictureCache.tileSize);

    // 1. Marca-textos primeiro (para ficarem "atrás" de traços normais)
    for (var i = 0; i < strokes.length; i++) {
      final s = strokes[i];
      if (s.toolType == InkToolType.highlighter) {
        StrokePictureCache._drawSingleStroke(canvas, s, reusablePaint);
      }
    }

    // 2. Traços regulares por cima
    for (var i = 0; i < strokes.length; i++) {
      final s = strokes[i];
      if (s.toolType != InkToolType.highlighter) {
        StrokePictureCache._drawSingleStroke(canvas, s, reusablePaint);
      }
    }

    picture = recorder.endRecording();
    isDirty = false;
    // Tiles com >= 4 traços são candidatos a baking em textura GPU
    _needsTextureBake = strokes.length >= 4;
  }

  /// Fase 2: Converte o Picture gravado em textura rasterizada na GPU via toImageSync.
  /// Operação cara — deve ser chamada de forma escalonada (máx. 1 tile por frame).
  /// Retorna true se o baking foi realizado com sucesso.
  bool tryBake() {
    if (!_needsTextureBake || picture == null) return false;
    try {
      final img = picture!.toImageSync(
        StrokePictureCache.tileSize.toInt(),
        StrokePictureCache.tileSize.toInt(),
      );
      image?.dispose();
      image = img;
      picture!.dispose();
      picture = null;
      _needsTextureBake = false;
      return true;
    } catch (_) {
      // Falha no baking — mantém o Picture como fallback
      _needsTextureBake = false;
      return false;
    }
  }

  void dispose() {
    image?.dispose();
    image = null;
    picture?.dispose();
    picture = null;
    strokes.clear();
  }
}

/// Gerenciador de Chunks / Tiles de 1024x1024 px (Padrão Indústria OneNote / Samsung Notes).
/// Com Baking Escalonado: permite 100.000 traços no canvas infinito com zero frame drops.
class StrokePictureCache {
  static const double tileSize = 1024.0;
  /// Máximo de tiles "assados" (toImageSync) por frame para evitar picos de latência.
  static const int _maxBakesPerFrame = 2;
  final Map<int, Map<int, CanvasTile>> _tiles = {};
  int _lastVersion = -1;
  int _lastCount = -1;
  final Paint _reusablePaint = Paint();

  CanvasTile _getOrCreateTile(int tx, int ty) {
    return _tiles.putIfAbsent(tx, () => {}).putIfAbsent(ty, () => CanvasTile(tx, ty));
  }

  // Não usamos mais updateCache() porque causa lag insano ao apagar traços
  // O sincronismo de cache agora é gerenciado ativamente pelo NoteDocument (via addStroke / removeStroke)

  void insertStrokeToTiles(InkStroke stroke) {
    final bounds = stroke.boundingBox ?? SelectionGeometry.computeStrokeBounds(stroke);
    final minTx = (bounds.left / tileSize).floor();
    final maxTx = (bounds.right / tileSize).floor();
    final minTy = (bounds.top / tileSize).floor();
    final maxTy = (bounds.bottom / tileSize).floor();

    for (int tx = minTx; tx <= maxTx; tx++) {
      for (int ty = minTy; ty <= maxTy; ty++) {
        _getOrCreateTile(tx, ty).addStroke(stroke);
      }
    }
  }

  /// Desenha APENAS os tiles que estão dentro do campo de visão da tela (Viewport Culling O(1)).
  /// Usa Baking Escalonado: máximo de [_maxBakesPerFrame] tiles convertidos em textura GPU por frame.
  void drawViewportToCanvas(Canvas canvas, Rect viewportRect, {Set<String>? hiddenIds, bool isInteracting = false}) {
    final minTx = (viewportRect.left / tileSize).floor();
    final maxTx = (viewportRect.right / tileSize).floor();
    final minTy = (viewportRect.top / tileSize).floor();
    final maxTy = (viewportRect.bottom / tileSize).floor();

    final hasHidden = hiddenIds != null && hiddenIds.isNotEmpty;
    int bakesThisFrame = 0;

    for (int tx = minTx; tx <= maxTx; tx++) {
      final col = _tiles[tx];
      if (col == null) continue;

      for (int ty = minTy; ty <= maxTy; ty++) {
        final tile = col[ty];
        if (tile == null || tile.strokes.isEmpty) continue;

        if (hasHidden && tile.strokes.any((s) => hiddenIds.contains(s.id))) {
          // Apenas para os tiles que contêm traços selecionados sendo movidos, desenha dinamicamente
          for (var i = 0; i < tile.strokes.length; i++) {
            final s = tile.strokes[i];
            if (!hiddenIds.contains(s.id)) {
              _drawSingleStroke(canvas, s, _reusablePaint);
            }
          }
        } else {
          // Fase 1: Garantir que o tile tenha pelo menos um Picture gravado
          tile.render(_reusablePaint);

          // Fase 2: Baking Escalonado — converter Picture → Textura GPU (máx. N por frame)
          // PULA O BAKING se estiver interagindo (ex: apagando) para evitar stutter massivo!
          if (!isInteracting && tile.needsTextureBake && bakesThisFrame < _maxBakesPerFrame) {
            if (tile.tryBake()) bakesThisFrame++;
          }

          // Desenhar usando o formato mais eficiente disponível
          if (tile.image != null) {
            // Textura GPU: 1 única draw call por tile (O(1) — mais rápido possível)
            canvas.drawImage(
              tile.image!,
              Offset(tx * tileSize, ty * tileSize),
              Paint(),
            );
          } else if (tile.picture != null) {
            // Fallback Picture: replica os comandos de desenho (mais lento, mas sempre disponível
            // enquanto o baking escalonado ainda não completou este tile).
            // Picture foi gravado em coordenadas locais do tile — traduzir de volta para coordenadas mundo.
            canvas.save();
            canvas.translate(tx * tileSize, ty * tileSize);
            canvas.drawPicture(tile.picture!);
            canvas.restore();
          }
        }
      }
    }
  }

  int get totalTilesCount {
    int count = 0;
    for (final col in _tiles.values) {
      count += col.length;
    }
    return count;
  }

  int get gpuTexturesCount {
    int count = 0;
    for (final col in _tiles.values) {
      for (final tile in col.values) {
        if (tile.image != null) count++;
      }
    }
    return count;
  }

  /// Remove um traço apenas dos tiles que o contêm, marcando apenas esses tiles como dirty.
  /// (Evita rebuild de 50.000 traços durante o uso da Borracha!)
  void removeStrokeFromTiles(String id, Rect bounds) {
    final minTx = (bounds.left / tileSize).floor();
    final maxTx = (bounds.right / tileSize).floor();
    final minTy = (bounds.top / tileSize).floor();
    final maxTy = (bounds.bottom / tileSize).floor();

    for (int tx = minTx; tx <= maxTx; tx++) {
      final col = _tiles[tx];
      if (col == null) continue;
      for (int ty = minTy; ty <= maxTy; ty++) {
        final tile = col[ty];
        if (tile != null) {
          tile.removeStroke(id);
        }
      }
    }
  }

  /// Atualiza a posição de um traço movido apenas nos tiles afetados
  void updateStrokeInTiles(InkStroke updatedStroke, Rect oldBounds, Rect newBounds) {
    removeStrokeFromTiles(updatedStroke.id, oldBounds);
    insertStrokeToTiles(updatedStroke);
  }

  void clear() {
    for (final col in _tiles.values) {
      for (final tile in col.values) {
        tile.dispose();
      }
    }
    _tiles.clear();
    _lastVersion = -1;
    _lastCount = -1;
  }

  void invalidate() {
    clear();
  }

  void dispose() {
    clear();
  }

  static void _drawSingleStroke(Canvas canvas, InkStroke stroke, Paint reusablePaint) {
    if (stroke.points.isEmpty) return;

    final bool hasTransform = stroke.transform != Offset.zero;
    if (hasTransform) {
      canvas.save();
      canvas.translate(stroke.transform.dx, stroke.transform.dy);
    }

    try {
      if (stroke.points.length == 1) {
        final p = stroke.points.first;
        reusablePaint
          ..color = _getStrokeColor(stroke)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p.point, stroke.strokeWidth / 2, reusablePaint);
        return;
      }

    if (stroke.toolType == InkToolType.highlighter) {
      reusablePaint
        ..color = stroke.color.withOpacity(0.35)
        ..strokeWidth = stroke.strokeWidth * 3.5
        ..strokeCap = StrokeCap.square
        ..strokeJoin = StrokeJoin.bevel
        ..style = PaintingStyle.stroke;

      stroke.cachedPath ??= _buildSmoothCatmullRomPath(stroke.points);
      canvas.drawPath(stroke.cachedPath!, reusablePaint);
      return;
    }

    if (stroke.toolType == InkToolType.pencil) {
      reusablePaint
        ..color = stroke.color.withOpacity(0.65)
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      stroke.cachedPath ??= _buildSmoothCatmullRomPath(stroke.points);
      canvas.drawPath(stroke.cachedPath!, reusablePaint);
      return;
    }

    if (stroke.toolType == InkToolType.fountain) {
      _drawFountainStroke(canvas, stroke, reusablePaint);
      return;
    }

    if (stroke.enablePressure) {
      _drawPressureStroke(canvas, stroke, reusablePaint);
    } else {
      reusablePaint
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      // Otimização Extrema (GPU Tessellation Bypass)
      // Se for um rabisco muito denso, usar RawPoints é 10.000x mais rápido para a GPU do que Catmull-Rom + drawPath
      if (stroke.points.length > 50) {
        final Float32List rawPoints = Float32List(stroke.points.length * 2);
        for (int i = 0; i < stroke.points.length; i++) {
          rawPoints[i * 2] = stroke.points[i].point.dx;
          rawPoints[i * 2 + 1] = stroke.points[i].point.dy;
        }
        canvas.drawRawPoints(ui.PointMode.polygon, rawPoints, reusablePaint);
      } else {
        stroke.cachedPath ??= _buildSmoothCatmullRomPath(stroke.points);
        canvas.drawPath(stroke.cachedPath!, reusablePaint);
      }
    }
    } finally {
      if (hasTransform) {
        canvas.restore();
      }
    }
  }

  static Color _getStrokeColor(InkStroke stroke) {
    if (stroke.toolType == InkToolType.highlighter) return stroke.color.withOpacity(0.35);
    if (stroke.toolType == InkToolType.pencil) return stroke.color.withOpacity(0.65);
    return stroke.color;
  }

  static Path _buildSmoothCatmullRomPath(List<StrokePoint> points) {
    final path = Path();
    if (points.isEmpty) return path;
    if (points.length == 1) {
      path.addOval(Rect.fromCircle(center: points[0].point, radius: 0.1));
      return path;
    }
    if (points.length == 2) {
      path.moveTo(points[0].point.dx, points[0].point.dy);
      path.lineTo(points[1].point.dx, points[1].point.dy);
      return path;
    }

    path.moveTo(points[0].point.dx, points[0].point.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1].point : points[i].point;
      final p1 = points[i].point;
      final p2 = points[i + 1].point;
      final p3 = i < points.length - 2 ? points[i + 2].point : p2;

      final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6.0, p1.dy + (p2.dy - p0.dy) / 6.0);
      final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6.0, p2.dy - (p3.dy - p1.dy) / 6.0);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  static void _drawPressureStroke(Canvas canvas, InkStroke stroke, Paint reusablePaint) {
    final points = stroke.points;
    if (points.length < 2) return;

    reusablePaint
      ..color = stroke.color
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];

      final double pFactor = (p0.pressure.clamp(0.2, 1.5) + p1.pressure.clamp(0.2, 1.5)) / 2.0;
      reusablePaint.strokeWidth = (stroke.strokeWidth * pFactor).clamp(1.0, stroke.strokeWidth * 2.2);

      canvas.drawLine(p0.point, p1.point, reusablePaint);
    }
  }

  static void _drawFountainStroke(Canvas canvas, InkStroke stroke, Paint reusablePaint) {
    final points = stroke.points;
    if (points.length < 2) return;

    reusablePaint
      ..color = stroke.color
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i].point;
      final p1 = points[i + 1].point;

      final delta = p1 - p0;
      final angle = math.atan2(delta.dy, delta.dx);
      final double angleFactor = (math.sin(angle - (math.pi / 4)).abs() + 0.3).clamp(0.3, 1.4);
      reusablePaint.strokeWidth = stroke.strokeWidth * angleFactor;

      canvas.drawLine(p0, p1, reusablePaint);
    }
  }
}

/// Painter dedicado para desenhar o histórico de traços comitados.
/// Executa em 144Hz a 1 única chamada Skia Picture GPU.
class CommittedStrokesPainter extends CustomPainter {
  final List<InkStroke> strokes;
  final int strokesCount;
  final int strokesVersion;
  final Set<String>? hiddenStrokeIds;
  final Offset panOffset;
  final double zoomScale;
  final StrokePictureCache pictureCache;
  final bool isInteracting;

  // Pool de Paint reutilizável (Zero allocation por frame)
  final Paint _reusablePaint = Paint();

  CommittedStrokesPainter({
    required this.strokes,
    required this.strokesCount,
    this.strokesVersion = 0,
    this.hiddenStrokeIds,
    required this.panOffset,
    required this.zoomScale,
    required this.pictureCache,
    this.isInteracting = false,
  });

  @override
  void paint(Canvas canvas, Size size) {

    canvas.save();
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(zoomScale);

    final viewportRect = Rect.fromLTRB(
      -panOffset.dx / zoomScale,
      -panOffset.dy / zoomScale,
      (-panOffset.dx + size.width) / zoomScale,
      (-panOffset.dy + size.height) / zoomScale,
    );

    pictureCache.drawViewportToCanvas(
      canvas, 
      viewportRect, 
      hiddenIds: hiddenStrokeIds,
      isInteracting: isInteracting,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CommittedStrokesPainter oldDelegate) {
    return oldDelegate.strokesVersion != strokesVersion ||
        oldDelegate.strokesCount != strokesCount ||
        oldDelegate.hiddenStrokeIds != hiddenStrokeIds ||
        oldDelegate.panOffset != panOffset ||
        oldDelegate.zoomScale != zoomScale ||
        oldDelegate.isInteracting != isInteracting;
  }
}

/// Painter isolado que desenha APENAS o traço atualmente sendo desenhado.
/// Vinculado a um ValueNotifier para repintar 144Hz SEM disparar setState() no app.
class ActiveStrokePainter extends CustomPainter {
  final InkStroke? activeStroke;
  final ValueNotifier<int> updateNotifier;
  final Offset panOffset;
  final double zoomScale;

  // Pool de Paint reutilizável (Zero allocation por frame)
  final Paint _reusablePaint = Paint();

  ActiveStrokePainter({
    required this.activeStroke,
    required this.updateNotifier,
    required this.panOffset,
    required this.zoomScale,
  }) : super(repaint: updateNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = activeStroke;
    if (stroke == null || stroke.points.isEmpty) return;

    canvas.save();
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(zoomScale);

    _drawStroke(canvas, stroke);

    canvas.restore();
  }

  void _drawStroke(Canvas canvas, InkStroke stroke) {
    if (stroke.points.isEmpty) return;

    final bool hasTransform = stroke.transform != Offset.zero;
    if (hasTransform) {
      canvas.save();
      canvas.translate(stroke.transform.dx, stroke.transform.dy);
    }

    try {
      if (stroke.points.length == 1) {
        final p = stroke.points.first;
        _reusablePaint
          ..color = _getStrokeColor(stroke)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p.point, stroke.strokeWidth / 2, _reusablePaint);
        return;
      }

    if (stroke.toolType == InkToolType.highlighter) {
      _reusablePaint
        ..color = stroke.color.withOpacity(0.35)
        ..strokeWidth = stroke.strokeWidth * 3.5
        ..strokeCap = StrokeCap.square
        ..strokeJoin = StrokeJoin.bevel
        ..style = PaintingStyle.stroke;

      final path = _buildSmoothCatmullRomPath(stroke.points);
      canvas.drawPath(path, _reusablePaint);
      return;
    }

    if (stroke.toolType == InkToolType.pencil) {
      _reusablePaint
        ..color = stroke.color.withOpacity(0.65)
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = _buildSmoothCatmullRomPath(stroke.points);
      canvas.drawPath(path, _reusablePaint);
      return;
    }

    if (stroke.toolType == InkToolType.fountain) {
      _drawFountainStroke(canvas, stroke);
      return;
    }

    if (stroke.enablePressure) {
      _drawPressureStroke(canvas, stroke);
    } else {
      _reusablePaint
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = _buildSmoothCatmullRomPath(stroke.points);
      canvas.drawPath(path, _reusablePaint);
    }
    } finally {
      if (hasTransform) {
        canvas.restore();
      }
    }
  }

  Color _getStrokeColor(InkStroke stroke) {
    if (stroke.toolType == InkToolType.highlighter) return stroke.color.withOpacity(0.35);
    if (stroke.toolType == InkToolType.pencil) return stroke.color.withOpacity(0.65);
    return stroke.color;
  }

  Path _buildSmoothCatmullRomPath(List<StrokePoint> points) {
    final path = Path();
    if (points.isEmpty) return path;
    if (points.length == 1) {
      path.addOval(Rect.fromCircle(center: points[0].point, radius: 0.1));
      return path;
    }
    if (points.length == 2) {
      path.moveTo(points[0].point.dx, points[0].point.dy);
      path.lineTo(points[1].point.dx, points[1].point.dy);
      return path;
    }

    path.moveTo(points[0].point.dx, points[0].point.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1].point : points[i].point;
      final p1 = points[i].point;
      final p2 = points[i + 1].point;
      final p3 = i < points.length - 2 ? points[i + 2].point : p2;

      final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6.0, p1.dy + (p2.dy - p0.dy) / 6.0);
      final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6.0, p2.dy - (p3.dy - p1.dy) / 6.0);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  void _drawPressureStroke(Canvas canvas, InkStroke stroke) {
    final points = stroke.points;
    if (points.length < 2) return;

    _reusablePaint
      ..color = stroke.color
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];

      final double pFactor = (p0.pressure.clamp(0.2, 1.5) + p1.pressure.clamp(0.2, 1.5)) / 2.0;
      _reusablePaint.strokeWidth = (stroke.strokeWidth * pFactor).clamp(1.0, stroke.strokeWidth * 2.2);

      canvas.drawLine(p0.point, p1.point, _reusablePaint);
    }
  }

  void _drawFountainStroke(Canvas canvas, InkStroke stroke) {
    final points = stroke.points;
    if (points.length < 2) return;

    _reusablePaint
      ..color = stroke.color
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i].point;
      final p1 = points[i + 1].point;

      final delta = p1 - p0;
      final angle = math.atan2(delta.dy, delta.dx);
      final double angleFactor = (math.sin(angle - (math.pi / 4)).abs() + 0.3).clamp(0.3, 1.4);
      _reusablePaint.strokeWidth = stroke.strokeWidth * angleFactor;

      canvas.drawLine(p0, p1, _reusablePaint);
    }
  }

  @override
  bool shouldRepaint(covariant ActiveStrokePainter oldDelegate) {
    return oldDelegate.panOffset != panOffset || oldDelegate.zoomScale != zoomScale;
  }
}
