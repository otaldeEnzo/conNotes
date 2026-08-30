import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../controllers/canvas_input_context.dart';
import '../handlers/ink_input_handler.dart';
import '../handlers/selection_input_handler.dart';
import '../handlers/pan_zoom_input_handler.dart';
import '../services/settings_service.dart';
import '../widgets/ink_models.dart';
import '../widgets/selection_models.dart';
import '../widgets/selection_overlay_painter.dart';
import '../widgets/settings_models.dart';
import '../widgets/stem_ruler_model.dart';
import '../widgets/stem_protractor_model.dart';
import '../widgets/card_format_floating_pill.dart';
import '../theme/moscaro_theme_controller.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../services/cards_telemetry_controller.dart';
import '../services/stylus_native_channel.dart';

typedef CanvasLayerBuilder = Widget Function(BuildContext context, InkStroke? Function() getActiveStroke);

/// Estado do Hover do Stylus/Mouse para feedback visual em tempo real.
class CanvasHoverState {
  final Offset? position;
  final PointerDeviceKind? deviceKind;
  final int buttons;
  final double pressure;
  final double distance;
  final bool isTemporaryEraser;
  final bool isBarrelButton;
  final bool isInvertedStylus;
  final StylusBarrelAction? activeBarrelAction;
  final bool isVisible;

  const CanvasHoverState({
    this.position,
    this.deviceKind,
    this.buttons = 0,
    this.pressure = 0.0,
    this.distance = 0.0,
    this.isTemporaryEraser = false,
    this.isBarrelButton = false,
    this.isInvertedStylus = false,
    this.activeBarrelAction,
    this.isVisible = false,
  });

