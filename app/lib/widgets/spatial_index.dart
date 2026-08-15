import 'dart:ui';
import 'ink_models.dart';
import 'selection_models.dart';

/// Índice Espacial usando Spatial Hash Grid.
/// Oferece complexidade O(1) média para inserção e busca, dividindo o plano infinito
/// em células quadradas de tamanho [cellSize].
class SpatialIndex {
  final double cellSize;
  
  // Mapeia coordenadas de células (x, y) para conjuntos de IDs de traços
  final Map<int, Map<int, Set<String>>> _grid = {};

  SpatialIndex({this.cellSize = 512.0});

  /// Insere um traço no índice com base em sua bounding box.
  void insert(String strokeId, Rect bounds) {
    final startX = (bounds.left / cellSize).floor();
    final startY = (bounds.top / cellSize).floor();
    final endX = (bounds.right / cellSize).floor();
    final endY = (bounds.bottom / cellSize).floor();

    for (int x = startX; x <= endX; x++) {
      for (int y = startY; y <= endY; y++) {
        _grid.putIfAbsent(x, () => {}).putIfAbsent(y, () => {}).add(strokeId);
      }
    }
  }

  /// Remove um traço do índice usando sua antiga bounding box para localizar as células.
  void remove(String strokeId, Rect bounds) {
    final startX = (bounds.left / cellSize).floor();
    final startY = (bounds.top / cellSize).floor();
    final endX = (bounds.right / cellSize).floor();
    final endY = (bounds.bottom / cellSize).floor();

    for (int x = startX; x <= endX; x++) {
      for (int y = startY; y <= endY; y++) {
        _grid[x]?[y]?.remove(strokeId);
      }
    }
  }

  /// Remove e insere o traço com novas bordas (ex: durante movimento).
  void update(String strokeId, Rect oldBounds, Rect newBounds) {
    remove(strokeId, oldBounds);
    insert(strokeId, newBounds);
  }

  /// Retorna os IDs dos traços cujas bounding boxes podem sobrepor o viewport.
  Set<String> queryRect(Rect viewport) {
    final result = <String>{};
    
    final startX = (viewport.left / cellSize).floor();
    final startY = (viewport.top / cellSize).floor();
    final endX = (viewport.right / cellSize).floor();
    final endY = (viewport.bottom / cellSize).floor();

    for (int x = startX; x <= endX; x++) {
      for (int y = startY; y <= endY; y++) {
        final cell = _grid[x]?[y];
        if (cell != null) {
          result.addAll(cell);
        }
      }
    }
    return result;
  }

  /// Retorna os IDs dos traços num raio em volta de um ponto (ex: Eraser).
  Set<String> queryPoint(Offset point, double radius) {
    final rect = Rect.fromCircle(center: point, radius: radius);
    return queryRect(rect);
  }

  /// Carrega os traços em lote (útil na inicialização de notas grandes).
  void bulkLoad(Iterable<InkStroke> strokes) {
    _grid.clear();
    for (final stroke in strokes) {
      final bounds = stroke.boundingBox ?? SelectionGeometry.computeStrokeBounds(stroke);
      insert(stroke.id, bounds);
    }
  }

  /// Limpa o índice.
  void clear() {
    _grid.clear();
  }
}
