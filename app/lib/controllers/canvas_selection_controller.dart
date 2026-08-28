import 'package:flutter/foundation.dart';
import 'dart:ui';
import '../widgets/selection_models.dart';
import '../models/canvas_card_model.dart';
import '../widgets/ink_models.dart';

class CanvasSelectionController extends ChangeNotifier {
  static final CanvasSelectionController instance = CanvasSelectionController._internal();
  CanvasSelectionController._internal();

  SelectionState _state = SelectionState.empty();
  SelectionState get state => _state;

  // Lógica de Ferramenta
  SelectionType _selectionType = SelectionType.rectangle;
  SelectionType get selectionType => _selectionType;

  void setSelectionType(SelectionType type) {
    if (_selectionType != type) {
      _selectionType = type;
      notifyListeners();
    }
  }

  void updateState(SelectionState newState) {
    _state = newState;
    notifyListeners();
  }

  void clearSelection() {
    _state = SelectionState.empty().copyWith(type: _selectionType);
    notifyListeners();
  }

  void selectStroke(String strokeId) {
    _state = _state.copyWith(
      selectedStrokeIds: {..._state.selectedStrokeIds, strokeId},
    );
    notifyListeners();
  }

  void selectCard(String cardId) {
    _state = _state.copyWith(
      selectedCardIds: {..._state.selectedCardIds, cardId},
    );
    notifyListeners();
  }
}
