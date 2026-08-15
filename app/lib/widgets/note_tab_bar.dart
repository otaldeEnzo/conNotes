import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import 'svg_icon.dart';

/// TabBar Superior Centralizada (Abas de Notas Ativas estilo Navegador)
/// Ajustada para respeitar o espaço do ZoomHudPill no canto superior direito.
class NoteTabBar extends StatefulWidget {
  final List<String> activeNoteIds;
  final Map<String, String> noteTitles;
  final String? selectedNoteId;
  final ValueChanged<String> onSelectNote;
  final ValueChanged<String> onCloseNote;
  final VoidCallback onAddNote;
  final VoidCallback onToggleSidebar;
  final bool isSidebarOpen;

  const NoteTabBar({
    super.key,
    required this.activeNoteIds,
    required this.noteTitles,
    required this.selectedNoteId,
    required this.onSelectNote,
    required this.onCloseNote,
    required this.onAddNote,
    required this.onToggleSidebar,
    required this.isSidebarOpen,
  });

  @override
  State<NoteTabBar> createState() => _NoteTabBarState();
}

class _NoteTabBarState extends State<NoteTabBar> {
  final ScrollController _scrollController = ScrollController();
  double _scrollProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollProgress);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollProgress);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollProgress() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    setState(() {
      _scrollProgress = maxScroll > 0 ? (currentScroll / maxScroll).clamp(0.0, 1.0) : 0.0;
    });
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final double newOffset = (_scrollController.offset + event.scrollDelta.dy).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      
      _scrollController.animateTo(
        newOffset,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    
    // Desconta o espaço da Sidebar (380px) à esquerda se aberta e o espaço do Zoom HUD (160px) à direita
    final double maxPossibleWidth = widget.isSidebarOpen 
        ? (screenWidth - 380 - 160) 
        : (screenWidth - 200);
        
    final double absoluteMaxWidth = maxPossibleWidth.clamp(140.0, 950.0);

    final double estimatedContentWidth = 102.0 + (widget.activeNoteIds.length * 122.0);
    final double targetWidth = estimatedContentWidth.clamp(140.0, absoluteMaxWidth);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      height: 38,
      width: targetWidth,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                const SizedBox(width: 8),
                IconButton(
                  icon: SvgIcon(
                    assetName: 'grid',
                    size: 18,
                    color: widget.isSidebarOpen ? MoscaroTokens.auroraBlue : Colors.white,
                  ),
                  onPressed: widget.onToggleSidebar,
                  tooltip: 'Menu de Notas',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 14, color: Colors.white24),
                const SizedBox(width: 10),
                Expanded(
                  child: widget.activeNoteIds.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhuma nota aberta',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        )
                      : Listener(
                          onPointerSignal: _handlePointerSignal,
                          child: ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context).copyWith(
                              dragDevices: {
                                PointerDeviceKind.touch,
                                PointerDeviceKind.mouse,
                                PointerDeviceKind.trackpad,
                              },
                              scrollbars: false,
                            ),
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: widget.activeNoteIds.map((noteId) {
                                  final isSelected = noteId == widget.selectedNoteId;
                                  final title = widget.noteTitles[noteId] ?? 'Nota sem título';

                                  return GestureDetector(
                                    onTap: () => widget.onSelectNote(noteId),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(MoscaroTokens.radiusButton),
                                        border: Border.all(
                                          color: isSelected ? MoscaroTokens.borderGlow : Colors.transparent,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            title,
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : Colors.white70,
                                              fontSize: 12,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          GestureDetector(
                                            onTap: () => widget.onCloseNote(noteId),
                                            child: const Icon(Icons.close, size: 12, color: Colors.white38),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 14, color: Colors.white24),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  onPressed: widget.onAddNote,
                  tooltip: 'Nova Nota',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          if (widget.activeNoteIds.isNotEmpty && _scrollController.hasClients && _scrollController.position.maxScrollExtent > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: Container(
                  height: 2.0,
                  width: double.infinity,
                  color: Colors.white12,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: _scrollProgress,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [MoscaroTokens.auroraBlue, MoscaroTokens.auroraPurple],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ).moscaroV2(
      borderRadius: MoscaroTokens.radiusPill,
      padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
    );
  }
}
