import 'dart:ui';
import 'ink_models.dart';
import 'spatial_index.dart';
import 'selection_models.dart';
import 'canvas_layers.dart';

/// Modelo que representa uma Nota e seus dados associados
class NoteDocument {
  final String id;
  String title;
  final List<NoteDocument> children; // Subnotas hierárquicas
  
  // Lista ordenada para renderização (z-index)
  final List<InkStroke> _strokesList;
  final Map<String, int> _strokeIndex = {};
  
  // Mapa de busca O(1) e SpatialIndex para buscas espaciais
  final Map<String, InkStroke> _strokeMap = {};
  final SpatialIndex spatialIndex = SpatialIndex(cellSize: 512.0);

  // Cache Skia Picture para 144Hz instantâneo durante Pan / Zoom / Hover
  final StrokePictureCache pictureCache = StrokePictureCache();

  double panX;
  double panY;
  String? nativeDocId;

  NoteDocument({
    required this.id,
    required this.title,
    List<NoteDocument>? children,
    List<InkStroke>? strokes,
    this.panX = 0.0,
    this.panY = 0.0,
    this.nativeDocId,
  })  : children = children ?? [],
        _strokesList = strokes ?? [] {
    // Inicializar mapa e índice se houver traços prévios
    for (final stroke in _strokesList) {
      _strokeMap[stroke.id] = stroke;
      _strokeIndex[stroke.id] = _strokeIndex.length;
      pictureCache.insertStrokeToTiles(stroke);
    }
    spatialIndex.bulkLoad(_strokesList);
  }

  /// Retorna a lista de traços (acesso direto sem wrapper para zero-allocation)
  List<InkStroke> get strokes => _strokesList;

  /// Contadores cacheados para telemetria sem iteração
  int _cachedPointCount = 0;
  int get strokeCount => _strokesList.length;
  int get pointCount => _cachedPointCount;
  
  InkStroke? getStroke(String id) => _strokeMap[id];

  void addStroke(InkStroke stroke) {
    // Pre-compute e cachear bounding box se ainda não existir
    stroke.boundingBox ??= SelectionGeometry.computeStrokeBounds(stroke);
    
    _strokesList.add(stroke);
    _strokeMap[stroke.id] = stroke;
    _strokeIndex[stroke.id] = _strokesList.length - 1;
    _cachedPointCount += stroke.points.length;
    spatialIndex.insert(stroke.id, stroke.boundingBox!);
    pictureCache.insertStrokeToTiles(stroke);
  }

  /// Adiciona múltiplos traços em lote sem destruir o cache dos tiles existentes
  void addAllStrokes(List<InkStroke> newStrokes) {
    if (newStrokes.isEmpty) return;
    for (var i = 0; i < newStrokes.length; i++) {
      final s = newStrokes[i];
      _strokesList.add(s);
      s.boundingBox ??= SelectionGeometry.computeStrokeBounds(s);
      _strokeMap[s.id] = s;
      _strokeIndex[s.id] = _strokesList.length - 1;
      _cachedPointCount += s.points.length;
      spatialIndex.insert(s.id, s.boundingBox!);
      pictureCache.insertStrokeToTiles(s);
    }
  }

  void removeStroke(String id) {
    removeAllStrokes([id]);
  }

  /// Remove múltiplos traços em lote cirúrgico
  void removeAllStrokes(Iterable<String> ids) {
    final idSet = ids.toSet();
    if (idSet.isEmpty) return;
    final removedBounds = <String, Rect>{};

    for (final id in idSet) {
      final stroke = _strokeMap.remove(id);
      if (stroke != null) {
        _cachedPointCount -= stroke.points.length;
        final bounds = stroke.boundingBox ?? SelectionGeometry.computeStrokeBounds(stroke);
        spatialIndex.remove(id, bounds);
        removedBounds[id] = bounds;
      }
    }

    if (removedBounds.isEmpty) return;

    _strokesList.removeWhere((s) => idSet.contains(s.id));
    _rebuildStrokeIndices();
    pictureCache.removeStrokesFromTiles(removedBounds);
  }

  void updateStroke(InkStroke updatedStroke) {
    updateAllStrokes([updatedStroke]);
  }

  /// Atualiza múltiplos traços em lote unificado O(1) de tiles
  void updateAllStrokes(List<InkStroke> updatedStrokes) {
    if (updatedStrokes.isEmpty) return;
    final oldBoundsMap = <String, Rect>{};
    final validUpdates = <InkStroke>[];

    for (var i = 0; i < updatedStrokes.length; i++) {
      final updated = updatedStrokes[i];
      final old = _strokeMap[updated.id];
      if (old != null) {
        final index = _strokeIndex[updated.id];
        if (index != null) {
          _strokesList[index] = updated;
        }
        _strokeMap[updated.id] = updated;

        final oldBounds = old.boundingBox ?? SelectionGeometry.computeStrokeBounds(old);
        final newBounds = updated.boundingBox ?? SelectionGeometry.computeStrokeBounds(updated);
        spatialIndex.update(updated.id, oldBounds, newBounds);

        oldBoundsMap[updated.id] = oldBounds;
        validUpdates.add(updated);
      }
    }

    if (validUpdates.isEmpty) return;

    pictureCache.removeStrokesFromTiles(oldBoundsMap);
    for (var i = 0; i < validUpdates.length; i++) {
      pictureCache.insertStrokeToTiles(validUpdates[i]);
    }
  }

  /// Mantido para retrocompatibilidade
  void updateStrokes(Iterable<InkStroke> updatedStrokes) {
    updateAllStrokes(updatedStrokes.toList());
  }

  void _rebuildStrokeIndices() {
    _strokeIndex
      ..clear()
      ..addEntries(_strokesList.asMap().entries.map(
        (entry) => MapEntry(entry.value.id, entry.key),
      ));
  }

  /// Limpa todos os traços do documento.
  void clearStrokes() {
    _strokesList.clear();
    _strokeMap.clear();
    _strokeIndex.clear();
    _cachedPointCount = 0;
    spatialIndex.clear();
    pictureCache.invalidate();
  }
}
