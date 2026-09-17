import 'package:flutter/material.dart';
import '../../services/workspace_storage_service.dart';
import '../../theme/moscaro_v2_tokens.dart';
import '../note_models.dart';
import '../svg_icon.dart';
import 'home_empty_state.dart';
import 'home_note_card.dart';
import 'home_tags_bar.dart';
import 'home_notebooks_carousel.dart';

/// Seção principal da Biblioteca de Notas da Página Inicial.
/// Gerencia a exibição em Grade/Lista, filtros por caderno/tag/busca e animação de alto desempenho.
class HomeNotesGrid extends StatefulWidget {
  final String searchQuery;
  final ValueChanged<NoteDocument> onNoteSelected;
  final VoidCallback onCreateNotePressed;

  const HomeNotesGrid({
    super.key,
    this.searchQuery = '',
    required this.onNoteSelected,
    required this.onCreateNotePressed,
  });

  @override
  State<HomeNotesGrid> createState() => _HomeNotesGridState();
}

class _HomeNotesGridState extends State<HomeNotesGrid> with SingleTickerProviderStateMixin {
  String? _selectedNotebookId;
  String? _selectedTag;
  bool _isGridView = true;
  late AnimationController _staggerController;
  final Map<int, Animation<double>> _staggerAnimations = {};

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  List<NoteDocument> _filterNotes(List<NoteDocument> allNotes) {
    // 1. Filtrar por caderno selecionado
    List<NoteDocument> baseNotes = allNotes;
    if (_selectedNotebookId != null) {
      final notebooks = WorkspaceStorageService.instance.notebooks;
      final target = notebooks.cast<NotebookFolder?>().firstWhere(
        (nb) => nb?.id == _selectedNotebookId,
        orElse: () => null,
      );
      if (target != null) {
        baseNotes = target.notes;
      }
    }

    return baseNotes.where((note) {
      // Filtro por tag
      if (_selectedTag != null && !note.tags.contains(_selectedTag)) {
        return false;
      }
      // Filtro por busca textual
      if (widget.searchQuery.trim().isNotEmpty) {
        final query = widget.searchQuery.toLowerCase();
        final matchTitle = note.title.toLowerCase().contains(query);
        final matchTags = note.tags.any((t) => t.toLowerCase().contains(query));
        if (!matchTitle && !matchTags) return false;
      }
      return true;
    }).toList();
  }

  void _onFavoriteToggle(NoteDocument note) {
    note.isFavorite = !note.isFavorite;
    WorkspaceStorageService.instance.saveNoteNow(note);
    setState(() {});
  }

  void _onDeleteNote(NoteDocument note) {
    WorkspaceStorageService.instance.moveToTrash(note);
  }

  void _onDuplicateNote(NoteDocument note) async {
    final copy = NoteDocument(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      title: '${note.title} (Cópia)',
      tags: List.from(note.tags),
      strokes: List.from(note.strokes),
      cards: List.from(note.cards),
    );
    await WorkspaceStorageService.instance.saveNoteNow(copy);
    await WorkspaceStorageService.instance.scanWorkspace();
    WorkspaceStorageService.instance.notifyNotesListChanged();
  }

