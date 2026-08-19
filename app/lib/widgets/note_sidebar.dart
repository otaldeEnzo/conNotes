import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_theme_controller.dart';
import 'note_models.dart';
import 'svg_icon.dart';
import '../services/workspace_storage_service.dart';

enum NoteDropZone { before, inside, after }

/// Sidebar Esquerda com Hierarquia de Cadernos, Pastas e Notas .cncanvas (100% Moscaro v2 Adaptativo).
class NoteSidebar extends StatefulWidget {
  final bool isOpen;
  final String? selectedNoteId;
  final ValueChanged<NoteDocument> onSelectNote;
  final VoidCallback? onAddNote;

  const NoteSidebar({
    super.key,
    required this.isOpen,
    this.selectedNoteId,
    required this.onSelectNote,
    this.onAddNote,
  });

  @override
  State<NoteSidebar> createState() => _NoteSidebarState();
}

class _NoteSidebarState extends State<NoteSidebar> {
  final Set<String> _expandedFolderIds = {};
  final Set<String> _expandedNoteIds = {};
  bool _isTrashExpanded = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Estado de Renomeação Inline por Duplo Clique
  String? _editingNoteId;
  final TextEditingController _inlineRenameController = TextEditingController();
  final FocusNode _inlineRenameFocusNode = FocusNode();

  // Estado de Drag & Drop
  bool _isDragging = false;
  String? _dropHoverTargetId;
  NoteDropZone? _dropHoverZone;
  bool _isTrashHovered = false;

  // Overlay Menu à Direita da Sidebar
  OverlayEntry? _activeMenuOverlay;