  CanvasHoverState copyWith({
    Offset? position,
    PointerDeviceKind? deviceKind,
    int? buttons,
    double? pressure,
    double? distance,
    bool? isTemporaryEraser,
    bool? isBarrelButton,
    bool? isInvertedStylus,
    StylusBarrelAction? activeBarrelAction,
    bool? isVisible,
  }) {
    return CanvasHoverState(
      position: position ?? this.position,
      deviceKind: deviceKind ?? this.deviceKind,
      buttons: buttons ?? this.buttons,
      pressure: pressure ?? this.pressure,
      distance: distance ?? this.distance,
      isTemporaryEraser: isTemporaryEraser ?? this.isTemporaryEraser,
      isBarrelButton: isBarrelButton ?? this.isBarrelButton,
      isInvertedStylus: isInvertedStylus ?? this.isInvertedStylus,
      activeBarrelAction: activeBarrelAction ?? this.activeBarrelAction,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}

class CanvasInputRouter extends StatefulWidget {
  final CanvasInputContext canvasContext;
  final Widget? child;
  final CanvasLayerBuilder? builder;
  final PenSlotPreset activePenPreset;
  final ValueNotifier<int> activeStrokeUpdateNotifier;
  final ValueNotifier<int> selectionUpdateNotifier;
  final ValueNotifier<Offset> panNotifier;
  final ValueNotifier<double> zoomNotifier;
  final Function(InkStroke) onCommitStroke;
  final VoidCallback onScheduleBounceCheck;
  final SelectedStrokesPictureCache? dragPictureCache;

  const CanvasInputRouter({
    super.key,
    required this.canvasContext,
    this.child,
    this.builder,
    required this.activePenPreset,
    required this.activeStrokeUpdateNotifier,
    required this.selectionUpdateNotifier,
    required this.panNotifier,
    required this.zoomNotifier,
    required this.onCommitStroke,
    required this.onScheduleBounceCheck,
    this.dragPictureCache,
  }) : assert(child != null || builder != null, 'Either child or builder must be provided');

  @override
  State<CanvasInputRouter> createState() => _CanvasInputRouterState();
}

class _CanvasInputRouterState extends State<CanvasInputRouter> {
  late final InkInputHandler _inkHandler;
  late final SelectionInputHandler _selectionHandler;
  late final PanZoomInputHandler _panZoomHandler;

  // Notifier para renderização desacoplada e suave do feedback de hover
  final ValueNotifier<CanvasHoverState> _hoverNotifier = ValueNotifier(const CanvasHoverState());

  // Rastreamento de Stylus e Rejeição de Palma
  int _lastStylusTimestampMs = 0;
  final Set<int> _activePalmPointerIds = {};

  // Estado dos botões do stylus (Hold vs Toggle) para Botão Inferior (Primário) e Superior (Secundário)
  int _lastButtons = 0;
  bool _isPrimaryBarrelToggleActive = false;
  bool _isSecondaryBarrelToggleActive = false;
  StylusBarrelAction? _currentActiveAction;
  bool _isActionExecuting = false;

  bool _isDraggingRuler = false;
  bool _isRotatingRuler = false;
  Offset? _rulerDragStart;
  StemRulerState? _rulerInitialState;

  bool _isDraggingProtractor = false;
  bool _isRotatingProtractor = false;
  Offset? _protractorDragStart;
  StemProtractorState? _protractorInitialState;

  bool _isInteractingWithCard = false;
  final ValueNotifier<MouseCursor> _cursorNotifier = ValueNotifier(SystemMouseCursors.basic);

  @override
  void initState() {
    super.initState();
    _inkHandler = InkInputHandler(
      activeStrokeUpdateNotifier: widget.activeStrokeUpdateNotifier,
      onInteracting: widget.canvasContext.setInteracting,
    );
    _selectionHandler = SelectionInputHandler(
      selectionUpdateNotifier: widget.selectionUpdateNotifier,
      onInteracting: widget.canvasContext.setInteracting,
      onStrokesCommitted: () {
        widget.canvasContext.incrementCommittedStrokes();
        widget.canvasContext.incrementStrokesVersion();
        widget.canvasContext.scheduleAutoSave();
      },
      dragPictureCache: widget.dragPictureCache,
    );
    _panZoomHandler = PanZoomInputHandler(
      panNotifier: widget.panNotifier,
      zoomNotifier: widget.zoomNotifier,
      onInteracting: widget.canvasContext.setInteracting,
      onScheduleBounceCheck: widget.onScheduleBounceCheck,
    );
    SettingsService.instance.addListener(_onSettingsChanged);
    StylusNativeChannel.instance.addListener(_onStylusNativeStateChanged);
  }

  void _onStylusNativeStateChanged(StylusNativeStateData state) {
    int buttons = 0;
    if (state.isPrimaryBarrelPressed) buttons |= kSecondaryStylusButton;
    if (state.isSecondaryBarrelPressed) buttons |= 0x08;
    _handleButtonTransitions(buttons);
  }

  void _onSettingsChanged() {
    _resetToolAndToggleStates();
  }

  void _resetToolAndToggleStates() {
    _isPrimaryBarrelToggleActive = false;
    _isSecondaryBarrelToggleActive = false;
    _isActionExecuting = false;
    _currentActiveAction = null;
    _lastButtons = 0;
    if (_cursorNotifier.value != SystemMouseCursors.basic) {
      _cursorNotifier.value = SystemMouseCursors.basic;
    }
  }

  @override
  void didUpdateWidget(CanvasInputRouter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activePenPreset.id != widget.activePenPreset.id) {
      _isActionExecuting = false;
      _currentActiveAction = null;
    }
  }

  @override
  void dispose() {
    SettingsService.instance.removeListener(_onSettingsChanged);
    StylusNativeChannel.instance.removeListener(_onStylusNativeStateChanged);
    _hoverNotifier.dispose();
    _cursorNotifier.dispose();
    super.dispose();
  }

  /// Heurística estrita de Rejeição de Palma (Palm Rejection)
  bool _isPalmContact(PointerEvent event) {
    if (event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus) {
      _lastStylusTimestampMs = DateTime.now().millisecondsSinceEpoch;
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Proximidade temporal com caneta ativa (rejeita toques de dedos nos 800ms após uso do stylus)
    if (now - _lastStylusTimestampMs < 800) {
      widget.canvasContext.onPalmContactRejected(
        position: event.localPosition,
        contactSize: event.size > 0 ? event.size : (event is PointerDownEvent ? event.radiusMajor : 0),
      );
      return true;
    }

    // 2. Detecção de área de contato estendida (palma da mão apoiada na tela)
    if (event is PointerDownEvent && (event.size > 0.35 || event.radiusMajor > 26.0 || event.radiusMinor > 20.0)) {
      widget.canvasContext.onPalmContactRejected(
        position: event.localPosition,
        contactSize: event.size > 0 ? event.size : event.radiusMajor,
      );
      return true;
    }

    // 3. Pressão excessiva no toque capacitivo sem stylus
    if (event is PointerDownEvent && (event.pressure > 0.95 && event.radiusMajor > 18.0)) {
      widget.canvasContext.onPalmContactRejected(
        position: event.localPosition,
        contactSize: event.size > 0 ? event.size : event.radiusMajor,
      );
      return true;
    }

    return false;
  }

  /// Detecta se o Botão Inferior (Primário / Barrel 1) está pressionado
  bool _isPrimaryBarrelPressed(int buttons) {
    if (StylusNativeChannel.instance.state.isPrimaryBarrelPressed) return true;
    return (buttons & kSecondaryMouseButton != 0) || (buttons & kSecondaryStylusButton != 0);
  }

  /// Detecta se o Botão Superior (Secundário / Barrel 2) está pressionado
  bool _isSecondaryBarrelPressed(int buttons) {
    if (StylusNativeChannel.instance.state.isSecondaryBarrelPressed) return true;
    return (buttons & 0x08 != 0) || (buttons & 0x10 != 0) || (buttons & kMiddleMouseButton != 0);
  }

  void _handleButtonTransitions(int currentButtons) {
    final settings = SettingsService.instance.currentSettings;

    // 1. Transição do Botão Inferior (Primário)
    final wasPrimaryPressed = _isPrimaryBarrelPressed(_lastButtons);
    final isPrimaryPressed = _isPrimaryBarrelPressed(currentButtons);
    if (!wasPrimaryPressed && isPrimaryPressed) {
      if (settings.stylusPrimaryTriggerMode == StylusTriggerMode.toggle) {
        _isPrimaryBarrelToggleActive = !_isPrimaryBarrelToggleActive;
      }
    }

    // 2. Transição do Botão Superior (Secundário)
    final wasSecondaryPressed = _isSecondaryBarrelPressed(_lastButtons);
    final isSecondaryPressed = _isSecondaryBarrelPressed(currentButtons);
    if (!wasSecondaryPressed && isSecondaryPressed) {
      if (settings.stylusSecondaryTriggerMode == StylusTriggerMode.toggle) {
        _isSecondaryBarrelToggleActive = !_isSecondaryBarrelToggleActive;
      }
    }

    _lastButtons = currentButtons;
  }

  StylusBarrelAction _getEffectiveStylusAction(int buttons, PointerDeviceKind? kind) {
    if (kind == PointerDeviceKind.mouse && (buttons == kMiddleMouseButton || buttons == 4)) {
      return StylusBarrelAction.disabled;
    }
    final settings = SettingsService.instance.currentSettings;

    // 1. Botão Superior (Secundário / Barrel 2)
    if (settings.stylusSecondaryBarrelAction != StylusBarrelAction.disabled) {
      final isPressed = _isSecondaryBarrelPressed(buttons);
      final isActive = (settings.stylusSecondaryTriggerMode == StylusTriggerMode.hold)
          ? isPressed
          : _isSecondaryBarrelToggleActive;
      if (isActive) {
        return settings.stylusSecondaryBarrelAction;
      }
    }

    // 2. Botão Inferior (Primário / Barrel 1)
    if (settings.stylusPrimaryBarrelAction != StylusBarrelAction.disabled) {
      final isPressed = _isPrimaryBarrelPressed(buttons);
      final isActive = (settings.stylusPrimaryTriggerMode == StylusTriggerMode.hold)
          ? isPressed
          : _isPrimaryBarrelToggleActive;
      if (isActive) {
        return settings.stylusPrimaryBarrelAction;
      }
    }

    // 3. Ponta Traseira Física (Inverted Eraser)
    bool isInverted = kind == PointerDeviceKind.invertedStylus ||
        StylusNativeChannel.instance.state.isInvertedEraser;
    
    if (isInverted) {
      return StylusBarrelAction.strokeEraser;
    }

    return StylusBarrelAction.disabled;
  }

  void _updateHoverState({
    required Offset? position,
    PointerDeviceKind? deviceKind,
    int buttons = 0,
    double pressure = 0.0,
    double distance = 0.0,
    bool isVisible = true,
  }) {
    final isBarrel = _isPrimaryBarrelPressed(buttons) || _isSecondaryBarrelPressed(buttons);
    final isInverted = deviceKind == PointerDeviceKind.invertedStylus;
    final barrelAction = _getEffectiveStylusAction(buttons, deviceKind);
    final isEraser = isInverted ||
        barrelAction == StylusBarrelAction.strokeEraser ||
        barrelAction == StylusBarrelAction.pixelEraser;

    _hoverNotifier.value = CanvasHoverState(
      position: position,
      deviceKind: deviceKind,
      buttons: buttons,
      pressure: pressure,
      distance: distance,
      isTemporaryEraser: isEraser,
      isBarrelButton: isBarrel || _isPrimaryBarrelToggleActive || _isSecondaryBarrelToggleActive,
      isInvertedStylus: isInverted,
      activeBarrelAction: barrelAction,
      isVisible: isVisible && position != null,
    );
  }
  void _updateCursorForSelection(Offset canvasPoint) {
    MouseCursor nextCursor = SystemMouseCursors.basic;
    final ctx = widget.canvasContext;
    if (ctx.selectionState.hasSelection && ctx.selectionState.bounds != null) {
      final handle = SelectionGeometry.getHandleAtPoint(
        canvasPoint,
        ctx.selectionState.bounds!,
        ctx.zoomScale,
        rotation: ctx.selectionState.rotationAngle,
      );
      switch (handle) {
        case SelectionHandleType.topCenter:
        case SelectionHandleType.bottomCenter:
          nextCursor = SystemMouseCursors.resizeUpDown;
          break;
        case SelectionHandleType.centerLeft:
        case SelectionHandleType.centerRight:
          nextCursor = SystemMouseCursors.resizeLeftRight;
          break;
        case SelectionHandleType.topLeft:
        case SelectionHandleType.bottomRight:
          nextCursor = SystemMouseCursors.resizeUpLeftDownRight;
          break;
        case SelectionHandleType.topRight:
        case SelectionHandleType.bottomLeft:
          nextCursor = SystemMouseCursors.resizeUpRightDownLeft;
          break;
        default:
          break;
      }
    }
    if (_cursorNotifier.value != nextCursor) {
      _cursorNotifier.value = nextCursor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.canvasContext;
    final note = ctx.currentNote;

    final childWidget = widget.builder != null
        ? widget.builder!(context, () => _inkHandler.activeStroke)
        : widget.child!;

    return ValueListenableBuilder<MouseCursor>(
      valueListenable: _cursorNotifier,
      builder: (context, cursor, child) {
        return MouseRegion(
          cursor: cursor,
          onExit: (_) {
            _updateHoverState(position: null, isVisible: false);
          },
          child: child,
        );
      },
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            if (globalIsHoveringFloatingPill) {
              return;
            }
            if (note != null && ctx.selectedCardId != null) {
              final rawCanvasPoint = (event.localPosition - ctx.panOffset) / ctx.zoomScale;
              for (final card in note.cards) {
                if (card.id == ctx.selectedCardId) {
                  final pillRect = Rect.fromLTWH(
                    card.x - 30.0,
                    card.y - 70.0,
                    math.max(card.width, 360.0) + 60.0,
                    70.0,
                  );
                  if (pillRect.contains(rawCanvasPoint)) {
                    return;
                  }
                }
              }
            }
            _panZoomHandler.handlePointerScroll(event);
          }
        },
        onPointerHover: (event) {
          _handleButtonTransitions(event.buttons);
          ctx.updateMousePos(event.localPosition);

          final rawCanvasPoint = (event.localPosition - ctx.panOffset) / ctx.zoomScale;
          final canvasPoint = Offset(math.max(0.0, rawCanvasPoint.dx), math.max(0.0, rawCanvasPoint.dy));

          _updateCursorForSelection(canvasPoint);

          CardsTelemetryController.instance.updatePointerEvent(
            eventType: 'Hover',
            deviceKind: event.kind,
            buttons: event.buttons,
            pressure: event.pressure,
            screenPosition: event.localPosition,
            canvasPosition: canvasPoint,
            activeTool: ctx.activeTool,
            selectedCardId: ctx.selectedCardId,
            cards: note?.cards,
          );

          if (event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus) {
            _lastStylusTimestampMs = DateTime.now().millisecondsSinceEpoch;
            ctx.onStylusHover(
              position: event.localPosition,
              pressure: event.pressure > 0.0 ? event.pressure : null,
              tilt: event.tilt != 0.0 ? event.tilt : null,
              distance: event.distance != 0.0 ? event.distance : null,
            );
          }

          _updateHoverState(
            position: event.localPosition,
            deviceKind: event.kind,
            buttons: event.buttons,
            pressure: event.pressure,
            distance: event.distance,
            isVisible: true,
          );
        },
        onPointerDown: (event) {
          _handleButtonTransitions(event.buttons);

          // 1. Verificação de Rejeição de Palma
          if (_isPalmContact(event)) {
            _activePalmPointerIds.add(event.pointer);
            return;
          }

          if (event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus) {
            _lastStylusTimestampMs = DateTime.now().millisecondsSinceEpoch;
          }

          ctx.updateMousePos(event.localPosition);
          final rawCanvasPoint = (event.localPosition - ctx.panOffset) / ctx.zoomScale;
          final canvasPoint = Offset(math.max(0.0, rawCanvasPoint.dx), math.max(0.0, rawCanvasPoint.dy));
          ctx.updatePointerInfo(event.timeStamp.inMilliseconds, canvasPoint);

          // Detecta se o toque inicial caiu sobre qualquer área de card ou suas alças de redimensionamento
          final cardHit = note != null
              ? CardsTelemetryController.detectCardZone(
                  cards: note.cards,
                  selectedCardId: ctx.selectedCardId,
                  canvasPoint: canvasPoint,
                )
              : (zone: CardHoverZone.none, card: null);

          final bool isTouchingCard = cardHit.zone != CardHoverZone.none || ctx.findCardAtPoint(canvasPoint) != null;
          _isInteractingWithCard = isTouchingCard;

          CardsTelemetryController.instance.updatePointerEvent(
            eventType: 'Down',
            deviceKind: event.kind,
            buttons: event.buttons,
            pressure: event.pressure,
            screenPosition: event.localPosition,
            canvasPosition: canvasPoint,
            activeTool: ctx.activeTool,
            selectedCardId: ctx.selectedCardId,
            cards: note?.cards,
            isInteractingWithCard: isTouchingCard,
          );

          final effectiveAction = _getEffectiveStylusAction(event.buttons, event.kind);
          _currentActiveAction = effectiveAction;

          _updateHoverState(
            position: event.localPosition,
            deviceKind: event.kind,
            buttons: event.buttons,
            pressure: event.pressure,
            distance: event.distance,
            isVisible: effectiveAction != StylusBarrelAction.disabled,
          );

          // Se estiver tocando num card ou suas alças, seleciona se necessário e NÃO permite iniciar traços/formas/borracha
          // IMPORTANTE: Defer o selectCard para pós-frame para que o PointerDown original
          // propagate completamente até os GestureDetectors dos cards antes de qualquer rebuild.
          if (isTouchingCard) {
            final clickedCard = cardHit.card ?? ctx.findCardAtPoint(canvasPoint);
            if (clickedCard != null) {
              if (ctx.selectedCardId != clickedCard.id) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ctx.selectCard(clickedCard.id);
                  ctx.updateSelectionState(SelectionState.empty());
                });
              }
            }
            return;
          }

          // 2. Execução da Ação do Barrel Button / Stylus Invertido
          if (effectiveAction != StylusBarrelAction.disabled) {
            _isActionExecuting = true;
            _currentActiveAction = effectiveAction;
            ctx.hideUIElementsOnInteraction();
            ctx.setInteracting();

            switch (effectiveAction) {
              case StylusBarrelAction.strokeEraser:
                ctx.eraseStrokesNear(canvasPoint, mode: EraserMode.stroke);
                ctx.onBarrelButtonPressed(isPressed: true, position: event.localPosition);
                return;
              case StylusBarrelAction.pixelEraser:
                ctx.eraseStrokesNear(canvasPoint, mode: EraserMode.precision);
                ctx.onBarrelButtonPressed(isPressed: true, position: event.localPosition);
                return;
              case StylusBarrelAction.selectionLasso:
                if (note != null) {
                  _selectionHandler.startSelection(
                    canvasPoint: canvasPoint,
                    selectionState: ctx.selectionState,
                    selectionType: SelectionType.lasso,
                    zoomScale: ctx.zoomScale,
                    currentNote: note,
                    onUpdateState: ctx.updateSelectionState,
                  );
                }
                return;
              case StylusBarrelAction.selectionRect:
                if (note != null) {
                  _selectionHandler.startSelection(
                    canvasPoint: canvasPoint,
                    selectionState: ctx.selectionState,
                    selectionType: SelectionType.rectangle,
                    zoomScale: ctx.zoomScale,
                    currentNote: note,
                    onUpdateState: ctx.updateSelectionState,
                  );
                }
                return;
              case StylusBarrelAction.colorPicker:
                ctx.sampleColorAt(canvasPoint);
                ctx.triggerHapticFeedback();
                return;
              case StylusBarrelAction.pan:
                return;
              case StylusBarrelAction.disabled:
                break;
            }
          }

          // 3. Botão do meio (Pan / Navegação de mouse: buttons == 4)
          if (event.buttons == 4 || (event.buttons & kMiddleMouseButton != 0)) {
            _isActionExecuting = true;
            _currentActiveAction = StylusBarrelAction.pan;
            ctx.hideUIElementsOnInteraction();
            ctx.setInteracting();
            return;
          }

          // 4. Toque / Clique Primário / Stylus Drawing
          if (event.buttons == 1 || (event.buttons & kPrimaryMouseButton != 0) || (event.kind == PointerDeviceKind.stylus && effectiveAction == StylusBarrelAction.disabled)) {
            ctx.hideUIElementsOnInteraction();

            // Interação direta com a Régua STEM (Arrastar ou Rotacionar)
            if (ctx.rulerState.isVisible && ctx.rulerState.containsPoint(canvasPoint)) {
              final isCenter = ctx.rulerState.isNearCenterProtractor(canvasPoint);
              _isRotatingRuler = isCenter;
              _isDraggingRuler = !isCenter;
              _rulerDragStart = canvasPoint;
              _rulerInitialState = ctx.rulerState;
              ctx.setInteracting();
              return;
            }

            // Interação direta com o Transferidor STEM (Arrastar ou Rotacionar)
            if (ctx.protractorState.isVisible && ctx.protractorState.containsPoint(canvasPoint)) {
              final isRotate = ctx.protractorState.isNearRotateHandle(canvasPoint);
              _isRotatingProtractor = isRotate;
              _isDraggingProtractor = !isRotate;
              _protractorDragStart = canvasPoint;
              _protractorInitialState = ctx.protractorState;
              ctx.setInteracting();
              return;
            }

            // Desmarca cards caso o clique seja no vazio (deferir para pós-frame para não quebrar propagação)
            if (ctx.selectedCardId != null && ctx.selectionState.selectedCardIds.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                FocusManager.instance.primaryFocus?.unfocus();
                ctx.selectCard(null);
              });
            } else if (ctx.selectionState.selectedCardIds.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                FocusManager.instance.primaryFocus?.unfocus();
                ctx.selectCard(null);
                ctx.updateSelectionState(SelectionState.empty());
              });
            }

            if (note != null) {
              // Se há uma seleção ativa no canvas, checamos primeiro se o toque foi sobre ela
              // (nas alças de redimensionamento/rotação ou no corpo da seleção para mover).
              if (ctx.selectionState.hasSelection) {
                final bounds = ctx.selectionState.bounds;
                if (bounds != null) {
                  final handle = SelectionGeometry.getHandleAtPoint(
                    canvasPoint,
                    bounds,
                    ctx.zoomScale,
                    rotation: ctx.selectionState.rotationAngle,
                  );
                  final isInside = bounds.inflate(10 / ctx.zoomScale).contains(canvasPoint);

                  if (handle != SelectionHandleType.none || isInside) {
                    // Usuário clicou na seleção existente para manipular/mover/redimensionar
                    _selectionHandler.startSelection(
                      canvasPoint: canvasPoint,
                      selectionState: ctx.selectionState,
                      selectionType: ctx.selectionState.type,
                      zoomScale: ctx.zoomScale,
                      currentNote: note,
                      onUpdateState: ctx.updateSelectionState,
                    );
                    return;
                  } else {
                    // Usuário clicou FORA da seleção existente -> limpa a seleção
                    ctx.updateSelectionState(SelectionState.empty());
                  }
                }
              }

              if (ctx.activeTool == 'card_insert') {
                ctx.insertCardAt(canvasPoint);
                return;
              } else if (ctx.activeTool == 'laser') {
                ctx.laserEngine.onPointerDown(canvasPoint);
                return;
              } else if (ctx.activeTool == 'select') {
                _selectionHandler.startSelection(
                  canvasPoint: canvasPoint,
                  selectionState: ctx.selectionState,
                  selectionType: ctx.selectionType,
                  zoomScale: ctx.zoomScale,
                  currentNote: note,
                  onUpdateState: ctx.updateSelectionState,
                );
                return;
              }

              if (ctx.activeTool == 'pen') {
                final pressure = event.kind != PointerDeviceKind.mouse && event.pressure > 0.0
                    ? event.pressure
                    : 0.6;
                _inkHandler.startStroke(
                  canvasPoint: canvasPoint,
                  pressure: pressure,
                  preset: widget.activePenPreset,
                  rulerState: ctx.rulerState,
                  protractorState: ctx.protractorState,
                );
              } else if (ctx.activeTool == 'shapes') {
                final pressure = event.kind != PointerDeviceKind.mouse && event.pressure > 0.0
                    ? event.pressure
                    : 0.6;
                _inkHandler.startGeometricShape(
                  shapeType: ctx.activeShapeType,
                  canvasPoint: canvasPoint,
                  pressure: pressure,
                  preset: widget.activePenPreset,
                );
              } else if (ctx.activeTool == 'eraser') {
                ctx.eraseStrokesNear(canvasPoint);
              }
            }
          }
        },
        onPointerMove: (event) {
          _handleButtonTransitions(event.buttons);
          if (_activePalmPointerIds.contains(event.pointer)) {
            return;
          }

          if (event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus) {
            _lastStylusTimestampMs = DateTime.now().millisecondsSinceEpoch;
          }

          ctx.updateMousePos(event.localPosition);

          final rawCanvasPoint = (event.localPosition - ctx.panOffset) / ctx.zoomScale;
          final canvasPoint = Offset(math.max(0.0, rawCanvasPoint.dx), math.max(0.0, rawCanvasPoint.dy));

          final isInteractingCard = _isInteractingWithCard || CardsTelemetryController.instance.isInteractingWithCard;

          CardsTelemetryController.instance.updatePointerEvent(
            eventType: 'Move',
            deviceKind: event.kind,
            buttons: event.buttons,
            pressure: event.pressure,
            screenPosition: event.localPosition,
            canvasPosition: canvasPoint,
            activeTool: ctx.activeTool,
            selectedCardId: ctx.selectedCardId,
            cards: note?.cards,
            isInteractingWithCard: isInteractingCard,
          );

          final effectiveAction = _getEffectiveStylusAction(event.buttons, event.kind);
          _updateHoverState(
            position: event.localPosition,
            deviceKind: event.kind,
            buttons: event.buttons,
            pressure: event.pressure,
            distance: event.distance,
            isVisible: _isActionExecuting || effectiveAction != StylusBarrelAction.disabled,
          );

          if (event.buttons == 4 || (event.buttons & kMiddleMouseButton != 0) || (_isActionExecuting && _currentActiveAction == StylusBarrelAction.pan)) {
            _panZoomHandler.handlePanDelta(event.delta);
            return;
          }

          // Se estiver interagindo com um Card (arrastando, redimensionando, digitando),
          // bloqueia estritamente qualquer desenho de tinta, borracha ou laço do canvas.
          if (isInteractingCard) {
            return;
          }

          // Execução de ação contínua do Stylus Barrel Button
          if (_isActionExecuting && _currentActiveAction != null) {
            ctx.setInteracting();
            switch (_currentActiveAction!) {
              case StylusBarrelAction.strokeEraser:
                ctx.eraseStrokesNear(canvasPoint, mode: EraserMode.stroke);
                return;
              case StylusBarrelAction.pixelEraser:
                ctx.eraseStrokesNear(canvasPoint, mode: EraserMode.precision);
                return;
              case StylusBarrelAction.selectionLasso:
                _selectionHandler.updateSelection(
                  canvasPoint: canvasPoint,
                  selectionState: ctx.selectionState,
                  selectionType: SelectionType.lasso,
                  zoomScale: ctx.zoomScale,
                  onUpdateState: ctx.updateSelectionState,
                );
                return;
              case StylusBarrelAction.selectionRect:
                _selectionHandler.updateSelection(
                  canvasPoint: canvasPoint,
                  selectionState: ctx.selectionState,
                  selectionType: SelectionType.rectangle,
                  zoomScale: ctx.zoomScale,
                  onUpdateState: ctx.updateSelectionState,
                );
                return;
              case StylusBarrelAction.colorPicker:
                ctx.sampleColorAt(canvasPoint);
                return;
              case StylusBarrelAction.pan:
                _panZoomHandler.handlePanDelta(event.delta);
                return;
              case StylusBarrelAction.disabled:
                break;
            }
          }

          if (event.buttons == 1 || (event.buttons & kPrimaryMouseButton != 0)) {
            if (ctx.activeTool == 'laser') {
              ctx.laserEngine.onPointerMove(canvasPoint);
              return;
            }

            // Movimentação / Rotação da Régua STEM
            if (_isDraggingRuler && _rulerDragStart != null && _rulerInitialState != null) {
              ctx.setInteracting();
              final delta = canvasPoint - _rulerDragStart!;
              ctx.updateRulerState(_rulerInitialState!.copyWith(
                center: _rulerInitialState!.center + delta,
              ));
              return;
            }

            if (_isRotatingRuler && _rulerInitialState != null && _rulerDragStart != null) {
              ctx.setInteracting();
              final center = _rulerInitialState!.center;
              final initialAngle = math.atan2(_rulerDragStart!.dy - center.dy, _rulerDragStart!.dx - center.dx);
              final currentAngle = math.atan2(canvasPoint.dy - center.dy, canvasPoint.dx - center.dx);

              double diff = currentAngle - initialAngle;
              while (diff > math.pi) {
                diff -= 2 * math.pi;
              }
              while (diff < -math.pi) {
                diff += 2 * math.pi;
              }

              final targetAngle = _rulerInitialState!.angle + diff;
              final snapped = StemRulerState.snapAngle(targetAngle);
              ctx.updateRulerState(_rulerInitialState!.copyWith(angle: snapped));
              return;
            }

            // Movimentação / Rotação do Transferidor STEM
            if (_isDraggingProtractor && _protractorDragStart != null && _protractorInitialState != null) {
              ctx.setInteracting();
              final delta = canvasPoint - _protractorDragStart!;
              ctx.updateProtractorState(_protractorInitialState!.copyWith(
                center: _protractorInitialState!.center + delta,
              ));
              return;
            }

            if (_isRotatingProtractor && _protractorInitialState != null && _protractorDragStart != null) {
              ctx.setInteracting();
              final center = _protractorInitialState!.center;
              final initialAngle = math.atan2(_protractorDragStart!.dy - center.dy, _protractorDragStart!.dx - center.dx);
              final currentAngle = math.atan2(canvasPoint.dy - center.dy, canvasPoint.dx - center.dx);

              double diff = currentAngle - initialAngle;
              while (diff > math.pi) {
                diff -= 2 * math.pi;
              }
              while (diff < -math.pi) {
                diff += 2 * math.pi;
              }

              final targetAngle = _protractorInitialState!.angle + diff;
              final snapped = StemProtractorState.snapAngle(targetAngle);
              ctx.updateProtractorState(_protractorInitialState!.copyWith(angle: snapped));
              return;
            }

            if (note != null) {
              // Se a seleção estiver ativa sendo arrastada ou redimensionada pelas alças
              if (ctx.selectionState.isDraggingSelection || ctx.selectionState.isTransforming) {
                _selectionHandler.updateSelection(
                  canvasPoint: canvasPoint,
                  selectionState: ctx.selectionState,
                  selectionType: ctx.selectionState.type,
                  zoomScale: ctx.zoomScale,
                  onUpdateState: ctx.updateSelectionState,
                );
                return;
              }

              if (ctx.activeTool == 'pen') {
                final pressure = event.kind != PointerDeviceKind.mouse && event.pressure > 0.0
                    ? event.pressure
                    : 0.6;
                _inkHandler.appendPoint(
                  canvasPoint: canvasPoint,
                  pressure: pressure,
                  preset: widget.activePenPreset,
                  rulerState: ctx.rulerState,
                  protractorState: ctx.protractorState,
                );
              } else if (ctx.activeTool == 'shapes') {
                final pressure = event.kind != PointerDeviceKind.mouse && event.pressure > 0.0
                    ? event.pressure
                    : 0.6;
                _inkHandler.updateGeometricShape(
                  shapeType: ctx.activeShapeType,
                  canvasPoint: canvasPoint,
                  pressure: pressure,
                  preset: widget.activePenPreset,
                );
              } else if (ctx.activeTool == 'eraser') {
                ctx.eraseStrokesNear(canvasPoint);
              } else if (ctx.activeTool == 'select') {
                _selectionHandler.updateSelection(
                  canvasPoint: canvasPoint,
                  selectionState: ctx.selectionState,
                  selectionType: ctx.selectionType,
                  zoomScale: ctx.zoomScale,
                  onUpdateState: ctx.updateSelectionState,
                );
              }
            }
          }
        },
        onPointerUp: (event) {
          _handleButtonTransitions(event.buttons);
          if (_activePalmPointerIds.remove(event.pointer)) {
            return;
          }

          final rawCanvasPoint = (event.localPosition - ctx.panOffset) / ctx.zoomScale;
          final canvasPoint = Offset(math.max(0.0, rawCanvasPoint.dx), math.max(0.0, rawCanvasPoint.dy));

          CardsTelemetryController.instance.updatePointerEvent(
            eventType: 'Up',
            deviceKind: event.kind,
            buttons: 0,
            pressure: 0.0,
            screenPosition: event.localPosition,
            canvasPosition: canvasPoint,
            activeTool: ctx.activeTool,
            selectedCardId: ctx.selectedCardId,
            cards: note?.cards,
            isInteractingWithCard: false,
          );

          if (_isInteractingWithCard) {
            _isInteractingWithCard = false;
            CardsTelemetryController.instance.setInteractingWithCard(false);
            return;
          }

          if (_isActionExecuting && _currentActiveAction != null) {
            final finishedAction = _currentActiveAction!;
            _isActionExecuting = false;
            _currentActiveAction = null;

            switch (finishedAction) {
              case StylusBarrelAction.strokeEraser:
              case StylusBarrelAction.pixelEraser:
                ctx.scheduleEraseCommit();
                ctx.onBarrelButtonPressed(isPressed: false, position: event.localPosition);
                break;
              case StylusBarrelAction.selectionLasso:
              case StylusBarrelAction.selectionRect:
                _selectionHandler.finishSelection(
                  selectionState: ctx.selectionState,
                  currentNote: note,
                  onUpdateState: ctx.updateSelectionState,
                );
                break;
              case StylusBarrelAction.colorPicker:
                break;
              case StylusBarrelAction.pan:
                widget.onScheduleBounceCheck();
                break;
              case StylusBarrelAction.disabled:
                break;
            }

            _updateHoverState(
              position: event.localPosition,
              deviceKind: event.kind,
              buttons: 0,
              pressure: 0.0,
              isVisible: true,
            );
            return;
          }

          if (ctx.activeTool == 'laser') {
            ctx.laserEngine.onPointerUp();
            return;
          }

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

          // Se finalizou o arraste ou transformação da seleção existente
          if (ctx.selectionState.isDraggingSelection || ctx.selectionState.isTransforming) {
            if (note != null) {
              _selectionHandler.finishSelection(
                selectionState: ctx.selectionState,
                currentNote: note,
                onUpdateState: ctx.updateSelectionState,
              );
            }
            return;
          }

          if (ctx.activeTool == 'pen' || ctx.activeTool == 'shapes') {
            final finishedStroke = _inkHandler.finishStroke();
            if (finishedStroke != null) {
              widget.onCommitStroke(finishedStroke);
            }
          } else if (ctx.activeTool == 'eraser') {
            ctx.scheduleEraseCommit();
          } else if (ctx.activeTool == 'select') {
            _selectionHandler.finishSelection(
              selectionState: ctx.selectionState,
              currentNote: note,
              onUpdateState: ctx.updateSelectionState,
            );
          }
        },
        onPointerCancel: (event) {
          _handleButtonTransitions(0);
          _activePalmPointerIds.remove(event.pointer);
          _isInteractingWithCard = false;
          CardsTelemetryController.instance.setInteractingWithCard(false);
          CardsTelemetryController.instance.updatePointerEvent(
            eventType: 'Cancel',
            deviceKind: event.kind,
            buttons: 0,
            pressure: 0.0,
            screenPosition: event.localPosition,
            canvasPosition: null,
            activeTool: ctx.activeTool,
            selectedCardId: ctx.selectedCardId,
            cards: note?.cards,
            isInteractingWithCard: false,
          );
          if (_isActionExecuting && _currentActiveAction != null) {
            if (_currentActiveAction == StylusBarrelAction.strokeEraser ||
                _currentActiveAction == StylusBarrelAction.pixelEraser) {
              ctx.scheduleEraseCommit();
            }
          }
          _isActionExecuting = false;
          _currentActiveAction = null;
          _lastButtons = 0;
        },
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            childWidget,
            // Camada de Feedback Visual de Hover Desacoplada e Suave
            Positioned.fill(
              child: IgnorePointer(
                child: _CanvasHoverFeedbackOverlay(
                  hoverNotifier: _hoverNotifier,
                  canvasContext: ctx,
                  activePenPreset: widget.activePenPreset,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Overlay visual de feedback de hover do stylus/mouse limpo e de alta precisão.
class _CanvasHoverFeedbackOverlay extends StatelessWidget {
  final ValueNotifier<CanvasHoverState> hoverNotifier;
  final CanvasInputContext canvasContext;
  final PenSlotPreset activePenPreset;

  const _CanvasHoverFeedbackOverlay({
    required this.hoverNotifier,
    required this.canvasContext,
    required this.activePenPreset,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        hoverNotifier,
        MoscaroThemeController.instance,
        SettingsService.instance,
      ]),
      builder: (context, _) {
        final settings = SettingsService.instance.currentSettings;
        if (!settings.enableStylusHoverPreview) {
          return const SizedBox.shrink();
        }

        final hoverState = hoverNotifier.value;
        if (!hoverState.isVisible || hoverState.position == null) {
          return const SizedBox.shrink();
        }

        // Oculta o retículo de hover quando a caneta estiver tocando a tela/escrevendo (pressão > 0)
        // para evitar o círculo expansivo intrusivo sob a ponta física da caneta.
        if (hoverState.pressure > 0.0 && !hoverState.isTemporaryEraser && !hoverState.isInvertedStylus) {
          return const SizedBox.shrink();
        }

        final pos = hoverState.position!;
        final zoom = canvasContext.zoomScale;

        // Determinar ferramenta efetiva em tempo real
        String effectiveTool = canvasContext.activeTool;
        final barrelAction = hoverState.activeBarrelAction;

        if (hoverState.isInvertedStylus) {
          effectiveTool = 'eraser';
        } else if (barrelAction != null && barrelAction != StylusBarrelAction.disabled) {
          switch (barrelAction) {
            case StylusBarrelAction.strokeEraser:
            case StylusBarrelAction.pixelEraser:
              effectiveTool = 'eraser';
              break;
            case StylusBarrelAction.selectionLasso:
            case StylusBarrelAction.selectionRect:
              effectiveTool = 'select';
              break;
            case StylusBarrelAction.colorPicker:
              effectiveTool = 'colorPicker';
              break;
            case StylusBarrelAction.pan:
              effectiveTool = 'pan';
              break;
            case StylusBarrelAction.disabled:
              break;
          }
        }

        final isEraser = effectiveTool == 'eraser' ||
            hoverState.isTemporaryEraser ||
            hoverState.isInvertedStylus;

        final isPixelEraser = barrelAction == StylusBarrelAction.pixelEraser;

        final theme = MoscaroThemeController.instance.currentTheme;
        final accentPrimary = theme.accentPrimary;
        final accentSecondary = theme.accentSecondary;

        // Para a Caneta (Pen) e Formas: Não desenha o círculo/retículo sob a ponta física da caneta/mesa
        if (effectiveTool == 'pen' || effectiveTool == 'shapes') {
          return const SizedBox.shrink();
        }

        // Cálculo do Raio do Retículo de Hover para ferramentas que necessitam de preview de área
        double ringRadius = 12.0;
        if (isEraser) {
          ringRadius = math.max(14.0, (canvasContext.eraserRadius * zoom));
        } else if (effectiveTool == 'laser') {
          ringRadius = 9.0;
        } else if (effectiveTool == 'select') {
          ringRadius = 14.0;
        } else if (effectiveTool == 'colorPicker') {
          ringRadius = 12.0;
        } else if (effectiveTool == 'pan') {
          ringRadius = 12.0;
        }

        return RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _HoverRingCustomPainter(
              center: pos,
              radius: ringRadius,
              effectiveTool: effectiveTool,
              isEraser: isEraser,
              isPixelEraser: isPixelEraser,
              penColor: activePenPreset.color,
              accentPrimary: accentPrimary,
              accentSecondary: accentSecondary,
              borderGlowColor: theme.borderGlowColor,
              pressure: hoverState.pressure,
            ),
          ),
        );
      },
    );
  }
}

