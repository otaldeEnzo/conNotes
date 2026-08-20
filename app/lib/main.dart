import 'dart:math' as math;
import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'theme/moscaro_v2_tokens.dart';
import 'theme/moscaro_v2_extension.dart';
import 'models/theme_models.dart';
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
import 'widgets/eraser_sub_bar.dart';
import 'widgets/shapes_sub_bar.dart';
import 'widgets/grid_menu_card.dart';
import 'widgets/laser_pointer.dart';
import 'widgets/smart_shapes.dart';
import 'widgets/stem_ruler_model.dart';
import 'widgets/stem_ruler_widget.dart';
import 'widgets/stem_protractor_model.dart';
import 'widgets/stem_protractor_widget.dart';
import 'widgets/ruler_sub_bar.dart';
import 'widgets/settings_models.dart';
import 'widgets/settings_tab_bar.dart';
import 'widgets/settings_page_view.dart';
import 'theme/moscaro_theme_controller.dart';
import 'services/settings_service.dart';
import 'services/workspace_storage_service.dart';
import 'services/windows_mime_association_service.dart';
import 'widgets/undo_commands.dart';
import 'ffi/native_bridge.dart';
import 'dev_hub/dev_hub_server.dart';
import 'models/canvas_card_model.dart';
import 'widgets/cards_sub_bar.dart';
import 'widgets/canvas_cards_layer.dart';
import 'widgets/canvas_card_widget.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WindowsMimeAssociationService.registerMimeAssociation();
  final isRustReady = ConnotesNativeBridge.instance.isAvailable;
  debugPrint('[ConNotes] Motor Rust Core inicializado: $isRustReady');
  runApp(const ConNotesApp());
}

class ConNotesApp extends StatelessWidget {
  const ConNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MoscaroThemeController.instance,
      builder: (context, _) {
        final isLight = MoscaroTokens.isLight;
        return MaterialApp(
          title: 'conNotes STEM Canvas',
          debugShowCheckedModeBanner: false,
          theme: (isLight ? ThemeData.light() : ThemeData.dark()).copyWith(
            scaffoldBackgroundColor: MoscaroTokens.backgroundDeep,
          ),
          home: const CanvasHomeScreen(),
        );
      },
    );
  }
}

class CanvasHomeScreen extends StatefulWidget {
  const CanvasHomeScreen({super.key});

  @override
  State<CanvasHomeScreen> createState() => _CanvasHomeScreenState();
}

class _CanvasHomeScreenState extends State<CanvasHomeScreen> with TickerProviderStateMixin {
  // Estado de Documentos e Notas
  final List<NoteDocument> _notes = [];
  final List<String> _activeNoteIds = [];
  String? _selectedNoteId;
  bool _isSidebarOpen = false;

  // Motor do Ponteiro Laser
  final LaserPointerEngine _laserEngine = LaserPointerEngine();

  // Estado de Navegação do Canvas Desacoplado (144Hz Zero-Rebuild)
  final ValueNotifier<Offset> _panNotifier = ValueNotifier(Offset.zero);
  final ValueNotifier<double> _zoomNotifier = ValueNotifier(1.0);
  final ValueNotifier<Offset?> _mousePosNotifier = ValueNotifier(null);
  CanvasBackgroundType _currentBackground = CanvasBackgroundType.dotGrid;

  Offset get _panOffset => _panNotifier.value;
  double get _zoomScale => _zoomNotifier.value;

  // Animação de Retorno à Zona Segura (4º Quadrante: x >= 0, y >= 0)
  late AnimationController _bounceController;
  Animation<Offset>? _bounceAnimation;
  Timer? _scrollBounceTimer;

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
  EraserConfig _eraserConfig = const EraserConfig();
  SelectionState _selectionState = SelectionState.empty();
  final ValueNotifier<int> _selectionUpdateNotifier = ValueNotifier(0);
  final ValueNotifier<int> _committedStrokesNotifier = ValueNotifier(0);
  Offset? _selectionStartCanvasPoint;
  final SelectedStrokesPictureCache _dragPictureCache = SelectedStrokesPictureCache();
  final TransientStrokesPictureCache _transientPictureCache = TransientStrokesPictureCache();
  final ValueNotifier<int> _transientUpdateNotifier = ValueNotifier(0);

  // Estado de Formas Geométricas & Smart Shapes (Draw & Hold)
  ShapeType _activeShapeType = ShapeType.line;
  Offset? _shapeDragStartPoint;
  Timer? _drawAndHoldTimer;
  bool _isSmartShapeSnapped = false;
  ShapeType? _snappedShapeType;
  Offset? _smartShapeStartPoint;
  Rect? _smartShapeInitialBounds;
  Offset? _smartShapeCenter;
  // Estado das Ferramentas de Medição STEM (Régua e Transferidor - Fase 5.2)
  MeasurementToolType _activeMeasurementTool = MeasurementToolType.ruler;
  bool _isMeasurementSubBarVisible = false;
  StemRulerState _rulerState = const StemRulerState(isVisible: false);
  StemProtractorState _protractorState = const StemProtractorState(isVisible: false);
  final ValueNotifier<int> _rulerUpdateNotifier = ValueNotifier(0);
  bool _isDraggingRuler = false;
  bool _isRotatingRuler = false;
  Offset? _rulerDragStart;
  StemRulerState? _rulerInitialState;
  bool _isDraggingProtractor = false;
  bool _isRotatingProtractor = false;
  Offset? _protractorDragStart;
  StemProtractorState? _protractorInitialState;

  bool _isGridMenuOpen = false;
  // Estado dos Cards do Canvas (Fase 11)
  bool _isCardsSubBarVisible = false;
  CardTypePreset? _activeCardPreset;
  String? _selectedCardId;
  double _smoothedPressure = 0.6;
  int _lastPointerTimestampMs = 0;
  Offset? _lastPointerCanvasPoint;

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

  // Estado das Configurações do conNotes (Fase 6)
  AppSettingsState _settings = AppSettingsState.defaults();
  bool _isSettingsOpen = false;
  SettingsCategory _activeSettingsCategory = SettingsCategory.visual;

  void _loadSavedSettings() async {
    final loaded = await SettingsService.instance.loadSettings();
    MoscaroTokens.blurSigma = loaded.blurSigma;
    MoscaroThemeController.instance.initialize(
      themeId: loaded.activeThemeId,
      bgModeId: loaded.customBgMode,
      customSolidHex: loaded.customBgColorHex,
      customGradStartHex: loaded.customGradStartHex,
      customGradEndHex: loaded.customGradEndHex,
      textureId: loaded.customTextureType,
      imagePath: loaded.customImagePath,
      imageOpacity: loaded.customImageOpacity,
      customThemes: loaded.customThemes,
    );

    await WorkspaceStorageService.instance.initialize(
      customPath: loaded.workspaceDirectoryPath,
    );

    final allNotes = <NoteDocument>[
      ...WorkspaceStorageService.instance.rootNotes,
    ];
    for (final nb in WorkspaceStorageService.instance.notebooks) {
      allNotes.addAll(nb.notes);
    }

    if (allNotes.isNotEmpty) {
      _notes.clear();
      _notes.addAll(allNotes);
      final first = allNotes.first;
      _activeNoteIds.clear();
      _activeNoteIds.add(first.id);
      _selectedNoteId = first.id;
      _panNotifier.value = Offset(first.panX, first.panY);
      _zoomNotifier.value = first.zoomScale;
    } else {
      final defaultNote = await WorkspaceStorageService.instance.createNote(title: 'Anotações STEM');
      _notes.clear();
      _notes.add(defaultNote);
      _activeNoteIds.clear();
      _activeNoteIds.add(defaultNote.id);
      _selectedNoteId = defaultNote.id;
    }

    if (mounted) {
      setState(() {
        _settings = loaded;
      });
    }
  }

  void _updateSettings(AppSettingsState newSettings) {
    MoscaroTokens.blurSigma = newSettings.blurSigma;
    MoscaroThemeController.instance.initialize(
      themeId: newSettings.activeThemeId,
      bgModeId: newSettings.customBgMode,
      customSolidHex: newSettings.customBgColorHex,
      customGradStartHex: newSettings.customGradStartHex,
      customGradEndHex: newSettings.customGradEndHex,
      textureId: newSettings.customTextureType,
      imagePath: newSettings.customImagePath,
      imageOpacity: newSettings.customImageOpacity,
      customThemes: newSettings.customThemes,
    );
    setState(() {
      _settings = newSettings;
    });
    SettingsService.instance.saveSettings(newSettings);
  }

  void _resetSettingsCategory() {
    final def = AppSettingsState.defaults();
    AppSettingsState updated = _settings;
    switch (_activeSettingsCategory) {
      case SettingsCategory.themes:
        updated = _settings.copyWith(
          activeThemeId: def.activeThemeId,
          customBgMode: def.customBgMode,
          customBgColorHex: def.customBgColorHex,
          customGradStartHex: def.customGradStartHex,
          customGradEndHex: def.customGradEndHex,
          customTextureType: def.customTextureType,
          customImagePath: def.customImagePath,
          customImageOpacity: def.customImageOpacity,
        );
        break;
      case SettingsCategory.visual:
        updated = _settings.copyWith(
          blurSigma: def.blurSigma,
          enableAuroraBorders: def.enableAuroraBorders,
          showTelemetryHud: def.showTelemetryHud,
        );
        break;
      case SettingsCategory.canvas:
        updated = _settings.copyWith(
          gridSpacing: def.gridSpacing,
          enableMouseGlow: def.enableMouseGlow,
          mouseGlowRadius: def.mouseGlowRadius,
        );
        break;
      case SettingsCategory.pen:
        updated = _settings.copyWith(
          rdpSmoothingTolerance: def.rdpSmoothingTolerance,
          pressureSensitivity: def.pressureSensitivity,
          drawAndHoldDurationMs: def.drawAndHoldDurationMs,
        );
        break;
      case SettingsCategory.measurement:
        updated = _settings.copyWith(
          angleSnapStepDegrees: def.angleSnapStepDegrees,
          inkSnapTolerance: def.inkSnapTolerance,
        );
        break;
      case SettingsCategory.shortcuts:
        break;
      case SettingsCategory.ai:
        updated = _settings.copyWith(
          geminiApiKey: def.geminiApiKey,
          defaultAiModel: def.defaultAiModel,
        );
        break;
    }
    _updateSettings(updated);
  }

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
    WorkspaceStorageService.instance.initialize().then((_) {
      if (mounted) {
        setState(() {
          final allNotes = WorkspaceStorageService.instance.allNotes;
          for (final n in allNotes) {
            if (!_notes.any((existing) => existing.id == n.id)) {
              _notes.add(n);
            }
          }
          if (_selectedNoteId == null && _notes.isNotEmpty) {
            _selectedNoteId = _notes.first.id;
            if (!_activeNoteIds.contains(_selectedNoteId!)) {
              _activeNoteIds.add(_selectedNoteId!);
            }
          }
        });
      }
    });
    _laserEngine.init(this);
    _activeSlotId = _penSlots.first.id;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _bounceController.addListener(() {
      if (_bounceAnimation != null) {
        _panNotifier.value = _bounceAnimation!.value;
      }
    });

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