  void _onRenameNote(NoteDocument note) {
    final textController = TextEditingController(text: note.title);
    final isLight = MoscaroTokens.isLight;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isLight ? const Color(0xF8FFFFFF) : const Color(0xF8121622),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: MoscaroTokens.auroraBlue.withValues(alpha: 0.4),
            width: 1.0,
          ),
        ),
        title: Text(
          'Renomear Nota',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isLight ? const Color(0xFF0F172A) : Colors.white,
          ),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: TextStyle(color: isLight ? const Color(0xFF0F172A) : Colors.white),
          decoration: InputDecoration(
            hintText: 'Novo tÃ­tulo...',
            hintStyle: TextStyle(color: isLight ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            filled: true,
            fillColor: isLight ? const Color(0x100F172A) : const Color(0x18FFFFFF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: MoscaroTokens.auroraBlue.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: MoscaroTokens.auroraBlue, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: TextStyle(color: isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MoscaroTokens.auroraBlue,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final newTitle = textController.text.trim();
              if (newTitle.isNotEmpty) {
                note.title = newTitle;
                note.updatedAt = DateTime.now();
                WorkspaceStorageService.instance.saveNoteNow(note);
                setState(() {});
              }
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = MoscaroTokens.isLight;

    return ListenableBuilder(
      listenable: WorkspaceStorageService.instance.notesListNotifier,
      builder: (context, _) {
        final allNotes = WorkspaceStorageService.instance.allNotes;
        final filteredNotes = _filterNotes(allNotes);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header da SeÃ§Ã£o
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SvgIcon(
                            name: 'book',
                            size: 20,
                            color: MoscaroTokens.auroraBlue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Biblioteca de Notas',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: isLight ? const Color(0xFF0F172A) : Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Acesse suas anotações STEM com renderização vetorial e suporte nativo a caneta.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Ações de Criação: Secundária (Novo Caderno) + Hero Primária (Nova Nota)
                Row(
                  children: [
                    // Ação Secundária: + Novo Caderno (Outline Glass)
                    InkWell(
                      onTap: () => HomeNotebooksCarousel.showCreateNotebookDialog(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isLight ? const Color(0x0F0F172A) : const Color(0x10FFFFFF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: MoscaroTokens.auroraBlue.withValues(alpha: isLight ? 0.35 : 0.45),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            SvgIcon(
                              name: 'book',
                              size: 14,
                              color: isLight ? const Color(0xFF0284C7) : MoscaroTokens.auroraBlue,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Novo Caderno',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isLight ? const Color(0xFF0284C7) : MoscaroTokens.auroraBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Hero CTA Primário: + Nova Nota (Sólido Neon Ciano com Alto Contraste)
                    InkWell(
                      onTap: widget.onCreateNotePressed,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8.5),
                        decoration: BoxDecoration(
                          color: isLight ? const Color(0xFF0284C7) : const Color(0xFF00E1FF),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: (isLight ? const Color(0xFF0284C7) : const Color(0xFF00E1FF))
                                  .withValues(alpha: 0.38),
                              blurRadius: 14,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            SvgIcon(
                              name: 'plus',
                              size: 15,
                              color: isLight ? Colors.white : const Color(0xFF070B14),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Nova Nota',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                                color: isLight ? Colors.white : const Color(0xFF070B14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Carrossel de Cadernos (Notebooks)
            HomeNotebooksCarousel(
              selectedNotebookId: _selectedNotebookId,
              onNotebookSelected: (nbId) {
                if (_selectedNotebookId != nbId) {
                  setState(() {
                    _selectedNotebookId = nbId;
                    _staggerAnimations.clear();
                    _staggerController.forward(from: 0.0);
                  });
                }
              },
            ),

            const SizedBox(height: 20),

            // Barra de Tags e visualização
            HomeTagsBar(
              selectedTag: _selectedTag,
              isGridView: _isGridView,
              onTagSelected: (tag) {
                if (_selectedTag != tag) {
                  setState(() {
                    _selectedTag = tag;
                    _staggerAnimations.clear();
                    _staggerController.forward(from: 0.0);
                  });
                }
              },
              onViewModeChanged: (grid) => setState(() => _isGridView = grid),
              onAddTagPressed: () {},
            ),

            const SizedBox(height: 16),

            // Conteúdo principal com transição animada fluida ao abrir cadernos
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.035),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey('notes_view_${_selectedNotebookId ?? "all"}_${_selectedTag ?? "all"}_$_isGridView'),
                child: filteredNotes.isEmpty
                    ? HomeEmptyState(
                        title: _selectedTag != null
                            ? 'Nenhuma nota com a tag "$_selectedTag"'
                            : (widget.searchQuery.isNotEmpty
                                ? 'Nenhum resultado para "${widget.searchQuery}"'
                                : 'Nenhuma nota criada ainda neste caderno'),
                        description: 'Comece seu estudo criando uma nova folha de anotações ou explorando temas.',
                        actionLabel: 'Criar Nova Nota',
                        onActionPressed: widget.onCreateNotePressed,
                      )
                    : _isGridView
                        ? _buildGridView(filteredNotes)
                        : _buildListView(filteredNotes),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGridView(List<NoteDocument> notes) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 280).floor().clamp(1, 5);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.05,
          ),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            return _buildStaggeredItem(
              index: index,
              child: HomeNoteCard(
                note: note,
                onTap: () => widget.onNoteSelected(note),
                onFavoriteToggle: () => _onFavoriteToggle(note),
                onDelete: () => _onDeleteNote(note),
                onDuplicate: () => _onDuplicateNote(note),
                onRename: () => _onRenameNote(note),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildListView(List<NoteDocument> notes) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final note = notes[index];
        return _buildStaggeredItem(
          index: index,
          child: SizedBox(
            height: 76,
            child: HomeNoteCard(
              note: note,
              isListMode: true,
              onTap: () => widget.onNoteSelected(note),
              onFavoriteToggle: () => _onFavoriteToggle(note),
              onDelete: () => _onDeleteNote(note),
              onDuplicate: () => _onDuplicateNote(note),
              onRename: () => _onRenameNote(note),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStaggeredItem({required int index, required Widget child}) {
    if (_staggerController.isCompleted) {
      return child;
    }

    final animation = _staggerAnimations.putIfAbsent(index, () {
      final start = (index * 0.04).clamp(0.0, 0.6);
      final end = (start + 0.35).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _staggerController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });

    return AnimatedBuilder(
      animation: animation,
      builder: (context, c) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - animation.value)),
            child: child,
          ),
        );
      },
    );
  }
}


