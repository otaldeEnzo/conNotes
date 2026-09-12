import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'moscaro_window_title_bar.dart';
import '../controllers/canvas_input_context.dart';
import 'canvas_input_router.dart';
import 'canvas_layer_stack.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import 'canvas_dot_grid_painter.dart';
import 'toolbar_pill.dart';
import 'pen_slots_sub_bar.dart';
import 'ai_sidebar.dart';
import 'note_tab_bar.dart';
import 'note_sidebar.dart';
import 'note_models.dart';
import 'ink_models.dart';
import 'canvas_layers.dart';
import 'zoom_hud_pill.dart';
import 'selection_models.dart';
import 'selection_overlay_painter.dart';
import 'selection_action_bar.dart';
import 'selection_sub_bar.dart';
import 'eraser_sub_bar.dart';
import 'shapes_sub_bar.dart';
import 'grid_menu_card.dart';
import 'laser_pointer.dart';
import 'smart_shapes.dart';
import 'stem_ruler_model.dart';
import 'stem_protractor_model.dart';
import 'ruler_sub_bar.dart';
import 'settings_models.dart';
import 'settings_tab_bar.dart';
import '../theme/moscaro_theme_controller.dart';
import '../services/settings_service.dart';
import '../services/workspace_storage_service.dart';
import 'undo_commands.dart';
import '../dev_hub/dev_hub_server.dart';
import '../models/canvas_card_model.dart';
import 'media_lightbox_modal.dart';
import 'cards_sub_bar.dart';
import '../models/ai_message_model.dart';
import '../models/ai_provider_models.dart';
import '../services/ai_service_bridge.dart';
import 'cards_debug_overlay.dart';
import '../services/cards_telemetry_controller.dart';
import 'package:file_picker/file_picker.dart';
import '../services/media_compression_service.dart';
import 'canvas_area_selection_overlay.dart';
import 'debug/performance_debug_hud.dart';
import '../services/diagnostics_override_controller.dart';
import '../services/vm_service_client.dart';
import '../services/canvas_clipboard_service.dart';
import '../services/canvas_media_ocr_service.dart';
import '../controllers/pen_slots_controller.dart';
import 'settings_overlay_view.dart';

class CanvasHomeScreen extends StatefulWidget {
  final NoteDocument? initialNote;
  final List<String>? initialOpenNoteIds;
  final void Function(List<String> activeTabIds)? onBackToHome;

  const CanvasHomeScreen({
    super.key,
    this.initialNote,
    this.initialOpenNoteIds,
    this.onBackToHome,
  });

  @override
  State<CanvasHomeScreen> createState() => _CanvasHomeScreenState();
}

class _CanvasHomeScreenState extends State<CanvasHomeScreen> with TickerProviderStateMixin implements CanvasInputContext {
  // Estado de Documentos e Notas
  final List<NoteDocument> _notes = [];
  final List<String> _activeNoteIds = [];
  String? _selectedNoteId;
  final ValueNotifier<bool> _isSidebarOpenNotifier = ValueNotifier(false);
  bool get _isSidebarOpen => _isSidebarOpenNotifier.value;
  set _isSidebarOpen(bool val) => _isSidebarOpenNotifier.value = val;

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
  final ValueNotifier<String> _activeToolNotifier = ValueNotifier('pen');
  String get _activeTool => _activeToolNotifier.value;
  set _activeTool(String val) => _activeToolNotifier.value = val;
  final ValueNotifier<bool> _isPenSubBarVisibleNotifier = ValueNotifier(true);
  bool get _isPenSubBarVisible => _isPenSubBarVisibleNotifier.value;
  set _isPenSubBarVisible(bool val) => _isPenSubBarVisibleNotifier.value = val;

  List<PenSlotPreset> get _penSlots => PenSlotsController.instance.slots;
  String get _activeSlotId => PenSlotsController.instance.activeSlotId;
  set _activeSlotId(String id) => PenSlotsController.instance.selectSlot(id);

  // Histórico Universal de Desfazer/Refazer (Command Pattern)
  final AppUndoManager _undoManager = AppUndoManager();
  int _strokesVersion = 0;

  final ValueNotifier<bool> _isAIOpenNotifier = ValueNotifier(false);
  bool get _isAIOpen => _isAIOpenNotifier.value;
  set _isAIOpen(bool val) => _isAIOpenNotifier.value = val;
  final List<AiMessage> _aiMessages = [];
  bool _isAiStreaming = false;
  AiModelDefinition _activeAiModel = AiModelDefinition.allModels.first;
  AiScopeType _activeAiScope = AiScopeType.activeNote;
  bool _isDebugCardsOverlayVisible = false;
  final GlobalKey<AiSidebarState> _aiSidebarKey = GlobalKey<AiSidebarState>();
  final GlobalKey _canvasRepaintBoundaryKey = GlobalKey();
  bool _isSelectingAreaForAi = false;

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
  ValueNotifier<int> get _strokeUpdateNotifier => _committedStrokesNotifier;
  final ValueNotifier<int> _canvasUpdateNotifier = ValueNotifier(0);
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
  final ValueNotifier<bool> _isMeasurementSubBarVisibleNotifier = ValueNotifier(false);
  bool get _isMeasurementSubBarVisible => _isMeasurementSubBarVisibleNotifier.value;
  set _isMeasurementSubBarVisible(bool val) => _isMeasurementSubBarVisibleNotifier.value = val;
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

  final ValueNotifier<bool> _isGridMenuOpenNotifier = ValueNotifier(false);
  bool get _isGridMenuOpen => _isGridMenuOpenNotifier.value;
  set _isGridMenuOpen(bool val) => _isGridMenuOpenNotifier.value = val;
  // Estado dos Cards do Canvas (Fase 11)
  final ValueNotifier<bool> _isCardsSubBarVisibleNotifier = ValueNotifier(false);
  bool get _isCardsSubBarVisible => _isCardsSubBarVisibleNotifier.value;
  set _isCardsSubBarVisible(bool val) => _isCardsSubBarVisibleNotifier.value = val;
  CardTypePreset? _activeCardPreset;
  final ValueNotifier<String?> _selectedCardIdNotifier = ValueNotifier(null);
  String? get _selectedCardId => _selectedCardIdNotifier.value;
  set _selectedCardId(String? val) => _selectedCardIdNotifier.value = val;
  double _smoothedPressure = 0.6;
  int _lastPointerTimestampMs = 0;
  Offset? _lastPointerCanvasPoint;

  // Interação (Renderização Híbrida)
  final ValueNotifier<bool> _isInteractingNotifier = ValueNotifier(false);
  Timer? _interactionTimer;

  // --- CanvasInputContext Implementation ---
  @override
  NoteDocument? get currentNote => _currentNote;
  @override
  String get activeTool => _activeTool;
  @override
  SelectionState get selectionState => _selectionState;
  @override
  SelectionType get selectionType => _selectionType;
  @override
  Offset get panOffset => _panOffset;
  @override
  double get zoomScale => _zoomScale;
  @override
  Offset? get mousePos => _mousePosNotifier.value;
  @override
  double get smoothedPressure => _smoothedPressure;
  @override
  int get lastPointerTimestampMs => _lastPointerTimestampMs;
  @override
  Offset? get lastPointerCanvasPoint => _lastPointerCanvasPoint;
  @override
  ShapeType get activeShapeType => _activeShapeType;
  @override
  bool get isGridMenuOpen => _isGridMenuOpen;
  @override
  StemRulerState get rulerState => _rulerState;
  @override
  StemProtractorState get protractorState => _protractorState;
  @override
  String? get selectedCardId => _selectedCardId;

  @override
  LaserPointerEngine get laserEngine => _laserEngine;

  @override
  void insertCardAt(Offset canvasPoint) {
    _insertCardAtPosition(canvasPoint, preset: _activeCardPreset);
  }

  @override
  void updateSelectionState(SelectionState state) {
    _selectionState = state;
    _selectionUpdateNotifier.value++;
  }
  @override
  void triggerSelectionUpdate() {
    _selectionUpdateNotifier.value++;
  }
  @override
  void setInteracting() {
    _setInteracting();
  }
  @override
  void triggerHapticFeedback() {}
  @override
  void updateSmoothedPressure(double pressure) {
    _smoothedPressure = pressure;
  }
  @override
  void updatePointerInfo(int timestampMs, Offset? canvasPoint) {
    _lastPointerTimestampMs = timestampMs;
    _lastPointerCanvasPoint = canvasPoint;
  }
  @override
  void pushCommand(UndoCommand command, {required bool execute, NoteDocument? note}) {
    if (note != null) {
      _undoManager.pushCommand(command, execute: execute, note: note);
    }
  }
  @override
  void scheduleAutoSave() {
    if (_currentNote != null) {
      WorkspaceStorageService.instance.scheduleAutoSave(_currentNote!);
    }
  }
  @override
  void incrementStrokesVersion() {
    _strokesVersion++;
  }
  @override
  void incrementCommittedStrokes() {
    _committedStrokesNotifier.value++;
  }
  @override
  void selectCard(String? id) {
    if (_selectedCardId != id) {
      setState(() {
        _selectedCardId = id;
      });
    }
  }
  @override
  void hideUIElementsOnInteraction() {
    if (_isCardsSubBarVisible || _isGridMenuOpen || _isSettingsOpen) {
      _isCardsSubBarVisible = false;
        _isGridMenuOpen = false;
        _isSettingsOpen = false;
    }
  }
  // -----------------------------------------

  void _setInteracting() {
    _isInteractingNotifier.value = true;
    _interactionTimer?.cancel();
    _interactionTimer = Timer(const Duration(milliseconds: 150), () {
      _isInteractingNotifier.value = false;
    });
  }

