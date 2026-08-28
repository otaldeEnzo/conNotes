import 'package:flutter/foundation.dart';
import 'dart:ui';
import '../widgets/note_models.dart';
import '../widgets/canvas_dot_grid_painter.dart';

class CanvasWorkspaceState extends ChangeNotifier {
  static final CanvasWorkspaceState instance = CanvasWorkspaceState._internal();
  CanvasWorkspaceState._internal();

  // Notas e Documentos
  final List<NoteDocument> _notes = [];
  final List<String> _activeNoteIds = [];
  String? _selectedNoteId;

  List<NoteDocument> get notes => List.unmodifiable(_notes);
  List<String> get activeNoteIds => List.unmodifiable(_activeNoteIds);
  String? get selectedNoteId => _selectedNoteId;
  NoteDocument? get currentNote => _selectedNoteId != null 
      ? _notes.cast<NoteDocument?>().firstWhere((n) => n?.id == _selectedNoteId, orElse: () => null) 
      : null;

  // Viewport (Pan & Zoom)
  final ValueNotifier<Offset> panNotifier = ValueNotifier(Offset.zero);
  final ValueNotifier<double> zoomNotifier = ValueNotifier(1.0);
  final ValueNotifier<Offset?> mousePosNotifier = ValueNotifier(null);
  
  Offset get panOffset => panNotifier.value;
  double get zoomScale => zoomNotifier.value;

  // Fundo
  CanvasBackgroundType _currentBackground = CanvasBackgroundType.dotGrid;
  CanvasBackgroundType get currentBackground => _currentBackground;

  void setNotes(List<NoteDocument> newNotes) {
    _notes.clear();
    _notes.addAll(newNotes);
    notifyListeners();
  }

  void addActiveNote(String noteId) {
    if (!_activeNoteIds.contains(noteId)) {
      _activeNoteIds.add(noteId);
      notifyListeners();
    }
  }

  void removeActiveNote(String noteId) {
    if (_activeNoteIds.contains(noteId)) {
      _activeNoteIds.remove(noteId);
      if (_selectedNoteId == noteId) {
        _selectedNoteId = _activeNoteIds.isNotEmpty ? _activeNoteIds.last : null;
      }
      notifyListeners();
    }
  }

  void selectNote(String noteId) {
    if (_selectedNoteId != noteId) {
      _selectedNoteId = noteId;
      notifyListeners();
    }
  }

  void setBackground(CanvasBackgroundType type) {
    if (_currentBackground != type) {
      _currentBackground = type;
      notifyListeners();
    }
  }

  void updatePan(Offset newPan) {
    if (panNotifier.value != newPan) {
      panNotifier.value = newPan;
    }
  }

  void updateZoom(double newZoom) {
    if (zoomNotifier.value != newZoom) {
      zoomNotifier.value = newZoom;
    }
  }

  void updateMousePos(Offset? pos) {
    if (mousePosNotifier.value != pos) {
      mousePosNotifier.value = pos;
    }
  }
}
