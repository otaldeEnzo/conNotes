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
    _cachedPointCount += stroke.points.length;
    spatialIndex.insert(stroke.id, stroke.boundingBox!);
    pictureCache.insertStrokeToTiles(stroke);
  }

  /// Adiciona múltiplos traços em lote sem destruir o cache dos tiles existentes
  void addAllStrokes(List<InkStroke> newStrokes) {
    if (newStrokes.isEmpty) return;
    _strokesList.addAll(newStrokes);
    for (var i = 0; i < newStrokes.length; i++) {
      final s = newStrokes[i];
      s.boundingBox ??= SelectionGeometry.computeStrokeBounds(s);
      _strokeMap[s.id] = s;
      _cachedPointCount += s.points.length;
      spatialIndex.insert(s.id, s.boundingBox!);
      pictureCache.insertStrokeToTiles(s);
    }
  }

  void removeStroke(String id) {
    final stroke = _strokeMap.remove(id);
    if (stroke != null) {
      _strokesList.removeWhere((s) => s.id == id);
      _cachedPointCount -= stroke.points.length;
      final bounds = stroke.boundingBox ?? SelectionGeometry.computeStrokeBounds(stroke);
      spatialIndex.remove(id, bounds);
      // Invalidação cirúrgica: remove apenas dos tiles afetados (O(1))
      pictureCache.removeStrokeFromTiles(id, bounds);
    }
  }

  /// Remove múltiplos traços em lote
  void removeAllStrokes(Iterable<String> ids) {
    final idSet = ids.toSet();
    if (idSet.isEmpty) return;
    _strokesList.removeWhere((s) {
      if (idSet.contains(s.id)) {
        final stroke = _strokeMap.remove(s.id);
        if (stroke != null) {
          final bounds = stroke.boundingBox ?? SelectionGeometry.computeStrokeBounds(stroke);
          spatialIndex.remove(s.id, bounds);
          pictureCache.removeStrokeFromTiles(s.id, bounds);
        }
        return true;
      }
      return false;
    });
  }

  void updateStroke(InkStroke updatedStroke) {
    final oldStroke = _strokeMap[updatedStroke.id];
    if (oldStroke != null) {
      // Atualizar lista mantendo a ordem
      final index = _strokesList.indexWhere((s) => s.id == updatedStroke.id);
      if (index != -1) {
        _strokesList[index] = updatedStroke;
      }
      
      _strokeMap[updatedStroke.id] = updatedStroke;
      
      final oldBounds = oldStroke.boundingBox ?? SelectionGeometry.computeStrokeBounds(oldStroke);
      final newBounds = updatedStroke.boundingBox ?? SelectionGeometry.computeStrokeBounds(updatedStroke);
      spatialIndex.update(updatedStroke.id, oldBounds, newBounds);
      // Invalidação cirúrgica: atualiza apenas os tiles envolvidos no deslocamento
      pictureCache.updateStrokeInTiles(updatedStroke, oldBounds, newBounds);
    }
  }

  /// Limpa todos os traços do documento.
  void clearStrokes() {
    _strokesList.clear();
    _strokeMap.clear();
    _cachedPointCount = 0;
    spatialIndex.clear();
    pictureCache.invalidate();
  }
}