  // Clipboard gerenciado pelo CanvasClipboardService isolado
  int _globalCounter = 0;
  Timer? _telemetrySyncTimer;
  final Map<String, InkStroke> _pendingErasures = {};
  bool _eraseCommitScheduled = false;

  // Estado das Configurações do conNotes (Fase 6)
  AppSettingsState _settings = AppSettingsState.defaults();
  final ValueNotifier<bool> _isSettingsOpenNotifier = ValueNotifier(false);
  bool get _isSettingsOpen => _isSettingsOpenNotifier.value;
  set _isSettingsOpen(bool val) => _isSettingsOpenNotifier.value = val;
  final ValueNotifier<SettingsCategory> _activeSettingsCategoryNotifier = ValueNotifier(SettingsCategory.visual);
  SettingsCategory get _activeSettingsCategory => _activeSettingsCategoryNotifier.value;
  set _activeSettingsCategory(SettingsCategory val) => _activeSettingsCategoryNotifier.value = val;

  void _loadSavedSettings() async {
    final loaded = await SettingsService.instance.loadSettings();
    PenSlotsController.instance.initialize(loaded);
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

    NoteDocument? defaultNote;
    if (allNotes.isEmpty) {
      defaultNote = await WorkspaceStorageService.instance.createNote(title: 'Anotações STEM');
    }

    if (mounted) {
      setState(() {
        if (allNotes.isNotEmpty) {
          _notes.clear();
          _notes.addAll(allNotes);
          final target = widget.initialNote ?? allNotes.first;
          _activeNoteIds.clear();
          if (widget.initialOpenNoteIds != null && widget.initialOpenNoteIds!.isNotEmpty) {
            for (final id in widget.initialOpenNoteIds!) {
              if (allNotes.any((n) => n.id == id) && !_activeNoteIds.contains(id)) {
                _activeNoteIds.add(id);
              }
            }
          }
          if (!_activeNoteIds.contains(target.id)) {
            _activeNoteIds.add(target.id);
          }
          _selectedNoteId = target.id;
          _panNotifier.value = Offset(target.panX, target.panY);
          _zoomNotifier.value = target.zoomScale;
        } else if (defaultNote != null) {
          _notes.clear();
          _notes.add(defaultNote);
          _activeNoteIds.clear();
          _activeNoteIds.add(defaultNote.id);
          _selectedNoteId = defaultNote.id;
        }
        _settings = loaded;
      });
    }
  }