    // Observador Dinâmico de Temas para atualização em 0ms de traços e UI
    MoscaroThemeController.instance.addListener(_handleThemeChanged);
  }

  void _handleThemeChanged() {
    for (final note in _notes) {
      note.pictureCache.invalidatePictures();
    }
    _strokesVersion++;
    _committedStrokesNotifier.value++;
    _activeStrokeUpdateNotifier.value++;
    if (mounted) setState(() {});
  }

  void _checkAndAnimatePanToSafeZone() {
    final currentPan = _panNotifier.value;
    final targetX = math.min(0.0, currentPan.dx);
    final targetY = math.min(0.0, currentPan.dy);
    if (targetX != currentPan.dx || targetY != currentPan.dy) {
      _bounceController.stop();
      _bounceAnimation = Tween<Offset>(
        begin: currentPan,
        end: Offset(targetX, targetY),
      ).animate(CurvedAnimation(
        parent: _bounceController,
        curve: Curves.easeOutCubic,
      ));
      _bounceController.forward(from: 0.0);
    }
  }

  void _handlePanDelta(Offset delta) {
    _setInteracting();
    _bounceController.stop();
    final current = _panNotifier.value;
    double newX = current.dx + delta.dx;
    double newY = current.dy + delta.dy;

    // Resistência elástica (rubberband) mais rígida caso ultrapasse o limite do 4º quadrante (0, 0)
    if (newX > 0) {
      newX = current.dx + delta.dx * 0.12;
    }
    if (newY > 0) {
      newY = current.dy + delta.dy * 0.12;
    }

    _panNotifier.value = Offset(newX, newY);
  }

  void _scheduleBounceCheck() {
    _scrollBounceTimer?.cancel();
    _scrollBounceTimer = Timer(const Duration(milliseconds: 90), () {
      _checkAndAnimatePanToSafeZone();
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
    MoscaroThemeController.instance.removeListener(_handleThemeChanged);
    _laserEngine.dispose();
    _bounceController.dispose();
    _telemetrySyncTimer?.cancel();
    _interactionTimer?.cancel();
    _drawAndHoldTimer?.cancel();
    _scrollBounceTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
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

      // Se estiver editando texto de bloco ou título de card, não intercepta teclas de edição (Backspace, etc.)
      if (globalIsEditingText) {
        if (event.logicalKey != LogicalKeyboardKey.escape) {
          return false;
        }
      }

      final primaryFocus = FocusManager.instance.primaryFocus;
      if (primaryFocus != null &&
          (primaryFocus.context?.widget is EditableText ||
              (primaryFocus.hasFocus &&
                  (primaryFocus.debugLabel?.contains('EditableText') == true ||
                      primaryFocus.debugLabel?.contains('TextField') == true)))) {
        if (event.logicalKey != LogicalKeyboardKey.escape) {
          return false;
        }
      }

      if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (_isSettingsOpen) {
          setState(() {
            _isSettingsOpen = false;
          });
          return true;
        }
      }

      // Apenas a tecla DELETE remove cards selecionados (NUNCA Backspace).
      if (event.logicalKey == LogicalKeyboardKey.delete) {
        final note = _currentNote;
        if (_selectedCardId != null && note != null) {
          final target = note.cards.cast<CanvasCardModel?>().firstWhere((c) => c?.id == _selectedCardId, orElse: () => null);
          if (target != null) {
            _undoManager.pushCommand(RemoveCardCommand(target), execute: true, note: note);
            setState(() {
              _selectedCardId = null;
            });
            WorkspaceStorageService.instance.scheduleAutoSave(note);
            return true;
          }
        } else if (_selectionState.hasSelection) {
          _deleteSelectedStrokes();
          return true;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
        // Backspace APENAS deleta traços selecionados pelo laço quando não estiver editando texto, NUNCA cards!
        if (_selectionState.hasSelection) {
          _deleteSelectedStrokes();
          return true;
        }
      }

      final isCtrl = HardwareKeyboard.instance.isControlPressed;
      if (isCtrl) {
        if (event.logicalKey == LogicalKeyboardKey.keyA) {
          _selectAll();
          return true;
        } else if (event.logicalKey == LogicalKeyboardKey.keyZ) {
          final isShift = HardwareKeyboard.instance.isShiftPressed;
          if (isShift) {
            _redo();
          } else {
            _undo();
          }
          return true;
        } else if (event.logicalKey == LogicalKeyboardKey.keyY) {
          _redo();
          return true;
        } else if (event.logicalKey == LogicalKeyboardKey.comma) {
          setState(() {
            _isSettingsOpen = !_isSettingsOpen;
          });
          return true;
        } else if (event.logicalKey == LogicalKeyboardKey.keyC) {
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

  Future<void> _addNewNote(String title) async {
    final doc = await WorkspaceStorageService.instance.createNote(title: title);
    setState(() {
      if (!_notes.any((n) => n.id == doc.id)) {
        _notes.add(doc);
      }
      if (!_activeNoteIds.contains(doc.id)) {
        _activeNoteIds.add(doc.id);
      }
      _selectedNoteId = doc.id;
      _panNotifier.value = Offset(doc.panX, doc.panY);
      _zoomNotifier.value = doc.zoomScale;
      _strokesVersion++;
      _committedStrokesNotifier.value++;
    });
  }

  NoteDocument? get _currentNote {
    if (_selectedNoteId == null) return null;
    final local = _findNoteById(_notes, _selectedNoteId!);
    if (local != null) return local;

    final allStorage = WorkspaceStorageService.instance.allNotes;
    final fromStorage = _findNoteById(allStorage, _selectedNoteId!);
    if (fromStorage != null) {
      if (!_notes.any((n) => n.id == fromStorage.id)) {
        _notes.add(fromStorage);
      }
      return fromStorage;
    }
    return null;
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
    WorkspaceStorageService.instance.scheduleAutoSave(note);
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
    WorkspaceStorageService.instance.scheduleAutoSave(note);
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

  void _rotateSelectedStrokesBy(double radians) {
    final note = _currentNote;
    if (note == null || !_selectionState.hasSelection) return;

    final bounds = _selectionState.bounds!;
    final pivot = bounds.center;
    final cosA = math.cos(radians);
    final sinA = math.sin(radians);

    final originalStrokes = <InkStroke>[];
    final updatedStrokes = <InkStroke>[];

    for (final id in _selectionState.selectedStrokeIds) {
      final s = note.getStroke(id);
      if (s != null) {
        final newPoints = <StrokePoint>[];
        for (final p in s.points) {
          final localP = p.point + s.transform;
          final dx = localP.dx - pivot.dx;
          final dy = localP.dy - pivot.dy;
          final newX = pivot.dx + dx * cosA - dy * sinA;
          final newY = pivot.dy + dx * sinA + dy * cosA;
          newPoints.add(StrokePoint(point: Offset(newX, newY), pressure: p.pressure, tilt: p.tilt));
        }

        final newBounds = SelectionGeometry.computePointsBounds(newPoints, s.strokeWidth);
        final Path newCachedPath;
        if (s.toolType == InkToolType.fountain || s.enablePressure) {
          newCachedPath = FreehandOutlineRenderer.generateOutlinePath(
            newPoints,
            baseWidth: s.strokeWidth,
            isTapered: s.toolType == InkToolType.fountain,
          );
        } else {
          newCachedPath = InkStroke.buildCatmullRomPath(newPoints);
        }

        final transformed = InkStroke(
          id: s.id,
          points: newPoints,
          color: s.color,
          strokeWidth: s.strokeWidth,
          toolType: s.toolType,
          enablePressure: s.enablePressure,
          boundingBox: newBounds,
          cachedPath: newCachedPath,
        );

        originalStrokes.add(s);
        updatedStrokes.add(transformed);
      }
    }

    if (updatedStrokes.isEmpty) return;

    _undoManager.pushCommand(
      MoveStrokesCommand(originalStrokes: originalStrokes, updatedStrokes: updatedStrokes),
      execute: true,
      note: note,
    );

    final newCombinedBounds = SelectionGeometry.computeCombinedBounds(updatedStrokes);

    setState(() {
      _strokesVersion++;
      _committedStrokesNotifier.value++;
      _dragPictureCache.invalidate();
      _selectionState = _selectionState.copyWith(
        activeHandle: SelectionHandleType.none,
        rotationAngle: 0.0,
        bounds: newCombinedBounds,
      );
      _selectionUpdateNotifier.value++;
    });
  }

  void _onRotatePanStart(DragStartDetails details) {
    if (!_selectionState.hasSelection) return;
    _setInteracting();
    final bounds = _selectionState.bounds!;
    _dragPictureCache.update(_currentNote!, _selectionState.selectedStrokeIds);
    _selectionState = _selectionState.copyWith(
      activeHandle: SelectionHandleType.rotation,
      transformPivot: bounds.center,
      rotationAngle: 0.0,
    );
    _committedStrokesNotifier.value++;
    _selectionUpdateNotifier.value++;
  }

  void _onRotatePanUpdate(DragUpdateDetails details) {
    if (!_selectionState.hasSelection || _selectionState.activeHandle != SelectionHandleType.rotation) return;
    _setInteracting();
    final canvasCenter = _selectionState.transformPivot ?? _selectionState.bounds!.center;
    final screenCenter = canvasCenter * _zoomScale + _panOffset;
    final currentPos = details.globalPosition;

    final initialAngle = -math.pi / 2.0; // Posição 12h
    final currentAngle = math.atan2(currentPos.dy - screenCenter.dy, currentPos.dx - screenCenter.dx);
    final rawRotation = currentAngle - initialAngle;
    final snappedRotation = SelectionGeometry.snapAngle(rawRotation);

    _selectionState = _selectionState.copyWith(
      rotationAngle: snappedRotation,
    );
    _selectionUpdateNotifier.value++;
  }

  void _onRotatePanEnd(DragEndDetails details) {
    if (!_selectionState.hasSelection || _selectionState.activeHandle != SelectionHandleType.rotation) return;
    final rot = _selectionState.rotationAngle;
    if (rot.abs() > 0.01) {
      _rotateSelectedStrokesBy(rot);
    } else {
      setState(() {
        _selectionState = _selectionState.copyWith(
          activeHandle: SelectionHandleType.none,
          rotationAngle: 0.0,
        );
        _committedStrokesNotifier.value++;
        _selectionUpdateNotifier.value++;
      });
    }
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
    if (_selectionState.hasSelection || _selectionState.isSelectingArea || _selectedCardId != null) {
      setState(() {
        _selectionState = SelectionState.empty();
        _selectedCardId = null;
      });
    }
  }

  CanvasCardModel? _findCardAtPoint(List<CanvasCardModel> cards, Offset canvasPoint, String? selectedCardId) {
    for (final card in cards.reversed) {
      final bool isSelected = card.id == selectedCardId;
      final bool isCollapsed = card.isCollapsed;
      final bool isCompact = card.width < 540.0;
      final double measuredH = CanvasCardWidget.actualHeights[card.id] ?? 0.0;
      final int linesCount = card.content.split('\n').length;
      final double estimatedH = math.max(card.height, linesCount * 32.0 + 80.0);
      final double cardH = isCollapsed ? 42.0 : math.max(measuredH, estimatedH);
      final double handleMargin = isSelected ? 18.0 : 0.0;

      // 1. Área do Card Principal (inclui margem de 18px para alças de redimensionamento quando selecionado)
      final cardRect = Rect.fromLTRB(
        card.x - handleMargin,
        card.y - handleMargin,
        card.x + card.width + handleMargin,
        card.y + cardH + handleMargin,
      );
      if (cardRect.contains(canvasPoint)) {
        return card;
      }

      // 2. Área da Pílula Flutuante Superior (quando selecionado)
      if (isSelected) {
        final double pillHeight = isCompact ? 85.0 : 48.0;
        final pillRect = Rect.fromLTWH(
          card.x - 20.0,
          card.y - pillHeight - 10.0,
          card.width + 40.0,
          pillHeight + 14.0,
        );
        if (pillRect.contains(canvasPoint)) {
          return card;
        }
      }
    }
    return null;
  }

  void _selectAll() {
    final note = _currentNote;
    if (note == null) return;
    if (note.strokes.isEmpty && note.cards.isEmpty) return;

    setState(() {
      if (note.strokes.isNotEmpty) {
        final allIds = note.strokes.map((s) => s.id).toSet();
        final combinedBounds = SelectionGeometry.computeCombinedBounds(note.strokes);

        _activeTool = 'select';
        _isPenSubBarVisible = false;
        _selectionState = SelectionState(
          type: _selectionType,
          selectedStrokeIds: allIds,
          bounds: combinedBounds,
        );
      }

      if (note.cards.isNotEmpty) {
        if (_selectedCardId == null || !note.cards.any((c) => c.id == _selectedCardId)) {
          _selectedCardId = note.cards.last.id;
        }
      }
    });

    if (note.strokes.isNotEmpty) {
      _selectionUpdateNotifier.value++;
    }
  }

  void _handleZoomDelta(double delta, Offset focalPoint) {
    final double currentZoom = _zoomNotifier.value;
    final Offset currentPan = _panNotifier.value;
    final double newScale = (currentZoom + delta).clamp(0.25, 4.0);
    if (newScale == currentZoom) return;

    final Offset focalInCanvas = (focalPoint - currentPan) / currentZoom;
    _zoomNotifier.value = newScale;
    final rawPan = focalPoint - (focalInCanvas * newScale);
    _panNotifier.value = Offset(math.min(0.0, rawPan.dx), math.min(0.0, rawPan.dy));
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
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): _selectAll,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): _redo,
        const SingleActivator(LogicalKeyboardKey.keyC, control: true): _copySelectedStrokes,
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): _pasteStrokes,
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): _duplicateSelectedStrokes,

        const SingleActivator(LogicalKeyboardKey.comma, control: true): () {
          setState(() {
            _isSettingsOpen = !_isSettingsOpen;
          });
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_isSettingsOpen) {
            setState(() {
              _isSettingsOpen = false;
            });
          } else {
            _deselect();
          }
        },
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent || event is KeyRepeatEvent) {
            // Se o foco estiver em um campo de texto, ignore o atalho para que o campo de texto processe a digitação/remoção de caracteres.
            if (globalIsEditingText) {
              return KeyEventResult.ignored;
            }

            final primaryFocus = FocusManager.instance.primaryFocus;
            if (primaryFocus != null &&
                (primaryFocus.context?.widget is EditableText ||
                    (primaryFocus.hasFocus &&
                        (primaryFocus.debugLabel?.contains('EditableText') == true ||
                            primaryFocus.debugLabel?.contains('TextField') == true)))) {
              return KeyEventResult.ignored;
            }
            
            final note = _currentNote;
            // Apenas a tecla DELETE remove o card selecionado (NUNCA Backspace).
            if (event.logicalKey == LogicalKeyboardKey.delete) {
              if (_selectedCardId != null && note != null) {
                final target = note.cards.cast<CanvasCardModel?>().firstWhere((c) => c?.id == _selectedCardId, orElse: () => null);
                if (target != null) {
                  _undoManager.pushCommand(RemoveCardCommand(target), execute: true, note: note);
                  setState(() {
                    _selectedCardId = null;
                  });
                  WorkspaceStorageService.instance.scheduleAutoSave(note);
                }
                return KeyEventResult.handled;
              } else if (_selectionState.hasSelection) {
                _deleteSelectedStrokes();
                return KeyEventResult.handled;
              }
            } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
              if (_selectionState.hasSelection) {
                _deleteSelectedStrokes();
                return KeyEventResult.handled;
              }
            }
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          body: Stack(
            children: [
              // 1. Fundo do Canvas Infinito & Traços
              MouseRegion(
                cursor: _activeTool == 'laser' ? SystemMouseCursors.none : MouseCursor.defer,
                onHover: (event) {
                  _mousePosNotifier.value = event.localPosition;
                  if (_activeTool == 'laser') {
                    final rawCanvasPoint = (event.localPosition - _panOffset) / _zoomScale;
                    _laserEngine.updateHoverPosition(rawCanvasPoint);
                  }
                },
                onExit: (_) {
                  _mousePosNotifier.value = null;
                  if (_activeTool == 'laser') {
                    _laserEngine.updateHoverPosition(null);
                  }
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
                        if (note != null) {
                          final canvasPoint = (event.localPosition - _panOffset) / _zoomScale;
                          final hitCard = _findCardAtPoint(note.cards, canvasPoint, _selectedCardId);
                          if (hitCard != null) {
                            // Ponteiro sobre o card ou sua barra flutuante: deixa o card consumir o scroll!
                            return;
                          }
                        }

                        final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
                        final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
                        if (isCtrlPressed) {
                          final delta = -event.scrollDelta.dy * 0.0015;
                          _setInteracting();
                          _handleZoomDelta(delta, event.localPosition);
                        } else if (isShiftPressed) {
                          _handlePanDelta(Offset(-event.scrollDelta.dy, 0.0));
                          _scheduleBounceCheck();
                        } else {
                          _handlePanDelta(Offset(0.0, -event.scrollDelta.dy));
                          _scheduleBounceCheck();
                        }
                      }
                    },
                    onPointerDown: (event) {
                      _mousePosNotifier.value = event.localPosition;
                      if (_isSettingsOpen) return;
                      final isMiddleButton = event.buttons == 4;
                      if (isMiddleButton) return;

                      if (event.buttons == 1 && note != null) {
                        final rawCanvasPoint = (event.localPosition - _panOffset) / _zoomScale;
                        final canvasPoint = Offset(math.max(0.0, rawCanvasPoint.dx), math.max(0.0, rawCanvasPoint.dy));

                        if (_activeTool == 'laser') {
                          _setInteracting();
                          _laserEngine.onPointerDown(canvasPoint);
                          return;
                        }

                        // Inserção de Novo Card no Canvas (Fase 11)
                        if (_activeCardPreset != null) {
                          final preset = _activeCardPreset!;
                          String templateContent = '';
                          if (preset == CardTypePreset.generalMarkdownLatex) {
                            templateContent = '# Título do Card\n\nTexto formatado com fórmulas inline \$E = mc^2\$ e equações em bloco:\n\n\$\$ \\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2} \$\$\n\n- [ ] Tarefa 1\n- [x] Tarefa Concluída\n';
                          } else if (preset == CardTypePreset.mathFormula) {
                            templateContent = '\$\$ \\vec{\\nabla} \\times \\vec{E} = -\\frac{\\partial \\vec{B}}{\\partial t} \$\$\n';
                          } else if (preset == CardTypePreset.stickyNote) {
                            templateContent = 'Lembrete / Nota Rápida\n';
                          }

                          final newCard = CanvasCardModel(
                            id: 'card_${DateTime.now().millisecondsSinceEpoch}',
                            x: canvasPoint.dx,
                            y: canvasPoint.dy,
                            content: templateContent,
                          );

                          _undoManager.pushCommand(
                            AddCardCommand(newCard),
                            execute: true,
                            note: note,
                          );

                          setState(() {
                            _selectedCardId = newCard.id;
                            _activeCardPreset = null;
                            _isCardsSubBarVisible = false;
                            _activeTool = 'pen';
                            _selectionState = SelectionState.empty();
                          });
                          WorkspaceStorageService.instance.scheduleAutoSave(note);
                          return;
                        }

                        // Interação e Seleção de Cards do Canvas (Fase 11)
                        final clickedCard = _findCardAtPoint(note.cards, canvasPoint, _selectedCardId);
                        if (clickedCard != null) {
                          if (_selectedCardId != clickedCard.id) {
                            setState(() {
                              _selectedCardId = clickedCard.id;
                              _selectionState = SelectionState.empty();
                            });
                          }
                          // O ponteiro atingiu o card, seu cabeçalho, a pílula ou alças de redimensionamento:
                          // Retorna imediatamente para NÃO iniciar traços de desenho com a caneta no canvas!
                          return;
                        } else if (_selectedCardId != null) {
                          // Toque no vazio do canvas: retira a seleção do card ativo e desativa foco
                          FocusManager.instance.primaryFocus?.unfocus();
                          setState(() {
                            _selectedCardId = null;
                          });
                        }

                        _lastPointerTimestampMs = event.timeStamp.inMilliseconds;
                        _lastPointerCanvasPoint = canvasPoint;
                        if (event.kind != PointerDeviceKind.mouse && event.pressure > 0.0) {
                          _smoothedPressure = (event.pressure * _settings.pressureSensitivity).clamp(0.1, 2.0);
                        } else {
                          _smoothedPressure = (0.6 * _settings.pressureSensitivity).clamp(0.1, 2.0);
                        }
                        final double pressure = _smoothedPressure;

                        // Interação direta com a Régua STEM (Arrastar ou Rotacionar)
                        if (_rulerState.isVisible && _rulerState.containsPoint(canvasPoint)) {
                          final isProtractor = _rulerState.isNearCenterProtractor(canvasPoint);
                          _isRotatingRuler = isProtractor;
                          _isDraggingRuler = !isProtractor;
                          _rulerDragStart = canvasPoint;
                          _rulerInitialState = _rulerState;
                          _setInteracting();
                          return;
                        }

                        // Interação direta com o Transferidor STEM (Arrastar ou Rotacionar)
                        if (_protractorState.isVisible && _protractorState.containsPoint(canvasPoint)) {
                          final isRotate = _protractorState.isNearRotateHandle(canvasPoint);
                          _isRotatingProtractor = isRotate;
                          _isDraggingProtractor = !isRotate;
                          _protractorDragStart = canvasPoint;
                          _protractorInitialState = _protractorState;
                          _setInteracting();
                          return;
                        }

                        if (_activeTool == 'pen') {
                          final currentPreset = _activePenPreset;

                          _isSmartShapeSnapped = false;
                          _snappedShapeType = null;
                          _smartShapeStartPoint = canvasPoint;

                          // Atração magnética por instrumentos STEM (Régua ou Transferidor)
                          final snapped = _rulerState.isVisible
                              ? _rulerState.snapPoint(canvasPoint)
                              : (_protractorState.isVisible ? _protractorState.snapPoint(canvasPoint) : null);
                          final effectiveStartPoint = snapped ?? canvasPoint;

                          setState(() {
                            _isDrawing = true;
                            _activeStroke = InkStroke(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              points: [StrokePoint(point: effectiveStartPoint, pressure: pressure)],
                              color: currentPreset.color,
                              strokeWidth: currentPreset.strokeWidth,
                              toolType: currentPreset.toolType,
                              enablePressure: currentPreset.enablePressure,
                            );
                          });
                          _activeStrokeUpdateNotifier.value++;

                          // Iniciar temporizador Draw & Hold (400ms para Smart Shape Snap)
                          _drawAndHoldTimer?.cancel();
                          _drawAndHoldTimer = Timer(const Duration(milliseconds: 400), () {
                            if (_isDrawing && _activeStroke != null && _activeStroke!.points.length >= 8) {
                              final recognized = SmartShapeEngine.recognizeDrawnShape(_activeStroke!.points);
                              if (recognized != null) {
                                _isSmartShapeSnapped = true;
                                _snappedShapeType = recognized;

                                // Calcula a Bounding Box real do desenho livre do usuário
                                double minX = double.infinity, minY = double.infinity;
                                double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
                                for (final p in _activeStroke!.points) {
                                  if (p.point.dx < minX) minX = p.point.dx;
                                  if (p.point.dy < minY) minY = p.point.dy;
                                  if (p.point.dx > maxX) maxX = p.point.dx;
                                  if (p.point.dy > maxY) maxY = p.point.dy;
                                }
                                final drawnBounds = Rect.fromLTRB(minX, minY, maxX, maxY);
                                _smartShapeInitialBounds = drawnBounds;
                                _smartShapeCenter = drawnBounds.center;

                                final shapePath = SmartShapeEngine.generateRecognizedPath(recognized, _activeStroke!.points, drawnBounds);
                                final shapePoints = SmartShapeEngine.samplePathPoints(shapePath, pressure: pressure);

                                _activeStroke = InkStroke(
                                  id: _activeStroke!.id,
                                  points: shapePoints,
                                  color: _activeStroke!.color,
                                  strokeWidth: _activeStroke!.strokeWidth,
                                  toolType: currentPreset.toolType,
                                  enablePressure: currentPreset.enablePressure,
                                  cachedPath: shapePath,
                                );
                                _activeStrokeUpdateNotifier.value++;
                              }
                            }
                          });
                        } else if (_activeTool == 'shapes') {
                          final currentPreset = _activePenPreset;
                          _shapeDragStartPoint = canvasPoint;
                          final initialPath = SmartShapeEngine.generateShapePath(
                            _activeShapeType,
                            canvasPoint,
                            canvasPoint + const Offset(1, 1),
                          );
                          final initialPoints = SmartShapeEngine.samplePathPoints(
                            initialPath,
                            pressure: pressure,
                          );

                          setState(() {
                            _isDrawing = true;
                            _activeStroke = InkStroke(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              points: initialPoints,
                              color: currentPreset.color,
                              strokeWidth: currentPreset.strokeWidth,
                              toolType: currentPreset.toolType,
                              enablePressure: currentPreset.enablePressure,
                              cachedPath: initialPath,
                            );
                          });
                          _activeStrokeUpdateNotifier.value++;
                        } else if (_activeTool == 'eraser') {
                          _eraseStrokesNear(canvasPoint);
                        } else if (_activeTool == 'select') {
                          _selectionStartCanvasPoint = canvasPoint;

                          if (_selectionState.hasSelection) {
                            final bounds = _selectionState.bounds!;
                            final handle = SelectionGeometry.getHandleAtPoint(
                              canvasPoint,
                              bounds,
                              _zoomScale,
                              rotation: _selectionState.rotationAngle,
                            );

                            if (handle != SelectionHandleType.none) {
                              // Clicou em um dos 9 manipuladores (Redimensionar ou Rotacionar)
                              _dragPictureCache.update(note, _selectionState.selectedStrokeIds);
                              _selectionState = _selectionState.copyWith(
                                activeHandle: handle,
                                transformPivot: bounds.center,
                                transformBounds: bounds,
                              );
                              _committedStrokesNotifier.value++;
                              _selectionUpdateNotifier.value++;
                              return;
                            } else if (bounds.inflate(10 / _zoomScale).contains(canvasPoint)) {
                              // Clicou dentro do corpo da Bounding Box -> arrastar traços
                              _dragPictureCache.update(note, _selectionState.selectedStrokeIds);
                              _selectionState = _selectionState.copyWith(
                                isDraggingSelection: true,
                                dragOffset: Offset.zero,
                              );
                              _committedStrokesNotifier.value++;
                              _selectionUpdateNotifier.value++;
                              return;
                            }
                          }

                          // Começar potencial nova seleção de área
                          _selectionState = SelectionState(
                            type: _selectionType,
                            startPoint: canvasPoint,
                            currentPoint: canvasPoint,
                            lassoPoints: [canvasPoint],
                          );
                          _selectionUpdateNotifier.value++;
                        }
                      }
                    },
                    onPointerMove: (event) {
                      _mousePosNotifier.value = event.localPosition;
                      final isMiddleButton = event.buttons == 4;

                      if (isMiddleButton) {
                        _handlePanDelta(event.delta);
                        return;
                      }

                      if (event.buttons == 1 && note != null) {
                        final rawCanvasPoint = (event.localPosition - _panOffset) / _zoomScale;
                        final canvasPoint = Offset(math.max(0.0, rawCanvasPoint.dx), math.max(0.0, rawCanvasPoint.dy));

                        if (_activeTool == 'laser') {
                          _setInteracting();
                          _laserEngine.onPointerMove(canvasPoint);
                          return;
                        }

                        // Movimentação / Rotação da Régua STEM
                        if (_isDraggingRuler && _rulerDragStart != null && _rulerInitialState != null) {
                          _setInteracting();
                          final delta = canvasPoint - _rulerDragStart!;
                          _rulerState = _rulerInitialState!.copyWith(
                            center: _rulerInitialState!.center + delta,
                          );
                          _rulerUpdateNotifier.value++;
                          return;
                        }

                        if (_isRotatingRuler && _rulerInitialState != null && _rulerDragStart != null) {
                          _setInteracting();
                          final center = _rulerInitialState!.center;
                          final initialAngle = math.atan2(_rulerDragStart!.dy - center.dy, _rulerDragStart!.dx - center.dx);
                          final currentAngle = math.atan2(canvasPoint.dy - center.dy, canvasPoint.dx - center.dx);
                          
                          // Rastreamento angular 1:1 contínuo (elimina qualquer salto ou descontinuidade)
                          double diff = currentAngle - initialAngle;
                          while (diff > math.pi) {
                            diff -= 2 * math.pi;
                          }
                          while (diff < -math.pi) {
                            diff += 2 * math.pi;
                          }

                          final targetAngle = _rulerInitialState!.angle + diff;
                          final snapped = StemRulerState.snapAngle(targetAngle);
                          
                          _rulerState = _rulerInitialState!.copyWith(
                            angle: snapped,
                          );
                          _rulerUpdateNotifier.value++;
                          return;
                        }

                        // Movimentação / Rotação do Transferidor STEM
                        if (_isDraggingProtractor && _protractorDragStart != null && _protractorInitialState != null) {
                          _setInteracting();
                          final delta = canvasPoint - _protractorDragStart!;
                          _protractorState = _protractorInitialState!.copyWith(
                            center: _protractorInitialState!.center + delta,
                          );
                          _rulerUpdateNotifier.value++;
                          return;
                        }

                        if (_isRotatingProtractor && _protractorInitialState != null && _protractorDragStart != null) {
                          _setInteracting();
                          final center = _protractorInitialState!.center;
                          final initialAngle = math.atan2(_protractorDragStart!.dy - center.dy, _protractorDragStart!.dx - center.dx);
                          final currentAngle = math.atan2(canvasPoint.dy - center.dy, canvasPoint.dx - center.dx);
                          
                          // Rastreamento angular 1:1 contínuo (elimina qualquer salto ou descontinuidade)
                          double diff = currentAngle - initialAngle;
                          while (diff > math.pi) {
                            diff -= 2 * math.pi;
                          }
                          while (diff < -math.pi) {
                            diff += 2 * math.pi;
                          }

                          final targetAngle = _protractorInitialState!.angle + diff;
                          final snapped = StemProtractorState.snapAngle(targetAngle);
                          
                          _protractorState = _protractorInitialState!.copyWith(
                            angle: snapped,
                          );
                          _rulerUpdateNotifier.value++;
                          return;
                        }

                        final double pressure;
                        if (event.kind != PointerDeviceKind.mouse && event.pressure > 0.0) {
                          pressure = event.pressure.clamp(0.2, 1.6);
                        } else {
                          final currentMs = event.timeStamp.inMilliseconds;
                          final dt = math.max(1, currentMs - _lastPointerTimestampMs);
                          final lastPt = _lastPointerCanvasPoint ?? canvasPoint;
                          final dist = (canvasPoint - lastPt).distance;
                          final speed = dist / dt; // pixels/ms

                          // Velocidade alta (> 0.8) -> Traço mais fino (0.4)
                          // Velocidade baixa (< 0.15) -> Traço mais encorpado (1.25)
                          final targetPressure = (1.2 - speed * 0.65).clamp(0.35, 1.35);
                          _smoothedPressure = _smoothedPressure * 0.65 + targetPressure * 0.35;
                          pressure = _smoothedPressure;

                          _lastPointerTimestampMs = currentMs;
                          _lastPointerCanvasPoint = canvasPoint;
                        }

                        if (_activeTool == 'pen' && _activeStroke != null) {
                          final currentPreset = _activePenPreset;
                          final isShift = HardwareKeyboard.instance.isShiftPressed;
                          final isCtrl = HardwareKeyboard.instance.isControlPressed;

                          if (isShift || isCtrl) {
                            _drawAndHoldTimer?.cancel();
                            final shapeType = isCtrl ? ShapeType.arrow : ShapeType.line;
                            final startPoint = _smartShapeStartPoint ?? _activeStroke!.points.first.point;
                            final shapePath = SmartShapeEngine.generateShapePath(shapeType, startPoint, canvasPoint);
                            final shapePoints = SmartShapeEngine.samplePathPoints(shapePath, pressure: pressure);

                            _activeStroke = InkStroke(
                              id: _activeStroke!.id,
                              points: shapePoints,
                              color: _activeStroke!.color,
                              strokeWidth: _activeStroke!.strokeWidth,
                              toolType: currentPreset.toolType,
                              enablePressure: currentPreset.enablePressure,
                              cachedPath: shapePath,
                            );
                            _activeStrokeUpdateNotifier.value++;
                          } else if (_isSmartShapeSnapped && _snappedShapeType != null && _smartShapeStartPoint != null) {
                            final recognized = _snappedShapeType!;
                            final Rect newBounds;
                            if (_smartShapeInitialBounds != null && _smartShapeCenter != null) {
                              final initBounds = _smartShapeInitialBounds!;
                              final center = _smartShapeCenter!;
                              final delta = canvasPoint - _smartShapeStartPoint!;

                              final newWidth = math.max(12.0, initBounds.width + delta.dx * 2);
                              final newHeight = math.max(12.0, initBounds.height + delta.dy * 2);
                              newBounds = Rect.fromCenter(center: center, width: newWidth, height: newHeight);
                            } else {
                              newBounds = Rect.fromPoints(_smartShapeStartPoint!, canvasPoint);
                            }

                            final shapePath = SmartShapeEngine.generateRecognizedPath(recognized, _activeStroke!.points, newBounds);
                            final shapePoints = SmartShapeEngine.samplePathPoints(shapePath, pressure: pressure);

                            _activeStroke = InkStroke(
                              id: _activeStroke!.id,
                              points: shapePoints,
                              color: _activeStroke!.color,
                              strokeWidth: _activeStroke!.strokeWidth,
                              toolType: currentPreset.toolType,
                              enablePressure: currentPreset.enablePressure,
                              cachedPath: shapePath,
                            );
                            _activeStrokeUpdateNotifier.value++;
                          } else {
                            final snapped = _rulerState.isVisible
                                ? _rulerState.snapPoint(canvasPoint)
                                : (_protractorState.isVisible ? _protractorState.snapPoint(canvasPoint) : null);
                            final effectivePoint = snapped ?? canvasPoint;
                            final lastPoint = _activeStroke!.points.last.point;
                            if ((effectivePoint - lastPoint).distanceSquared >= 2.25) {
                              _activeStroke!.points.add(
                                StrokePoint(point: effectivePoint, pressure: pressure),
                              );
                              _activeStroke!.cachedRawPoints = null;
                              _activeStroke!.cachedPath = null;
                              _activeStrokeUpdateNotifier.value++;

                              // Reiniciar temporizador configurado de Draw & Hold
                              _drawAndHoldTimer?.cancel();
                              _drawAndHoldTimer = Timer(Duration(milliseconds: _settings.drawAndHoldDurationMs), () {
                                if (_isDrawing && _activeStroke != null && _activeStroke!.points.length >= 8) {
                                  final recognized = SmartShapeEngine.recognizeDrawnShape(_activeStroke!.points);
                                  if (recognized != null) {
                                    _isSmartShapeSnapped = true;
                                    _snappedShapeType = recognized;

                                    double minX = double.infinity, minY = double.infinity;
                                    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
                                    for (final p in _activeStroke!.points) {
                                      if (p.point.dx < minX) minX = p.point.dx;
                                      if (p.point.dy < minY) minY = p.point.dy;
                                      if (p.point.dx > maxX) maxX = p.point.dx;
                                      if (p.point.dy > maxY) maxY = p.point.dy;
                                    }
                                    final drawnBounds = Rect.fromLTRB(minX, minY, maxX, maxY);
                                    _smartShapeInitialBounds = drawnBounds;
                                    _smartShapeCenter = drawnBounds.center;

                                    final shapePath = SmartShapeEngine.generateRecognizedPath(recognized, _activeStroke!.points, drawnBounds);
                                    final shapePoints = SmartShapeEngine.samplePathPoints(shapePath, pressure: pressure);

                                    _activeStroke = InkStroke(
                                      id: _activeStroke!.id,
                                      points: shapePoints,
                                      color: _activeStroke!.color,
                                      strokeWidth: _activeStroke!.strokeWidth,
                                      toolType: currentPreset.toolType,
                                      enablePressure: currentPreset.enablePressure,
                                      cachedPath: shapePath,
                                    );
                                    _activeStrokeUpdateNotifier.value++;
                                  }
                                }
                              });
                            }
                          }
                        } else if (_activeTool == 'shapes' && _shapeDragStartPoint != null && _activeStroke != null) {
                          final currentPreset = _activePenPreset;
                          final shapePath = SmartShapeEngine.generateShapePath(
                            _activeShapeType,
                            _shapeDragStartPoint!,
                            canvasPoint,
                          );
                          final shapePoints = SmartShapeEngine.samplePathPoints(
                            shapePath,
                            pressure: pressure,
                          );
                          _activeStroke = InkStroke(
                            id: _activeStroke!.id,
                            points: shapePoints,
                            color: currentPreset.color,
                            strokeWidth: currentPreset.strokeWidth,
                            toolType: currentPreset.toolType,
                            enablePressure: currentPreset.enablePressure,
                            cachedPath: shapePath,
                          );
                          _activeStrokeUpdateNotifier.value++;
                        } else if (_activeTool == 'eraser') {
                          _eraseStrokesNear(canvasPoint);
                        } else if (_activeTool == 'select' && _selectionStartCanvasPoint != null) {
                          if (_selectionState.isTransforming) {
                            _setInteracting();
                            final handle = _selectionState.activeHandle;
                            final pivot = _selectionState.transformPivot ?? _selectionState.bounds!.center;

                            if (handle == SelectionHandleType.rotation) {
                              // Cálculo de rotação com Snap Magnético
                              final initialAngle = -math.pi / 2.0; // Posição 12h (topo)
                              final currentAngle = math.atan2(canvasPoint.dy - pivot.dy, canvasPoint.dx - pivot.dx);
                              final rawRotation = currentAngle - initialAngle;
                              final snappedRotation = SelectionGeometry.snapAngle(rawRotation);

                              _selectionState = _selectionState.copyWith(
                                rotationAngle: snappedRotation,
                              );
                              _selectionUpdateNotifier.value++;
                            } else {
                              // Redimensionamento pelas 3 Alças com ancoragem no canto superior-esquerdo (Fidelidade 100%)
                              final bounds = _selectionState.bounds!;
                              double newLeft = bounds.left;
                              double newTop = bounds.top;
                              double newRight = bounds.right;
                              double newBottom = bounds.bottom;

                              switch (handle) {
                                case SelectionHandleType.centerRight:
                                  newRight = math.max(newLeft + 12.0, canvasPoint.dx);
                                  break;
                                case SelectionHandleType.bottomCenter:
                                  newBottom = math.max(newTop + 12.0, canvasPoint.dy);
                                  break;
                                case SelectionHandleType.bottomRight:
                                  newRight = math.max(newLeft + 12.0, canvasPoint.dx);
                                  newBottom = math.max(newTop + 12.0, canvasPoint.dy);
                                  break;
                                default:
                                  break;
                              }

                              final newRect = Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
                              _selectionState = _selectionState.copyWith(
                                transformBounds: newRect,
                              );
                              _selectionUpdateNotifier.value++;
                            }
                          } else if (_selectionState.isDraggingSelection) {
                            _setInteracting();
                            final delta = canvasPoint - _selectionStartCanvasPoint!;
                            _selectionState = _selectionState.copyWith(dragOffset: delta);
                            _selectionUpdateNotifier.value++;
                          } else {
                            final dist = (canvasPoint - _selectionStartCanvasPoint!).distance;
                            if (dist > 4.0 || _selectionState.isSelectingArea) {
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
                      _mousePosNotifier.value = event.localPosition;
                      _drawAndHoldTimer?.cancel();

                      if (_isDraggingRuler || _isRotatingRuler) {
                        _isDraggingRuler = false;
                        _isRotatingRuler = false;
                        _rulerDragStart = null;
                        _rulerInitialState = null;
                        return;
                      }

                      if (_isDraggingProtractor || _isRotatingProtractor) {
                        _isDraggingProtractor = false;
                        _isRotatingProtractor = false;
                        _protractorDragStart = null;
                        _protractorInitialState = null;
                        return;
                      }

                      if (_activeTool == 'laser') {
                        _laserEngine.onPointerUp();
                        return;
                      }
                      final wasShapeSnapped = _isSmartShapeSnapped;
                      final shapeCachedPath = _activeStroke?.cachedPath;

                      _isSmartShapeSnapped = false;
                      _snappedShapeType = null;
                      _smartShapeStartPoint = null;
                      _smartShapeInitialBounds = null;
                      _smartShapeCenter = null;
                      _shapeDragStartPoint = null;

                      _checkAndAnimatePanToSafeZone();

                      if ((_activeTool == 'pen' || _activeTool == 'shapes') && _activeStroke != null && note != null) {
                        final simplifiedPoints = (wasShapeSnapped || _activeTool == 'shapes' || shapeCachedPath != null)
                            ? _activeStroke!.points
                            : InkStroke.simplifyRDP(_activeStroke!.points, _settings.rdpSmoothingTolerance / _zoomScale);
                        
                        if (simplifiedPoints.isNotEmpty) {
                          double minX = double.infinity, minY = double.infinity;
                          double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
                          for (final p in simplifiedPoints) {
                            if (p.point.dx < minX) minX = p.point.dx;
                            if (p.point.dy < minY) minY = p.point.dy;
                            if (p.point.dx > maxX) maxX = p.point.dx;
                            if (p.point.dy > maxY) maxY = p.point.dy;
                          }
                          final double padding = _activeStroke!.strokeWidth * 2;
                          final boundingBox = Rect.fromLTRB(minX - padding, minY - padding, maxX + padding, maxY + padding);

                          final Path cachedPath;
                          if (shapeCachedPath != null) {
                            cachedPath = shapeCachedPath;
                          } else if (_activeStroke!.toolType == InkToolType.fountain || _activeStroke!.enablePressure) {
                            cachedPath = FreehandOutlineRenderer.generateOutlinePath(
                              simplifiedPoints,
                              baseWidth: _activeStroke!.strokeWidth,
                              isTapered: _activeStroke!.toolType == InkToolType.fountain,
                            );
                          } else {
                            cachedPath = InkStroke.buildCatmullRomPath(simplifiedPoints);
                          }

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
                          WorkspaceStorageService.instance.queueAutosave(note);
                          _activeStrokeUpdateNotifier.value++;
                        } else {
                          setState(() {
                            _activeStroke = null;
                            _isDrawing = false;
                          });
                          _activeStrokeUpdateNotifier.value++;
                        }
                      } else if (_activeTool == 'select' && _selectionStartCanvasPoint != null && note != null) {
                        final canvasPoint = (event.localPosition - _panOffset) / _zoomScale;

                        // 1. Concluir Transformação (Redimensionar / Rotacionar)
                        if (_selectionState.isTransforming) {
                          final rotation = _selectionState.rotationAngle;
                          final transformBounds = _selectionState.transformBounds;
                          final bounds = _selectionState.bounds!;
                          final isResizing = transformBounds != null &&
                              _selectionState.activeHandle != SelectionHandleType.rotation &&
                              _selectionState.activeHandle != SelectionHandleType.none;
                          final pivot = _selectionState.transformPivot ?? bounds.center;

                          if (isResizing || rotation != 0.0) {
                            final originalStrokes = <InkStroke>[];
                            final updatedStrokes = <InkStroke>[];
                            final cosA = math.cos(rotation);
                            final sinA = math.sin(rotation);

                            final double scaleX = isResizing ? (transformBounds.width / bounds.width) : 1.0;
                            final double scaleY = isResizing ? (transformBounds.height / bounds.height) : 1.0;

                            for (final id in _selectionState.selectedStrokeIds) {
                              final s = note.getStroke(id);
                              if (s != null) {
                                final newPoints = <StrokePoint>[];

                                for (final p in s.points) {
                                  final localP = p.point + s.transform;
                                  final double newX;
                                  final double newY;

                                  if (isResizing) {
                                    // Mapeamento afim direto 1:1 de bounds -> transformBounds
                                    final u = (localP.dx - bounds.left) / bounds.width;
                                    final v = (localP.dy - bounds.top) / bounds.height;
                                    newX = transformBounds.left + u * transformBounds.width;
                                    newY = transformBounds.top + v * transformBounds.height;
                                  } else {
                                    // Rotação em torno do centro do Bounding Box
                                    final dx = localP.dx - pivot.dx;
                                    final dy = localP.dy - pivot.dy;
                                    newX = pivot.dx + dx * cosA - dy * sinA;
                                    newY = pivot.dy + dx * sinA + dy * cosA;
                                  }

                                  newPoints.add(StrokePoint(
                                    point: Offset(newX, newY),
                                    pressure: p.pressure,
                                  ));
                                }

                                final newStrokeWidth = (s.strokeWidth * math.sqrt(scaleX * scaleY)).clamp(0.5, 50.0);
                                final newBounds = SelectionGeometry.computePointsBounds(newPoints, newStrokeWidth);

                                final Path newCachedPath;
                                if (s.toolType == InkToolType.fountain || s.enablePressure) {
                                  newCachedPath = FreehandOutlineRenderer.generateOutlinePath(
                                    newPoints,
                                    baseWidth: newStrokeWidth,
                                    isTapered: s.toolType == InkToolType.fountain,
                                  );
                                } else {
                                  newCachedPath = InkStroke.buildCatmullRomPath(newPoints);
                                }

                                final transformedStroke = InkStroke(
                                  id: s.id,
                                  points: newPoints,
                                  color: s.color,
                                  strokeWidth: newStrokeWidth,
                                  toolType: s.toolType,
                                  enablePressure: s.enablePressure,
                                  boundingBox: newBounds,
                                  cachedPath: newCachedPath,
                                );

                                originalStrokes.add(s);
                                updatedStrokes.add(transformedStroke);
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

                          final newCombinedBounds = isResizing
                              ? transformBounds
                              : SelectionGeometry.computeCombinedBounds(
                                  _selectionState.selectedStrokeIds
                                      .map((id) => note.getStroke(id))
                                      .whereType<InkStroke>()
                                      .toList(),
                                );

                          setState(() {
                            _strokesVersion++;
                            _committedStrokesNotifier.value++;
                            _selectionState = _selectionState.copyWith(
                              activeHandle: SelectionHandleType.none,
                              rotationAngle: 0.0,
                              scaleX: 1.0,
                              scaleY: 1.0,
                              clearTransformBounds: true,
                              clearTransformPivot: true,
                              bounds: newCombinedBounds,
                            );
                            _dragPictureCache.invalidate();
                            _selectionStartCanvasPoint = null;
                            _selectionUpdateNotifier.value++;
                          });
                          return;
                        }

                        // 2. Concluir Arraste (Mover)
                        if (_selectionState.isDraggingSelection) {
                          final delta = _selectionState.dragOffset;
                          if (delta != Offset.zero) {
                            final originalStrokes = <InkStroke>[];
                            final updatedStrokes = <InkStroke>[];

                            for (final id in _selectionState.selectedStrokeIds) {
                              final s = note.getStroke(id);
                              if (s != null) {
                                final updatedStroke = InkStroke(
                                  id: s.id,
                                  points: s.points,
                                  transform: s.transform + delta,
                                  color: s.color,
                                  strokeWidth: s.strokeWidth,
                                  toolType: s.toolType,
                                  enablePressure: s.enablePressure,
                                  boundingBox: s.boundingBox?.shift(delta),
                                  cachedPath: s.cachedPath,
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
                            _dragPictureCache.invalidate();
                            _selectionStartCanvasPoint = null;
                            _selectionUpdateNotifier.value++;
                          });
                          return;
                        }

                        final totalMove = (canvasPoint - _selectionStartCanvasPoint!).distance;

                        // 1. Clique simples (Tap-to-Select)
                        if (totalMove < 4.0) {
                          final hitCard = _findCardAtPoint(note.cards, canvasPoint, _selectedCardId);
                          if (hitCard != null) {
                            setState(() {
                              _selectedCardId = hitCard.id;
                              _selectionState = SelectionState.empty();
                              _selectionStartCanvasPoint = null;
                            });
                            return;
                          }

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
                              _selectedCardId = null;
                            } else {
                              _selectionState = SelectionState.empty();
                              _selectedCardId = null;
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

                          // Se não selecionou traços, verifica se englobou algum Card
                          if (selectedIds.isEmpty) {
                            for (final c in note.cards.reversed) {
                              final cRect = Rect.fromLTWH(c.x, c.y, c.width, c.height);
                              if (rect.overlaps(cRect) || rect.contains(Offset(c.x, c.y))) {
                                setState(() {
                                  _selectedCardId = c.id;
                                  _selectionState = SelectionState.empty();
                                  _selectionStartCanvasPoint = null;
                                });
                                return;
                              }
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

                          if (selectedIds.isEmpty) {
                            for (final c in note.cards.reversed) {
                              final cRect = Rect.fromLTWH(c.x, c.y, c.width, c.height);
                              if (rect.overlaps(cRect) || rect.contains(Offset(c.x, c.y))) {
                                setState(() {
                                  _selectedCardId = c.id;
                                  _selectionState = SelectionState.empty();
                                  _selectionStartCanvasPoint = null;
                                });
                                return;
                              }
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
                            _selectedCardId = null;
                          } else {
                            _selectionState = SelectionState.empty();
                            _selectedCardId = null;
                          }
                          _selectionStartCanvasPoint = null;
                        });
                      }
                    },
                    child: Stack(
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

                        // Camada 1: Grade de Fundo (Dot Grid com suporte a Temas e Texturas STEM)
                        ListenableBuilder(
                          listenable: Listenable.merge([_panNotifier, _zoomNotifier, _mousePosNotifier, MoscaroThemeController.instance]),
                          builder: (context, _) {
                            final pan = _panNotifier.value;
                            final zoom = _zoomNotifier.value;
                            final mousePos = _mousePosNotifier.value;
                            final themeCtrl = MoscaroThemeController.instance;

                            return RepaintBoundary(
                              child: CustomPaint(
                                size: Size.infinite,
                                painter: CanvasDotGridPainter(
                                  panOffset: pan,
                                  zoomScale: zoom,
                                  mousePosition: mousePos,
                                  backgroundType: _isSettingsOpen ? CanvasBackgroundType.emBranco : _currentBackground,
                                  isDrawing: _isDrawing,
                                  gridSpacing: _settings.gridSpacing,
                                  enableMouseGlow: _settings.enableMouseGlow,
                                  mouseGlowRadius: _settings.mouseGlowRadius,
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

                        // Camada 2: Traços Comitados (Acelerada via Grid Sub-Chunks & Texturas D3D11 O(1))
                        if (!_isSettingsOpen && note != null)
                          ListenableBuilder(
                            listenable: Listenable.merge([
                              _panNotifier,
                              _zoomNotifier,
                              _activeStrokeUpdateNotifier,
                              _isInteractingNotifier,
                              _committedStrokesNotifier,
                              _selectionUpdateNotifier,
                            ]),
                            builder: (context, _) {
                              final pan = _panNotifier.value;
                              final zoom = _zoomNotifier.value;
                              final isInteracting = _isInteractingNotifier.value;
                              final hideSelected = _selectionState.isDraggingSelection || _selectionState.isTransforming;
                              return RepaintBoundary(
                                child: CustomPaint(
                                  size: Size.infinite,
                                  isComplex: true,
                                  willChange: false,
                                  painter: CommittedStrokesPainter(
                                    strokes: note.strokes,
                                    strokesCount: note.strokes.length,
                                    strokesVersion: _strokesVersion,
                                    hiddenStrokeIds: hideSelected
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
                        if (!_isSettingsOpen)
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
                        if (!_isSettingsOpen && note != null)
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
                        if (!_isSettingsOpen && note != null)
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

                        // Camada 5: Cursor Halo da Borracha (Sub-camada isolada ultra-fluida 1000Hz)
                        if (!_isSettingsOpen && _activeTool == 'eraser')
                          ListenableBuilder(
                            listenable: _mousePosNotifier,
                            builder: (context, _) {
                              final mousePos = _mousePosNotifier.value;
                              if (mousePos == null) return const SizedBox.shrink();
                              return RepaintBoundary(
                                child: CustomPaint(
                                  size: Size.infinite,
                                  painter: _EraserHaloPainter(
                                    mousePosition: mousePos,
                                    radius: _eraserConfig.radius,
                                  ),
                                ),
                              );
                            },
                          ),

                        // Camada 6: Rastro Incandescente do Laser Pointer (Efêmero 144Hz)
                        if (!_isSettingsOpen)
                          RepaintBoundary(
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: LaserPointerPainter(
                                engine: _laserEngine,
                                panOffset: _panOffset,
                                zoomScale: _zoomScale,
                              ),
                            ),
                          ),

                        // Camada 7: Instrumentos de Medição STEM (Régua e Transferidor - Fase 5.2)
                        if (!_isSettingsOpen && _rulerState.isVisible)
                          ListenableBuilder(
                            listenable: Listenable.merge([_panNotifier, _zoomNotifier, _rulerUpdateNotifier]),
                            builder: (context, _) {
                              final pan = _panNotifier.value;
                              final zoom = _zoomNotifier.value;
                              return StemRulerWidget(
                                state: _rulerState,
                                panOffset: pan,
                                zoomScale: zoom,
                                onStateChanged: (newState) {
                                  setState(() {
                                    _rulerState = newState;
                                  });
                                  _rulerUpdateNotifier.value++;
                                },
                                onClose: () {
                                  setState(() {
                                    _rulerState = _rulerState.copyWith(isVisible: false);
                                  });
                                  _rulerUpdateNotifier.value++;
                                },
                              );
                            },
                          ),

                        if (!_isSettingsOpen && _protractorState.isVisible)
                          ListenableBuilder(
                            listenable: Listenable.merge([_panNotifier, _zoomNotifier, _rulerUpdateNotifier]),
                            builder: (context, _) {
                              final pan = _panNotifier.value;
                              final zoom = _zoomNotifier.value;
                              return StemProtractorWidget(
                                state: _protractorState,
                                panOffset: pan,
                                zoomScale: zoom,
                                onStateChanged: (newState) {
                                  setState(() {
                                    _protractorState = newState;
                                  });
                                  _rulerUpdateNotifier.value++;
                                },
                                onClose: () {
                                  setState(() {
                                    _protractorState = _protractorState.copyWith(isVisible: false);
                                  });
                                  _rulerUpdateNotifier.value++;
                                },
                              );
                            },
                          ),
                        // Camada 4.8: Cards Interativos no Canvas (Fase 11)
                        if (!_isSettingsOpen && note != null)
                          CanvasCardsLayer(
                            cards: note.cards,
                            selectedCardId: _selectedCardId,
                            panNotifier: _panNotifier,
                            zoomNotifier: _zoomNotifier,
                            onUpdateCard: (updated) {
                              final idx = note.cards.indexWhere((c) => c.id == updated.id);
                              if (idx != -1) {
                                final prev = note.cards[idx];
                                _undoManager.pushCommand(
                                  UpdateCardCommand(cardId: updated.id, previousCard: prev, newCard: updated),
                                  execute: true,
                                  note: note,
                                );
                                setState(() {});
                                WorkspaceStorageService.instance.scheduleAutoSave(note);
                              }
                            },
                            onSelectCard: (cardId) {
                              setState(() {
                                _selectedCardId = cardId;
                                _selectionState = SelectionState.empty();
                              });
                            },
                            onDeleteCard: (cardId) {
                              final target = note.cards.cast<CanvasCardModel?>().firstWhere((c) => c?.id == cardId, orElse: () => null);
                              if (target != null) {
                                _undoManager.pushCommand(
                                  RemoveCardCommand(target),
                                  execute: true,
                                  note: note,
                                );
                                setState(() {
                                  if (_selectedCardId == cardId) _selectedCardId = null;
                                });
                                WorkspaceStorageService.instance.scheduleAutoSave(note);
                              }
                            },
                            onDuplicateCard: (card) {
                              final dup = card.copyWith(
                                id: 'card_${DateTime.now().millisecondsSinceEpoch}',
                                x: card.x + 30,
                                y: card.y + 30,
                              );
                              _undoManager.pushCommand(
                                AddCardCommand(dup),
                                execute: true,
                                note: note,
                              );
                              setState(() {
                                _selectedCardId = dup.id;
                              });
                              WorkspaceStorageService.instance.scheduleAutoSave(note);
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
                  top: math.max(16, _selectionState.bounds!.top * _zoomScale + _panOffset.dy - 50),
                  left: math.max(16, (_selectionState.bounds!.center.dx * _zoomScale + _panOffset.dx) - 95),
                  child: SelectionActionBar(
                    availableColors: _penSlots.map((s) => s.color).toSet().toList(),
                    onDuplicate: _duplicateSelectedStrokes,
                    onChangeColor: _changeSelectedStrokesColor,
                    onRotate90: () => _rotateSelectedStrokesBy(math.pi / 2.0),
                    onRotatePanStart: _onRotatePanStart,
                    onRotatePanUpdate: _onRotatePanUpdate,
                    onRotatePanEnd: _onRotatePanEnd,
                    onDelete: _deleteSelectedStrokes,
                    onDeselect: _deselect,
                  ),
                ),

              // 3. Visualização de Configurações (SettingsPageView no Canvas com Fundo Unificado)
              if (_isSettingsOpen)
                Positioned.fill(
                  top: 0,
                  left: _isSidebarOpen ? 348 : 0,
                  right: 0,
                  bottom: 0,
                  child: SettingsPageView(
                    activeCategory: _activeSettingsCategory,
                    settings: _settings,
                    onUpdateSettings: _updateSettings,
                    onResetCategory: _resetSettingsCategory,
                  ),
                ),

              // 4. TabBar Superior (Alternância fluida entre Abas de Notas e Abas de Configurações)
              Positioned(
                top: 24,
                left: _isSidebarOpen ? 348 : 0,
                right: 140,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _isSettingsOpen
                        ? SettingsTabBar(
                            key: const ValueKey('settings_tab_bar'),
                            activeCategory: _activeSettingsCategory,
                            onSelectCategory: (cat) {
                              setState(() {
                                _activeSettingsCategory = cat;
                              });
                            },
                            onBackToNotes: () {
                              setState(() {
                                _isSettingsOpen = false;
                              });
                            },
                          )
                        : NoteTabBar(
                            key: const ValueKey('note_tab_bar'),
                            activeNoteIds: _activeNoteIds,
                            noteTitles: noteTitles,
                            selectedNoteId: _selectedNoteId,
                            isSidebarOpen: _isSidebarOpen,
                            onOpenSettings: () {
                              setState(() {
                                _isSettingsOpen = true;
                              });
                            },
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
              ),

              // 4.1 HUD de Zoom no Topo Superior Direito
              if (!_isSettingsOpen)
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

              // 4.5 Barreira transparente para fechar o Menu do Grid ao clicar fora
              if (_isGridMenuOpen)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      setState(() {
                        _isGridMenuOpen = false;
                      });
                    },
                    child: Container(color: Colors.transparent),
                  ),
                ),

              // 5. Sub-Barras Flutuantes e Menu do Grid Unificados em Row com AnimatedSize (Zero Sobreposição Garantida)
              if (!_isSettingsOpen &&
                  ((_activeTool == 'pen' && _isPenSubBarVisible) ||
                      _activeTool == 'select' ||
                      _activeTool == 'eraser' ||
                      _activeTool == 'shapes' ||
                      _isMeasurementSubBarVisible ||
                      _rulerState.isVisible ||
                      _protractorState.isVisible ||
                      _isCardsSubBarVisible ||
                      _isGridMenuOpen))
                Positioned(
                  bottom: 96,
                  left: _isSidebarOpen ? 348 : 0,
                  right: 0,
                  child: Center(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.bottomCenter,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // 1. Sub-Barra de Slots de Caneta
                          if (_activeTool == 'pen' && _isPenSubBarVisible)
                            PenSlotsSubBar(
                              isVisible: true,
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

                          // 2. Sub-Barra de Seleção
                          if (_activeTool == 'select')
                            SelectionSubBar(
                              isVisible: true,
                              activeType: _selectionType,
                              onSelectType: (newType) {
                                setState(() {
                                  _selectionType = newType;
                                  _selectionState = SelectionState.empty();
                                });
                              },
                            ),

                          // 3. Sub-Barra da Borracha
                          if (_activeTool == 'eraser')
                            EraserSubBar(
                              isVisible: true,
                              activeMode: _eraserConfig.mode,
                              radius: _eraserConfig.radius,
                              eraseHighlighterOnly: _eraserConfig.eraseHighlighterOnly,
                              onSelectMode: (mode) {
                                setState(() {
                                  _eraserConfig = _eraserConfig.copyWith(mode: mode);
                                });
                              },
                              onChangeRadius: (rad) {
                                setState(() {
                                  _eraserConfig = _eraserConfig.copyWith(radius: rad);
                                });
                              },
                              onToggleHighlighterOnly: (val) {
                                setState(() {
                                  _eraserConfig = _eraserConfig.copyWith(eraseHighlighterOnly: val);
                                });
                              },
                            ),

                          // 4. Sub-Barra de Formas Geométricas
                          if (_activeTool == 'shapes')
                            ShapesSubBar(
                              isVisible: true,
                              activeShape: _activeShapeType,
                              onSelectShape: (shape) {
                                setState(() {
                                  _activeShapeType = shape;
                                });
                              },
                            ),

                          // 5. Sub-Barra de Instrumentos de Medição STEM (Régua e Transferidor - Fase 5.2)
                          if (_isMeasurementSubBarVisible || _rulerState.isVisible || _protractorState.isVisible)
                            RulerSubBar(
                              isVisible: true,
                              activeTool: _activeMeasurementTool,
                              onSelectTool: (tool) {
                                setState(() {
                                  _activeMeasurementTool = tool;
                                  final viewportCenter = (-_panOffset + Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2)) / _zoomScale;
                                  if (tool == MeasurementToolType.ruler) {
                                    _protractorState = _protractorState.copyWith(isVisible: false);
                                    _rulerState = _rulerState.copyWith(
                                      isVisible: true,
                                      center: _rulerState.isVisible ? null : viewportCenter,
                                    );
                                  } else {
                                    _rulerState = _rulerState.copyWith(isVisible: false);
                                    _protractorState = _protractorState.copyWith(
                                      isVisible: true,
                                      center: _protractorState.isVisible ? null : viewportCenter,
                                    );
                                  }
                                });
                                _rulerUpdateNotifier.value++;
                              },
                            ),

                          // 5.1 Sub-Barra de Criação de Cards no Canvas (Fase 11)
                          if (_isCardsSubBarVisible)
                            CardsSubBar(
                              isVisible: true,
                              activePreset: _activeCardPreset,
                              onSelectPreset: (preset) {
                                setState(() {
                                  _activeCardPreset = preset;
                                  _activeTool = 'card_insert';
                                  _selectionState = SelectionState.empty();
                                });
                              },
                            ),

                          // Espaçador dinâmico entre a Sub-Barra ativa e o Menu do Grid
                          if (((_activeTool == 'pen' && _isPenSubBarVisible) ||
                                  _activeTool == 'select' ||
                                  _activeTool == 'eraser' ||
                                  _activeTool == 'shapes' ||
                                  _isMeasurementSubBarVisible ||
                                  _rulerState.isVisible ||
                                  _protractorState.isVisible ||
                                  _isCardsSubBarVisible) &&
                              _isGridMenuOpen)
                            const SizedBox(width: 14),

                          // 6. Menu Flutuante de Fundo / Grid com Animação Fluida Pop & Fade
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 240),
                            reverseDuration: const Duration(milliseconds: 180),
                            switchInCurve: Curves.easeOutBack,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(begin: 0.88, end: 1.0).animate(animation),
                                  alignment: Alignment.bottomRight,
                                  child: child,
                                ),
                              );
                            },
                            child: _isGridMenuOpen
                                ? GridMenuCard(
                                    key: const ValueKey('grid_menu_open'),
                                    currentBackground: _currentBackground,
                                    onSelectBackground: (newBg) {
                                      setState(() {
                                        _currentBackground = newBg;
                                        _isGridMenuOpen = false;
                                      });
                                    },
                                  )
                                : const SizedBox.shrink(key: ValueKey('grid_menu_closed')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 7. Barra de Ferramentas / ToolbarPill (Inferior)
              if (!_isSettingsOpen)
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
                    isShapesActive: _activeTool == 'shapes',
                    isSelectActive: _activeTool == 'select',
                    isLaserActive: _activeTool == 'laser',
                    isRulerActive: _isMeasurementSubBarVisible || _rulerState.isVisible || _protractorState.isVisible,
                    isCardsActive: _isCardsSubBarVisible || _activeCardPreset != null,
                    onToggleCards: () {
                      setState(() {
                        _isCardsSubBarVisible = !_isCardsSubBarVisible;
                        if (!_isCardsSubBarVisible) _activeCardPreset = null;
                        _isPenSubBarVisible = false;
                        _isGridMenuOpen = false;
                        _isMeasurementSubBarVisible = false;
                      });
                    },
                    selectionType: _selectionType,
                    activePenPreset: _activePenPreset,
                    canUndo: canUndo,
                    canRedo: canRedo,
                    onUndo: _undo,
                    onRedo: _redo,
                    isGridMenuOpen: _isGridMenuOpen,
                    onToggleGridMenu: () {
                      setState(() {
                        _isGridMenuOpen = !_isGridMenuOpen;
                      });
                    },
                    onToggleRuler: () {
                      setState(() {
                        final bool isAnyMeasurementActive = _rulerState.isVisible || _protractorState.isVisible;
                        if (isAnyMeasurementActive) {
                          // Se já está ativo, clicar na toolbar fecha as ferramentas e a subbarra
                          _isMeasurementSubBarVisible = false;
                          _rulerState = _rulerState.copyWith(isVisible: false);
                          _protractorState = _protractorState.copyWith(isVisible: false);
                        } else {
                          // Se está fechado, abre a subbarra e exibe a ferramenta ativa atual
                          _isMeasurementSubBarVisible = true;
                          _isPenSubBarVisible = false;
                          _isCardsSubBarVisible = false;
                          _isGridMenuOpen = false;
                          final viewportCenter = (-_panOffset + Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2)) / _zoomScale;
                          if (_activeMeasurementTool == MeasurementToolType.ruler) {
                            _protractorState = _protractorState.copyWith(isVisible: false);
                            _rulerState = _rulerState.copyWith(
                              isVisible: true,
                              center: viewportCenter,
                            );
                          } else {
                            _rulerState = _rulerState.copyWith(isVisible: false);
                            _protractorState = _protractorState.copyWith(
                              isVisible: true,
                              center: viewportCenter,
                            );
                          }
                        }
                      });
                      _rulerUpdateNotifier.value++;
                    },
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
                        _isPenSubBarVisible = false;
                        _selectionState = SelectionState.empty();
                      });
                    },
                    onSelectShapes: () {
                      setState(() {
                        _activeTool = 'shapes';
                        _isPenSubBarVisible = false;
                        _selectionState = SelectionState.empty();
                      });
                    },
                    onSelectTool: () {
                      setState(() {
                        _activeTool = 'select';
                        _isPenSubBarVisible = false;
                      });
                    },
                    onSelectLaser: () {
                      setState(() {
                        _activeTool = 'laser';
                        _isPenSubBarVisible = false;
                        _selectionState = SelectionState.empty();
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

              // 8. Sidebar Esquerda de Notas & Cadernos
              NoteSidebar(
                isOpen: _isSidebarOpen,
                selectedNoteId: _selectedNoteId,
                onSelectNote: (selectedNote) {
                  setState(() {
                    if (!_notes.any((n) => n.id == selectedNote.id)) {
                      _notes.add(selectedNote);
                    }
                    if (!_activeNoteIds.contains(selectedNote.id)) {
                      _activeNoteIds.add(selectedNote.id);
                    }
                    _selectedNoteId = selectedNote.id;
                    _panNotifier.value = Offset(selectedNote.panX, selectedNote.panY);
                    _zoomNotifier.value = selectedNote.zoomScale;
                    _strokesVersion++;
                    _committedStrokesNotifier.value++;
                  });
                },
                onAddNote: () async {
                  final note = await WorkspaceStorageService.instance.createNote(
                    title: "Nova Nota ${_notes.length + 1}",
                  );
                  setState(() {
                    _notes.add(note);
                    _activeNoteIds.add(note.id);
                    _selectedNoteId = note.id;
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
    
    final eraserRadius = _eraserConfig.radius / _zoomScale;
    final eraserRadiusSq = eraserRadius * eraserRadius;

    final candidateIds = note.spatialIndex.queryPoint(canvasPoint, eraserRadius);
    final candidateStrokes = candidateIds
        .map((id) => note.getStroke(id))
        .whereType<InkStroke>()
        .where((s) => !_eraserConfig.eraseHighlighterOnly || s.toolType == InkToolType.highlighter)
        .toList();

    if (candidateStrokes.isEmpty) return;

    if (_eraserConfig.mode == EraserMode.stroke) {
      // 1. Borracha de Traço Inteiro
      final toRemove = candidateStrokes
          .where((stroke) => SelectionGeometry.isPointNearStroke(canvasPoint, stroke, eraserRadius))
          .toList();

      if (toRemove.isNotEmpty) {
        _undoManager.pushCommand(RemoveStrokesCommand(toRemove), execute: true, note: note);
        _strokesVersion++;
        _committedStrokesNotifier.value++;
      }
    } else {
      // 2. Borracha de Precisão / Segmentação
      final removedOld = <InkStroke>[];
      final addedNew = <InkStroke>[];

      for (final stroke in candidateStrokes) {
        if (!SelectionGeometry.isPointNearStroke(canvasPoint, stroke, eraserRadius)) {
          continue;
        }

        final segments = <List<StrokePoint>>[];
        var currentSegment = <StrokePoint>[];

        for (final p in stroke.points) {
          final distSq = (p.point - canvasPoint).distanceSquared;
          if (distSq >= eraserRadiusSq) {
            currentSegment.add(p);
          } else {
            if (currentSegment.isNotEmpty) {
              segments.add(currentSegment);
              currentSegment = <StrokePoint>[];
            }
          }
        }
        if (currentSegment.isNotEmpty) {
          segments.add(currentSegment);
        }

        // Se nenhum ponto foi cortado, ignora
        if (segments.length == 1 && segments[0].length == stroke.points.length) {
          continue;
        }

        removedOld.add(stroke);

        for (final seg in segments) {
          if (seg.isEmpty) continue;
          final newId = '${stroke.id}_seg_${_globalCounter++}';
          final bounds = SelectionGeometry.computePointsBounds(seg, stroke.strokeWidth);
          addedNew.add(InkStroke(
            id: newId,
            points: seg,
            color: stroke.color,
            strokeWidth: stroke.strokeWidth,
            toolType: stroke.toolType,
            enablePressure: stroke.enablePressure,
            boundingBox: bounds,
          ));
        }
      }

      if (removedOld.isNotEmpty) {
        note.removeStrokes(removedOld);
        if (addedNew.isNotEmpty) {
          note.addAllStrokes(addedNew);
        }
        _strokesVersion++;
        _committedStrokesNotifier.value++;
      }
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

/// Painter do Cursor Halo da Borracha
class _EraserHaloPainter extends CustomPainter {
  final Offset mousePosition;
  final double radius;

  _EraserHaloPainter({required this.mousePosition, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = MoscaroTokens.auroraBlue.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = MoscaroTokens.auroraBlue.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final centerDotPaint = Paint()
      ..color = MoscaroTokens.auroraBlue
      ..style = PaintingStyle.fill;

    canvas.drawCircle(mousePosition, radius, fillPaint);
    canvas.drawCircle(mousePosition, radius, borderPaint);
    canvas.drawCircle(mousePosition, 2.0, centerDotPaint);
  }

  @override
  bool shouldRepaint(covariant _EraserHaloPainter oldDelegate) {
    return oldDelegate.mousePosition != mousePosition || oldDelegate.radius != radius;
  }
}
