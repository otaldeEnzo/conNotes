import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'theme/moscaro_v2_tokens.dart';
import 'theme/moscaro_v2_extension.dart';
import 'widgets/canvas_dot_grid_painter.dart';
import 'widgets/toolbar_pill.dart';
import 'widgets/pen_slots_sub_bar.dart';
import 'widgets/ai_sidebar.dart';
import 'widgets/note_tab_bar.dart';
import 'widgets/note_sidebar.dart';
import 'widgets/note_models.dart';
import 'widgets/ink_models.dart';
import 'widgets/canvas_layers.dart';
import 'widgets/zoom_hud_pill.dart';
import 'widgets/selection_models.dart';
import 'widgets/selection_overlay_painter.dart';
import 'widgets/selection_action_bar.dart';
import 'widgets/selection_sub_bar.dart';
import 'widgets/spatial_index.dart';
import 'widgets/undo_commands.dart';
import 'ffi/native_bridge.dart';
import 'dev_hub/dev_hub_server.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final isRustReady = ConnotesNativeBridge.instance.isAvailable;
  debugPrint('[ConNotes] Motor Rust Core inicializado: $isRustReady');
  runApp(const ConNotesApp());
}

class ConNotesApp extends StatelessWidget {
  const ConNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'conNotes STEM Canvas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: MoscaroTokens.backgroundDeep,
      ),
      home: const CanvasHomeScreen(),
    );
  }
}

class CanvasHomeScreen extends StatefulWidget {
  const CanvasHomeScreen({super.key});

  @override
  State<CanvasHomeScreen> createState() => _CanvasHomeScreenState();
}

class _CanvasHomeScreenState extends State<CanvasHomeScreen> {
  // Estado de Documentos e Notas
  final List<NoteDocument> _notes = [];
  final List<NoteDocument> _trashNotes = [];
  final List<String> _activeNoteIds = [];
  String? _selectedNoteId;
  bool _isSidebarOpen = false;

  // Estado de Navegação do Canvas Desacoplado (144Hz Zero-Rebuild)
  final ValueNotifier<Offset> _panNotifier = ValueNotifier(Offset.zero);
  final ValueNotifier<double> _zoomNotifier = ValueNotifier(1.0);
  final ValueNotifier<Offset?> _mousePosNotifier = ValueNotifier(null);
  CanvasBackgroundType _currentBackground = CanvasBackgroundType.dotGrid;

  Offset get _panOffset => _panNotifier.value;
  double get _zoomScale => _zoomNotifier.value;

  // Estado de Ferramentas & Sub-Barra de Canetas Vivas
  String _activeTool = 'pen';
  bool _isPenSubBarVisible = true;

  final List<PenSlotPreset> _penSlots = [
    const PenSlotPreset(id: '1', name: 'Ciano', color: Color(0xFF00E1FF), strokeWidth: 3.0, toolType: InkToolType.technical, enablePressure: false),
    const PenSlotPreset(id: '2', name: 'Rosa', color: Color(0xFFFF007A), strokeWidth: 4.0, toolType: InkToolType.fountain, enablePressure: false),
    const PenSlotPreset(id: '3', name: 'Roxo', color: Color(0xFFA855F7), strokeWidth: 2.5, toolType: InkToolType.pencil, enablePressure: false),
    const PenSlotPreset(id: '4', name: 'Marca-Texto', color: Color(0xFFF59E0B), strokeWidth: 6.0, toolType: InkToolType.highlighter, enablePressure: false),
    const PenSlotPreset(id: '5', name: 'Branco', color: Colors.white, strokeWidth: 3.0, toolType: InkToolType.technical, enablePressure: true),
  ];
  late String _activeSlotId;

  // Histórico Universal de Desfazer/Refazer (Command Pattern)
  final AppUndoManager _undoManager = AppUndoManager();
  int _strokesVersion = 0;

  bool _isAIOpen = false;

  // Desenhos / Escrita Manual do traço ativo
  InkStroke? _activeStroke;
  final ValueNotifier<int> _activeStrokeUpdateNotifier = ValueNotifier(0);
  bool _isDrawing = false;

  // Estado da Ferramenta de Seleção (Área Retangular, Laço e Tap-to-Select)
  SelectionType _selectionType = SelectionType.rectangle;
  SelectionState _selectionState = SelectionState.empty();
  final ValueNotifier<int> _selectionUpdateNotifier = ValueNotifier(0);
  final ValueNotifier<int> _committedStrokesNotifier = ValueNotifier(0);
  Offset? _selectionStartCanvasPoint;
  final SelectedStrokesPictureCache _dragPictureCache = SelectedStrokesPictureCache();
  final TransientStrokesPictureCache _transientPictureCache = TransientStrokesPictureCache();
  final ValueNotifier<int> _transientUpdateNotifier = ValueNotifier(0);

  // Interação (Renderização Híbrida)
  final ValueNotifier<bool> _isInteractingNotifier = ValueNotifier(false);
  Timer? _interactionTimer;

  void _setInteracting() {
    _isInteractingNotifier.value = true;
    _interactionTimer?.cancel();
    _interactionTimer = Timer(const Duration(milliseconds: 150), () {
      _isInteractingNotifier.value = false;
    });
  }

  List<InkStroke> _clipboardStrokes = [];
  int _globalCounter = 0;
  Timer? _telemetrySyncTimer;
  final Map<String, InkStroke> _pendingErasures = {};
  bool _eraseCommitScheduled = false;

