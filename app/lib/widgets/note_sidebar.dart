import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import 'note_models.dart';
import 'svg_icon.dart';

/// Sidebar Esquerda com hierarquia infinita, Seleção de Notas, Lixeira e Busca.
class NoteSidebar extends StatefulWidget {
  final bool isOpen;
  final List<NoteDocument> rootNotes;
  final List<NoteDocument> trashNotes;
  final ValueChanged<NoteDocument> onSelectNote;
  final VoidCallback onAddNote;
  final Function(NoteDocument dragged, NoteDocument? target) onReorderNote;
  final Function(List<String> noteIds) onMoveToTrash;
  final ValueChanged<String> onRestoreNote;
  final ValueChanged<String> onDeletePermanently;
  final VoidCallback onEmptyTrash;

  const NoteSidebar({
    super.key,
    required this.isOpen,
    required this.rootNotes,
    required this.trashNotes,
    required this.onSelectNote,
    required this.onAddNote,
    required this.onReorderNote,
    required this.onMoveToTrash,
    required this.onRestoreNote,
    required this.onDeletePermanently,
    required this.onEmptyTrash,
  });

  @override
  State<NoteSidebar> createState() => _NoteSidebarState();
}

class _NoteSidebarState extends State<NoteSidebar> {
  final Set<String> _expandedNoteIds = {};
  final Set<String> _selectedNoteIds = {};
  bool _isSelectionMode = false;
  bool _isTrashExpanded = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<NoteDocument> _filterNotes(List<NoteDocument> notes) {
    if (_searchQuery.isEmpty) return notes;
    List<NoteDocument> filtered = [];
    for (final note in notes) {
      final matchesSearch = note.title.toLowerCase().contains(_searchQuery.toLowerCase());
      final filteredChildren = _filterNotes(note.children);

      if (matchesSearch || filteredChildren.isNotEmpty) {
        filtered.add(NoteDocument(
          id: note.id,
          title: note.title,
          children: filteredChildren,
          strokes: note.strokes,
          panX: note.panX,
          panY: note.panY,
        ));
      }
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotes = _filterNotes(widget.rootNotes);
    final isLight = MoscaroTokens.isLight;
    final textPrimary = MoscaroTokens.textPrimary;
    final textSecondary = MoscaroTokens.textSecondary;
    final iconColor = MoscaroTokens.iconInactive;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      left: widget.isOpen ? 24 : -370,
      top: 24,
      bottom: 24,
      child: SizedBox(
        width: 330,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header e Botões de Ação
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isSelectionMode ? 'Selecionadas (${_selectedNoteIds.length})' : 'Cadernos & Notas',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isSelectionMode ? Icons.check_circle : Icons.check_circle_outline,
                        color: _isSelectionMode ? MoscaroTokens.auroraBlue : iconColor,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = !_isSelectionMode;
                          _selectedNoteIds.clear();
                        });
                      },
                      tooltip: 'Selecionar Notas',
                    ),
                    if (_isSelectionMode && _selectedNoteIds.isNotEmpty)
                      IconButton(
                        icon: const SvgIcon(assetName: 'trash', size: 18, color: MoscaroTokens.auroraPink),
                        onPressed: () {
                          widget.onMoveToTrash(_selectedNoteIds.toList());
                          setState(() {
                            _selectedNoteIds.clear();
                            _isSelectionMode = false;
                          });
                        },
                        tooltip: 'Mover para Lixeira',
                      )
                    else
                      IconButton(
                        icon: Icon(Icons.note_add_outlined, color: MoscaroTokens.auroraBlue, size: 22),
                        onPressed: widget.onAddNote,
                        tooltip: 'Nova Nota',
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Busca
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(color: textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar nota...',
                hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 12),
                prefixIcon: Icon(Icons.search, color: iconColor, size: 18),
                filled: true,
                fillColor: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.05),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isLight ? Colors.black12 : Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: MoscaroTokens.auroraBlue, width: 1.3),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: isLight ? Colors.black12 : Colors.white12),
            const SizedBox(height: 12),
            // Lista Principal de Notas
            Expanded(
              child: DragTarget<NoteDocument>(
                onWillAcceptWithDetails: (details) => true,
                onAcceptWithDetails: (details) {
                  widget.onReorderNote(details.data, null);
                },
                builder: (context, candidateData, rejectedData) {
                  return Container(
                    decoration: BoxDecoration(
                      color: candidateData.isNotEmpty
                          ? (isLight ? MoscaroTokens.auroraBlue.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.02))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: filteredNotes.isEmpty
                        ? Center(
                            child: Text(
                              'Sem resultados',
                              style: TextStyle(color: textSecondary.withValues(alpha: 0.5), fontSize: 13),
                            ),
                          )
                        : ScrollConfiguration(
                            behavior: const ScrollBehavior().copyWith(scrollbars: false),
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: filteredNotes.map((note) => _buildNoteItem(note)).toList(),
                            ),
                          ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // Pasta da Lixeira Física no rodapé
            _buildTrashFolder(),
          ],
        ),
      ).moscaroV2(
        borderRadius: MoscaroTokens.radiusPanel,
        enableBlur: MoscaroTokens.enableSidebarBlur,
        padding: const EdgeInsets.all(18),
      ),
    );
  }

  Widget _buildNoteItem(NoteDocument note, [double indent = 0.0]) {
    final bool isExpanded = _expandedNoteIds.contains(note.id);
    final bool hasChildren = note.children.isNotEmpty;

    final noteItemWidget = Padding(
      padding: EdgeInsets.only(left: indent, bottom: 4),
      child: DragTarget<NoteDocument>(
        onWillAcceptWithDetails: (details) => details.data.id != note.id,
        onAcceptWithDetails: (details) {
          widget.onReorderNote(details.data, note);
        },
        builder: (context, candidateData, rejectedData) {
          return LongPressDraggable<NoteDocument>(
            data: note,
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 290 - indent,
                child: _buildNotePill(note, isExpanded, hasChildren, false, isGhost: true),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: _buildNotePill(note, isExpanded, hasChildren, candidateData.isNotEmpty),
            ),
            child: _buildNotePill(note, isExpanded, hasChildren, candidateData.isNotEmpty),
          );
        },
      ),
    );

    if (!hasChildren || !isExpanded) {
      return noteItemWidget;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        noteItemWidget,
        ...note.children.map((child) => _buildNoteItem(child, indent + 14.0)),
      ],
    );
  }

  Widget _buildNotePill(NoteDocument note, bool isExpanded, bool hasChildren, bool isCandidate, {bool isGhost = false}) {
    final bool isSelected = _selectedNoteIds.contains(note.id);
    final isLight = MoscaroTokens.isLight;
    final textPrimary = MoscaroTokens.textPrimary;
    final iconColor = MoscaroTokens.iconInactive;

    final Color pillColor = isGhost
        ? Colors.black.withValues(alpha: 0.4)
        : (isSelected
            ? (isLight ? MoscaroTokens.auroraBlue.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.06))
            : (isCandidate
                ? (isLight ? MoscaroTokens.auroraBlue.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.08))
                : (isLight ? Colors.black.withValues(alpha: 0.02) : Colors.white.withValues(alpha: 0.03))));

    return Container(
      decoration: BoxDecoration(
        color: pillColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? MoscaroTokens.auroraBlue.withValues(alpha: 0.8)
              : (isCandidate ? MoscaroTokens.auroraBlue : (isLight ? Colors.black12 : Colors.white10)),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          dense: true,
          horizontalTitleGap: 6,
          leading: _isSelectionMode
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: isSelected,
                    activeColor: MoscaroTokens.auroraBlue,
                    onChanged: (val) {
                      setState(() {
                        if (isSelected) {
                          _selectedNoteIds.remove(note.id);
                        } else {
                          _selectedNoteIds.add(note.id);
                        }
                      });
                    },
                  ),
                )
              : (hasChildren
                  ? GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedNoteIds.remove(note.id);
                          } else {
                            _expandedNoteIds.add(note.id);
                          }
                        });
                      },
                      child: Icon(
                        isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                        color: iconColor,
                        size: 18,
                      ),
                    )
                  : Icon(Icons.description_outlined, color: iconColor, size: 16)),
          title: Text(
            note.title,
            style: TextStyle(
              color: isSelected ? (isLight ? MoscaroTokens.auroraBlue : textPrimary) : textPrimary,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: _isSelectionMode
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const SvgIcon(assetName: 'trash', size: 16, color: MoscaroTokens.auroraPink),
                      onPressed: () => widget.onMoveToTrash([note.id]),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Mover para Lixeira',
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.drag_indicator, color: isLight ? Colors.black26 : Colors.white24, size: 14),
                  ],
                ),
          onTap: _isSelectionMode
              ? () {
                  setState(() {
                    if (isSelected) {
                      _selectedNoteIds.remove(note.id);
                    } else {
                      _selectedNoteIds.add(note.id);
                    }
                  });
                }
              : () => widget.onSelectNote(note),
        ),
      ),
    );
  }

  Widget _buildTrashFolder() {
    final isLight = MoscaroTokens.isLight;
    final textSecondary = MoscaroTokens.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isLight ? Colors.black12 : Colors.white10, width: 1.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Row(
                children: [
                  const Icon(Icons.delete_outline, size: 18, color: MoscaroTokens.auroraPink),
                  const SizedBox(width: 8),
                  Text(
                    'Lixeira (${widget.trashNotes.length})',
                    style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              childrenPadding: const EdgeInsets.all(10),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.trashNotes.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep, size: 18, color: MoscaroTokens.auroraPink),
                      onPressed: widget.onEmptyTrash,
                      tooltip: 'Esvaziar Lixeira',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _isTrashExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    color: textSecondary.withValues(alpha: 0.6),
                  ),
                ],
              ),
              onExpansionChanged: (expanded) {
                setState(() {
                  _isTrashExpanded = expanded;
                });
              },
              children: [
                if (widget.trashNotes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Lixeira vazia',
                      style: TextStyle(color: textSecondary.withValues(alpha: 0.4), fontSize: 12),
                    ),
                  )
                else
                  SizedBox(
                    height: 120,
                    child: ScrollConfiguration(
                      behavior: const ScrollBehavior().copyWith(scrollbars: false),
                      child: ListView(
                        children: widget.trashNotes.map((note) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isLight ? Colors.black12 : Colors.white10, width: 1.0),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    note.title,
                                    style: TextStyle(color: textSecondary, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.restore, size: 16, color: Colors.greenAccent),
                                      onPressed: () => widget.onRestoreNote(note.id),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Restaurar Nota',
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_forever, size: 16, color: MoscaroTokens.auroraPink),
                                      onPressed: () => widget.onDeletePermanently(note.id),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Excluir Definitivamente',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
