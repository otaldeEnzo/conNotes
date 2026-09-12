import 'package:flutter/foundation.dart';
import '../widgets/undo_commands.dart';
import '../widgets/note_models.dart';

class CanvasHistoryController extends ChangeNotifier {
  static final CanvasHistoryController instance = CanvasHistoryController._internal();
  CanvasHistoryController._internal();

  final AppUndoManager _undoManager = AppUndoManager.instance;
  AppUndoManager get undoManager => _undoManager;

  int _strokesVersion = 0;
  int get strokesVersion => _strokesVersion;

  void incrementStrokesVersion() {
    _strokesVersion++;
    notifyListeners();
  }

  void pushCommand(UndoCommand command, NoteDocument note, {bool execute = true}) {
    _undoManager.pushCommand(command, execute: execute, note: note);
    notifyListeners();
  }

  void undo(NoteDocument note) {
    if (_undoManager.canUndo(note)) {
      _undoManager.undo(note);
      notifyListeners();
    }
  }

  void redo(NoteDocument note) {
    if (_undoManager.canRedo(note)) {
      _undoManager.redo(note);
      notifyListeners();
    }
  }
}
