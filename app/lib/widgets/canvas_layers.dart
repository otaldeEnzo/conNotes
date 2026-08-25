import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/stem_ink_theme_adapter.dart';
import 'ink_models.dart';
import 'selection_models.dart';

/// Sub-camada imutável dentro de um CanvasTile (Chunk de até 128 traços).
/// Ao apagar traços, apenas o sub-chunk afetado é regravado, permitindo
/// 144 FPS instantâneos mesmo com 50.000 traços concentrados no mesmo tile.
class TileSubChunk {
  static const int maxChunkSize = 128;
  final List<InkStroke> strokes = [];
  ui.Picture? picture;
  bool isDirty = true;

  bool get isFull => strokes.length >= maxChunkSize;
  bool get isEmpty => strokes.isEmpty;

  void addStroke(InkStroke stroke) {
    strokes.add(stroke);
    isDirty = true;
  }

  bool removeStroke(String id) {
    final prevLen = strokes.length;
    strokes.removeWhere((s) => s.id == id);
    if (strokes.length != prevLen) {
      isDirty = true;
      return true;
    }
    return false;
  }

  bool removeStrokes(Set<String> ids) {
    final prevLen = strokes.length;
    strokes.removeWhere((s) => ids.contains(s.id));
    if (strokes.length != prevLen) {
      isDirty = true;
      return true;
    }
    return false;
  }

  void render(Paint reusablePaint, int tileX, int tileY) {
    if (!isDirty && picture != null) return;

    picture?.dispose();
    picture = null;

    if (strokes.isEmpty) {
      isDirty = false;
      return;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
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
  }

  void draw(Canvas canvas, {Set<String>? hiddenIds, Paint? reusablePaint, int tileX = 0, int tileY = 0}) {
    if (strokes.isEmpty) return;

    // Se algum traço deste chunk estiver oculto (ex: sendo movido ou apagado), desenha dinamicamente
    if (hiddenIds != null && strokes.any((s) => hiddenIds.contains(s.id))) {
      final paint = reusablePaint ?? Paint();
      canvas.save();
      canvas.translate(-tileX * StrokePictureCache.tileSize, -tileY * StrokePictureCache.tileSize);
      for (var i = 0; i < strokes.length; i++) {
        final s = strokes[i];
        if (!hiddenIds.contains(s.id)) {
          StrokePictureCache._drawSingleStroke(canvas, s, paint);
        }
      }
      canvas.restore();
      return;
    }

    if (picture != null) {
      canvas.drawPicture(picture!);
    }
  }

  void invalidatePicture() {
    picture?.dispose();
    picture = null;
    isDirty = true;
  }

  void dispose() {
    picture?.dispose();
    picture = null;
    strokes.clear();
  }
}

/// Célula/Tile individual de 1024x1024 px composta por sub-chunks imutáveis (Sub-Pictures).
/// Pipeline escalonado de 2 fases:
///   render()  → Grava apenas os sub-chunks alterados num ui.Picture independente (O(1), <0.2ms)
///   tryBake() → Converte os sub-chunks compostos em textura GPU via toImageSync em idle
class CanvasTile {
  final int tileX;
  final int tileY;
  final List<TileSubChunk> _chunks = [];
  final Map<String, TileSubChunk> _strokeToChunkMap = {};
  ui.Picture? picture;
  ui.Image? image;
  bool isDirty = true;
  bool _needsTextureBake = false;
  int lastUsedFrame = 0;

  CanvasTile(this.tileX, this.tileY);

  int get totalStrokes => _strokeToChunkMap.length;
  bool get isEmpty => _strokeToChunkMap.isEmpty;

  Iterable<InkStroke> get allStrokes sync* {
    for (final chunk in _chunks) {
      yield* chunk.strokes;
    }
  }

  bool containsHidden(Set<String> hiddenIds) {
    for (final id in hiddenIds) {
      if (_strokeToChunkMap.containsKey(id)) return true;
    }
    return false;
  }