/// CustomPainter para desenhar os anéis luminosos e retículos de alta precisão.
class _HoverRingCustomPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final String effectiveTool;
  final bool isEraser;
  final bool isPixelEraser;
  final Color penColor;
  final Color accentPrimary;
  final Color accentSecondary;
  final Color borderGlowColor;
  final double pressure;

  _HoverRingCustomPainter({
    required this.center,
    required this.radius,
    required this.effectiveTool,
    required this.isEraser,
    this.isPixelEraser = false,
    required this.penColor,
    required this.accentPrimary,
    required this.accentSecondary,
    required this.borderGlowColor,
    required this.pressure,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isEraser) {
      // Feedback da Borracha: Anel Neon Pro Max com halo suave
      final glowPaint = Paint()
        ..color = MoscaroTokens.auroraPink.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      canvas.drawCircle(center, radius, glowPaint);

      final ringPaint = Paint()
        ..color = MoscaroTokens.auroraPink.withValues(alpha: 0.90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawCircle(center, radius, ringPaint);

      // Micro retículo central
      final corePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 1.8, corePaint);

      if (isPixelEraser) {
        // Miras de precisão nos eixos
        final crossPaint = Paint()
          ..color = MoscaroTokens.auroraPink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        const tick = 3.5;
        canvas.drawLine(Offset(center.dx - radius - tick, center.dy), Offset(center.dx - radius + 1, center.dy), crossPaint);
        canvas.drawLine(Offset(center.dx + radius - 1, center.dy), Offset(center.dx + radius + tick, center.dy), crossPaint);
        canvas.drawLine(Offset(center.dx, center.dy - radius - tick), Offset(center.dx, center.dy - radius + 1), crossPaint);
        canvas.drawLine(Offset(center.dx, center.dy + radius - 1), Offset(center.dx, center.dy + radius + tick), crossPaint);
      }
      return;
    }

    if (effectiveTool == 'laser') {
      final laserHalo = Paint()
        ..color = const Color(0xFFFF0055).withValues(alpha: 0.45)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.0);
      canvas.drawCircle(center, 7.0, laserHalo);

      final laserDot = Paint()
        ..color = const Color(0xFFFF2A6D)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 3.0, laserDot);
      return;
    }

    if (effectiveTool == 'select') {
      final selectPaint = Paint()
        ..color = accentPrimary.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(center, radius, selectPaint);

      final tickPaint = Paint()
        ..color = accentPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      const tick = 4.0;
      canvas.drawLine(Offset(center.dx - radius - tick, center.dy), Offset(center.dx - radius + 2, center.dy), tickPaint);
      canvas.drawLine(Offset(center.dx + radius - 2, center.dy), Offset(center.dx + radius + tick, center.dy), tickPaint);
      canvas.drawLine(Offset(center.dx, center.dy - radius - tick), Offset(center.dx, center.dy - radius + 2), tickPaint);
      canvas.drawLine(Offset(center.dx, center.dy + radius - 2), Offset(center.dx, center.dy + radius + tick), tickPaint);
      return;
    }

    if (effectiveTool == 'colorPicker') {
      // Retículo de conta-gotas / amostragem de cor
      final outerGlow = Paint()
        ..color = accentPrimary.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      canvas.drawCircle(center, radius, outerGlow);

      final ringPaint = Paint()
        ..color = accentPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, radius, ringPaint);

      // Ponto de visualização da cor ativa
      final previewPaint = Paint()
        ..color = penColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 4.0, previewPaint);

      final innerBorder = Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, 4.0, innerBorder);
      return;
    }

    if (effectiveTool == 'pan') {
      final panRing = Paint()
        ..color = accentPrimary.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(center, radius, panRing);

      final cross = Paint()
        ..color = accentPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(center.dx - 4, center.dy), Offset(center.dx + 4, center.dy), cross);
      canvas.drawLine(Offset(center.dx, center.dy - 4), Offset(center.dx, center.dy + 4), cross);
      return;
    }

    // Feedback da Caneta / Formas: Anel correspondente à espessura real do traço
    final glowPaint = Paint()
      ..color = penColor.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawCircle(center, radius, glowPaint);

    final ringPaint = Paint()
      ..color = penColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, ringPaint);

    // Retículo de alta precisão no centro
    final centerDotPaint = Paint()
      ..color = penColor.computeLuminance() > 0.6 ? Colors.black87 : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 1.4, centerDotPaint);
  }

  @override
  bool shouldRepaint(covariant _HoverRingCustomPainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.radius != radius ||
        oldDelegate.effectiveTool != effectiveTool ||
        oldDelegate.isEraser != isEraser ||
        oldDelegate.isPixelEraser != isPixelEraser ||
        oldDelegate.penColor != penColor ||
        oldDelegate.accentPrimary != accentPrimary ||
        oldDelegate.pressure != pressure;
  }
}