  void _updateSettings(AppSettingsState newSettings) {
    final themesToKeep = newSettings.customThemes.isNotEmpty
        ? newSettings.customThemes
        : MoscaroThemeController.instance.customThemes;
    final mergedSettings = newSettings.copyWith(customThemes: themesToKeep);

    MoscaroTokens.blurSigma = mergedSettings.blurSigma;
    MoscaroThemeController.instance.initialize(
      themeId: mergedSettings.activeThemeId,
      bgModeId: mergedSettings.customBgMode,
      customSolidHex: mergedSettings.customBgColorHex,
      customGradStartHex: mergedSettings.customGradStartHex,
      customGradEndHex: mergedSettings.customGradEndHex,
      textureId: mergedSettings.customTextureType,
      imagePath: mergedSettings.customImagePath,
      imageOpacity: mergedSettings.customImageOpacity,
      customThemes: themesToKeep,
    );
    setState(() {
      _settings = mergedSettings;
      if (_currentNote != null) {
        _currentNote?.pictureCache.invalidatePictures();
      }
      _committedStrokesNotifier.value++;
      _canvasUpdateNotifier.value++;
    });
    SettingsService.instance.saveSettings(mergedSettings);
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
          openAiApiKey: def.openAiApiKey,
          claudeApiKey: def.claudeApiKey,
          ollamaEndpointUrl: def.ollamaEndpointUrl,
          activeAiModelId: def.activeAiModelId,
        );
        break;
    }
    _updateSettings(updated);
  }

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();

    _laserEngine.init(this);
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

  void _switchToNote(NoteDocument targetNote) {
    if (!_notes.any((n) => n.id == targetNote.id)) {
      _notes.add(targetNote);
    }
    if (!_activeNoteIds.contains(targetNote.id)) {
      _activeNoteIds.add(targetNote.id);
    }
    _selectedNoteId = targetNote.id;
    _selectedCardId = null;
    _selectionState = SelectionState.empty();
    _activeStroke = null;
    _panNotifier.value = Offset(targetNote.panX, targetNote.panY);
    _zoomNotifier.value = targetNote.zoomScale;
    _currentBackground = targetNote.backgroundType;
    _strokesVersion++;
    _committedStrokesNotifier.value++;
    _selectionUpdateNotifier.value++;
    _undoManager.clear();
  }

  @override
  void didUpdateWidget(covariant CanvasHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialOpenNoteIds != null && widget.initialOpenNoteIds!.isNotEmpty) {
      for (final id in widget.initialOpenNoteIds!) {
        if (!_activeNoteIds.contains(id)) {
          _activeNoteIds.add(id);
        }
      }
    }
    if (widget.initialNote != null && widget.initialNote?.id != _selectedNoteId) {
      setState(() {
        _switchToNote(widget.initialNote!);
      });
    }
  }

  void _handleThemeChanged() {
    _currentNote?.pictureCache.invalidatePictures();
    _strokesVersion++;
    _committedStrokesNotifier.value++;
    _activeStrokeUpdateNotifier.value++;
    _canvasUpdateNotifier.value++;
    if (mounted) {
      setState(() {});
    }
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
    SettingsService.instance.settingsNotifier.removeListener(_handleThemeChanged);
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

      // F2 -> Alternar modo de depuração visual dos cards
      if (event.logicalKey == LogicalKeyboardKey.f2) {
        setState(() {
          _isDebugCardsOverlayVisible = !_isDebugCardsOverlayVisible;
        });
        return true;
      }

      // Se a tela de configurações estiver aberta, não intercepta atalhos de canvas (Ctrl+V, Ctrl+C, etc.), exceto Escape e Ctrl+,
      if (_isSettingsOpen) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          _isSettingsOpen = false;
          return true;
        } else if (event.logicalKey == LogicalKeyboardKey.comma && HardwareKeyboard.instance.isControlPressed) {
          _isSettingsOpen = false;
          return true;
        }
        return false;
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

      if (event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_selectedCardId != null || _selectionState.hasSelection) {
          _deleteSelection();
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
          _isSettingsOpen = !_isSettingsOpen;
          return true;
        } else if (event.logicalKey == LogicalKeyboardKey.keyC) {
          _copy();
          return true;
        } else if (event.logicalKey == LogicalKeyboardKey.keyV) {
          _paste();
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

  void _copy() {
    final note = _currentNote;
    if (note == null) return;
    CanvasClipboardService.instance.copy(
      note: note,
      selectionState: _selectionState,
      selectedCardId: _selectedCardId,
    );
  }

  Future<void> _paste() async {
    final note = _currentNote;
    if (note == null) return;

    final mousePos = _mousePosNotifier.value ?? const Offset(400, 300);
    final canvasMousePos = (mousePos - _panOffset) / _zoomScale;

    final result = await CanvasClipboardService.instance.paste(
      note: note,
      canvasMousePos: canvasMousePos,
      zoomScale: _zoomScale,
      selectionType: _selectionType,
      undoManager: _undoManager,
      ingestStrokesAdaptively: _ingestStrokesAdaptively,
    );

    if (result != null && mounted) {
      setState(() {
        _strokesVersion++;
        _committedStrokesNotifier.value++;
        _activeTool = 'select';
        _isPenSubBarVisible = false;
        _selectedCardId = result.singleSelectedCardId;
        _selectionState = result.newSelectionState;
      });
      _selectionUpdateNotifier.value++;
    }
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

  void _deleteSelection() {
    final note = _currentNote;
    if (note == null) return;

    final commands = <UndoCommand>[];

    // 1. Delete standalone active card
    if (_selectedCardId != null && !_selectionState.hasSelection) {
      final target = note.cards.cast<CanvasCardModel?>().firstWhere((c) => c?.id == _selectedCardId, orElse: () => null);
      if (target != null) {
        commands.add(RemoveCardCommand(target));
      }
    } 
    // 2. Delete multi-selection
    else if (_selectionState.hasSelection) {
      for (final cardId in _selectionState.selectedCardIds) {
        final target = note.cards.cast<CanvasCardModel?>().firstWhere((c) => c?.id == cardId, orElse: () => null);
        if (target != null) {
          commands.add(RemoveCardCommand(target));
        }
      }

      final selectedStrokes = _selectionState.selectedStrokeIds.map((id) => note.getStroke(id)).whereType<InkStroke>().toList();
      if (selectedStrokes.isNotEmpty) {
        commands.add(RemoveStrokesCommand(selectedStrokes));
      }
    }

    if (commands.isEmpty) return;

    DevHubServer.instance.logAction('Deletar Seleção (${commands.length} ações)');

    final finalCommand = commands.length == 1 ? commands.first : BatchCommand(commands);

    setState(() {
      _undoManager.pushCommand(finalCommand, execute: true, note: note);
      _strokesVersion++;
      _committedStrokesNotifier.value++;
      _selectionState = SelectionState.empty();
      _selectedCardId = null;
      _selectionUpdateNotifier.value++;
    });
    
    WorkspaceStorageService.instance.scheduleAutoSave(note);
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
    final match = CardsTelemetryController.detectCardZone(
      cards: cards,
      selectedCardId: selectedCardId,
      canvasPoint: canvasPoint,
    );
    return match.card;
  }

  void _selectAll() {
    final note = _currentNote;
    if (note == null) return;
    if (note.strokes.isEmpty && note.cards.isEmpty) return;

    setState(() {
      final allStrokeIds = note.strokes.map((s) => s.id).toSet();
      final allCardIds = note.cards.map((c) => c.id).toSet();
      
      Rect? combinedBounds;
      if (note.strokes.isNotEmpty) {
        combinedBounds = SelectionGeometry.computeCombinedBounds(note.strokes);
      }
      
      // We could compute bounds for cards too if we want a unified bounding box
      if (note.cards.isNotEmpty) {
        double left = double.infinity, top = double.infinity;
        double right = -double.infinity, bottom = -double.infinity;
        for (final c in note.cards) {
          if (c.x < left) left = c.x;
          if (c.y < top) top = c.y;
          if (c.x + c.width > right) right = c.x + c.width;
          if (c.y + c.height > bottom) bottom = c.y + c.height;
        }
        final cardsRect = Rect.fromLTRB(left, top, right, bottom);
        if (combinedBounds != null) {
          combinedBounds = combinedBounds.expandToInclude(cardsRect);
        } else {
          combinedBounds = cardsRect;
        }
      }

      _activeTool = 'select';
      _isPenSubBarVisible = false;
      _selectionState = SelectionState(
        type: _selectionType,
        selectedStrokeIds: allStrokeIds,
        selectedCardIds: allCardIds,
        bounds: combinedBounds,
      );

      // We might want to keep the single _selectedCardId for backward compatibility
      // of showing the single card floating bar, or maybe clear it if multiple are selected.
      if (allCardIds.length == 1) {
        _selectedCardId = allCardIds.first;
      } else {
        _selectedCardId = null; 
      }
    });

    if (note.strokes.isNotEmpty || note.cards.isNotEmpty) {
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

  Future<void> _insertCardAtPosition(Offset canvasPoint, {CardTypePreset? preset}) async {
    final note = _currentNote;
    if (note == null) return;

    if (preset == CardTypePreset.media) {
      try {
        final result = await FilePickerPlatform.instance.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
        );
        if (result != null && result.isNotEmpty) {
          final path = result.first.path;
          if (path != null) {
            final bytes = await File(path).readAsBytes();
            final compressed = await MediaCompressionService.compressImageBytes(bytes);
            if (compressed != null) {
              final id = 'card_media_${DateTime.now().millisecondsSinceEpoch}';
              final visualDesiredWidth = 420.0;
              final zoomScaledWidth = visualDesiredWidth / (_zoomScale > 0 ? _zoomScale : 1.0);
              final targetWidth = zoomScaledWidth.clamp(160.0, 1400.0);
              final targetHeight = compressed.aspectRatio > 0 ? (targetWidth / compressed.aspectRatio) : 220.0;
              final newCard = CanvasCardModel(
                id: id,
                cardType: CardType.media,
                title: 'Mídia',
                mediaData: compressed.dataUri,
                originalAspectRatio: compressed.aspectRatio,
                lockAspectRatio: true,
                x: canvasPoint.dx,
                y: canvasPoint.dy,
                width: targetWidth,
                height: targetHeight,
              );
              _undoManager.pushCommand(
                AddCardCommand(newCard),
                execute: true,
                note: note,
              );
              setState(() {
                _selectedCardId = newCard.id;
                _activeTool = 'select';
                _activeCardPreset = null;
                _isCardsSubBarVisible = false;
              });
              WorkspaceStorageService.instance.scheduleAutoSave(note);
              DevHubServer.instance.logAction('Novo Card de Mídia (${compressed.byteSize ~/ 1024} KB)');
            }
          }
        }
      } catch (e) {
        debugPrint('[_insertCardAtPosition] Erro ao selecionar mídia: $e');
      }
      return;
    }

    final id = 'card_${DateTime.now().millisecondsSinceEpoch}';
    const title = 'Card STEM';
    const double width = 360.0;
    const double height = 320.0;

    final newCard = CanvasCardModel(
      id: id,
      x: canvasPoint.dx,
      y: canvasPoint.dy,
      width: width,
      height: height,
      title: title,
      content: '',
    );

    _undoManager.pushCommand(
      AddCardCommand(newCard),
      execute: true,
      note: note,
    );

    setState(() {
      _selectedCardId = newCard.id;
      _activeTool = 'select';
      _activeCardPreset = null;
      _isCardsSubBarVisible = false;
    });

    WorkspaceStorageService.instance.scheduleAutoSave(note);
    DevHubServer.instance.logAction('Novo Card (${newCard.title})');
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
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () {
          _isSettingsOpen = !_isSettingsOpen;
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_isSettingsOpen) {
            _isSettingsOpen = false;
          } else {
            _deselect();
          }
        },
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent || event is KeyRepeatEvent) {
            // Se o foco estiver em um campo de texto (Sidebar de IA, cards, settings, etc.),
            // ignore completamente o atalho para que o backspace/delete atue apenas no campo de texto.
            final primaryFocus = FocusManager.instance.primaryFocus;
            final isEditingText = globalIsEditingText ||
                (primaryFocus != null &&
                    (primaryFocus.context?.widget is EditableText ||
                     primaryFocus.context?.findAncestorWidgetOfExactType<EditableText>() != null ||
                     primaryFocus.context?.findAncestorWidgetOfExactType<TextField>() != null ||
                     (primaryFocus.hasFocus &&
                         (primaryFocus.debugLabel?.contains('EditableText') == true ||
                          primaryFocus.debugLabel?.contains('TextField') == true))));

            if (isEditingText) {
              return KeyEventResult.ignored;
            }
            
            final note = _currentNote;
            if (event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace) {
              if (_selectedCardId != null || _selectionState.hasSelection) {
                _deleteSelection();
                return KeyEventResult.handled;
              }
            }
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          body: DragTarget<AiMessage>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) {
              _handleInsertAiMessageIntoCanvas(details.data, details.offset);
            },
            builder: (context, candidateData, rejectedData) {
              return Stack(
                children: [
              // 1. Fundo do Canvas Infinito & Traços (Isolado com RepaintBoundary)
              RepaintBoundary(
                key: _canvasRepaintBoundaryKey,
                child: MouseRegion(
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
                child: CanvasInputRouter(
                    canvasContext: this,
                    activePenPreset: _activePenPreset,
                    activeStrokeUpdateNotifier: _activeStrokeUpdateNotifier,
                    selectionUpdateNotifier: _selectionUpdateNotifier,
                    panNotifier: _panNotifier,
                    zoomNotifier: _zoomNotifier,
                    dragPictureCache: _dragPictureCache,
                    onScheduleBounceCheck: _scheduleBounceCheck,
                    onCommitStroke: (newStroke) {
                      final n = _currentNote;
                      if (n != null) {
                        InkStroke strokeToAdd = newStroke;
                        // Se >= 50% dos pontos do traço estiverem dentro da área de imagem da mídia (descontando cabeçalho de 28px)
                        if (newStroke.points.isNotEmpty) {
                          for (final card in n.cards) {
                            if (card.cardType == CardType.media) {
                              final imgRect = Rect.fromLTWH(
                                card.x,
                                card.y + 28.0,
                                card.width,
                                math.max(1.0, card.height - 28.0),
                              );
                              int pointsInside = 0;
                              for (final p in newStroke.points) {
                                if (imgRect.contains(p.point)) {
                                  pointsInside++;
                                }
                              }
                              final overlapRatio = pointsInside / newStroke.points.length;
                              if (overlapRatio >= 0.5) {
                                strokeToAdd = newStroke.copyWith(parentCardId: card.id);
                                if (!card.attachedStrokeIds.contains(newStroke.id)) {
                                  final cardIdx = n.cards.indexOf(card);
                                  n.cards[cardIdx] = card.copyWith(
                                    attachedStrokeIds: [...card.attachedStrokeIds, newStroke.id],
                                  );
                                }
                                break;
                              }
                            }
                          }
                        }

                        n.addStroke(strokeToAdd);
                        _undoManager.pushCommand(
                          AddStrokeCommand(strokeToAdd),
                          execute: false,
                          note: n,
                        );
                        _strokesVersion++;
                        _strokeUpdateNotifier.value++;
                        _committedStrokesNotifier.value++;
                        _canvasUpdateNotifier.value++;
                        setState(() {});
                        WorkspaceStorageService.instance.scheduleAutoSave(n);
                      }
                    },
                    builder: (context, getActiveStroke) => CanvasLayerStack(
                      note: _currentNote,
                      backgroundType: _currentBackground,
                      isSettingsOpen: _isSettingsOpen,
                      settings: _settings,
                      panNotifier: _panNotifier,
                      zoomNotifier: _zoomNotifier,
                      mousePosNotifier: _mousePosNotifier,
                      isInteractingNotifier: _isInteractingNotifier,
                      committedStrokesNotifier: _committedStrokesNotifier,
                      activeStrokeUpdateNotifier: _activeStrokeUpdateNotifier,
                      selectionUpdateNotifier: _selectionUpdateNotifier,
                      transientUpdateNotifier: _transientUpdateNotifier,
                      rulerUpdateNotifier: _rulerUpdateNotifier,
                      getActiveStroke: getActiveStroke,
                      selectionState: _selectionState,
                      getSelectionState: () => _selectionState,
                      strokesVersion: _strokesVersion,
                      transientPictureCache: _transientPictureCache,
                      dragPictureCache: _dragPictureCache,
                      laserEngine: _laserEngine,
                      rulerState: _rulerState,
                      protractorState: _protractorState,
                      selectedCardId: _selectedCardId,
                      activeTool: _activeTool,
                      eraserRadius: _eraserConfig.radius,
                      onSyncCardStrokes: _handleSyncCardStrokes,
                      onUpdateCard: (updated) {
                        final n = _currentNote;
                        if (n != null) {
                          final idx = n.cards.indexWhere((c) => c.id == updated.id);
                          if (idx != -1) {
                            final prev = n.cards[idx];
                            final deltaX = updated.x - prev.x;
                            final deltaY = updated.y - prev.y;
                            final angleDelta = updated.rotation - prev.rotation;
                            final isMedia = updated.cardType == CardType.media;
                            final scaleX = prev.width > 0 ? (updated.width / prev.width) : 1.0;
                            final prevMediaH = math.max(1.0, prev.height - 28.0);
                            final updatedMediaH = math.max(1.0, updated.height - 28.0);
                            final scaleY = isMedia
                                ? (updatedMediaH / prevMediaH)
                                : (prev.height > 0 ? (updated.height / prev.height) : 1.0);
                            final turnsDelta = (updated.imageRotationQuarterTurns - prev.imageRotationQuarterTurns) % 4;
                            final flipHChanged = updated.isFlippedHorizontal != prev.isFlippedHorizontal;
                            final flipVChanged = updated.isFlippedVertical != prev.isFlippedVertical;
                            final attachedIds = {...prev.attachedStrokeIds, ...updated.attachedStrokeIds};
                            final mediaCenter = isMedia
                                ? Offset(updated.x + updated.width / 2.0, updated.y + 28.0 + updatedMediaH / 2.0)
                                : updated.center;

                            bool strokesChanged = false;
                            final newStrokes = List.of(n.strokes);

                            // Se for Rotação Interna de 90° (Quarter Turns)
                            if (turnsDelta != 0 && attachedIds.isNotEmpty) {
                              final quarterAngle = turnsDelta * math.pi / 2;
                              final center = mediaCenter;
                              for (int i = 0; i < newStrokes.length; i++) {
                                final s = newStrokes[i];
                                if (attachedIds.contains(s.id)) {
                                  final updatedPoints = s.points.map((p) => p.rotateAround(center, quarterAngle)).toList();
                                  double minX = double.infinity, minY = double.infinity;
                                  double maxX = -double.infinity, maxY = -double.infinity;
                                  for (final p in updatedPoints) {
                                    if (p.point.dx < minX) minX = p.point.dx;
                                    if (p.point.dx > maxX) maxX = p.point.dx;
                                    if (p.point.dy < minY) minY = p.point.dy;
                                    if (p.point.dy > maxY) maxY = p.point.dy;
                                  }
                                  final newBounds = minX.isFinite ? Rect.fromLTRB(minX, minY, maxX, maxY) : null;
                                  newStrokes[i] = s.copyWith(
                                    points: updatedPoints,
                                    boundingBox: newBounds,
                                  )..cachedPath = null;
                                  strokesChanged = true;
                                }
                              }
                            } else if ((flipHChanged || flipVChanged) && attachedIds.isNotEmpty) {
                              // Se for Espelhamento Horizontal ou Vertical (Flips)
                              final center = mediaCenter;
                              for (int i = 0; i < newStrokes.length; i++) {
                                final s = newStrokes[i];
                                if (attachedIds.contains(s.id)) {
                                  final updatedPoints = s.points.map((p) {
                                    double px = p.point.dx;
                                    double py = p.point.dy;
                                    if (flipHChanged) px = 2 * center.dx - px;
                                    if (flipVChanged) py = 2 * center.dy - py;
                                    return StrokePoint(
                                      point: Offset(px, py),
                                      pressure: p.pressure,
                                      tilt: p.tilt,
                                    );
                                  }).toList();

                                  double minX = double.infinity, minY = double.infinity;
                                  double maxX = -double.infinity, maxY = -double.infinity;
                                  for (final p in updatedPoints) {
                                    if (p.point.dx < minX) minX = p.point.dx;
                                    if (p.point.dx > maxX) maxX = p.point.dx;
                                    if (p.point.dy < minY) minY = p.point.dy;
                                    if (p.point.dy > maxY) maxY = p.point.dy;
                                  }
                                  final newBounds = minX.isFinite ? Rect.fromLTRB(minX, minY, maxX, maxY) : null;
                                  newStrokes[i] = s.copyWith(
                                    points: updatedPoints,
                                    boundingBox: newBounds,
                                  )..cachedPath = null;
                                  strokesChanged = true;
                                }
                              }
                            } else {
                              // Caso normal: Arraste (Translação), Resize ou Rotação livre

                              // 1. Translação (quando o card é arrastado)
                              if (deltaX != 0 || deltaY != 0) {
                                final deltaOffset = Offset(deltaX, deltaY);
                                for (int i = 0; i < newStrokes.length; i++) {
                                  final s = newStrokes[i];
                                  if (s.parentCardId == updated.id) {
                                    final newTrans = s.transform + deltaOffset;
                                    newStrokes[i] = s.copyWith(
                                      transform: newTrans,
                                      boundingBox: s.boundingBox?.shift(deltaOffset),
                                    );
                                    strokesChanged = true;
                                  } else if (attachedIds.contains(s.id)) {
                                    final updatedPoints = s.points.map((p) => p.translate(deltaOffset.dx, deltaOffset.dy)).toList();
                                    newStrokes[i] = s.copyWith(
                                      points: updatedPoints,
                                      boundingBox: s.boundingBox?.shift(deltaOffset),
                                    );
                                    strokesChanged = true;
                                  }
                                }
                              }

                              // 2. Redimensionamento / Scale (Bake proporcional a partir da origem do card)
                              if ((scaleX != 1.0 || scaleY != 1.0) && attachedIds.isNotEmpty) {
                                final originX = updated.x;
                                final originY = isMedia ? (updated.y + 28.0) : updated.y;
                                for (int i = 0; i < newStrokes.length; i++) {
                                  final s = newStrokes[i];
                                  if (attachedIds.contains(s.id)) {
                                    final updatedPoints = s.points.map((p) {
                                      final nx = originX + (p.point.dx - originX) * scaleX;
                                      final ny = originY + (p.point.dy - originY) * scaleY;
                                      return StrokePoint(
                                        point: Offset(nx, ny),
                                        pressure: p.pressure,
                                        tilt: p.tilt,
                                      );
                                    }).toList();

                                    double minX = double.infinity, minY = double.infinity;
                                    double maxX = -double.infinity, maxY = -double.infinity;
                                    for (final p in updatedPoints) {
                                      if (p.point.dx < minX) minX = p.point.dx;
                                      if (p.point.dx > maxX) maxX = p.point.dx;
                                      if (p.point.dy < minY) minY = p.point.dy;
                                      if (p.point.dy > maxY) maxY = p.point.dy;
                                    }
                                    final newBounds = minX.isFinite ? Rect.fromLTRB(minX, minY, maxX, maxY) : null;
                                    newStrokes[i] = s.copyWith(
                                      points: updatedPoints,
                                      boundingBox: newBounds,
                                    )..cachedPath = null;
                                    strokesChanged = true;
                                  }
                                }
                              }

                              // 3. Rotação livre do card (ao redor do centro do card)
                              if (angleDelta != 0 && attachedIds.isNotEmpty) {
                                final center = updated.center;
                                for (int i = 0; i < newStrokes.length; i++) {
                                  final s = newStrokes[i];
                                  if (attachedIds.contains(s.id)) {
                                    final updatedPoints = s.points.map((p) => p.rotateAround(center, angleDelta)).toList();
                                    double minX = double.infinity, minY = double.infinity;
                                    double maxX = -double.infinity, maxY = -double.infinity;
                                    for (final p in updatedPoints) {
                                      if (p.point.dx < minX) minX = p.point.dx;
                                      if (p.point.dx > maxX) maxX = p.point.dx;
                                      if (p.point.dy < minY) minY = p.point.dy;
                                      if (p.point.dy > maxY) maxY = p.point.dy;
                                    }
                                    final newBounds = minX.isFinite ? Rect.fromLTRB(minX, minY, maxX, maxY) : null;
                                    newStrokes[i] = s.copyWith(
                                      points: updatedPoints,
                                      boundingBox: newBounds,
                                    )..cachedPath = null;
                                    strokesChanged = true;
                                  }
                                }
                              }
                            }

                            if (strokesChanged) {
                              n.updateAllStrokes(newStrokes);
                              _strokesVersion++;
                              _strokeUpdateNotifier.value++;
                              _canvasUpdateNotifier.value++;
                            }

                            _undoManager.pushCommand(
                              UpdateCardCommand(cardId: updated.id, previousCard: prev, newCard: updated),
                              execute: true,
                              note: n,
                            );
                            setState(() {});
                            WorkspaceStorageService.instance.scheduleAutoSave(n);
                          }
                        }
                      },
                      onSelectCard: (cardId) {
                        if (_selectedCardId == cardId) return;
                        setState(() {
                          _selectedCardId = cardId;
                          _selectionState = SelectionState.empty();
                        });
                      },
                      onDeleteCard: (cardId) {
                        final n = _currentNote;
                        if (n != null) {
                          final target = n.cards.cast<CanvasCardModel?>().firstWhere((c) => c?.id == cardId, orElse: () => null);
                          if (target != null) {
                            if (target.attachedStrokeIds.isNotEmpty) {
                              final strokesToRemove = n.strokes.where((s) => target.attachedStrokeIds.contains(s.id)).toList();
                              if (strokesToRemove.isNotEmpty) {
                                _undoManager.pushCommand(
                                  RemoveStrokesCommand(strokesToRemove),
                                  execute: true,
                                  note: n,
                                );
                                _strokesVersion++;
                                _strokeUpdateNotifier.value++;
                                _canvasUpdateNotifier.value++;
                              }
                            }
                            _undoManager.pushCommand(
                              RemoveCardCommand(target),
                              execute: true,
                              note: n,
                            );
                            setState(() {
                              if (_selectedCardId == cardId) _selectedCardId = null;
                            });
                            WorkspaceStorageService.instance.scheduleAutoSave(n);
                          }
                        }
                      },
                      onDuplicateCard: (card) {
                        final n = _currentNote;
                        if (n != null) {
                          final now = DateTime.now().millisecondsSinceEpoch;
                          final newAttachedIds = <String>[];
                          final clonedStrokes = <InkStroke>[];
                          
                          if (card.attachedStrokeIds.isNotEmpty) {
                            for (int i = 0; i < card.attachedStrokeIds.length; i++) {
                              final oldId = card.attachedStrokeIds[i];
                              final originalStroke = n.getStroke(oldId);
                              if (originalStroke != null) {
                                final newStrokeId = 'stroke_${now}_$i';
                                newAttachedIds.add(newStrokeId);
                                final shiftedPoints = originalStroke.points.map((p) => p.translate(30.0, 30.0)).toList();
                                final shiftedBounds = originalStroke.boundingBox?.shift(const Offset(30.0, 30.0));
                                clonedStrokes.add(originalStroke.copyWith(
                                  id: newStrokeId,
                                  points: shiftedPoints,
                                  boundingBox: shiftedBounds,
                                  parentCardId: 'card_$now',
                                ));
                              }
                            }
                          }

                          final dup = card.copyWith(
                            id: 'card_$now',
                            x: card.x + 30,
                            y: card.y + 30,
                            attachedStrokeIds: newAttachedIds,
                          );

                          if (clonedStrokes.isNotEmpty) {
                            n.addAllStrokes(clonedStrokes);
                            for (final s in clonedStrokes) {
                              _undoManager.pushCommand(AddStrokeCommand(s), execute: false, note: n);
                            }
                            _strokesVersion++;
                            _strokeUpdateNotifier.value++;
                            _canvasUpdateNotifier.value++;
                          }

                          _undoManager.pushCommand(
                            AddCardCommand(dup),
                            execute: true,
                            note: n,
                          );
                          setState(() {
                            _selectedCardId = dup.id;
                          });
                          WorkspaceStorageService.instance.scheduleAutoSave(n);
                        }
                      },
                      onRulerStateChanged: (newState) {
                        setState(() {
                          _rulerState = newState;
                        });
                        _rulerUpdateNotifier.value++;
                      },
                      onProtractorStateChanged: (newState) {
                        setState(() {
                          _protractorState = newState;
                        });
                        _rulerUpdateNotifier.value++;
                      },
                      onCloseRuler: () {
                        setState(() {
                          _rulerState = _rulerState.copyWith(isVisible: false);
                        });
                        _rulerUpdateNotifier.value++;
                      },
                      onCloseProtractor: () {
                        setState(() {
                          _protractorState = _protractorState.copyWith(isVisible: false);
                        });
                        _rulerUpdateNotifier.value++;
                      },
                      onSolveWithAi: _handleSolveCardWithAi,
                      onExtractLatex: _handleExtractLatexFromCard,
                    ),
                  ),
                ),
              ),

              // 2. Barra de Ações Rápidas da Seleção (Flutuante sobre a Bounding Box - Reativa a _selectionUpdateNotifier)
              ListenableBuilder(
                listenable: _selectionUpdateNotifier,
                builder: (context, _) {
                  if (!_selectionState.hasSelection || _currentNote == null || _selectionState.bounds == null) {
                    return const SizedBox.shrink();
                  }
                  final effectiveBounds = _selectionState.transformBounds ??
                      (_selectionState.isDraggingSelection
                          ? _selectionState.bounds!.shift(_selectionState.dragOffset)
                          : _selectionState.bounds!);

                  return Positioned(
                    top: math.max(16, effectiveBounds.top * _zoomScale + _panOffset.dy - 50),
                    left: math.max(16, (effectiveBounds.center.dx * _zoomScale + _panOffset.dx) - 95),
                    child: SelectionActionBar(
                      availableColors: _penSlots.map((s) => s.color).toSet().toList(),
                      onDuplicate: _duplicateSelectedStrokes,
                      onChangeColor: _changeSelectedStrokesColor,
                      onRotate90: () => _rotateSelectedStrokesBy(math.pi / 2.0),
                      onRotatePanStart: _onRotatePanStart,
                      onRotatePanUpdate: _onRotatePanUpdate,
                      onRotatePanEnd: _onRotatePanEnd,
                      onDelete: _deleteSelection,
                      onDeselect: _deselect,
                      onAskAi: _settings.enableAiSelectionActions
                          ? () {
                              _isAIOpen = true;
                              _handleSubmitAiPrompt('O que significa ou como resolver o conteúdo selecionado?');
                            }
                          : null,
                    ),
                  );
                },
              ),

              // --- UI Overlays Isolados (Zero Rebuild do Canvas) ---
              Positioned.fill(
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    _isAIOpenNotifier,
                    _isSidebarOpenNotifier,
                    _isSettingsOpenNotifier,
                    _isGridMenuOpenNotifier,
                    _isCardsSubBarVisibleNotifier,
                    _isPenSubBarVisibleNotifier,
                    _activeToolNotifier,
                    _selectedCardIdNotifier,
                    _activeSettingsCategoryNotifier,
                  ]),
                  builder: (context, _) {
                    return Stack(
                      children: [
                        // 3. Visualização de Configurações (SettingsOverlayView no Canvas com Fundo Unificado e Transição Moscaro v2)
                        SettingsOverlayView(
                          isOpen: _isSettingsOpen,
                          leftOffset: _isSidebarOpen ? 348 : 0,
                          activeCategory: _activeSettingsCategory,
                          settings: _settings,
                          onUpdateSettings: _updateSettings,
                          onResetCategory: _resetSettingsCategory,
                        ),

              // 4. TabBar Superior (Alternância fluida entre Abas de Notas e Abas de Configurações)
              Positioned(
                top: 48,
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
                              _activeSettingsCategory = cat;
                            },
                            onBackToNotes: () {
                              _isSettingsOpen = false;
                            },
                          )
                        : NoteTabBar(
                            key: const ValueKey('note_tab_bar'),
                            activeNoteIds: _activeNoteIds,
                            noteTitles: noteTitles,
                            selectedNoteId: _selectedNoteId,
                            isSidebarOpen: _isSidebarOpen,
                            onBackToHome: () {
                              widget.onBackToHome?.call(_activeNoteIds);
                            },
                            onOpenSettings: () {
                              _isSettingsOpen = true;
                            },
                            onSelectNote: (noteId) {
                              final note = _findNoteById(_notes, noteId) ?? _findNoteById(WorkspaceStorageService.instance.allNotes, noteId);
                              if (note != null) {
                                setState(() {
                                  _switchToNote(note);
                                });
                              }
                            },
                            onCloseNote: (noteId) {
                              setState(() {
                                _activeNoteIds.remove(noteId);
                                if (_selectedNoteId == noteId) {
                                  final newSelectedId = _activeNoteIds.isNotEmpty ? _activeNoteIds.last : null;
                                  if (newSelectedId != null) {
                                    final note = _findNoteById(_notes, newSelectedId) ?? _findNoteById(WorkspaceStorageService.instance.allNotes, newSelectedId);
                                    if (note != null) {
                                      _switchToNote(note);
                                    } else {
                                      _selectedNoteId = null;
                                    }
                                  } else {
                                    _selectedNoteId = null;
                                  }
                                }
                                _selectionState = SelectionState.empty();
                              });
                            },
                            onAddNote: () {
                              _addNewNote("Nova Nota ${_notes.length + 1}");
                            },
                            onToggleSidebar: () {
                              _isSidebarOpen = !_isSidebarOpen;
                            },
                          ),
                  ),
                ),
              ),

              // 4.1 HUD de Zoom no Topo Superior Direito
              if (!_isSettingsOpen)
                Positioned(
                  top: 48,
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
                      _isGridMenuOpen = false;
                    },
                    child: Container(color: Colors.transparent),
                  ),
                ),

              // 5 e 7. Sub-Barras Flutuantes e ToolbarPill encapsuladas para 144Hz Zero-Rebuild
              Positioned.fill(
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    _activeToolNotifier,
                    _isPenSubBarVisibleNotifier,
                    _isGridMenuOpenNotifier,
                    _isCardsSubBarVisibleNotifier,
                    _isMeasurementSubBarVisibleNotifier,
                    _selectionUpdateNotifier,
                    _rulerUpdateNotifier,
                    _isSidebarOpenNotifier,
                  ]),
                  builder: (context, _) {
                    return Stack(
                      children: [
                        // 5. Sub-Barras Flutuantes e Menu do Grid
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
                                  PenSlotsController.instance.selectSlot(preset.id);
                                  _activeTool = 'pen';
                                  _selectionState = SelectionState.empty();
                                });
                              },
                              onUpdatePreset: (updated) {
                                PenSlotsController.instance.updateSlot(updated);
                                setState(() {});
                              },
                              onReorderSlots: (oldIndex, newIndex) {
                                PenSlotsController.instance.reorderSlots(oldIndex, newIndex);
                                setState(() {});
                              },
                              onAddNewSlot: () {
                                PenSlotsController.instance.addNewSlot();
                                setState(() {
                                  _activeTool = 'pen';
                                  _selectionState = SelectionState.empty();
                                });
                              },
                              onDeleteSlot: (slotId) {
                                PenSlotsController.instance.deleteSlot(slotId);
                                setState(() {});
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
                                  _isCardsSubBarVisible = false;
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
                                        _currentNote?.backgroundType = newBg;
                                        _isGridMenuOpen = false;
                                      });
                                      if (_currentNote != null) {
                                        WorkspaceStorageService.instance.scheduleAutoSave(_currentNote!);
                                      }
                                    },
                                  )
                                : const SizedBox.shrink(key: ValueKey('grid_menu_closed')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Overlay de Diagnóstico Visual dos Cards (Pressione F2 para ocultar/exibir)
                if (_currentNote != null)
                  Positioned.fill(
                    child: ListenableBuilder(
                      listenable: Listenable.merge([_panNotifier, _zoomNotifier, _mousePosNotifier]),
                      builder: (context, _) => CardsDebugOverlay(
                        cards: _currentNote!.cards,
                        selectedCardId: _selectedCardId,
                        panOffset: _panOffset,
                        zoomScale: _zoomScale,
                        mousePos: _mousePosNotifier.value,
                        isVisible: _isDebugCardsOverlayVisible,
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
                      _isCardsSubBarVisible = !_isCardsSubBarVisible;
                      if (!_isCardsSubBarVisible) _activeCardPreset = null;
                      _isPenSubBarVisible = false;
                      _isGridMenuOpen = false;
                      _isMeasurementSubBarVisible = false;
                    },
                    selectionType: _selectionType,
                    activePenPreset: _activePenPreset,
                    canUndo: canUndo,
                    canRedo: canRedo,
                    onUndo: _undo,
                    onRedo: _redo,
                    isGridMenuOpen: _isGridMenuOpen,
                    onToggleGridMenu: () {
                      _isGridMenuOpen = !_isGridMenuOpen;
                    },
                    onToggleRuler: () {
                      setState(() {
                        final bool isAnyMeasurementActive = _rulerState.isVisible || _protractorState.isVisible;
                        if (isAnyMeasurementActive) {
                          _isMeasurementSubBarVisible = false;
                          _rulerState = _rulerState.copyWith(isVisible: false);
                          _protractorState = _protractorState.copyWith(isVisible: false);
                        } else {
                          _isMeasurementSubBarVisible = true;
                          _isPenSubBarVisible = false;
                          _isCardsSubBarVisible = false;
                          _isGridMenuOpen = false;
                          final viewportCenter = (-_panOffset + Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2)) / _zoomScale;
                          if (_activeMeasurementTool == MeasurementToolType.ruler) {
                            _protractorState = _protractorState.copyWith(isVisible: false);
                            _rulerState = _rulerState.copyWith(isVisible: true, center: viewportCenter);
                          } else {
                            _rulerState = _rulerState.copyWith(isVisible: false);
                            _protractorState = _protractorState.copyWith(isVisible: true, center: viewportCenter);
                          }
                        }
                      });
                      _rulerUpdateNotifier.value++;
                    },
                    onBackgroundChanged: (newBg) {
                      setState(() {
                        _currentBackground = newBg;
                        _currentNote?.backgroundType = newBg;
                      });
                      if (_currentNote != null) {
                        WorkspaceStorageService.instance.scheduleAutoSave(_currentNote!);
                      }
                    },
                    onSelectPen: () {
                      setState(() {
                        _activeTool = 'pen';
                        _isPenSubBarVisible = true;
                        _selectionState = SelectionState.empty();
                      });
                      _selectionUpdateNotifier.value++;
                    },
                    onSelectEraser: () {
                      setState(() {
                        _activeTool = 'eraser';
                        _isPenSubBarVisible = false;
                        _selectionState = SelectionState.empty();
                      });
                      _selectionUpdateNotifier.value++;
                    },
                    onSelectShapes: () {
                      setState(() {
                        _activeTool = 'shapes';
                        _isPenSubBarVisible = false;
                        _selectionState = SelectionState.empty();
                      });
                      _selectionUpdateNotifier.value++;
                    },
                    onSelectTool: () {
                      setState(() {
                        _activeTool = 'select';
                        _isPenSubBarVisible = false;
                        _selectionState = SelectionState.empty();
                      });
                      _selectionUpdateNotifier.value++;
                    },
                    onSelectLaser: () {
                      setState(() {
                        _activeTool = 'laser';
                        _isPenSubBarVisible = false;
                        _selectionState = SelectionState.empty();
                      });
                      _selectionUpdateNotifier.value++;
                    },
                    onToggleAI: () {
                      _isAIOpen = !_isAIOpen;
                    },
                  ).moscaroV2(
                    borderRadius: MoscaroTokens.radiusPill,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  ),
                ),
              ),
                      ],
                    );
                  },
                ),
              ),

              // 8. Sidebar Esquerda de Notas & Cadernos
              NoteSidebar(
                isOpen: _isSidebarOpen,
                selectedNoteId: _selectedNoteId,
                onSelectNote: (selectedNote) {
                  setState(() {
                    _switchToNote(selectedNote);
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
                key: _aiSidebarKey,
                isOpen: _isAIOpen,
                onClose: () {
                  _isAIOpen = false;
                },
                messages: _aiMessages,
                isStreaming: _isAiStreaming,
                activeModel: _activeAiModel,
                activeScope: _activeAiScope,
                availableNoteTitles: _notes.map((n) => n.title).toList(),
                onSelectModel: (m) {
                  setState(() {
                    _activeAiModel = m;
                  });
                },
                onSelectScope: (s) {
                  setState(() {
                    _activeAiScope = s;
                  });
                },
                onSubmitPrompt: _handleSubmitAiPrompt,
                onClearChat: () {
                  setState(() {
                    _aiMessages.clear();
                  });
                },
                onInsertIntoCanvas: (msg) {
                  _handleInsertAiMessageIntoCanvas(msg);
                },
                onOpenSettings: () {
                  setState(() {
                    _isSettingsOpen = true;
                    _activeSettingsCategory = SettingsCategory.ai;
                  });
                },
                onSelectCanvasArea: _startAreaCaptureForAi,
              ),

              // Overlay de Seleção de Área do Canvas para IA
              if (_isSelectingAreaForAi)
                Positioned.fill(
                  child: CanvasAreaSelectionOverlay(
                    onAreaSelected: _handleAreaSelectedForAi,
                    onCancel: () {
                      setState(() {
                        _isSelectingAreaForAi = false;
                      });
                    },
                  ),
                ),

              // 9. Barra de Título Customizada Moscaro (Frameless Window Header com Suíte Dev sob kDebugMode)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: MoscaroWindowTitleBar(
                  onHotReload: () {
                    VmServiceClient.instance.hotReload();
                  },
                  onHotRestart: () async {
                    final didRestart = await VmServiceClient.instance.hotRestart();
                    if (!didRestart) {
                      WidgetsBinding.instance.reassembleApplication();
                      DevHubServer.instance.logAction('Para compilar arquivos em disco, pressione "R" no terminal do flutter run.');
                    }
                  },
                  onToggleFps: () {
                    DiagnosticsOverrideController.instance.cycleHudMode();
                  },
                  isFpsActive: DiagnosticsOverrideController.instance.hudMode != PerformanceHudDisplayMode.off,
                  isDebugCardsActive: _isDebugCardsOverlayVisible,
                  onToggleDebugCards: () {
                    setState(() {
                      _isDebugCardsOverlayVisible = !_isDebugCardsOverlayVisible;
                    });
                  },
                  onOpenDevHub: () {
                    DevHubServer.instance.openInBrowser();
                  },
                ),
              ),

              // 10. MiniHUD de Performance (FPS, 1% Low, Latência de UI e Raster)
              const PerformanceDebugHud(),
            ],
          );
        },
      ),
    ),
  ],
);
            },
          ),
        ),
      ),
    );
  }

  Future<String?> _renderSelectedStrokesToBase64() async {
    final note = _currentNote;
    if (note == null || !_selectionState.hasSelection || _selectionState.bounds == null) return null;

    final selectedIds = _selectionState.selectedStrokeIds;
    final selectedStrokes = note.strokes.where((s) => selectedIds.contains(s.id)).toList();
    if (selectedStrokes.isEmpty) return null;

    final bounds = _selectionState.bounds!;
    const padding = 24.0;
    final paddedBounds = bounds.inflate(padding);
    final width = math.max(160.0, math.min(1024.0, paddedBounds.width));
    final height = math.max(160.0, math.min(1024.0, paddedBounds.height));

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    // Fundo contrastante para reconhecimento de visão computacional / OCR
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = const Color(0xFF0D0E15));
    canvas.translate(-paddedBounds.left, -paddedBounds.top);

    for (final stroke in selectedStrokes) {
      if (stroke.points.isEmpty) continue;
      final strokePaint = Paint()
        ..color = stroke.color == Colors.black ? Colors.white : stroke.color
        ..strokeWidth = math.max(3.0, stroke.strokeWidth)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first.point, stroke.strokeWidth / 2, strokePaint..style = PaintingStyle.fill);
      } else {
        final path = Path();
        path.moveTo(stroke.points.first.point.dx, stroke.points.first.point.dy);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].point.dx, stroke.points[i].point.dy);
        }
        canvas.drawPath(path, strokePaint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.round(), height.round());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    return base64Encode(byteData.buffer.asUint8List());
  }

  Future<String?> _renderNoteStrokesToBase64(NoteDocument note) async {
    if (note.strokes.isEmpty) return null;

    final allPoints = <Offset>[];
    for (final s in note.strokes) {
      for (final p in s.points) {
        allPoints.add(p.point);
      }
    }
    if (allPoints.isEmpty) return null;

    double minX = double.infinity, minY = double.infinity, maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final p in allPoints) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }

    final rawBounds = Rect.fromLTRB(minX, minY, maxX, maxY);
    const padding = 32.0;
    final paddedBounds = rawBounds.inflate(padding);
    final width = math.max(200.0, math.min(1280.0, paddedBounds.width));
    final height = math.max(200.0, math.min(1280.0, paddedBounds.height));

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    // Fundo contrastante escuro para reconhecimento nítido da caligrafia pelo Gemini
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = const Color(0xFF0D0E15));
    canvas.translate(-paddedBounds.left, -paddedBounds.top);

    for (final stroke in note.strokes) {
      if (stroke.points.isEmpty) continue;
      final strokePaint = Paint()
        ..color = stroke.color == Colors.black ? Colors.white : stroke.color
        ..strokeWidth = math.max(2.5, stroke.strokeWidth)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first.point, stroke.strokeWidth / 2, strokePaint..style = PaintingStyle.fill);
      } else {
        final path = Path();
        path.moveTo(stroke.points.first.point.dx, stroke.points.first.point.dy);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].point.dx, stroke.points[i].point.dy);
        }
        canvas.drawPath(path, strokePaint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.round(), height.round());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    return base64Encode(byteData.buffer.asUint8List());
  }

  Future<void> _handleSubmitAiPrompt(String promptText, [String? userAttachedImageBase64]) async {
    if (promptText.trim().isEmpty && (userAttachedImageBase64 == null || userAttachedImageBase64.isEmpty)) return;

    final userMsg = AiMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: AiMessageRole.user,
      content: promptText.trim().isNotEmpty ? promptText.trim() : '(Imagem enviada para análise)',
      timestamp: DateTime.now(),
    );

    final assistantMsgId = (DateTime.now().millisecondsSinceEpoch + 1).toString();
    final assistantMsg = AiMessage(
      id: assistantMsgId,
      role: AiMessageRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
      modelName: _activeAiModel.displayName,
    );

    setState(() {
      _aiMessages.add(userMsg);
      _aiMessages.add(assistantMsg);
      _isAiStreaming = true;
    });

    // Constrói o contexto com base nos elementos selecionados, notas mencionadas (@) e grau de consciência ativo
    String scopeContext = '';
    final imagesList = <String>[];
    if (userAttachedImageBase64 != null && userAttachedImageBase64.isNotEmpty) {
      imagesList.add(userAttachedImageBase64);
      scopeContext += 'Imagem enviada pelo usuário em anexo para análise.\n';
    }

    final note = _currentNote;

    // 1. Processamento de Menções @nome_da_nota no prompt
    final mentionMatches = RegExp(r'@([a-zA-Z0-9_\-]+)').allMatches(promptText);
    if (mentionMatches.isNotEmpty) {
      final mentionedTitles = mentionMatches.map((m) => m.group(1)!.replaceAll('_', ' ').toLowerCase()).toSet();
      for (final n in _notes) {
        final nTitleLower = n.title.toLowerCase();
        final nTitleSanitized = n.title.replaceAll(' ', '_').toLowerCase();
        if (mentionedTitles.contains(nTitleLower) || mentionedTitles.contains(nTitleSanitized)) {
          scopeContext += '\n--- NOTA MENCIONADA: [${n.title}] ---\n';
          if (n.cards.isNotEmpty) {
            scopeContext += 'Cards na nota:\n' + n.cards.map((c) => '[${c.title}]: ${c.content}').join('\n') + '\n';
          }
          if (n.strokes.isNotEmpty) {
            final strokeImg = await _renderNoteStrokesToBase64(n);
            if (strokeImg != null) {
              imagesList.add(strokeImg);
              scopeContext += '(Traços desenhados na nota [${n.title}] incluídos como imagem em anexo)\n';
            }
          }
        }
      }
    }

    // 2. Processamento dos Escopos Ativos
    if (_selectionState.hasSelection && note != null) {
      final selectedIds = _selectionState.selectedStrokeIds;
      final selectedStrokes = note.strokes.where((s) => selectedIds.contains(s.id)).toList();
      if (selectedStrokes.isNotEmpty) {
        final img = await _renderSelectedStrokesToBase64();
        if (img != null) imagesList.add(img);
        scopeContext += '\nImagem em anexo com a caligrafia/desenho selecionado pelo usuário no canvas. Interprete o conteúdo como a mensagem/dúvida do usuário e responda diretamente a ela.';
      }
      if (_selectedCardId != null) {
        final card = note.cards.cast<CanvasCardModel?>().firstWhere((c) => c?.id == _selectedCardId, orElse: () => null);
        if (card != null) {
          scopeContext += '\nCard selecionado:\n[${card.title}]:\n${card.content}';
        }
      }
    } else if (_activeAiScope == AiScopeType.activeNote && note != null) {
      scopeContext += '\n--- NOTA ATIVA ATUAL: [${note.title}] ---\n';
      if (note.cards.isNotEmpty) {
        final cardTexts = note.cards.map((c) => 'Card [${c.title}]:\n${c.content}').join('\n---\n');
        scopeContext += 'Cards e anotações no Canvas:\n$cardTexts\n';
      }
      if (note.strokes.isNotEmpty) {
        final strokeImg = await _renderNoteStrokesToBase64(note);
        if (strokeImg != null) {
          imagesList.add(strokeImg);
          scopeContext += '(Traços e caligrafia manuscrita da nota atual incluídos como imagem em anexo. Leia e interprete os traços desenhados)\n';
        }
      }
    } else if (_activeAiScope == AiScopeType.allNotes) {
      scopeContext += '\n--- CADERNO COMPLETO / TODAS AS NOTAS (${_notes.length} notas) ---\n';
      for (final n in _notes) {
        scopeContext += '\nNota: [${n.title}]\n';
        if (n.cards.isNotEmpty) {
          scopeContext += 'Cards:\n' + n.cards.map((c) => '- [${c.title}]: ${c.content}').join('\n') + '\n';
        }
        if (n.strokes.isNotEmpty) {
          final strokeImg = await _renderNoteStrokesToBase64(n);
          if (strokeImg != null) {
            imagesList.add(strokeImg);
            scopeContext += '(Traços e caligrafia manuscrita desta nota incluídos como imagem em anexo.)\n';
          }
        }
      }
    }

    final buffer = StringBuffer();
    int lastUiUpdate = 0;

    AiServiceBridge.instance.streamPrompt(
      userPrompt: promptText,
      model: _activeAiModel,
      scopeContext: scopeContext,
      imagesBase64: imagesList,
    ).listen(
      (chunk) {
        buffer.write(chunk);
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastUiUpdate > 35) {
          lastUiUpdate = now;
          setState(() {
            final index = _aiMessages.indexWhere((m) => m.id == assistantMsgId);
            if (index != -1) {
              _aiMessages[index] = _aiMessages[index].copyWith(
                content: buffer.toString(),
                isStreaming: true,
              );
            }
          });
        }
      },
      onError: (err) {
        setState(() {
          final index = _aiMessages.indexWhere((m) => m.id == assistantMsgId);
          if (index != -1) {
            _aiMessages[index] = _aiMessages[index].copyWith(
              errorMessage: err.toString(),
              isStreaming: false,
            );
          }
          _isAiStreaming = false;
        });
      },
      onDone: () {
        setState(() {
          final index = _aiMessages.indexWhere((m) => m.id == assistantMsgId);
          if (index != -1) {
            _aiMessages[index] = _aiMessages[index].copyWith(
              content: buffer.toString(),
              isStreaming: false,
            );
          }
          _isAiStreaming = false;
        });
      },
    );
  }

  /// Inicia a seleção de área do canvas através do overlay
  void _startAreaCaptureForAi() {
    setState(() {
      _isSelectingAreaForAi = true;
    });
  }

  /// Captura a área demarcada na tela através do RepaintBoundary e anexa na AiSidebar
  Future<void> _handleAreaSelectedForAi(Rect screenRect) async {
    setState(() {
      _isSelectingAreaForAi = false;
    });

    try {
      final boundary = _canvasRepaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final pixelRatio = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 2.0);
      final fullImage = await boundary.toImage(pixelRatio: pixelRatio);

      final cropRect = Rect.fromLTWH(
        screenRect.left * pixelRatio,
        screenRect.top * pixelRatio,
        screenRect.width * pixelRatio,
        screenRect.height * pixelRatio,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        fullImage,
        cropRect,
        Rect.fromLTWH(0, 0, screenRect.width * pixelRatio, screenRect.height * pixelRatio),
        Paint(),
      );
      final picture = recorder.endRecording();
      final croppedImage = await picture.toImage(
        cropRect.width.round(),
        cropRect.height.round(),
      );

      final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final base64String = 'data:image/png;base64,${base64Encode(bytes)}';

      setState(() {
        _isAIOpen = true;
      });

      // Anexa imagem no chat da IA (campo de texto permanece limpo sem prompt injetado)
      _aiSidebarKey.currentState?.attachImage(
        bytes: bytes,
        base64: base64String,
      );
    } catch (e) {
      debugPrint('[_handleAreaSelectedForAi] Erro ao capturar área: $e');
    }
  }

  /// Ação no card de mídia: Enviar imagem diretamente para o painel de IA resolver o exercício
  void _handleSolveCardWithAi(CanvasCardModel card) {
    final mediaData = card.mediaData;
    if (mediaData == null || mediaData.isEmpty) return;

    try {
      Uint8List? bytes;
      if (mediaData.startsWith('data:')) {
        final comma = mediaData.indexOf(',');
        if (comma != -1) {
          bytes = base64Decode(mediaData.substring(comma + 1));
        }
      } else {
        final file = File(mediaData);
        if (file.existsSync()) {
          bytes = file.readAsBytesSync();
        }
      }

      if (bytes != null) {
        setState(() {
          _isAIOpen = true;
        });
        _aiSidebarKey.currentState?.attachImage(
          bytes: bytes,
          base64: mediaData,
          defaultPrompt: 'Resolva este exercício passo a passo detalhando todas as fórmulas e deduções em KaTeX:',
        );
      }
    } catch (e) {
      debugPrint('[_handleSolveCardWithAi] Erro ao anexar imagem do card: $e');
    }
  }

  /// Ação no card de mídia: OCR / Extrair LaTeX e criar card de texto adjacente
  void _handleExtractLatexFromCard(CanvasCardModel card) {
    final note = _currentNote;
    if (note == null) return;
    CanvasMediaOcrService.instance.extractLatexFromCard(
      card: card,
      note: note,
      activeAiModel: _activeAiModel,
      undoManager: _undoManager,
      onCardCreated: () {
        setState(() {});
      },
      onCardUpdated: () {
        setState(() {});
      },
    );
  }

  void _handleInsertAiMessageIntoCanvas(AiMessage message, [Offset? screenPosition]) {
    final note = _currentNote;
    if (note == null) return;

    final size = MediaQuery.of(context).size;
    final targetScreen = screenPosition ?? Offset(size.width / 2 - 190, size.height / 2 - 130);
    final worldX = (targetScreen.dx - _panOffset.dx) / _zoomScale;
    final worldY = (targetScreen.dy - _panOffset.dy) / _zoomScale;

    // Limpa tags de sugestões dinâmicas para não poluir o conteúdo do Card no Canvas
    final cleanContent = message.content
        .replaceAll(RegExp(r'\[(?:SUGESTOES|SUGESTÕES):\s*.*?\]', caseSensitive: false), '')
        .trim();

    final newCard = CanvasCardModel(
      id: 'card_ai_${DateTime.now().millisecondsSinceEpoch}',
      title: 'IA: ${message.modelName ?? "STEM"}',
      x: worldX,
      y: worldY,
      width: 440,
      height: 320,
      content: cleanContent,
    );

    _undoManager.pushCommand(
      AddCardCommand(newCard),
      execute: true,
      note: note,
    );

    setState(() {
      _selectedCardId = newCard.id;
    });
    WorkspaceStorageService.instance.scheduleAutoSave(note);
  }

  void _eraseStrokesNear(Offset canvasPoint, {EraserMode? mode}) {
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

    final effectiveMode = mode ?? _eraserConfig.mode;
    if (effectiveMode == EraserMode.stroke) {
      // 1. Borracha de Traço Inteiro
      final toRemove = candidateStrokes
          .where((stroke) => SelectionGeometry.isPointNearStroke(canvasPoint, stroke, eraserRadius))
          .toList();

      if (toRemove.isNotEmpty) {
        _undoManager.pushCommand(RemoveStrokesCommand(toRemove), execute: true, note: note);
        final removedIds = toRemove.map((s) => s.id).toSet();
        for (int cIdx = 0; cIdx < note.cards.length; cIdx++) {
          final c = note.cards[cIdx];
          if (c.attachedStrokeIds.any(removedIds.contains)) {
            note.cards[cIdx] = c.copyWith(
              attachedStrokeIds: c.attachedStrokeIds.where((id) => !removedIds.contains(id)).toList(),
            );
          }
        }
        _strokesVersion++;
        _committedStrokesNotifier.value++;
        _strokeUpdateNotifier.value++;
        _canvasUpdateNotifier.value++;
        setState(() {});
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
            parentCardId: stroke.parentCardId,
            boundingBox: bounds,
          ));
        }
      }

      if (removedOld.isNotEmpty) {
        note.removeStrokes(removedOld);
        if (addedNew.isNotEmpty) {
          note.addAllStrokes(addedNew);
        }
        final removedIds = removedOld.map((s) => s.id).toSet();
        for (int cIdx = 0; cIdx < note.cards.length; cIdx++) {
          final c = note.cards[cIdx];
          if (c.attachedStrokeIds.any(removedIds.contains)) {
            final survivingAttachedIds = c.attachedStrokeIds.where((id) => !removedIds.contains(id)).toList();
            final newSegmentsForThisCard = addedNew.where((s) => s.parentCardId == c.id).map((s) => s.id);
            note.cards[cIdx] = c.copyWith(
              attachedStrokeIds: [...survivingAttachedIds, ...newSegmentsForThisCard],
            );
          }
        }
        _strokesVersion++;
        _committedStrokesNotifier.value++;
        _strokeUpdateNotifier.value++;
        _canvasUpdateNotifier.value++;
        setState(() {});
      }
    }
  }

  @override
  CanvasCardModel? findCardAtPoint(Offset canvasPoint) {
    final note = _currentNote;
    if (note == null) return null;
    return _findCardAtPoint(note.cards, canvasPoint, _selectedCardId);
  }

  @override
  void attachStrokeToCard(String cardId, String strokeId) {
    final note = _currentNote;
    if (note == null) return;
    final idx = note.cards.indexWhere((c) => c.id == cardId);
    if (idx != -1) {
      final card = note.cards[idx];
      if (!card.attachedStrokeIds.contains(strokeId)) {
        final updatedList = List<String>.from(card.attachedStrokeIds)..add(strokeId);
        final updatedCard = card.copyWith(attachedStrokeIds: updatedList);
        note.cards[idx] = updatedCard;

        final sIdx = note.strokes.indexWhere((s) => s.id == strokeId);
        if (sIdx != -1) {
          note.strokes[sIdx] = note.strokes[sIdx].copyWith(parentCardId: cardId);
        }

        _strokesVersion++;
        _strokeUpdateNotifier.value++;
        _committedStrokesNotifier.value++;
        _canvasUpdateNotifier.value++;
        WorkspaceStorageService.instance.scheduleAutoSave(note);
      }
    }
  }

  @override
  void eraseStrokesNear(Offset canvasPoint, {EraserMode? mode}) => _eraseStrokesNear(canvasPoint, mode: mode);

  @override
  Color? sampleColorAt(Offset canvasPoint) {
    final note = _currentNote;
    if (note == null) return null;
    final candidateIds = note.spatialIndex.queryPoint(canvasPoint, 24.0 / _zoomScale);
    final candidateStrokes = candidateIds
        .map((id) => note.getStroke(id))
        .whereType<InkStroke>()
        .toList();
    for (final stroke in candidateStrokes.reversed) {
      if (SelectionGeometry.isPointNearStroke(canvasPoint, stroke, 16.0 / _zoomScale)) {
        final sampled = stroke.color;
        final active = PenSlotsController.instance.activePreset;
        PenSlotsController.instance.updateSlot(active.copyWith(color: sampled));
        setState(() {});
        return sampled;
      }
    }
    final card = _findCardAtPoint(note.cards, canvasPoint, _selectedCardId);
    if (card != null) {
      final cardColor = card.customGlassColor ?? card.highlightColor ?? card.textColor;
      if (cardColor != null) {
        final active = PenSlotsController.instance.activePreset;
        PenSlotsController.instance.updateSlot(active.copyWith(color: cardColor));
        setState(() {});
        return cardColor;
      }
    }
    return null;
  }

  @override
  void scheduleEraseCommit() {
    final note = _currentNote;
    if (note != null) _scheduleEraseCommit(note);
  }

  @override
  void updateRulerState(StemRulerState state) {
    _rulerState = state;
    _rulerUpdateNotifier.value++;
  }

  @override
  void updateProtractorState(StemProtractorState state) {
    _protractorState = state;
    _rulerUpdateNotifier.value++;
  }

  @override
  void updateMousePos(Offset? pos) {
    _mousePosNotifier.value = pos;
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

  // --- Implementação de Suporte a Caneta e Mesas (CanvasInputContext) ---
  @override
  double get eraserRadius => 24.0;

  @override
  bool get isPalmRejectionEnabled => true;

  @override
  void onStylusHover({Offset? position, double? pressure, double? tilt, double? distance}) {
    if (position != null) {
      _mousePosNotifier.value = position;
    }
  }

  @override
  void onBarrelButtonPressed({required bool isPressed, Offset? position}) {}

  @override
  void onInvertedStylusChanged({required bool isInverted}) {}

  @override
  void onPalmContactRejected({required Offset position, required double contactSize}) {}

  bool _isLightboxOpen = false;

  @override
  void openMediaLightbox(String cardId) async {
    if (_isLightboxOpen) return;
    _isLightboxOpen = true;
    try {
      final n = _currentNote;
      if (n == null) return;
      final card = n.cards.cast<CanvasCardModel?>().firstWhere(
        (c) => c?.id == cardId,
        orElse: () => null,
      );
      if (card == null || card.cardType != CardType.media) return;

      final attached = card.attachedStrokeIds.isNotEmpty
          ? n.strokes.where((s) => card.attachedStrokeIds.contains(s.id)).toList()
          : <InkStroke>[];

      final finalStrokes = await MediaLightboxModal.show(
        context,
        mediaData: card.mediaData,
        title: card.title.isNotEmpty ? card.title : 'Visualização de Mídia',
        initialStrokes: attached,
        cardX: card.x,
        cardY: card.y + 28.0,
        cardWidth: card.width,
        cardHeight: math.max(1.0, card.height - 28.0),
        parentCardId: card.id,
      );

      if (finalStrokes != null) {
        _handleSyncCardStrokes(finalStrokes, card.id);
      }
    } finally {
      _isLightboxOpen = false;
    }
  }

  void _handleSyncCardStrokes(List<InkStroke> finalStrokes, String cardId) {
    final n = _currentNote;
    if (n != null) {
      final idx = n.cards.indexWhere((c) => c.id == cardId);
      if (idx != -1) {
        final card = n.cards[idx];
        final oldAttachedIds = card.attachedStrokeIds.toSet();
        final oldStrokes = n.strokes.where((s) => oldAttachedIds.contains(s.id)).toList();

        // Remove os traços antigos deste card do documento
        n.removeAllStrokes(oldAttachedIds);
        // Adiciona os traços finais vindos do Lightbox
        n.addAllStrokes(finalStrokes);

        final newAttachedIds = finalStrokes.map((s) => s.id).toList();
        n.cards[idx] = card.copyWith(
          attachedStrokeIds: newAttachedIds,
        );

        _undoManager.pushCommand(
          SyncCardStrokesCommand(
            cardId: cardId,
            oldStrokes: oldStrokes,
            newStrokes: finalStrokes,
          ),
          execute: false,
          note: n,
        );

        _strokesVersion++;
        _strokeUpdateNotifier.value++;
        _committedStrokesNotifier.value++;
        _canvasUpdateNotifier.value++;
        setState(() {});
        WorkspaceStorageService.instance.scheduleAutoSave(n);
      }
    }
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