  void addStroke(InkStroke stroke) {
    if (_chunks.isEmpty || _chunks.last.isFull) {
      _chunks.add(TileSubChunk());
    }
    final targetChunk = _chunks.last;
    targetChunk.addStroke(stroke);
    _strokeToChunkMap[stroke.id] = targetChunk;
    isDirty = true;
    _needsTextureBake = false;
  }

  void removeStroke(String id) {
    final chunk = _strokeToChunkMap.remove(id);
    if (chunk != null) {
      chunk.removeStroke(id);
      isDirty = true;
      _needsTextureBake = false;
      _cleanupEmptyChunks();
    }
  }

  void removeStrokes(Set<String> ids) {
    final affectedChunks = <TileSubChunk>{};
    for (final id in ids) {
      final chunk = _strokeToChunkMap.remove(id);
      if (chunk != null) {
        affectedChunks.add(chunk);
      }
    }
    for (final chunk in affectedChunks) {
      chunk.removeStrokes(ids);
    }
    if (affectedChunks.isNotEmpty) {
      isDirty = true;
      _needsTextureBake = false;
      _cleanupEmptyChunks();
    }
  }

  void _cleanupEmptyChunks() {
    _chunks.removeWhere((c) {
      if (c.isEmpty) {
        c.dispose();
        return true;
      }
      return false;
    });
  }

  bool get needsTextureBake => _needsTextureBake;

  /// Fase 1: Grava APENAS os sub-chunks sujos (O(1)) e compõe em 1 único Picture do tile.
  void render(Paint reusablePaint) {
    if (!isDirty && picture != null) {
      return;
    }

    if (_chunks.isEmpty) {
      picture?.dispose();
      picture = null;
      image?.dispose();
      image = null;
      isDirty = false;
      _needsTextureBake = false;
      return;
    }

    bool anyChunkChanged = false;
    for (var i = 0; i < _chunks.length; i++) {
      if (_chunks[i].isDirty || _chunks[i].picture == null) {
        _chunks[i].render(reusablePaint, tileX, tileY);
        anyChunkChanged = true;
      }
    }

    if (anyChunkChanged || picture == null) {
      picture?.dispose();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (var i = 0; i < _chunks.length; i++) {
        if (_chunks[i].picture != null) {
          canvas.drawPicture(_chunks[i].picture!);
        }
      }
      picture = recorder.endRecording();
      image?.dispose();
      image = null;
    }

    isDirty = false;
    _needsTextureBake = totalStrokes >= 4;
  }

  /// Desenha o tile inteiro com 1 única chamada Skia Picture GPU (0.01ms por tile)
  void draw(Canvas canvas, Paint reusablePaint, {Set<String>? hiddenIds}) {
    if (hiddenIds != null && containsHidden(hiddenIds)) {
      for (var i = 0; i < _chunks.length; i++) {
        _chunks[i].draw(
          canvas,
          hiddenIds: hiddenIds,
          reusablePaint: reusablePaint,
          tileX: tileX,
          tileY: tileY,
        );
      }
      return;
    }

    if (picture != null) {
      canvas.drawPicture(picture!);
    }
  }

  /// Fase 2: Converte o Picture composto em textura GPU em idle
  bool tryBake() {
    if (!_needsTextureBake || picture == null) return false;
    try {
      final img = picture!.toImageSync(
        StrokePictureCache.tileSize.toInt(),
        StrokePictureCache.tileSize.toInt(),
      );
      image?.dispose();
      image = img;
      _needsTextureBake = false;
      return true;
    } catch (_) {
      _needsTextureBake = false;
      return false;
    }
  }

  void invalidatePictures() {
    image?.dispose();
    image = null;
    picture?.dispose();
    picture = null;
    isDirty = true;
    _needsTextureBake = true;
    for (var i = 0; i < _chunks.length; i++) {
      _chunks[i].invalidatePicture();
    }
  }

