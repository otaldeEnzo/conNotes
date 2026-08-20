import 'dart:ui';
import 'package:flutter/material.dart';
import 'ink_models.dart';
import 'spatial_index.dart';
import 'selection_models.dart';
import 'canvas_layers.dart';
import '../models/canvas_card_model.dart';

/// Tipos de Documento Suportados no Ecossistema conNotes
enum NoteType {
  canvas,
  text,
  pdf,
  code,
  simulation;

  String get extension => switch (this) {
    NoteType.canvas => '.cncanvas',
    NoteType.text => '.cntext',
    NoteType.pdf => '.cnpdf',
    NoteType.code => '.cncode',
    NoteType.simulation => '.cnsim',
  };

  static NoteType fromExtensionOrName(String val) {
    if (val.endsWith('.cncanvas') || val == 'canvas') return NoteType.canvas;
    if (val.endsWith('.cntext') || val == 'text') return NoteType.text;
    if (val.endsWith('.cnpdf') || val == 'pdf') return NoteType.pdf;
    if (val.endsWith('.cncode') || val == 'code') return NoteType.code;
    if (val.endsWith('.cnsim') || val == 'simulation') return NoteType.simulation;
    return NoteType.canvas;
  }
}

/// Modelo para Cadernos e Pastas de Disciplinas no Workspace
class NotebookFolder {
  final String id;
  String name;
  String folderPath;
  Color color;
  String iconKey;
  bool isPinned;
  final List<NoteDocument> notes;
  final List<NotebookFolder> subFolders;

  NotebookFolder({
    required this.id,
    required this.name,
    required this.folderPath,
    this.color = const Color(0xFF00E1FF),
    this.iconKey = 'book',
    this.isPinned = false,
    List<NoteDocument>? notes,
    List<NotebookFolder>? subFolders,
  })  : notes = notes ?? [],
        subFolders = subFolders ?? [];
}

/// Modelo que representa uma Nota e seus dados associados
class NoteDocument {
  final String id;
  String title;
  NoteType noteType;
  String? filePath;
  bool isFavorite;
  List<String> tags;
  String? themeId;
  DateTime createdAt;
  DateTime updatedAt;

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
  double zoomScale;
  String? nativeDocId;
  final List<CanvasCardModel> cards;

  NoteDocument({
    required this.id,
    required this.title,
    this.noteType = NoteType.canvas,
    this.filePath,
    this.isFavorite = false,
    List<String>? tags,
    this.themeId,
    List<NoteDocument>? children,
    List<InkStroke>? strokes,
    List<CanvasCardModel>? cards,
    this.panX = 0.0,
    this.panY = 0.0,
    this.zoomScale = 1.0,
    this.nativeDocId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : tags = tags ?? [],
        children = children ?? [],
        _strokesList = strokes ?? [],
        cards = cards ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now() {
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

  void removeStrokes(List<InkStroke> strokes) {
    removeAllStrokes(strokes.map((s) => s.id));
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

  /// Converte o documento para a estrutura JSON padronizada do formato .cncanvas
  Map<String, dynamic> toCnCanvasMap() {
    return {
      'connotesHeader': {
        'docType': noteType.name,
        'schemaVersion': 1,
        'generator': 'conNotes Desktop v1.0',
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      'metadata': {
        'noteId': id,
        'title': title,
        'tags': tags,
        'isFavorite': isFavorite,
        'themeId': themeId,
      },
      'canvasData': {
        'panX': panX,
        'panY': panY,
        'zoomScale': zoomScale,
        'strokes': _strokesList.map((s) => s.toJson()).toList(),
        'cards': cards.map((c) => c.toMap()).toList(),
      },
      'childrenSubnotes': children.map((c) => c.toCnCanvasMap()).toList(),
    };
  }

  /// Reconstrói o NoteDocument a partir do mapa JSON do .cncanvas
  factory NoteDocument.fromCnCanvasMap(Map<String, dynamic> map, {String? filePath}) {
    final header = map['connotesHeader'] as Map<String, dynamic>? ?? {};
    final docTypeStr = header['docType'] as String? ?? 'canvas';
    final noteType = NoteType.fromExtensionOrName(docTypeStr);

    final metadata = map['metadata'] as Map<String, dynamic>? ?? {};
    final canvasData = map['canvasData'] as Map<String, dynamic>? ?? {};

    final id = metadata['noteId'] as String? ?? (map['id'] as String? ?? 'note_${DateTime.now().millisecondsSinceEpoch}');
    final title = metadata['title'] as String? ?? (map['title'] as String? ?? 'Sem Título');
    final tags = (metadata['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ?? [];
    final isFavorite = metadata['isFavorite'] as bool? ?? false;
    final themeId = metadata['themeId'] as String?;

    final panX = (canvasData['panX'] as num?)?.toDouble() ?? (map['panX'] as num?)?.toDouble() ?? 0.0;
    final panY = (canvasData['panY'] as num?)?.toDouble() ?? (map['panY'] as num?)?.toDouble() ?? 0.0;
    final zoomScale = (canvasData['zoomScale'] as num?)?.toDouble() ?? 1.0;

    final rawStrokes = (canvasData['strokes'] as List<dynamic>?) ?? (map['strokes'] as List<dynamic>?) ?? [];
    final List<InkStroke> strokes = rawStrokes
        .map((s) => InkStroke.fromJson(s as Map<String, dynamic>))
        .toList();

    final rawCards = (canvasData['cards'] as List<dynamic>?) ?? (map['cards'] as List<dynamic>?) ?? [];
    final List<CanvasCardModel> parsedCards = rawCards
        .map((c) => CanvasCardModel.fromMap(c as Map<String, dynamic>))
        .toList();

    final rawChildren = (map['childrenSubnotes'] as List<dynamic>?) ?? (map['children'] as List<dynamic>?) ?? [];
    final List<NoteDocument> children = rawChildren
        .map((c) => NoteDocument.fromCnCanvasMap(c as Map<String, dynamic>))
        .toList();

    DateTime parseDate(dynamic val) {
      if (val is String) {
        try {
          return DateTime.parse(val);
        } catch (_) {}
      }
      return DateTime.now();
    }

    return NoteDocument(
      id: id,
      title: title,
      noteType: noteType,
      filePath: filePath ?? (map['filePath'] as String?),
      isFavorite: isFavorite,
      tags: tags,
      themeId: themeId,
      panX: panX,
      panY: panY,
      zoomScale: zoomScale,
      strokes: strokes,
      cards: parsedCards,
      children: children,
      createdAt: parseDate(header['createdAt']),
      updatedAt: parseDate(header['updatedAt']),
    );
  }
}
