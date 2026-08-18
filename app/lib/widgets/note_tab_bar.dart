import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import 'svg_icon.dart';

/// Barra de Abas Superior Centralizada (Pílula Glassmorphism Moscaro v2 Pro Max).
class NoteTabBar extends StatefulWidget {
  final List<String> activeNoteIds;
  final String? selectedNoteId;
  final Map<String, String> noteTitles;
  final ValueChanged<String> onSelectNote;
  final ValueChanged<String> onCloseNote;
  final VoidCallback onAddNote;
  final VoidCallback onToggleSidebar;
  final VoidCallback onOpenSettings;
  final bool isSidebarOpen;

  const NoteTabBar({
    super.key,
    required this.activeNoteIds,
    required this.selectedNoteId,
    required this.noteTitles,
    required this.onSelectNote,
    required this.onCloseNote,
    required this.onAddNote,
    required this.onToggleSidebar,
    required this.onOpenSettings,
    this.isSidebarOpen = false,
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
    if (maxScroll <= 0) {
      if (_scrollProgress != 0.0) {
        setState(() => _scrollProgress = 0.0);
      }
      return;
    }
    final progress = (_scrollController.offset / maxScroll).clamp(0.0, 1.0);
    if ((progress - _scrollProgress).abs() > 0.01) {
      setState(() => _scrollProgress = progress);
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && _scrollController.hasClients) {
      final double delta = event.scrollDelta.dy != 0 ? event.scrollDelta.dy : event.scrollDelta.dx;
      final double targetOffset = (_scrollController.offset + delta).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(targetOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double absoluteMaxWidth = (screenWidth * 0.85).clamp(320.0, 950.0);

    double tabsWidth = 0.0;
    for (final noteId in widget.activeNoteIds) {
      final title = widget.noteTitles[noteId] ?? 'Nota sem título';
      final tabW = (title.length * 7.5 + 46.0).clamp(90.0, 170.0);
      tabsWidth += tabW;
    }
    if (widget.activeNoteIds.isEmpty) {
      tabsWidth = 130.0;
    }

    // Chrome fixo: menu(38) + divisores/espaçamentos(24) + add(26) + settings(26) + margens(16) = ~130px
    final double desiredWidth = 120.0 + tabsWidth;
    final double targetWidth = desiredWidth.clamp(170.0, absoluteMaxWidth);

    final isLight = MoscaroTokens.isLight;
    final textPrimary = MoscaroTokens.textPrimary;
    final textSecondary = MoscaroTokens.textSecondary;
    final iconColor = MoscaroTokens.iconInactive;
    final dividerColor = isLight ? Colors.black12 : Colors.white24;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      height: 38,
      width: targetWidth,
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 8),
                IconButton(
                  icon: SvgIcon(
                    assetName: 'grid',
                    size: 18,
                    color: widget.isSidebarOpen ? MoscaroTokens.auroraBlue : iconColor,
                  ),
                  onPressed: widget.onToggleSidebar,
                  tooltip: 'Menu de Notas',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Container(width: 1, height: 14, color: dividerColor),
                const SizedBox(width: 8),
                Flexible(
                  child: widget.activeNoteIds.isEmpty
                      ? Center(
                          child: Text(
                            'Nenhuma nota aberta',
                            style: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 12),
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

                                  return Listener(
                                    // Fechamento instantâneo com clique da rodinha do mouse (Middle Button)
                                    onPointerDown: (event) {
                                      if (event.buttons == kMiddleMouseButton) {
                                        widget.onCloseNote(noteId);
                                      }
                                    },
                                    child: GestureDetector(
                                      onTap: () => widget.onSelectNote(noteId),
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? (isLight ? MoscaroTokens.auroraBlue.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.12))
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(MoscaroTokens.radiusButton),
                                          border: Border.all(
                                            color: isSelected
                                                ? (isLight ? MoscaroTokens.auroraBlue.withValues(alpha: 0.4) : MoscaroTokens.borderGlow)
                                                : Colors.transparent,
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              title,
                                              style: TextStyle(
                                                color: isSelected ? (isLight ? MoscaroTokens.auroraBlue : textPrimary) : textSecondary,
                                                fontSize: 12,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            GestureDetector(
                                              onTap: () => widget.onCloseNote(noteId),
                                              child: Icon(
                                                Icons.close,
                                                size: 12,
                                                color: isSelected ? textSecondary : textSecondary.withValues(alpha: 0.5),
                                              ),
                                            ),
                                          ],
                                        ),
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
                Container(width: 1, height: 14, color: dividerColor),
                const SizedBox(width: 10),
                IconButton(
                  icon: Icon(Icons.add, color: iconColor, size: 18),
                  onPressed: widget.onAddNote,
                  tooltip: 'Nova Nota',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: SvgIcon(assetName: 'settings', size: 16, color: iconColor),
                  onPressed: widget.onOpenSettings,
                  tooltip: 'Configurações (Ctrl + ,)',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 6),
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
                  color: isLight ? Colors.black12 : Colors.white12,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: _scrollProgress,
                      child: Container(
                        decoration: BoxDecoration(
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
      enableBlur: MoscaroTokens.enableToolbarBlur,
      padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
    );
  }
}