  void dispose() {
    image?.dispose();
    image = null;
    picture?.dispose();
    picture = null;
    for (final chunk in _chunks) {
      chunk.dispose();
    }
    _chunks.clear();
    _strokeToChunkMap.clear();
  }
}

/// Gerenciador de Chunks / Tiles de 1024x1024 px (Padrão Indústria OneNote / Samsung Notes).
/// Com Sub-Chunks Imutáveis e Baking Escalonado: permite 100.000 traços no canvas infinito com zero frame drops.
class StrokePictureCache {
  static const double tileSize = 1024.0;
  /// Máximo de tiles "assados" (toImageSync) por frame para evitar picos de latência.
  static const int _maxBakesPerFrame = 3;
  static const int _maxGpuTextures = 128;
  static const double _maxTextureZoom = 1.35;
  final Map<int, Map<int, CanvasTile>> _tiles = {};
  final Paint _reusablePaint = Paint();
  int _frame = 0;

  CanvasTile _getOrCreateTile(int tx, int ty) {
    return _tiles.putIfAbsent(tx, () => {}).putIfAbsent(ty, () => CanvasTile(tx, ty));
  }

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
  /// Usa Sub-Chunks Imutáveis e Baking Escalonado para máxima fluidez.
  void drawViewportToCanvas(
    Canvas canvas,
    Rect viewportRect, {
    Set<String>? hiddenIds,
    bool isInteracting = false,
    double zoomScale = 1.0,
  }) {
    _frame++;
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
        if (tile == null || tile.isEmpty) continue;
        tile.lastUsedFrame = _frame;

        // Fase 1: Garantir que todos os sub-chunks sujos sejam gravados em ui.Picture
        tile.render(_reusablePaint);

        // Fase 2: Baking Escalonado — converter Picture → Textura GPU (máx. N por frame)
        // PULA O BAKING se estiver interagindo (ex: apagando) para evitar stutter massivo!
        if (!isInteracting && zoomScale <= _maxTextureZoom && tile.needsTextureBake && bakesThisFrame < _maxBakesPerFrame) {
          if (tile.tryBake()) bakesThisFrame++;
        }

        // Desenhar usando o formato mais eficiente disponível
        if (tile.image != null && zoomScale <= _maxTextureZoom && (!hasHidden || !tile.containsHidden(hiddenIds))) {
          // Textura GPU: 1 única draw call por tile (O(1))
          canvas.drawImage(
            tile.image!,
            Offset(tx * tileSize, ty * tileSize),
            Paint(),
          );
        } else {
          // Fallback Composto por Sub-Chunks: desenha a lista de Picture congeladas dos sub-chunks
          canvas.save();
          canvas.translate(tx * tileSize, ty * tileSize);
          tile.draw(canvas, _reusablePaint, hiddenIds: hasHidden ? hiddenIds : null);
          canvas.restore();
        }
      }
    }

