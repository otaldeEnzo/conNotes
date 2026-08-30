import 'package:flutter/material.dart';
import '../widgets/note_models.dart';
import '../models/canvas_card_model.dart';
import '../widgets/selection_models.dart';
import '../widgets/smart_shapes.dart';
import '../widgets/undo_commands.dart';
import '../widgets/stem_ruler_model.dart';
import '../widgets/stem_protractor_model.dart';
import '../widgets/laser_pointer.dart';

import '../widgets/ink_models.dart';

/// Interface de contexto passada do _CanvasHomeScreenState para os Input Handlers.
/// Isso permite extrair toda a lógica pesada de inputs sem precisar
/// refatorar imediatamente as 3700 linhas do estado principal.
abstract class CanvasInputContext {
  // Getters do Estado
  NoteDocument? get currentNote;
  String get activeTool;
  SelectionState get selectionState;
  SelectionType get selectionType;
  Offset get panOffset;
  double get zoomScale;
  Offset? get mousePos;
  double get smoothedPressure;
  int get lastPointerTimestampMs;
  Offset? get lastPointerCanvasPoint;

  // Shapes e Grid
  ShapeType get activeShapeType;
  bool get isGridMenuOpen;
  
  // Medição (Régua/Transferidor)
  StemRulerState get rulerState;
  StemProtractorState get protractorState;
  void updateRulerState(StemRulerState state);
  void updateProtractorState(StemProtractorState state);
  void updateMousePos(Offset? pos);

  // Ações e Callbacks
  void updateSelectionState(SelectionState state);
  void triggerSelectionUpdate();
  void setInteracting();
  void triggerHapticFeedback();
  void updateSmoothedPressure(double pressure);
  void updatePointerInfo(int timestampMs, Offset? canvasPoint);

  // Undo / Persistência
  void pushCommand(UndoCommand command, {required bool execute, NoteDocument? note});
  void scheduleAutoSave();
  void incrementStrokesVersion();
  void incrementCommittedStrokes();

  // Cards e Textos
  String? get selectedCardId;
  void selectCard(String? id);
  CanvasCardModel? findCardAtPoint(Offset canvasPoint);

  // Borracha e Laser
  LaserPointerEngine get laserEngine;
  void eraseStrokesNear(Offset canvasPoint, {EraserMode? mode});
  void scheduleEraseCommit();
  Color? sampleColorAt(Offset canvasPoint);

  // Inserção de Cards
  void insertCardAt(Offset canvasPoint);

  // Gestão de Sub-Barras UI
  void hideUIElementsOnInteraction();

  // Stylus, Borracha Invertida e Rejeição de Palma
  double get eraserRadius => 24.0;
  bool get isPalmRejectionEnabled => true;
  void onStylusHover({Offset? position, double? pressure, double? tilt, double? distance}) {}
  void onBarrelButtonPressed({required bool isPressed, Offset? position}) {}
  void onInvertedStylusChanged({required bool isInverted}) {}
  void onPalmContactRejected({required Offset position, required double contactSize}) {}
}