  @override
  void initState() {
    super.initState();
    _activeSlotId = _penSlots.first.id;
    _addNewNote("Anotações STEM");
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    // Configurar e Iniciar Servidor do Dev Hub em processo/janela separada
    DevHubServer.instance.onInjectStrokes = (count) {
      _injectStressTestStrokes(count);
    };
    DevHubServer.instance.onForceGc = () {
      final note = _currentNote;
      note?.pictureCache.clear();
      setState(() {
        _strokesVersion++;
        _committedStrokesNotifier.value++;
      });
    };
    DevHubServer.instance.start();

    // Sincronizar métricas do conNotes com o Dev Hub (10x por segundo)
    _telemetrySyncTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final note = _currentNote;
      if (note != null) {
        // Usar contadores cacheados (zero-iteration, O(1))
        DevHubServer.instance.strokeCount = note.strokeCount;
        DevHubServer.instance.pointCount = note.pointCount;
        DevHubServer.instance.activeTilesCount = note.pictureCache.totalTilesCount;
        DevHubServer.instance.gpuTexturesCount = note.pictureCache.gpuTexturesCount;
      }
    });
  }

  /// Injeção em lotes assíncronos adaptativos: distribui o trabalho pesado em fatias
  /// de tempo (2.5 ms por frame) para manter a UI responsiva a 144 FPS.
  bool _isInjecting = false;
  void _injectStressTestStrokes(int count) {
    final note = _currentNote;
    if (note == null || _isInjecting) return;

    _isInjecting = true;
    final random = math.Random();
    final center = -_panOffset / _zoomScale + const Offset(500, 300);
    int injected = 0;

    void injectSlice() {
      if (!mounted || injected >= count) {
        _isInjecting = false;
        return;
      }

      final newStrokes = <InkStroke>[];
      final stopwatch = Stopwatch()..start();

      while (injected + newStrokes.length < count && stopwatch.elapsedMicroseconds < 2500) {
        final startX = center.dx + (random.nextDouble() - 0.5) * 6000;
        final startY = center.dy + (random.nextDouble() - 0.5) * 5000;
        final pts = <StrokePoint>[];

        double minX = double.infinity, minY = double.infinity;
        double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

        for (int j = 0; j < 15; j++) {
          final dx = startX + j * 4 + random.nextDouble() * 2;
          final dy = startY + math.sin(j * 0.5) * 20;
          pts.add(StrokePoint(point: Offset(dx, dy), pressure: 0.5));
          if (dx < minX) minX = dx;
          if (dy < minY) minY = dy;
          if (dx > maxX) maxX = dx;
          if (dy > maxY) maxY = dy;
        }

        final pad = 2.5 * 1.5;
        newStrokes.add(InkStroke(
          id: 'stress_${_globalCounter++}',
          points: pts,
          color: const Color(0xFF00E1FF),
          strokeWidth: 2.5,
          toolType: InkToolType.technical,
          enablePressure: false,
          boundingBox: Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad),
        ));
      }

      if (newStrokes.isNotEmpty) {
        note.addAllStrokes(newStrokes);
        injected += newStrokes.length;
        _strokesVersion++;
        _committedStrokesNotifier.value++;
      }

      SchedulerBinding.instance.addPostFrameCallback((_) {
        injectSlice();
      });
    }

    injectSlice();
  }

  /// Ingestão adaptativa fatiada no tempo (2.5ms por frame) com prévia Picture instantânea
  void _ingestStrokesAdaptively(NoteDocument note, List<InkStroke> newStrokes) {
    if (newStrokes.length <= 200) {
      note.addAllStrokes(newStrokes);
      _strokesVersion++;
      _committedStrokesNotifier.value++;
      return;
    }

    // Para lotes grandes (> 200 traços):
    // 1. Renderização visual instantânea via camada transitória Picture O(1)
    _transientPictureCache.setStrokes(newStrokes);
    _transientUpdateNotifier.value++;

    // 2. Ingestão adaptativa em background (fatias de 2.5ms por frame)
    int cursor = 0;
    void processSlice() {
      if (!mounted) {
        _transientPictureCache.clear();
        return;
      }

      final sw = Stopwatch()..start();
      final slice = <InkStroke>[];
      while (cursor < newStrokes.length && sw.elapsedMicroseconds < 2500) {
        slice.add(newStrokes[cursor++]);
      }

      if (slice.isNotEmpty) {
        note.addAllStrokes(slice);
        _strokesVersion++;
        _committedStrokesNotifier.value++;
      }

      if (cursor < newStrokes.length) {
        SchedulerBinding.instance.addPostFrameCallback((_) => processSlice());
      } else {
        // Ingestão completa: limpa a camada transitória pois todos os traços já residem nos tiles
        _transientPictureCache.clear();
        _transientUpdateNotifier.value++;
        _committedStrokesNotifier.value++;
      }
    }

    SchedulerBinding.instance.addPostFrameCallback((_) => processSlice());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _telemetrySyncTimer?.cancel();
    _interactionTimer?.cancel();
    _dragPictureCache.dispose();
    _transientPictureCache.dispose();
    _pendingErasures.clear();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // F12 -> Abrir Dev Hub em janela separada
      if (event.logicalKey == LogicalKeyboardKey.f12) {
        DevHubServer.instance.openInBrowser();
        return true;
      }

      final isCtrl = HardwareKeyboard.instance.isControlPressed;
      if (isCtrl) {
        if (event.logicalKey == LogicalKeyboardKey.keyC) {
          _copySelectedStrokes();
          return true;
        } else if (event.logicalKey == LogicalKeyboardKey.keyV) {
          _pasteStrokes();
          return true;
        } else if (event.logicalKey == LogicalKeyboardKey.keyD) {
          _duplicateSelectedStrokes();
          return true;
        }
      }
    }
    return false;
  }

  PenSlotPreset get _activePenPreset {
    return _penSlots.firstWhere((s) => s.id == _activeSlotId, orElse: () => _penSlots.first);
  }

  void _addNewNote(String title) {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final nativeDocId = ConnotesNativeBridge.instance.createDocument() ?? newId;
    final newNote = NoteDocument(
      id: newId,
      title: title,
      nativeDocId: nativeDocId,
    );
    setState(() {
      _notes.add(newNote);
      _activeNoteIds.add(newId);
      _selectedNoteId = newId;
    });
  }

  NoteDocument? get _currentNote {
    if (_selectedNoteId == null) return null;
    return _findNoteById(_notes, _selectedNoteId!);
  }

  NoteDocument? _findNoteById(List<NoteDocument> list, String id) {
    for (final note in list) {
      if (note.id == id) return note;
      final found = _findNoteById(note.children, id);
      if (found != null) return found;
    }
    return null;
  }

  void _undo() {
    final note = _currentNote;
    if (note == null) return;
    
    DevHubServer.instance.logAction('Desfazer (Undo)');

    setState(() {
      _undoManager.undo(note);
      _strokesVersion++;
      _committedStrokesNotifier.value++;
      _selectionState = SelectionState.empty();
    });
  }

  void _redo() {
    final note = _currentNote;
    if (note == null) return;

    DevHubServer.instance.logAction('Refazer (Redo)');

    setState(() {
      _undoManager.redo(note);
      _strokesVersion++;
      _committedStrokesNotifier.value++;
      _selectionState = SelectionState.empty();
    });
  }

  void _copySelectedStrokes() {
    final note = _currentNote;
    if (note == null || !_selectionState.hasSelection) return;

    final selectedStrokes = _selectionState.selectedStrokeIds
        .map((id) => note.getStroke(id))
        .whereType<InkStroke>()
        .toList();
    if (selectedStrokes.isEmpty) return;

    // Cópia Flyweight: armazena referências aos traços sem realocar buffers de pontos
    _clipboardStrokes = List<InkStroke>.from(selectedStrokes);
    DevHubServer.instance.logAction('Copiar (${_clipboardStrokes.length} traços)');
  }

  void _pasteStrokes() {
    final note = _currentNote;
    if (note == null || _clipboardStrokes.isEmpty) return;

    final bounds = SelectionGeometry.computeCombinedBounds(_clipboardStrokes);
    if (bounds == null) return;

    final mousePos = _mousePosNotifier.value ?? const Offset(400, 300);
    final canvasMousePos = (mousePos - _panOffset) / _zoomScale;
    final offsetToMouse = canvasMousePos - bounds.center;

    DevHubServer.instance.logAction('Colar (${_clipboardStrokes.length} traços)');

    final nowMicro = DateTime.now().microsecondsSinceEpoch;
    final allNewStrokes = <InkStroke>[];
    final allNewSelectedIds = <String>{};

    for (var i = 0; i < _clipboardStrokes.length; i++) {
      final s = _clipboardStrokes[i];
      final newId = '${nowMicro}_${_globalCounter++}_${s.id}';

      final clone = InkStroke(
        id: newId,
        points: s.points, // Flyweight
        transform: s.transform + offsetToMouse, // Deslocamento visual O(1)
        color: s.color,
        strokeWidth: s.strokeWidth,
        toolType: s.toolType,
        enablePressure: s.enablePressure,
        boundingBox: s.boundingBox?.shift(offsetToMouse),
        cachedPath: s.cachedPath, // Raster Skia compartilhado
        cachedRawPoints: s.cachedRawPoints,
      );

      allNewStrokes.add(clone);
      allNewSelectedIds.add(newId);
    }

    _ingestStrokesAdaptively(note, allNewStrokes);
    _undoManager.pushCommand(DuplicateStrokesCommand(allNewStrokes), execute: false, note: note);

    setState(() {
      _strokesVersion++;
      _committedStrokesNotifier.value++;
      _activeTool = 'select';
      _isPenSubBarVisible = false;
      _selectionState = SelectionState(
        type: _selectionType,
        selectedStrokeIds: allNewSelectedIds,
        bounds: bounds.shift(offsetToMouse),
        dragOffset: Offset.zero,
      );
      _selectionUpdateNotifier.value++;
    });
  }

  void _duplicateSelectedStrokes() {
    final note = _currentNote;
    if (note == null || !_selectionState.hasSelection) return;

    final selectedStrokes = _selectionState.selectedStrokeIds
        .map((id) => note.getStroke(id))
        .whereType<InkStroke>()
        .toList();
    if (selectedStrokes.isEmpty) return;

    DevHubServer.instance.logAction('Duplicar (${selectedStrokes.length} traços)');

    const offset = Offset(20, 20);
    final nowMicro = DateTime.now().microsecondsSinceEpoch;
    final allNewStrokes = <InkStroke>[];
    final allNewSelectedIds = <String>{};

    for (var i = 0; i < selectedStrokes.length; i++) {
      final s = selectedStrokes[i];
      final newId = '${nowMicro}_${_globalCounter++}_${s.id}';

      final clone = InkStroke(
        id: newId,
        points: s.points, // Flyweight
        transform: s.transform + offset, // Deslocamento visual O(1)
        color: s.color,
        strokeWidth: s.strokeWidth,
        toolType: s.toolType,
        enablePressure: s.enablePressure,
        boundingBox: s.boundingBox?.shift(offset),
        cachedPath: s.cachedPath,
        cachedRawPoints: s.cachedRawPoints,
      );

      allNewStrokes.add(clone);
      allNewSelectedIds.add(newId);
    }

    _ingestStrokesAdaptively(note, allNewStrokes);
    _undoManager.pushCommand(DuplicateStrokesCommand(allNewStrokes), execute: false, note: note);

    setState(() {
      _strokesVersion++;
      _committedStrokesNotifier.value++;
      _selectionState = _selectionState.copyWith(
        selectedStrokeIds: allNewSelectedIds,
        bounds: _selectionState.bounds?.shift(offset),
      );
      _selectionUpdateNotifier.value++;
    });
  }

  void _changeSelectedStrokesColor(Color newColor) {
    final note = _currentNote;
    if (note == null || !_selectionState.hasSelection) return;

    final previousColors = <String, Color>{};
    final newColors = <String, Color>{};
    for (final id in _selectionState.selectedStrokeIds) {
      final stroke = note.getStroke(id);
      if (stroke != null) {
        previousColors[id] = stroke.color;
        newColors[id] = newColor;
      }
    }

    setState(() {
      _undoManager.pushCommand(ChangeColorCommand(previousColors: previousColors, newColors: newColors), execute: true, note: note);
      _strokesVersion++;
      _committedStrokesNotifier.value++;
    });
  }

  void _deleteSelectedStrokes() {
    final note = _currentNote;
    if (note == null || !_selectionState.hasSelection) return;

    final selectedStrokes = _selectionState.selectedStrokeIds.map((id) => note.getStroke(id)).whereType<InkStroke>().toList();

    DevHubServer.instance.logAction('Deletar (${selectedStrokes.length} traços)');

    setState(() {
      _undoManager.pushCommand(RemoveStrokesCommand(selectedStrokes), execute: true, note: note);
      _strokesVersion++;
      _committedStrokesNotifier.value++;
      _selectionState = SelectionState.empty();
      _selectionUpdateNotifier.value++;
    });
  }

  void _deselect() {
    if (_selectionState.hasSelection || _selectionState.isSelectingArea) {
      setState(() {
        _selectionState = SelectionState.empty();
      });
    }
  }

  void _handleZoomDelta(double delta, Offset focalPoint) {
    final double currentZoom = _zoomNotifier.value;
    final Offset currentPan = _panNotifier.value;
    final double newScale = (currentZoom + delta).clamp(0.25, 4.0);
    if (newScale == currentZoom) return;

    final Offset focalInCanvas = (focalPoint - currentPan) / currentZoom;
    _zoomNotifier.value = newScale;
    _panNotifier.value = focalPoint - (focalInCanvas * newScale);
  }

  @override
  Widget build(BuildContext context) {
    final note = _currentNote;
    final Map<String, String> noteTitles = {
      for (final n in _notes) n.id: n.title,
      for (final n in _notes) ..._flattenTitles(n)
    };

    final bool canUndo = note != null && _undoManager.canUndo(note);
    final bool canRedo = note != null && _undoManager.canRedo(note);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): _redo,
        const SingleActivator(LogicalKeyboardKey.keyC, control: true): _copySelectedStrokes,
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): _pasteStrokes,
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): _duplicateSelectedStrokes,
        const SingleActivator(LogicalKeyboardKey.delete): _deleteSelectedStrokes,
        const SingleActivator(LogicalKeyboardKey.backspace): _deleteSelectedStrokes,
        const SingleActivator(LogicalKeyboardKey.escape): _deselect,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Stack(
            children: [
              // 1. Fundo do Canvas Infinito & Traços
              MouseRegion(
                onHover: (event) {
                  _mousePosNotifier.value = event.localPosition;
                },
                onExit: (_) {
                  _mousePosNotifier.value = null;
                },
                child: GestureDetector(
                  onTapDown: (_) {
                    if (_isSidebarOpen) {
                      setState(() {
                        _isSidebarOpen = false;
                      });
                    }
                  },
                  child: Listener(
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent) {
                        final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
                        if (isCtrlPressed) {
                          final delta = -event.scrollDelta.dy * 0.0015;
                          _setInteracting();
                          _handleZoomDelta(delta, event.localPosition);
                        }
                      }
                    },
                    onPointerDown: (event) {
                      final isMiddleButton = event.buttons == 4;
                      if (isMiddleButton) return;

                      if (event.buttons == 1 && note != null) {
                        final canvasPoint = (event.localPosition - _panOffset) / _zoomScale;

                        if (_activeTool == 'pen') {
                          final currentPreset = _activePenPreset;

                          setState(() {
                            _isDrawing = true;
                            _activeStroke = InkStroke(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              points: [StrokePoint(point: canvasPoint, pressure: event.pressure)],
                              color: currentPreset.color,
                              strokeWidth: currentPreset.strokeWidth,
                              toolType: currentPreset.toolType,
                              enablePressure: currentPreset.enablePressure,
                            );
                          });
                          _activeStrokeUpdateNotifier.value++;
                        } else if (_activeTool == 'eraser') {
                          _eraseStrokesNear(canvasPoint);
                        } else if (_activeTool == 'select') {
                          _selectionStartCanvasPoint = canvasPoint;

                          // Se já tem seleção e clicou dentro da Bounding Box -> arrastar traços selecionados
                          if (_selectionState.hasSelection &&
                              _selectionState.bounds!.inflate(10 / _zoomScale).contains(canvasPoint)) {
                            // Pré-aquecimento da prévia para o dragZero
                            _dragPictureCache.update(note, _selectionState.selectedStrokeIds);
                            
                            _selectionState = _selectionState.copyWith(
                              isDraggingSelection: true,
                              dragOffset: Offset.zero,
                            );
                            _committedStrokesNotifier.value++;
                            _selectionUpdateNotifier.value++;
                          } else {
                            // Começar potencial nova seleção
                            _selectionState = SelectionState(
                              type: _selectionType,
                              startPoint: canvasPoint,
                              currentPoint: canvasPoint,
                              lassoPoints: [canvasPoint],
                            );
                            _selectionUpdateNotifier.value++;
                          }
                        }
                      }
                    },
                    onPointerMove: (event) {
                      final isMiddleButton = event.buttons == 4;

                      if (isMiddleButton) {
                        _setInteracting();
                        _panNotifier.value += event.delta;
                        return;
                      }

                      if (event.buttons == 1 && note != null) {
                        final canvasPoint = (event.localPosition - _panOffset) / _zoomScale;

                        if (_activeTool == 'pen' && _activeStroke != null) {
                          final lastPoint = _activeStroke!.points.last.point;
                          // 1.5px minimum distance filter (1.5^2 = 2.25)
                          if ((canvasPoint - lastPoint).distanceSquared < 2.25) return;

                          _activeStroke!.points.add(
                            StrokePoint(point: canvasPoint, pressure: event.pressure),
                          );
                          _activeStroke!.cachedRawPoints = null;
                          _activeStroke!.cachedPath = null;
                          _activeStrokeUpdateNotifier.value++;
                        } else if (_activeTool == 'eraser') {
                          _eraseStrokesNear(canvasPoint);
                        } else if (_activeTool == 'select' && _selectionStartCanvasPoint != null) {
                          if (_selectionState.isDraggingSelection) {
                            _setInteracting();
                            final delta = canvasPoint - _selectionStartCanvasPoint!;
                            _selectionState = _selectionState.copyWith(dragOffset: delta);
                            _selectionUpdateNotifier.value++;
                          } else {
                            final dist = (canvasPoint - _selectionStartCanvasPoint!).distance;
                            if (dist > 4.0 || _selectionState.isSelectingArea) {
                              // Eixo 7.1: Lasso Debounce (evita milhares de pontos O(1))
                              if (_selectionType == SelectionType.lasso && _selectionState.lassoPoints.isNotEmpty) {
                                if ((canvasPoint - _selectionState.lassoPoints.last).distanceSquared < 16.0) return;
                              }

                              _selectionState = _selectionState.copyWith(
                                isSelectingArea: true,
                                currentPoint: canvasPoint,
                                lassoPoints: [..._selectionState.lassoPoints, canvasPoint],
                              );
                              _selectionUpdateNotifier.value++;
                            }
                          }
                        }
                      }
                    },
                    onPointerUp: (event) {
                      if (_activeTool == 'pen' && _activeStroke != null && note != null) {
                        // Mantém o erro visual abaixo de ~0,35 px na escala atual.
                        final simplifiedPoints = InkStroke.simplifyRDP(
                          _activeStroke!.points,
                          0.35 / _zoomScale,
                        );
                        
                        if (simplifiedPoints.isNotEmpty) {
                          double minX = double.infinity, minY = double.infinity;
                          double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
                          for (final p in simplifiedPoints) {
                            if (p.point.dx < minX) minX = p.point.dx;
                            if (p.point.dy < minY) minY = p.point.dy;
                            if (p.point.dx > maxX) maxX = p.point.dx;
                            if (p.point.dy > maxY) maxY = p.point.dy;
                          }
                          // Padding básico para strokeWidth e possíveis marca-textos
                          final double padding = _activeStroke!.strokeWidth * 2;
                          final boundingBox = Rect.fromLTRB(minX - padding, minY - padding, maxX + padding, maxY + padding);

                          // Pré-compilar caminho Bézier para não recalcular durante Pan e Zoom
                          final cachedPath = InkStroke.buildCatmullRomPath(simplifiedPoints);

                          final finalStroke = InkStroke(
                            id: _activeStroke!.id,
                            points: simplifiedPoints,
                            color: _activeStroke!.color,
                            strokeWidth: _activeStroke!.strokeWidth,
                            toolType: _activeStroke!.toolType,
                            enablePressure: _activeStroke!.enablePressure,
                            boundingBox: boundingBox,
                            cachedPath: cachedPath,
                          );

                          // Sincroniza o traço com o motor Rust Nativo (Spatial Index & Undo)
                          final nativeDocId = note.nativeDocId;
                          if (nativeDocId != null && nativeDocId.isNotEmpty) {
                            ConnotesNativeBridge.instance.addStroke(
                              nativeDocId,
                              finalStroke.points,
                              r: finalStroke.color.red / 255.0,
                              g: finalStroke.color.green / 255.0,
                              b: finalStroke.color.blue / 255.0,
                              a: finalStroke.color.opacity,
                              strokeWidth: finalStroke.strokeWidth,
                            );
                          }

                          DevHubServer.instance.logAction('Desenhar Traço (${simplifiedPoints.length} pts)');

                          setState(() {
                            _undoManager.pushCommand(AddStrokeCommand(finalStroke), execute: true, note: note);
                            _strokesVersion++;
                            _committedStrokesNotifier.value++;
                            _activeStroke = null;
                            _isDrawing = false;
                          });
                        } else {
                          setState(() {
                            _activeStroke = null;
                            _isDrawing = false;
                          });
                        }
                      } else if (_activeTool == 'select' && _selectionStartCanvasPoint != null && note != null) {
                        final canvasPoint = (event.localPosition - _panOffset) / _zoomScale;

                        if (_selectionState.isDraggingSelection) {
                          final delta = _selectionState.dragOffset;
                          if (delta != Offset.zero) {
                            final originalStrokes = <InkStroke>[];
                            final updatedStrokes = <InkStroke>[];

                            // Coletar traços movidos usando Otimização Flyweight (0 alocações)
                            for (final id in _selectionState.selectedStrokeIds) {
                              final s = note.getStroke(id);
                              if (s != null) {
                                final updatedStroke = InkStroke(
                                  id: s.id,
                                  points: s.points, // Flyweight (compartilha)
                                  transform: s.transform + delta, // Apenas desloca o vetor visual!
                                  color: s.color,
                                  strokeWidth: s.strokeWidth,
                                  toolType: s.toolType,
                                  enablePressure: s.enablePressure,
                                  boundingBox: s.boundingBox?.shift(delta),
                                  cachedPath: s.cachedPath, // Flyweight (compartilha)
                                  cachedRawPoints: s.cachedRawPoints,
                                );

                                originalStrokes.add(s);
                                updatedStrokes.add(updatedStroke);
                              }
                            }

                            _undoManager.pushCommand(
                              MoveStrokesCommand(
                                originalStrokes: originalStrokes,
                                updatedStrokes: updatedStrokes,
                              ),
                              execute: true,
                              note: note,
                            );
                          }

                          final newBounds = _selectionState.bounds?.shift(delta);
                          setState(() {
                            _strokesVersion++;
                            _committedStrokesNotifier.value++;
                            _selectionState = _selectionState.copyWith(
                              isDraggingSelection: false,
                              dragOffset: Offset.zero,
                              bounds: newBounds,
                            );
                            _selectionStartCanvasPoint = null;
                            _selectionUpdateNotifier.value++;
                          });
                          return;
                        }

                        final totalMove = (canvasPoint - _selectionStartCanvasPoint!).distance;

                        // 1. Clique simples (Tap-to-Select)
                        if (totalMove < 4.0) {
                          InkStroke? hitStroke;
                          final tolerance = 12.0 / _zoomScale;
                          final candidateIds = note.spatialIndex.queryPoint(canvasPoint, tolerance);
                          // Procura do mais recente para o mais antigo (z-index)
                          for (int i = note.strokes.length - 1; i >= 0; i--) {
                            final s = note.strokes[i];
                            if (candidateIds.contains(s.id)) {
                              if (SelectionGeometry.isPointNearStroke(canvasPoint, s, tolerance)) {
                                hitStroke = s;
                                break;
                              }
                            }
                          }

                          setState(() {
                            if (hitStroke != null) {
                              final bounds = hitStroke.boundingBox ?? SelectionGeometry.computeStrokeBounds(hitStroke);
                              _selectionState = SelectionState(
                                type: _selectionType,
                                selectedStrokeIds: {hitStroke.id},
                                bounds: bounds,
                              );
                            } else {
                              _selectionState = SelectionState.empty();
                            }
                            _selectionStartCanvasPoint = null;
                          });
                          return;
                        }

                        // 2. Seleção por Área (Retângulo ou Laço)
                        final selectedIds = <String>{};
                        if (_selectionType == SelectionType.rectangle &&
                            _selectionState.startPoint != null &&
                            _selectionState.currentPoint != null) {
                          final rect = Rect.fromPoints(_selectionState.startPoint!, _selectionState.currentPoint!);
                          final candidateIds = note.spatialIndex.queryRect(rect);
                          for (final s in note.strokes) {
                            if (candidateIds.contains(s.id) && SelectionGeometry.isStrokeInRect(s, rect)) {
                              selectedIds.add(s.id);
                            }
                          }
                        } else if (_selectionType == SelectionType.lasso && _selectionState.lassoPoints.length > 2) {
                          double minX = double.infinity, minY = double.infinity, maxX = double.negativeInfinity, maxY = double.negativeInfinity;
                          for (final p in _selectionState.lassoPoints) {
                            if (p.dx < minX) minX = p.dx;
                            if (p.dy < minY) minY = p.dy;
                            if (p.dx > maxX) maxX = p.dx;
                            if (p.dy > maxY) maxY = p.dy;
                          }
                          final rect = Rect.fromLTRB(minX, minY, maxX, maxY);
                          final candidateIds = note.spatialIndex.queryRect(rect);
                          for (final s in note.strokes) {
                            if (candidateIds.contains(s.id) && SelectionGeometry.isStrokeInLasso(s, _selectionState.lassoPoints)) {
                              selectedIds.add(s.id);
                            }
                          }
                        }

                        setState(() {
                          if (selectedIds.isNotEmpty) {
                            final selectedStrokes = note.strokes.where((s) => selectedIds.contains(s.id));
                            final combinedBounds = SelectionGeometry.computeCombinedBounds(selectedStrokes);
                            _selectionState = SelectionState(
                              type: _selectionType,
                              selectedStrokeIds: selectedIds,
                              bounds: combinedBounds,
                            );
                          } else {
                            _selectionState = SelectionState.empty();
                          }
                          _selectionStartCanvasPoint = null;
                        });
                      }
                    },
                    child: Stack(
                      children: [
                        // Camada 1: Grade de Fundo (Dot Grid com Halo Cursor)
                        ListenableBuilder(
                          listenable: Listenable.merge([_panNotifier, _zoomNotifier, _mousePosNotifier]),
                          builder: (context, _) {
                            final pan = _panNotifier.value;
                            final zoom = _zoomNotifier.value;
                            final mousePos = _mousePosNotifier.value;
                            return RepaintBoundary(
                              child: CustomPaint(
                                size: Size.infinite,
                                painter: CanvasDotGridPainter(
                                  panOffset: pan,
                                  zoomScale: zoom,
                                  mousePosition: mousePos,
                                  backgroundType: _currentBackground,
                                  isDrawing: _isDrawing,
                                ),
                              ),
                            );
                          },
                        ),

                        // Camada 2: Traços Comitados (Samsung Notes Baking Model O(1) Chunks 1024x1024)
                        if (note != null)
                          ListenableBuilder(
                            listenable: Listenable.merge([_panNotifier, _zoomNotifier, _isInteractingNotifier, _committedStrokesNotifier]),
                            builder: (context, _) {
                              final pan = _panNotifier.value;
                              final zoom = _zoomNotifier.value;
                              final isInteracting = _isInteractingNotifier.value;
                              return RepaintBoundary(
                                child: CustomPaint(
                                  size: Size.infinite,
                                  isComplex: true,
                                  willChange: false,
                                  painter: CommittedStrokesPainter(
                                    strokes: note.strokes,
                                    strokesCount: note.strokes.length,
                                    strokesVersion: _strokesVersion,
                                    hiddenStrokeIds: _selectionState.isDraggingSelection
                                        ? _selectionState.selectedStrokeIds
                                        : null,
                                    panOffset: pan,
                                    zoomScale: zoom,
                                    pictureCache: note.pictureCache,
                                    isInteracting: isInteracting,
                                  ),
                                ),
                              );
                            },
                          ),

                        // Camada 2.5: Traços Transitórios (Ingestão Instantânea O(1) de Colagem Massiva)
                        ListenableBuilder(
                          listenable: Listenable.merge([_panNotifier, _zoomNotifier, _transientUpdateNotifier]),
                          builder: (context, _) {
                            final pan = _panNotifier.value;
                            final zoom = _zoomNotifier.value;
                            return RepaintBoundary(
                              child: CustomPaint(
                                size: Size.infinite,
                                painter: TransientStrokesPainter(
                                  cache: _transientPictureCache,
                                  panOffset: pan,
                                  zoomScale: zoom,
                                  updateNotifier: _transientUpdateNotifier,
                                ),
                              ),
                            );
                          },
                        ),

                        // Camada 3: Traço Ativo (Desenhado em tempo real na ponta da caneta - Traço Vivo)
                        if (note != null)
                          ListenableBuilder(
                            listenable: Listenable.merge([_panNotifier, _zoomNotifier, _activeStrokeUpdateNotifier]),
                            builder: (context, _) {
                              final pan = _panNotifier.value;
                              final zoom = _zoomNotifier.value;
                              return RepaintBoundary(
                                child: CustomPaint(
                                  size: Size.infinite,
                                  painter: ActiveStrokePainter(
                                    activeStroke: _activeStroke,
                                    updateNotifier: _activeStrokeUpdateNotifier,
                                    panOffset: pan,
                                    zoomScale: zoom,
                                  ),
                                ),
                              );
                            },
                          ),

                        // Camada 4: Overlay de Seleção e Bounding Box (Un-Baking em Bloco Único)
                        if (note != null)
                          ListenableBuilder(
                            listenable: Listenable.merge([_panNotifier, _zoomNotifier, _selectionUpdateNotifier]),
                            builder: (context, _) {
                              final pan = _panNotifier.value;
                              final zoom = _zoomNotifier.value;
                              return RepaintBoundary(
                                child: CustomPaint(
                                  size: Size.infinite,
                                  painter: SelectionOverlayPainter(
                                    selectionState: _selectionState,
                                    note: note,
                                    panOffset: pan,
                                    zoomScale: zoom,
                                    repaintNotifier: _selectionUpdateNotifier,
                                    dragCache: _dragPictureCache,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Barra de Ações Rápidas da Seleção (Flutuante sobre a Bounding Box)
              if (_selectionState.hasSelection && _currentNote != null)
                Positioned(
                  top: math.max(16, _selectionState.bounds!.top * _zoomScale + _panOffset.dy - 60),
                  left: math.max(16, (_selectionState.bounds!.center.dx * _zoomScale + _panOffset.dx) - 80),
                  child: SelectionActionBar(
                    availableColors: _penSlots.map((s) => s.color).toSet().toList(),
                    onDuplicate: _duplicateSelectedStrokes,
                    onChangeColor: _changeSelectedStrokesColor,
                    onDelete: _deleteSelectedStrokes,
                    onDeselect: _deselect,
                  ),
                ),

              // 3. TabBar Superior
              Positioned(
                top: 24,
                left: _isSidebarOpen ? 348 : 0,
                right: 140,
                child: Center(
                  child: NoteTabBar(
                    activeNoteIds: _activeNoteIds,
                    noteTitles: noteTitles,
                    selectedNoteId: _selectedNoteId,
                    isSidebarOpen: _isSidebarOpen,
                    onSelectNote: (noteId) {
                      setState(() {
                        _selectedNoteId = noteId;
                        _selectionState = SelectionState.empty();
                      });
                    },
                    onCloseNote: (noteId) {
                      setState(() {
                        _activeNoteIds.remove(noteId);
                        if (_selectedNoteId == noteId) {
                          _selectedNoteId = _activeNoteIds.isNotEmpty ? _activeNoteIds.last : null;
                        }
                        _selectionState = SelectionState.empty();
                      });
                    },
                    onAddNote: () {
                      _addNewNote("Nova Nota ${_notes.length + 1}");
                    },
                    onToggleSidebar: () {
                      setState(() {
                        _isSidebarOpen = !_isSidebarOpen;
                      });
                    },
                  ),
                ),
              ),

              // 4. HUD de Zoom no Topo Superior Direito
              Positioned(
                top: 24,
                right: 24,
                child: ValueListenableBuilder<double>(
                  valueListenable: _zoomNotifier,
                  builder: (context, zoom, _) {
                    return ZoomHudPill(
                      zoomScale: zoom,
                      onZoomIn: () {
                        final center = Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2);
                        _handleZoomDelta(0.15, center);
                      },
                      onZoomOut: () {
                        final center = Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2);
                        _handleZoomDelta(-0.15, center);
                      },
                      onResetZoom: () {
                        _zoomNotifier.value = 1.0;
                      },
                    );
                  },
                ),
              ),

              // 5. Sub-Barra Flutuante de Slots de Canetas (com Drag & Drop)
              Positioned(
                bottom: 96,
                left: _isSidebarOpen ? 348 : 0,
                right: 0,
                child: Center(
                  child: PenSlotsSubBar(
                    isVisible: _activeTool == 'pen' && _isPenSubBarVisible,
                    presets: _penSlots,
                    activePresetId: _activeSlotId,
                    onSelectPreset: (preset) {
                      setState(() {
                        _activeSlotId = preset.id;
                        _activeTool = 'pen';
                        _selectionState = SelectionState.empty();
                      });
                    },
                    onUpdatePreset: (updated) {
                      setState(() {
                        final idx = _penSlots.indexWhere((s) => s.id == updated.id);
                        if (idx != -1) {
                          _penSlots[idx] = updated;
                        }
                      });
                    },
                    onReorderSlots: (oldIndex, newIndex) {
                      setState(() {
                        final item = _penSlots.removeAt(oldIndex);
                        _penSlots.insert(newIndex, item);
                      });
                    },
                    onAddNewSlot: () {
                      final newId = DateTime.now().millisecondsSinceEpoch.toString();
                      final newSlot = PenSlotPreset(
                        id: newId,
                        name: 'Slot ${_penSlots.length + 1}',
                        color: MoscaroTokens.stemPalette[_penSlots.length % MoscaroTokens.stemPalette.length],
                        strokeWidth: 3.0,
                        toolType: InkToolType.technical,
                        enablePressure: false,
                      );
                      setState(() {
                        _penSlots.add(newSlot);
                        _activeSlotId = newId;
                        _activeTool = 'pen';
                        _selectionState = SelectionState.empty();
                      });
                    },
                    onDeleteSlot: (slotId) {
                      setState(() {
                        _penSlots.removeWhere((s) => s.id == slotId);
                        if (_activeSlotId == slotId && _penSlots.isNotEmpty) {
                          _activeSlotId = _penSlots.first.id;
                        }
                      });
                    },
                  ),
                ),
              ),

              // 6. Sub-Barra Flutuante de Seleção (Retângulo vs Laço)
              Positioned(
                bottom: 96,
                left: _isSidebarOpen ? 348 : 0,
                right: 0,
                child: Center(
                  child: SelectionSubBar(
                    isVisible: _activeTool == 'select',
                    activeType: _selectionType,
                    onSelectType: (newType) {
                      setState(() {
                        _selectionType = newType;
                        _selectionState = SelectionState.empty();
                      });
                    },
                  ),
                ),
              ),

              // 7. Barra de Ferramentas / ToolbarPill (Inferior)
              Positioned(
                bottom: 32,
                left: _isSidebarOpen ? 348 : 0,
                right: 0,
                child: Center(
                  child: ToolbarPill(
                    currentBackground: _currentBackground,
                    isAIOpen: _isAIOpen,
                    isPenActive: _activeTool == 'pen',
                    isEraserActive: _activeTool == 'eraser',
                    isSelectActive: _activeTool == 'select',
                    selectionType: _selectionType,
                    activePenPreset: _activePenPreset,
                    canUndo: canUndo,
                    canRedo: canRedo,
                    onUndo: _undo,
                    onRedo: _redo,
                    onBackgroundChanged: (newBg) {
                      setState(() {
                        _currentBackground = newBg;
                      });
                    },
                    onSelectPen: () {
                      setState(() {
                        _activeTool = 'pen';
                        _isPenSubBarVisible = true;
                        _selectionState = SelectionState.empty();
                      });
                    },
                    onSelectEraser: () {
                      setState(() {
                        _activeTool = 'eraser';
                        _selectionState = SelectionState.empty();
                      });
                    },
                    onSelectTool: () {
                      setState(() {
                        _activeTool = 'select';
                        _isPenSubBarVisible = false;
                      });
                    },
                    onToggleAI: () {
                      setState(() {
                        _isAIOpen = !_isAIOpen;
                      });
                    },
                  ).moscaroV2(
                    borderRadius: MoscaroTokens.radiusPill,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  ),
                ),
              ),

              // 8. Sidebar Esquerda de Notas
              NoteSidebar(
                isOpen: _isSidebarOpen,
                rootNotes: _notes,
                trashNotes: _trashNotes,
                onSelectNote: (selectedNote) {
                  setState(() {
                    if (!_activeNoteIds.contains(selectedNote.id)) {
                      _activeNoteIds.add(selectedNote.id);
                    }
                    _selectedNoteId = selectedNote.id;
                  });
                },
                onAddNote: () {
                  _addNewNote("Nova Nota ${_notes.length + 1}");
                },
                onReorderNote: (dragged, target) {
                  setState(() {
                    _moveNoteToSubnote(_notes, dragged, target);
                  });
                },
                onMoveToTrash: (noteIds) {
                  setState(() {
                    for (final id in noteIds) {
                      final targetNote = _findNoteById(_notes, id);
                      if (targetNote != null) {
                        _removeNoteFromTree(_notes, id);
                        _trashNotes.add(targetNote);
                        _activeNoteIds.remove(id);
                      }
                    }
                    if (_selectedNoteId != null && !_activeNoteIds.contains(_selectedNoteId)) {
                      _selectedNoteId = _activeNoteIds.isNotEmpty ? _activeNoteIds.last : null;
                    }
                  });
                },
                onRestoreNote: (noteId) {
                  setState(() {
                    final restoredIndex = _trashNotes.indexWhere((n) => n.id == noteId);
                    if (restoredIndex != -1) {
                      final restoredNote = _trashNotes.removeAt(restoredIndex);
                      _notes.add(restoredNote);
                      if (!_activeNoteIds.contains(noteId)) {
                        _activeNoteIds.add(noteId);
                      }
                      _selectedNoteId = noteId;
                    }
                  });
                },
                onDeletePermanently: (noteId) {
                  setState(() {
                    _trashNotes.removeWhere((n) => n.id == noteId);
                  });
                },
                onEmptyTrash: () {
                  setState(() {
                    _trashNotes.clear();
                  });
                },
              ),

              // 7. Painel Lateral Direito da IA
              AiSidebar(
                isOpen: _isAIOpen,
                onClose: () {
                  setState(() {
                    _isAIOpen = false;
                  });
                },
                onSubmitPrompt: (promptText) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Prompt enviado para IA: $promptText')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _eraseStrokesNear(Offset canvasPoint) {
    final note = _currentNote;
    if (note == null) return;
    
    final eraserRadius = 24.0 / _zoomScale;

    // A consulta espacial reduz o conjunto; o teste por segmento mantém a
    // precisão mesmo quando há pouca amostragem de pontos.
    final candidateIds = note.spatialIndex.queryPoint(canvasPoint, eraserRadius);
    final toRemove = candidateIds
        .map((id) => note.getStroke(id))
        .whereType<InkStroke>()
        .where((stroke) => !_pendingErasures.containsKey(stroke.id))
        .where((stroke) => SelectionGeometry.isPointNearStroke(canvasPoint, stroke, eraserRadius))
        .toList();

    if (toRemove.isNotEmpty) {
      for (final stroke in toRemove) {
        _pendingErasures[stroke.id] = stroke;
      }
      _scheduleEraseCommit(note);
    }
  }

  /// Uma passada de borracha pode receber centenas de eventos por segundo.
  /// Agrupar as mutações elimina rebuilds e comandos de undo redundantes.
  void _scheduleEraseCommit(NoteDocument note) {
    if (_eraseCommitScheduled) return;
    _eraseCommitScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _eraseCommitScheduled = false;
      if (!mounted || _pendingErasures.isEmpty) return;
      final erased = _pendingErasures.values.toList(growable: false);
      _pendingErasures.clear();
      _undoManager.pushCommand(RemoveStrokesCommand(erased), execute: true, note: note);
      _strokesVersion++;
      _committedStrokesNotifier.value++;
    });
  }

  Map<String, String> _flattenTitles(NoteDocument doc) {
    final Map<String, String> titles = {};
    for (final child in doc.children) {
      titles[child.id] = child.title;
      titles.addAll(_flattenTitles(child));
    }
    return titles;
  }

  void _moveNoteToSubnote(List<NoteDocument> root, NoteDocument dragged, NoteDocument? target) {
    if (_isDescendant(dragged, target)) {
      return;
    }

    _removeNoteFromTree(root, dragged.id);

    if (target == null) {
      root.add(dragged);
    } else {
      final targetNote = _findNoteById(root, target.id);
      if (targetNote != null) {
        targetNote.children.add(dragged);
      }
    }
  }

  bool _isDescendant(NoteDocument parent, NoteDocument? child) {
    if (child == null) return false;
    if (parent.id == child.id) return true;
    for (final c in parent.children) {
      if (_isDescendant(c, child)) return true;
    }
    return false;
  }

  bool _removeNoteFromTree(List<NoteDocument> root, String id) {
    for (int i = 0; i < root.length; i++) {
      if (root[i].id == id) {
        root.removeAt(i);
        return true;
      }
      final removed = _removeNoteFromTree(root[i].children, id);
      if (removed) return true;
    }
    return false;
  }
}