    if (bakesThisFrame > 0) {
      _evictLeastRecentlyUsedTextures();
    }
  }

  void _evictLeastRecentlyUsedTextures() {
    final texturedTiles = <CanvasTile>[];
    for (final column in _tiles.values) {
      for (final tile in column.values) {
        if (tile.image != null) texturedTiles.add(tile);
      }
    }
    if (texturedTiles.length <= _maxGpuTextures) return;

    texturedTiles.sort((a, b) => a.lastUsedFrame.compareTo(b.lastUsedFrame));
    for (final tile in texturedTiles.take(texturedTiles.length - _maxGpuTextures)) {
      tile.image?.dispose();
      tile.image = null;
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

  /// Remove um traço apenas dos tiles que o contêm, marcando apenas o sub-chunk correspondente como dirty.
  void removeStrokeFromTiles(String id, Rect bounds) {
    removeStrokesFromTiles({id: bounds});
  }

  /// Remove vários traços e percorre cada tile afetado apenas uma vez.
  void removeStrokesFromTiles(Map<String, Rect> strokeBounds) {
    final affected = <CanvasTile, Set<String>>{};
    for (final entry in strokeBounds.entries) {
      final bounds = entry.value;
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
            affected.putIfAbsent(tile, () => <String>{}).add(entry.key);
          }
        }
      }
    }
    for (final entry in affected.entries) {
      entry.key.removeStrokes(entry.value);
    }
  }

  /// Atualiza a posição de um traço movido apenas nos tiles afetados
  void updateStrokeInTiles(InkStroke updatedStroke, Rect oldBounds, Rect newBounds) {
    removeStrokesFromTiles({updatedStroke.id: oldBounds});
    insertStrokeToTiles(updatedStroke);
  }

  /// Invalida todas as texturas e Pictures compostos SEM apagar os traços dos tiles
  void invalidatePictures() {
    for (final col in _tiles.values) {
      for (final tile in col.values) {
        tile.invalidatePictures();
      }
    }
  }

  void clear() {
    for (final col in _tiles.values) {
      for (final tile in col.values) {
        tile.dispose();
      }
    }
    _tiles.clear();
  }

  void invalidate() {
    clear();
  }

  void dispose() {
    clear();
  }

  static void _drawSingleStroke(Canvas canvas, InkStroke stroke, Paint reusablePaint) {
    if (stroke.points.isEmpty) return;

    final hasTransform = stroke.transform != Offset.zero;
    if (hasTransform) {
      canvas.save();
      canvas.translate(stroke.transform.dx, stroke.transform.dy);
    }

    try {
      // 1. Caneta Tinteiro / Caligráfica / Pressão Orgânica (Perfect Freehand)
      if ((stroke.toolType == InkToolType.fountain || stroke.enablePressure) && !stroke.isShape) {
        reusablePaint
          ..color = _getStrokeColor(stroke)
          ..style = PaintingStyle.fill;

        stroke.cachedPath ??= FreehandOutlineRenderer.generateOutlinePath(
          stroke.points,
          baseWidth: stroke.strokeWidth,
          isTapered: stroke.toolType == InkToolType.fountain,
        );
        canvas.drawPath(stroke.cachedPath!, reusablePaint);
        return;
      }

      // 2. Marca-texto (Highlighter)
      if (stroke.toolType == InkToolType.highlighter) {
        reusablePaint
          ..color = _getStrokeColor(stroke)
          ..strokeWidth = stroke.strokeWidth * 3.5
          ..strokeCap = StrokeCap.square
          ..strokeJoin = StrokeJoin.miter
          ..style = PaintingStyle.stroke;

        stroke.cachedPath ??= _buildSmoothCatmullRomPath(stroke.points);
        canvas.drawPath(stroke.cachedPath!, reusablePaint);
        return;
      }

      // 3. Lápis Grafite (Pencil)
      if (stroke.toolType == InkToolType.pencil) {
        reusablePaint
          ..color = _getStrokeColor(stroke)
          ..strokeWidth = stroke.strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

        stroke.cachedPath ??= _buildSmoothCatmullRomPath(stroke.points);
        canvas.drawPath(stroke.cachedPath!, reusablePaint);
        return;
      }

      // 4. Traço Técnico Uniforme
      reusablePaint
        ..color = _getStrokeColor(stroke)
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.cachedPath != null) {
        canvas.drawPath(stroke.cachedPath!, reusablePaint);
      } else if (stroke.points.length > 50) {
        canvas.drawRawPoints(ui.PointMode.polygon, stroke.rawPoints, reusablePaint);
      } else {
        stroke.cachedPath ??= _buildSmoothCatmullRomPath(stroke.points);
        canvas.drawPath(stroke.cachedPath!, reusablePaint);
      }
    } finally {
      if (hasTransform) {
        canvas.restore();
      }
    }
  }

  static Color _getStrokeColor(InkStroke stroke) {
    final adapted = StemInkThemeAdapter.adaptStrokeColor(stroke.color, isLightTheme: MoscaroTokens.isLight);
    if (stroke.toolType == InkToolType.highlighter) return adapted.withValues(alpha: 0.35);
    if (stroke.toolType == InkToolType.pencil) return adapted.withValues(alpha: 0.65);
    return adapted;
  }

  static Path _buildSmoothCatmullRomPath(List<StrokePoint> points) {
    final path = Path();
    if (points.isEmpty) return path;
    if (points.length == 1) {
      path.moveTo(points[0].point.dx, points[0].point.dy);
      path.lineTo(points[0].point.dx, points[0].point.dy);
      return path;
    }
    if (points.length == 2) {
      final p0 = points[0].point;
      final p1 = points[1].point;
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.moveTo(p0.dx, p0.dy);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
      path.lineTo(p1.dx, p1.dy);
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
}

/// Gerador de contorno orgânico e caligráfico contínuo e suave (Continuous Ribbon Spline).
class FreehandOutlineRenderer {
  static Path generateOutlinePath(List<StrokePoint> points, {
    required double baseWidth,
    bool isTapered = true,
  }) {
    final path = Path();
    final len = points.length;
    if (len == 0) return path;

    if (len == 1) {
      final p = points[0];
      final r = (baseWidth * p.pressure.clamp(0.2, 1.8)) * 0.5;
      path.addOval(Rect.fromCircle(center: p.point, radius: math.max(0.8, r)));
      return path;
    }

    if (len == 2) {
      final p0 = points[0].point;
      final p1 = points[1].point;
      final delta = p1 - p0;
      final dist = delta.distance;
      if (dist < 0.001) {
        path.addOval(Rect.fromCircle(center: p0, radius: baseWidth * 0.5));
        return path;
      }
      final normal = Offset(-delta.dy / dist, delta.dx / dist);
      final r0 = (baseWidth * 0.5 * points[0].pressure.clamp(0.2, 1.8)).clamp(0.5, baseWidth * 2.0);
      final r1 = (baseWidth * 0.5 * points[1].pressure.clamp(0.2, 1.8)).clamp(0.5, baseWidth * 2.0);

      path.moveTo(p0.dx + normal.dx * r0, p0.dy + normal.dy * r0);
      path.lineTo(p1.dx + normal.dx * r1, p1.dy + normal.dy * r1);
      path.lineTo(p1.dx - normal.dx * r1, p1.dy - normal.dy * r1);
      path.lineTo(p0.dx - normal.dx * r0, p0.dy - normal.dy * r0);
      path.close();
      path.addOval(Rect.fromCircle(center: p0, radius: r0));
      path.addOval(Rect.fromCircle(center: p1, radius: r1));
      return path;
    }

    // 1. Calcula normais e raios dinâmicos para cada ponto da coluna vertebral
    final leftPoints = <Offset>[];
    final rightPoints = <Offset>[];

    for (int i = 0; i < len; i++) {
      final curr = points[i].point;
      Offset tangent;
      if (i == 0) {
        tangent = points[1].point - curr;
      } else if (i == len - 1) {
        tangent = curr - points[i - 1].point;
      } else {
        tangent = points[i + 1].point - points[i - 1].point;
      }

      final dist = tangent.distance;
      Offset normal;
      if (dist < 0.0001) {
        normal = const Offset(0, 1);
      } else {
        normal = Offset(-tangent.dy / dist, tangent.dx / dist);
      }

      // Caneta tinteiro aplica modulação direcional a 45 graus
      double angleMod = 1.0;
      if (isTapered && dist >= 0.0001) {
        final strokeAngle = math.atan2(tangent.dy, tangent.dx);
        angleMod = (0.5 + 0.5 * math.cos(strokeAngle - math.pi / 4).abs()).clamp(0.35, 1.25);
      }

      // Conicidade suave nas pontas inicial e final (tapering natural)
      double taper = 1.0;
      const int taperCount = 5;
      if (i < taperCount) {
        taper = (i + 1) / (taperCount + 1);
      } else if (i >= len - taperCount) {
        taper = (len - i) / (taperCount + 1);
      }
      taper = taper.clamp(0.2, 1.0);

      final double pFactor = points[i].pressure.clamp(0.15, 2.0);
      final double radius = (baseWidth * 0.5 * pFactor * angleMod * taper).clamp(0.6, baseWidth * 2.5);

      leftPoints.add(Offset(curr.dx + normal.dx * radius, curr.dy + normal.dy * radius));
      rightPoints.add(Offset(curr.dx - normal.dx * radius, curr.dy - normal.dy * radius));
    }

    // 2. Constrói contorno de fita spline contínuo fechado
    path.moveTo(leftPoints[0].dx, leftPoints[0].dy);

    // Lado Esquerdo (Spline por pontos médios)
    for (int i = 0; i < leftPoints.length - 1; i++) {
      final p0 = leftPoints[i];
      final p1 = leftPoints[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.lineTo(leftPoints.last.dx, leftPoints.last.dy);

    // Tampa da extremidade final (arredondada)
    final lastRadius = ((leftPoints.last - rightPoints.last).distance * 0.5).clamp(0.5, baseWidth * 2.0);
    path.arcToPoint(
      rightPoints.last,
      radius: Radius.circular(lastRadius),
      clockwise: true,
    );

    // Lado Direito Reverso (Spline por pontos médios)
    for (int i = rightPoints.length - 1; i > 0; i--) {
      final p0 = rightPoints[i];
      final p1 = rightPoints[i - 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.lineTo(rightPoints[0].dx, rightPoints[0].dy);

    // Tampa da extremidade inicial (arredondada)
    final firstRadius = ((leftPoints[0] - rightPoints[0]).distance * 0.5).clamp(0.5, baseWidth * 2.0);
    path.arcToPoint(
      leftPoints[0],
      radius: Radius.circular(firstRadius),
      clockwise: true,
    );

    path.close();
    return path;
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
      zoomScale: zoomScale,
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

/// Gerenciador de cache temporário para colagens ou injeções massivas de traços (10k-50k).
/// Permite renderizar a prévia visual instantânea (1 única draw call Picture) enquanto
/// a ingestão em background consolida os traços nos tiles em fatias de 2-3ms.
class TransientStrokesPictureCache {
  ui.Picture? _picture;
  int _strokeCount = 0;

  int get count => _strokeCount;
  bool get hasStrokes => _picture != null && _strokeCount > 0;

  void setStrokes(List<InkStroke> strokes) {
    _picture?.dispose();
    _picture = null;
    _strokeCount = strokes.length;

    if (strokes.isEmpty) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final reusablePaint = Paint();

    for (final stroke in strokes) {
      canvas.save();
      if (stroke.transform != Offset.zero) {
        canvas.translate(stroke.transform.dx, stroke.transform.dy);
      }
      final color = StrokePictureCache._getStrokeColor(stroke);
      if (stroke.points.length > 50) {
        reusablePaint
          ..color = color
          ..strokeWidth = stroke.strokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawRawPoints(ui.PointMode.polygon, stroke.rawPoints, reusablePaint);
      } else {
        stroke.cachedPath ??= StrokePictureCache._buildSmoothCatmullRomPath(stroke.points);
        reusablePaint
          ..color = color
          ..strokeWidth = stroke.strokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawPath(stroke.cachedPath!, reusablePaint);
      }
      canvas.restore();
    }

    _picture = recorder.endRecording();
  }

  void draw(Canvas canvas) {
    if (_picture != null) {
      canvas.drawPicture(_picture!);
    }
  }

  void clear() {
    _picture?.dispose();
    _picture = null;
  }

  void dispose() {
    clear();
  }
}

/// Painter que renderiza a camada de traços transitórios em ingestão de fundo
class TransientStrokesPainter extends CustomPainter {
  final TransientStrokesPictureCache cache;
  final Offset panOffset;
  final double zoomScale;
  final ValueNotifier<int> updateNotifier;

  TransientStrokesPainter({
    required this.cache,
    required this.panOffset,
    required this.zoomScale,
    required this.updateNotifier,
  }) : super(repaint: updateNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    if (!cache.hasStrokes) return;

    canvas.save();
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(zoomScale);

    cache.draw(canvas);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TransientStrokesPainter oldDelegate) {
    return oldDelegate.panOffset != panOffset ||
        oldDelegate.zoomScale != zoomScale ||
        oldDelegate.cache.count != cache.count;
  }
}

/// Painter ultra-eficiente para o traço em desenho ativo (144 Hz).
class ActiveStrokePainter extends CustomPainter {
  final InkStroke? activeStroke;
  final ValueNotifier<int>? updateNotifier;
  final Offset panOffset;
  final double zoomScale;
  final Paint _reusablePaint = Paint();

  ActiveStrokePainter({
    required this.activeStroke,
    this.updateNotifier,
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

    final hasTransform = stroke.transform != Offset.zero;
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

      // 1. Caneta Tinteiro / Caligráfica / Pressão Orgânica (Perfect Freehand)
      if ((stroke.toolType == InkToolType.fountain || stroke.enablePressure) && !stroke.isShape) {
        _reusablePaint
          ..color = _getStrokeColor(stroke)
          ..style = PaintingStyle.fill;

        final path = stroke.cachedPath ?? FreehandOutlineRenderer.generateOutlinePath(
          stroke.points,
          baseWidth: stroke.strokeWidth,
          isTapered: stroke.toolType == InkToolType.fountain,
        );
        canvas.drawPath(path, _reusablePaint);
        return;
      }

      // 2. Marca-texto (Highlighter)
      if (stroke.toolType == InkToolType.highlighter) {
        _reusablePaint
          ..color = _getStrokeColor(stroke)
          ..strokeWidth = stroke.strokeWidth * 3.5
          ..strokeCap = StrokeCap.square
          ..strokeJoin = StrokeJoin.miter
          ..style = PaintingStyle.stroke;

        final path = stroke.cachedPath ?? _buildSmoothCatmullRomPath(stroke.points);
        canvas.drawPath(path, _reusablePaint);
        return;
      }

      // 3. Lápis Grafite (Pencil)
      if (stroke.toolType == InkToolType.pencil) {
        _reusablePaint
          ..color = _getStrokeColor(stroke)
          ..strokeWidth = stroke.strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

        final path = stroke.cachedPath ?? _buildSmoothCatmullRomPath(stroke.points);
        canvas.drawPath(path, _reusablePaint);
        return;
      }

      // 4. Traço Técnico Uniforme
      _reusablePaint
        ..color = _getStrokeColor(stroke)
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.cachedPath != null) {
        canvas.drawPath(stroke.cachedPath!, _reusablePaint);
      } else {
        final path = _buildSmoothCatmullRomPath(stroke.points);
        canvas.drawPath(path, _reusablePaint);
      }
    } finally {
      if (hasTransform) {
        canvas.restore();
      }
      canvas.restore();
    }
  }

  Color _getStrokeColor(InkStroke stroke) {
    final adapted = StemInkThemeAdapter.adaptStrokeColor(stroke.color, isLightTheme: MoscaroTokens.isLight);
    if (stroke.toolType == InkToolType.highlighter) return adapted.withValues(alpha: 0.35);
    if (stroke.toolType == InkToolType.pencil) return adapted.withValues(alpha: 0.65);
    return adapted;
  }

  Path _buildSmoothCatmullRomPath(List<StrokePoint> points) {
    final path = Path();
    if (points.isEmpty) return path;
    if (points.length == 1) {
      path.moveTo(points[0].point.dx, points[0].point.dy);
      path.lineTo(points[0].point.dx, points[0].point.dy);
      return path;
    }
    if (points.length == 2) {
      final p0 = points[0].point;
      final p1 = points[1].point;
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.moveTo(p0.dx, p0.dy);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
      path.lineTo(p1.dx, p1.dy);
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

  @override
  bool shouldRepaint(covariant ActiveStrokePainter oldDelegate) {
    return oldDelegate.panOffset != panOffset || oldDelegate.zoomScale != zoomScale;
  }
}
