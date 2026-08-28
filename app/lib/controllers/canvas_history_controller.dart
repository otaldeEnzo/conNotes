import 'package:flutter/foundation.dart';
import '../widgets/undo_commands.dart';
import '../widgets/ink_models.dart';
import '../models/canvas_card_model.dart';

class CanvasHistoryController extends ChangeNotifier {
  static final CanvasHistoryController instance = CanvasHistoryController._internal();
  CanvasHistoryController._internal();

  final AppUndoManager _undoManager = AppUndoManager();
  AppUndoManager get undoManager => _undoManager;

  int _strokesVersion = 0;
  int get strokesVersion => _strokesVersion;

  void incrementStrokesVersion() {
    _strokesVersion++;
    notifyListeners();
  }

  void pushCommand(Command command) {
    _undoManager.push(command);
    notifyListeners();
  }

  void undo() {
    if (_undoManager.canUndo) {
      _undoManager.undo();
      notifyListeners();
    }
  }

  void redo() {
    if (_undoManager.canRedo) {
      _undoManager.redo();
      notifyListeners();
    }
  }
}