  @override
  void didUpdateWidget(NoteSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOpen != widget.isOpen && !widget.isOpen) {
      _closeActiveMenu();
    }
  }

  @override
  void dispose() {
    _closeActiveMenu();
    _searchController.dispose();
    _inlineRenameController.dispose();
    _inlineRenameFocusNode.dispose();
    super.dispose();
  }

  void _closeActiveMenu() {
    _activeMenuOverlay?.remove();
    _activeMenuOverlay = null;
  }

  void _startInlineRename(NoteDocument note) {
    _closeActiveMenu();
    setState(() {
      _editingNoteId = note.id;
      _inlineRenameController.text = note.title;
      _inlineRenameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: note.title.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inlineRenameFocusNode.requestFocus();
    });
  }

  Future<void> _commitInlineRename(NoteDocument note, WorkspaceStorageService storage) async {
    if (_editingNoteId != note.id) return;
    final newTitle = _inlineRenameController.text.trim();
    setState(() {
      _editingNoteId = null;
    });

    if (newTitle.isNotEmpty && newTitle != note.title) {
      await storage.renameNote(note, newTitle);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        WorkspaceStorageService.instance,
        MoscaroThemeController.instance,
      ]),
      builder: (context, _) {
        final storage = WorkspaceStorageService.instance;
        final isLight = MoscaroTokens.isLight;
        final textPrimary = MoscaroTokens.textPrimary;
        final textSecondary = MoscaroTokens.textSecondary;
        final iconColor = MoscaroTokens.iconInactive;
        final themeAccent = MoscaroTokens.auroraBlue;
        final glassTint = MoscaroTokens.glassTint;
        final blur = MoscaroTokens.blurSigma;

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          left: widget.isOpen ? 24 : -390,
          top: 24,
          bottom: 24,
          child: SizedBox(
            width: 340,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MoscaroTokens.radiusPanel),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: MoscaroTokens.enableSidebarBlur ? blur : 0.0,
                  sigmaY: MoscaroTokens.enableSidebarBlur ? blur : 0.0,
                ),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isLight
                        ? const Color(0xFFF8FAFC).withValues(alpha: 0.90)
                        : glassTint,
                    borderRadius: BorderRadius.circular(MoscaroTokens.radiusPanel),
                    border: Border.all(
                      color: isLight ? MoscaroTokens.borderSubtle : MoscaroTokens.borderGlow,
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isLight
                            ? const Color(0x180F172A)
                            : Colors.black.withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header e Botões de Ação de Cadernos / Notas
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SvgIcon(name: 'book', size: 19, color: themeAccent),
                              const SizedBox(width: 8),
                              Text(
                                'Cadernos & Notas',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15.5,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Botão Novo Caderno
                              _buildHeaderIconButton(
                                icon: 'folder',
                                color: themeAccent,
                                tooltip: 'Novo Caderno / Disciplina',
                                onPressed: _showCreateNotebookDialog,
                              ),
                              const SizedBox(width: 6),
                              // Botão Nova Nota
                              _buildHeaderIconButton(
                                icon: 'plus',
                                color: textPrimary,
                                tooltip: 'Nova Nota .cncanvas',
                                onPressed: () async {
                                  _closeActiveMenu();
                                  final note = await storage.createNote(
                                    title: 'Nota ${storage.rootNotes.length + 1}',
                                  );
                                  widget.onSelectNote(note);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Barra de Busca com Moscaro
                      TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                        style: TextStyle(color: textPrimary, fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Buscar cadernos ou notas...',
                          hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 12),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(10),
                            child: SvgIcon(name: 'search', size: 14, color: iconColor),
                          ),
                          filled: true,
                          fillColor: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.05),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isLight ? Colors.black12 : Colors.white12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: themeAccent, width: 1.3),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: isLight ? Colors.black12 : Colors.white12),
                      const SizedBox(height: 10),

                      // Lista de Cadernos e Notas
                      Expanded(
                        child: _buildNotebooksAndNotesTree(storage),
                      ),
                      const SizedBox(height: 8),

                      // Lixeira Local (.trash/) com Alvo de Soltura DragTarget
                      _buildTrashSection(storage),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderIconButton({
    required String icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final isLight = MoscaroTokens.isLight;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isLight ? Colors.black12 : Colors.white12),
          ),
          child: SvgIcon(name: icon, size: 16, color: color),
        ),
      ),
    );
  }

  Widget _buildNotebooksAndNotesTree(WorkspaceStorageService storage) {
    final notebooks = storage.notebooks;
    final rootNotes = storage.rootNotes;

    final filteredNotebooks = notebooks.where((nb) {
      if (_searchQuery.isEmpty) return true;
      final matchesSelf = nb.name.toLowerCase().contains(_searchQuery);
      final matchesNotes = nb.notes.any((n) => n.title.toLowerCase().contains(_searchQuery));
      return matchesSelf || matchesNotes;
    }).toList();

    final filteredRootNotes = rootNotes.where((n) {
      if (_searchQuery.isEmpty) return true;
      return n.title.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filteredNotebooks.isEmpty && filteredRootNotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgIcon(name: 'file', size: 32, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 10),
            Text(
              _searchQuery.isNotEmpty ? 'Nenhuma nota encontrada' : 'Nenhum caderno criado',
              style: TextStyle(color: MoscaroTokens.textSecondary.withValues(alpha: 0.6), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return DragTarget<NoteDocument>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) async {
        await storage.moveNoteToNotebook(details.data, null);
        setState(() {
          _isDragging = false;
          _dropHoverTargetId = null;
          _dropHoverZone = null;
        });
      },
      builder: (context, candidateData, rejectedData) {
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            // 1. Cadernos / Disciplinas
            for (final notebook in filteredNotebooks)
              _buildNotebookItem(notebook, storage),

            if (filteredRootNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  'NOTAS INDEPENDENTES',
                  style: TextStyle(
                    color: MoscaroTokens.textSecondary.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              for (final note in filteredRootNotes)
                _buildDraggableNoteItem(note, storage, indent: 0),
            ],
          ],
        );
      },
    );
  }

  Widget _buildNotebookItem(NotebookFolder notebook, WorkspaceStorageService storage) {
    final isExpanded = _expandedFolderIds.contains(notebook.id);
    final isLight = MoscaroTokens.isLight;
    final themeAccent = MoscaroTokens.auroraBlue;

    return DragTarget<NoteDocument>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) async {
        await storage.moveNoteToNotebook(details.data, notebook.name);
        setState(() {
          _isDragging = false;
          _expandedFolderIds.add(notebook.id);
          _dropHoverTargetId = null;
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isHoveredByDrag = _isDragging && candidateData.isNotEmpty;

        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho do Caderno com ESPESSURA EXATA DE UMA NOTA (38px)
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isHoveredByDrag
                        ? themeAccent
                        : (isLight ? Colors.black12 : Colors.white.withValues(alpha: 0.08)),
                    width: isHoveredByDrag ? 1.5 : 1.0,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    _closeActiveMenu();
                    setState(() {
                      if (isExpanded) {
                        _expandedFolderIds.remove(notebook.id);
                      } else {
                        _expandedFolderIds.add(notebook.id);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Row(
                      children: [
                        SvgIcon(
                          name: isExpanded ? 'chevron_down' : 'chevron_right',
                          size: 13,
                          color: notebook.color,
                        ),
                        const SizedBox(width: 6),
                        SvgIcon(
                          name: notebook.iconKey,
                          size: 15,
                          color: notebook.color,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            notebook.name,
                            style: TextStyle(
                              color: MoscaroTokens.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Botão + (Adicionar Nota ao Caderno)
                        Tooltip(
                          message: 'Nova Nota neste Caderno',
                          child: InkWell(
                            onTap: () async {
                              _closeActiveMenu();
                              final note = await storage.createNote(
                                title: 'Nota ${notebook.notes.length + 1}',
                                targetFolderName: notebook.name,
                              );
                              setState(() {
                                _expandedFolderIds.add(notebook.id);
                              });
                              widget.onSelectNote(note);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isLight ? Colors.black12 : Colors.white12),
                              ),
                              child: SvgIcon(name: 'plus', size: 12, color: MoscaroTokens.textPrimary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Sub-notas dentro do Caderno
              if (isExpanded) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 10, top: 4),
                  child: Column(
                    children: [
                      if (notebook.notes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'Caderno vazio. Clique no + para criar.',
                            style: TextStyle(color: MoscaroTokens.textSecondary.withValues(alpha: 0.5), fontSize: 11),
                          ),
                        )
                      else
                        for (final note in notebook.notes)
                          _buildDraggableNoteItem(note, storage, indent: 4, folderName: notebook.name),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDraggableNoteItem(NoteDocument note, WorkspaceStorageService storage, {double indent = 0, String? folderName}) {
    final isHoverTarget = _isDragging && _dropHoverTargetId == note.id;
    final isExpanded = _expandedNoteIds.contains(note.id);
    final hasChildren = note.children.isNotEmpty;
    final isEditing = _editingNoteId == note.id;
    final themeAccent = MoscaroTokens.auroraBlue;

    if (isEditing) {
      return _buildEditingPill(note, storage, indent: indent);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Indicador de inserção superior suave
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOutCubic,
          height: (isHoverTarget && _dropHoverZone == NoteDropZone.before) ? 3.0 : 0.0,
          margin: EdgeInsets.only(left: indent + 6, right: 6, bottom: 2),
          decoration: BoxDecoration(
            color: themeAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // A Nota em si com DragTarget suave
        DragTarget<NoteDocument>(
          onWillAcceptWithDetails: (details) => details.data.id != note.id,
          onMove: (details) {
            final renderBox = context.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final localY = details.offset.dy;
              const height = 38.0;
              final relativeY = (localY % height) / height;

              NoteDropZone zone = NoteDropZone.inside;
              if (relativeY < 0.25) {
                zone = NoteDropZone.before;
              } else if (relativeY > 0.75) {
                zone = NoteDropZone.after;
              }

              if (_dropHoverTargetId != note.id || _dropHoverZone != zone) {
                setState(() {
                  _dropHoverTargetId = note.id;
                  _dropHoverZone = zone;
                });
              }
            }
          },
          onLeave: (data) {
            if (_dropHoverTargetId == note.id) {
              setState(() {
                _dropHoverTargetId = null;
                _dropHoverZone = null;
              });
            }
          },
          onAcceptWithDetails: (details) async {
            final dragged = details.data;
            if (_dropHoverZone == NoteDropZone.inside) {
              // Tornar Subnota
              await storage.nestNoteAsSubnote(dragged, note);
              setState(() {
                _expandedNoteIds.add(note.id);
              });
            } else {
              // Reordenar antes ou depois
              final isBefore = _dropHoverZone == NoteDropZone.before;
              await storage.reorderNote(dragged, note, isBefore, targetFolderName: folderName);
            }
            setState(() {
              _isDragging = false;
              _dropHoverTargetId = null;
              _dropHoverZone = null;
            });
          },
          builder: (context, candidateData, rejectedData) {
            final isInsideDrop = isHoverTarget && _dropHoverZone == NoteDropZone.inside;

            return Draggable<NoteDocument>(
              data: note,
              onDragStarted: () {
                _closeActiveMenu();
                setState(() => _isDragging = true);
              },
              onDragEnd: (_) => setState(() {
                _isDragging = false;
                _dropHoverTargetId = null;
                _dropHoverZone = null;
              }),
              feedback: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: 280,
                  child: _buildNotePill(note, storage, indent: 0, isGhost: true),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.2,
                child: _buildNotePill(note, storage, indent: indent),
              ),
              child: _buildNotePill(
                note,
                storage,
                indent: indent,
                isSubnoteHighlight: isInsideDrop,
                hasChildren: hasChildren,
                isExpanded: isExpanded,
                onToggleExpand: () {
                  _closeActiveMenu();
                  setState(() {
                    if (isExpanded) {
                      _expandedNoteIds.remove(note.id);
                    } else {
                      _expandedNoteIds.add(note.id);
                    }
                  });
                },
              ),
            );
          },
        ),

        // Subnotas aninhadas (árvore recursiva)
        if (hasChildren && isExpanded) ...[
          for (final child in note.children)
            _buildDraggableNoteItem(child, storage, indent: indent + 14, folderName: folderName),
        ],

        // Indicador de inserção inferior suave
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOutCubic,
          height: (isHoverTarget && _dropHoverZone == NoteDropZone.after) ? 3.0 : 0.0,
          margin: EdgeInsets.only(left: indent + 6, right: 6, top: 2),
          decoration: BoxDecoration(
            color: themeAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildEditingPill(NoteDocument note, WorkspaceStorageService storage, {double indent = 0}) {
    final isLight = MoscaroTokens.isLight;
    final textPrimary = MoscaroTokens.textPrimary;
    final themeAccent = MoscaroTokens.auroraBlue;
    final glassTint = MoscaroTokens.glassTint;

    return TapRegion(
      onTapOutside: (_) => _commitInlineRename(note, storage),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: Container(
            height: 38,
            margin: EdgeInsets.only(left: indent, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isLight ? Colors.white.withValues(alpha: 0.92) : glassTint,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: themeAccent.withValues(alpha: 0.8), width: 1.2),
            ),
            child: Row(
              children: [
                SvgIcon(name: 'file', size: 14, color: themeAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _inlineRenameController,
                    focusNode: _inlineRenameFocusNode,
                    autofocus: true,
                    style: TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _commitInlineRename(note, storage),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.check, size: 16, color: themeAccent),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  tooltip: 'Salvar Nome',
                  onPressed: () => _commitInlineRename(note, storage),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotePill(
    NoteDocument note,
    WorkspaceStorageService storage, {
    double indent = 0,
    bool isGhost = false,
    bool isSubnoteHighlight = false,
    bool hasChildren = false,
    bool isExpanded = false,
    VoidCallback? onToggleExpand,
  }) {
    final isLight = MoscaroTokens.isLight;
    final themeAccent = MoscaroTokens.auroraBlue;
    final isSelected = widget.selectedNoteId != null && widget.selectedNoteId == note.id;

    // Cores e Estilo Moscaro Adaptativo ao Tema
    final Color bgColor = isSelected
        ? (isLight ? themeAccent.withValues(alpha: 0.14) : themeAccent.withValues(alpha: 0.18))
        : (isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.04));

    final Color borderColor = isSubnoteHighlight
        ? themeAccent
        : (isSelected
            ? themeAccent.withValues(alpha: 0.8)
            : (isLight ? Colors.black12 : Colors.white.withValues(alpha: 0.08)));

    final Color textColor = isSelected
        ? (isLight ? Colors.black : Colors.white)
        : MoscaroTokens.textPrimary;

    final FontWeight fontWeight = isSelected ? FontWeight.w600 : FontWeight.normal;
    final Color iconColor = isSelected ? themeAccent : MoscaroTokens.textSecondary.withValues(alpha: 0.7);

    return Container(
      height: 38,
      margin: EdgeInsets.only(left: indent, bottom: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: borderColor,
          width: (isSubnoteHighlight || isSelected) ? 1.2 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: () {
          _closeActiveMenu();
          widget.onSelectNote(note);
        },
        onDoubleTap: () => _startInlineRename(note),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              if (hasChildren)
                InkWell(
                  onTap: onToggleExpand,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: SvgIcon(
                      name: isExpanded ? 'chevron_down' : 'chevron_right',
                      size: 13,
                      color: isSelected ? themeAccent : const Color(0xFF00E1FF),
                    ),
                  ),
                )
              else
                SvgIcon(name: 'file', size: 14, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  note.title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12.5,
                    fontWeight: fontWeight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Gatilho do Menu Moscaro à Direita da Sidebar
              _buildMoscaroMenuTrigger(note, storage),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoscaroMenuTrigger(NoteDocument note, WorkspaceStorageService storage) {
    return Builder(
      builder: (btnContext) {
        return IconButton(
          icon: Icon(Icons.more_vert_rounded, size: 16, color: MoscaroTokens.iconInactive),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          tooltip: 'Opções da Nota',
          onPressed: () {
            _showMoscaroRightOverlayMenu(btnContext, note, storage);
          },
        );
      },
    );
  }

  void _showMoscaroRightOverlayMenu(BuildContext btnContext, NoteDocument note, WorkspaceStorageService storage) {
    _closeActiveMenu();

    final RenderBox renderBox = btnContext.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = MediaQuery.of(context).size;
    final isLight = MoscaroTokens.isLight;
    final themeAccent = MoscaroTokens.auroraBlue;
    final glassTint = MoscaroTokens.glassTint;
    final blur = MoscaroTokens.blurSigma;

    // Posicionar à direita da sidebar (Sidebar 340px + 24px margem + 8px gap = 372px)
    final double left = 372.0;
    final double top = offset.dy.clamp(24.0, size.height - 180.0);

    _activeMenuOverlay = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            // Barreira Invisível para fechar ao clicar em qualquer lugar fora (Sem piscar em branco)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeActiveMenu,
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 195,
                  decoration: BoxDecoration(
                    color: isLight
                        ? const Color(0xFFF8FAFC).withValues(alpha: 0.94)
                        : glassTint,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isLight
                          ? Colors.black12
                          : Colors.white.withValues(alpha: 0.1),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: blur > 0 ? blur : 20.0,
                        sigmaY: blur > 0 ? blur : 20.0,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Abrir no Navegador
                            _buildMenuItem(
                              icon: 'globe',
                              iconColor: themeAccent,
                              label: 'Abrir no Navegador',
                              onTap: () {
                                _closeActiveMenu();
                                storage.openInBrowser(note);
                              },
                            ),
                            const SizedBox(height: 2),
                            // 2. Renomear
                            _buildMenuItem(
                              icon: 'edit',
                              iconColor: themeAccent,
                              label: 'Renomear',
                              onTap: () {
                                _closeActiveMenu();
                                _startInlineRename(note);
                              },
                            ),
                            const SizedBox(height: 2),
                            Divider(
                              height: 8,
                              thickness: 0.8,
                              color: isLight ? Colors.black12 : Colors.white12,
                            ),
                            const SizedBox(height: 2),
                            // 3. Mover para Lixeira
                            _buildMenuItem(
                              icon: 'trash',
                              iconColor: const Color(0xFFFF007A),
                              label: 'Mover para Lixeira',
                              labelColor: const Color(0xFFFF007A),
                              onTap: () {
                                _closeActiveMenu();
                                storage.moveToTrash(note);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_activeMenuOverlay!);
  }

  Widget _buildMenuItem({
    required String icon,
    required Color iconColor,
    required String label,
    Color? labelColor,
    required VoidCallback onTap,
  }) {
    final textPrimary = labelColor ?? MoscaroTokens.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      hoverColor: MoscaroTokens.auroraBlue.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            SvgIcon(name: icon, size: 15, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrashSection(WorkspaceStorageService storage) {
    final isExpanded = _isTrashExpanded;
    final trashCount = storage.trashNotes.length;

    return DragTarget<NoteDocument>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) async {
        await storage.moveToTrash(details.data);
        setState(() {
          _isDragging = false;
          _isTrashHovered = false;
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = (_isDragging && candidateData.isNotEmpty) || _isTrashHovered;

        return Container(
          decoration: BoxDecoration(
            color: isHovered
                ? const Color(0xFFFF007A).withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovered ? const Color(0xFFFF007A) : Colors.white.withValues(alpha: 0.08),
              width: isHovered ? 1.6 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () {
                  _closeActiveMenu();
                  setState(() => _isTrashExpanded = !_isTrashExpanded);
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      SvgIcon(
                        name: isExpanded ? 'chevron_down' : 'chevron_right',
                        size: 14,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 6),
                      const SvgIcon(name: 'trash', size: 15, color: Color(0xFFFF007A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isHovered ? 'Soltar para apagar' : 'Lixeira ($trashCount)',
                          style: TextStyle(
                            color: isHovered ? const Color(0xFFFF007A) : Colors.white70,
                            fontSize: 12.5,
                            fontWeight: isHovered ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (trashCount > 0 && !isHovered)
                        TextButton(
                          onPressed: () => storage.emptyTrash(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Esvaziar', style: TextStyle(color: Color(0xFFFF007A), fontSize: 11)),
                        ),
                    ],
                  ),
                ),
              ),
              if (isExpanded) ...[
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: storage.trashNotes.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text('Lixeira vazia', style: TextStyle(color: Colors.white38, fontSize: 11)),
                          ),
                        )
                      : Column(
                          children: [
                            for (final trashNote in storage.trashNotes)
                              Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Row(
                                  children: [
                                    const SvgIcon(name: 'file', size: 13, color: Colors.white38),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        trashNote.title,
                                        style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: SvgIcon(name: 'restore', size: 14, color: MoscaroTokens.auroraBlue),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                      tooltip: 'Restaurar Nota',
                                      onPressed: () => storage.restoreFromTrash(trashNote),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showCreateNotebookDialog() {
    _closeActiveMenu();
    final controller = TextEditingController();
    Color selectedColor = MoscaroTokens.auroraBlue;
    String selectedIcon = 'book';

    final colors = [
      const Color(0xFF00E1FF),
      const Color(0xFFFF007A),
      const Color(0xFFA855F7),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
    ];

    final icons = ['book', 'atom', 'code', 'circuit', 'math'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SvgIcon(name: 'folder', size: 22, color: MoscaroTokens.auroraBlue),
                    const SizedBox(width: 10),
                    const Text('Novo Caderno / Disciplina', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Ex: Cálculo III, Física, Algoritmos...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: MoscaroTokens.auroraBlue, width: 1.4),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 18),
                // Seletor de Cores
                const Text('Cor de Destaque:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(
                  children: colors.map((c) {
                    final isSel = selectedColor == c;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = c),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: isSel ? Border.all(color: Colors.white, width: 2.5) : null,
                          boxShadow: isSel ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 1)] : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                // Seletor de Ícone
                const Text('Ícone Temático:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(
                  children: icons.map((ic) {
                    final isSel = selectedIcon == ic;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedIcon = ic),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSel ? selectedColor : Colors.white12),
                        ),
                        child: SvgIcon(name: ic, size: 20, color: isSel ? selectedColor : Colors.white70),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancelar', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () async {
                        final name = controller.text.trim();
                        if (name.isNotEmpty) {
                          await WorkspaceStorageService.instance.createNotebook(
                            name,
                            color: selectedColor,
                            iconKey: selectedIcon,
                          );
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MoscaroTokens.auroraBlue,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 6,
                        shadowColor: MoscaroTokens.auroraBlue.withValues(alpha: 0.5),
                      ),
                      child: const Text('Criar Caderno', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
