import 'package:flutter/material.dart';
import 'theme/moscaro_v2_tokens.dart';
import 'theme/moscaro_v2_extension.dart';
import 'widgets/canvas_dot_grid_painter.dart';
import 'widgets/toolbar_pill.dart';
import 'widgets/ai_sidebar.dart';
import 'widgets/note_tab_bar.dart';
import 'widgets/note_sidebar.dart';
import 'widgets/note_models.dart';
import 'widgets/ink_models.dart';
import 'widgets/stroke_painter.dart';

void main() {
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

  // Estado de Navegação do Canvas
  Offset _panOffset = Offset.zero;
  final double _zoomScale = 1.0;
  Offset? _mousePosition;
  CanvasBackgroundType _currentBackground = CanvasBackgroundType.dotGrid;

  // Estado de Ferramenta
  String _activeTool = 'pen';
  bool _isAIOpen = false;

  // Desenhos / Escrita Manual do traço ativo
  InkStroke? _activeStroke;

  @override
  void initState() {
    super.initState();
    _addNewNote("Anotações STEM");
  }

  void _addNewNote(String title) {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newNote = NoteDocument(
      id: newId,
      title: title,
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

  @override
  Widget build(BuildContext context) {
    final note = _currentNote;
    final Map<String, String> noteTitles = {
      for (final n in _notes) n.id: n.title,
      for (final n in _notes) ..._flattenTitles(n)
    };

    return Scaffold(
      body: Stack(
        children: [
          // 1. Fundo do Canvas
          MouseRegion(
            onHover: (event) {
              setState(() {
                _mousePosition = event.localPosition;
              });
            },
            onExit: (_) {
              setState(() {
                _mousePosition = null;
              });
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
                onPointerDown: (event) {
                  final isMiddleButton = event.buttons == 4;
                  if (isMiddleButton) return;

                  if (event.buttons == 1 && note != null) {
                    if (_activeTool == 'pen') {
                      final localPoint = event.localPosition - _panOffset;
                      setState(() {
                        _activeStroke = InkStroke(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          points: [StrokePoint(point: localPoint, pressure: event.pressure)],
                          color: Colors.white,
                          strokeWidth: 3.0,
                        );
                      });
                    } else if (_activeTool == 'eraser') {
                      _eraseStrokesNear(event.localPosition - _panOffset);
                    }
                  }
                },
                onPointerMove: (event) {
                  final isMiddleButton = event.buttons == 4;

                  if (isMiddleButton) {
                    setState(() {
                      _panOffset += event.delta;
                    });
                    return;
                  }

                  if (event.buttons == 1 && note != null) {
                    final localPoint = event.localPosition - _panOffset;
                    if (_activeTool == 'pen' && _activeStroke != null) {
                      setState(() {
                        _activeStroke!.points.add(
                          StrokePoint(point: localPoint, pressure: event.pressure),
                        );
                      });
                    } else if (_activeTool == 'eraser') {
                      _eraseStrokesNear(localPoint);
                    }
                  }
                },
                onPointerUp: (event) {
                  if (_activeStroke != null && note != null) {
                    setState(() {
                      note.strokes.add(_activeStroke!);
                      _activeStroke = null;
                    });
                  }
                },
                child: Stack(
                  children: [
                    CustomPaint(
                      size: Size.infinite,
                      painter: CanvasDotGridPainter(
                        panOffset: _panOffset,
                        zoomScale: _zoomScale,
                        mousePosition: _mousePosition,
                        backgroundType: _currentBackground,
                      ),
                    ),
                    if (note != null)
                      CustomPaint(
                        size: Size.infinite,
                        painter: StrokePainter(
                          strokes: note.strokes,
                          activeStroke: _activeStroke,
                          panOffset: _panOffset,
                          zoomScale: _zoomScale,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 2. TabBar Superior (Posicionado de forma adaptativa deslocado da Sidebar esquerda)
          Positioned(
            top: 24,
            left: _isSidebarOpen ? 348 : 0, // BUGFIX: Move a TabBar fisicamente para a direita quando a sidebar abrir!
            right: 0,
            child: Center(
              child: NoteTabBar(
                activeNoteIds: _activeNoteIds,
                noteTitles: noteTitles,
                selectedNoteId: _selectedNoteId,
                isSidebarOpen: _isSidebarOpen,
                onSelectNote: (noteId) {
                  setState(() {
                    _selectedNoteId = noteId;
                  });
                },
                onCloseNote: (noteId) {
                  setState(() {
                    _activeNoteIds.remove(noteId);
                    if (_selectedNoteId == noteId) {
                      _selectedNoteId = _activeNoteIds.isNotEmpty ? _activeNoteIds.last : null;
                    }
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

          // 3. Barra de Ferramentas / ToolbarPill (Inferior)
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: ToolbarPill(
                currentBackground: _currentBackground,
                isAIOpen: _isAIOpen,
                onBackgroundChanged: (newBg) {
                  setState(() {
                    _currentBackground = newBg;
                  });
                },
                onSelectPen: () {
                  setState(() {
                    _activeTool = 'pen';
                  });
                },
                onSelectEraser: () {
                  setState(() {
                    _activeTool = 'eraser';
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

          // 4. Sidebar Esquerda de Notas (Contém a Lixeira e Esvaziamento)
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

          // 5. Painel Lateral Direito da IA
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
    );
  }

  void _eraseStrokesNear(Offset localPoint) {
    final note = _currentNote;
    if (note == null) return;
    setState(() {
      note.strokes.removeWhere((stroke) {
        return stroke.points.any((p) => (p.point - localPoint).distance < 24.0);
      });
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
