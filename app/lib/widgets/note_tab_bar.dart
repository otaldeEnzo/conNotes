import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/workspace_storage_service.dart';
import '../theme/moscaro_theme_controller.dart';
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
  final VoidCallback? onBackToHome;
  final bool isSidebarOpen;

  static const double tabItemWidth = 96.0;

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
    this.onBackToHome,
    this.isSidebarOpen = false,
  });

  @override
  State<NoteTabBar> createState() => _NoteTabBarState();
}

class _NoteTabBarState extends State<NoteTabBar> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollProgress = ValueNotifier<double>(0.0);
  bool _hasScrollOverflow = false;
  bool _showScrollIndicator = false;
  Timer? _scrollIndicatorTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollProgress);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollProgress());
  }

  @override
  void didUpdateWidget(covariant NoteTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeNoteIds.length != widget.activeNoteIds.length ||
        oldWidget.selectedNoteId != widget.selectedNoteId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateScrollProgress();
      });
    }
  }

  @override
  void dispose() {
    _scrollIndicatorTimer?.cancel();
    _scrollController.removeListener(_updateScrollProgress);
    _scrollController.dispose();
    _scrollProgress.dispose();
    super.dispose();
  }

  void _triggerScrollIndicator() {
    if (!_showScrollIndicator && mounted) {
      setState(() => _showScrollIndicator = true);
    }
    _scrollIndicatorTimer?.cancel();
    _scrollIndicatorTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted && _showScrollIndicator) {
        setState(() => _showScrollIndicator = false);
      }
    });
  }

  void _updateScrollProgress() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final hasOverflow = maxScroll > 0.5;
    if (!hasOverflow) {
      if (_scrollProgress.value != 0.0) {
        _scrollProgress.value = 0.0;
      }
      if (_hasScrollOverflow) {
        setState(() {
          _hasScrollOverflow = false;
        });
      }
      return;
    }
    final progress = (_scrollController.offset / maxScroll).clamp(0.0, 1.0);
    _triggerScrollIndicator();

    if (!_hasScrollOverflow) {
      setState(() {
        _hasScrollOverflow = true;
      });
    }
    if ((progress - _scrollProgress.value).abs() > 0.01) {
      _scrollProgress.value = progress;
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && _scrollController.hasClients) {
      _triggerScrollIndicator();
      final double delta = event.scrollDelta.dy != 0 ? event.scrollDelta.dy : event.scrollDelta.dx;
      final double targetOffset = (_scrollController.offset + delta).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(targetOffset);
    }
  }

  String _resolveTabTitle(String noteId) {
    return WorkspaceStorageService.instance.getLiveNoteTitle(noteId) ??
        widget.noteTitles[noteId] ??
        'Nota sem título';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        WorkspaceStorageService.instance,
        MoscaroThemeController.instance,
      ]),
      builder: (context, _) {
        final screenWidth = MediaQuery.of(context).size.width;
        final double absoluteMaxWidth = (screenWidth * 0.85).clamp(320.0, 950.0);

        // Largura uniforme e padronizada para todas as abas (136px + 6px gap)
        final double tabsWidth = widget.activeNoteIds.isEmpty
            ? 130.0
            : widget.activeNoteIds.length * (NoteTabBar.tabItemWidth + 6.0);

        final double homeExtraWidth = widget.onBackToHome != null ? 28.0 : 0.0;
        final double desiredWidth = 120.0 + homeExtraWidth + tabsWidth;
        final double targetWidth = desiredWidth.clamp(170.0, absoluteMaxWidth);

        final theme = MoscaroThemeController.instance.currentTheme;
        final accent = theme.accentPrimary;
        final accentSecondary = theme.accentSecondary;
        final isLight = MoscaroTokens.isLight;
        final textPrimary = MoscaroTokens.textPrimary;
        final textSecondary = MoscaroTokens.textSecondary;
        final iconColor = MoscaroTokens.iconInactive;
        final dividerColor = isLight ? Colors.black12 : Colors.white24;

        return LayoutBuilder(
          builder: (context, constraints) {
            final maxW = math.max(0.0, constraints.maxWidth);
            final effectiveTargetWidth = maxW > 0 ? math.min(targetWidth, maxW) : targetWidth;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              height: 38,
              width: effectiveTargetWidth,
              child: ClipRect(
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          if (widget.onBackToHome != null) ...[
                            IconButton(
                              icon: SvgIcon(
                                name: 'home',
                                size: 16,
                                color: iconColor,
                              ),
                              onPressed: widget.onBackToHome,
                              tooltip: 'Página Inicial (Home)',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                          ],
                          TapRegion(
                            groupId: 'note_sidebar_region',
                            child: IconButton(
                              icon: SvgIcon(
                                assetName: 'grid',
                                size: 18,
                                color: widget.isSidebarOpen ? accent : iconColor,
                              ),
                              onPressed: widget.onToggleSidebar,
                              tooltip: 'Menu de Notas',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(width: 1, height: 14, color: dividerColor),
                          const SizedBox(width: 8),
                          Expanded(
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
                                        physics: const ClampingScrollPhysics(),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: widget.activeNoteIds.map((noteId) {
                                            final isSelected = noteId == widget.selectedNoteId;
                                            final title = _resolveTabTitle(noteId);

                                            return _NoteTabItem(
                                              key: ValueKey('tab_$noteId'),
                                              noteId: noteId,
                                              title: title,
                                              isSelected: isSelected,
                                              isLight: isLight,
                                              accent: accent,
                                              textPrimary: textPrimary,
                                              textSecondary: textSecondary,
                                              onSelect: widget.onSelectNote,
                                              onClose: widget.onCloseNote,
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Container(width: 1, height: 14, color: dividerColor),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: SvgIcon(name: 'plus', color: iconColor, size: 16),
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
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                    if (widget.activeNoteIds.isNotEmpty && _hasScrollOverflow)
                      AnimatedOpacity(
                        opacity: _showScrollIndicator ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(1),
                            child: Container(
                              height: 2.0,
                              width: double.infinity,
                              color: isLight ? Colors.black12 : Colors.white12,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: ValueListenableBuilder<double>(
                                  valueListenable: _scrollProgress,
                                  builder: (context, progress, _) {
                                    return FractionallySizedBox(
                                      widthFactor: progress.clamp(0.1, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [accent, accentSecondary],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ).moscaroV2(
              borderRadius: MoscaroTokens.radiusPill,
              enableBlur: MoscaroTokens.enableToolbarBlur,
              padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
            );
          },
        );
      },
    );
  }
}

class _NoteTabItem extends StatefulWidget {
  final String noteId;
  final String title;
  final bool isSelected;
  final bool isLight;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onClose;

  const _NoteTabItem({
    super.key,
    required this.noteId,
    required this.title,
    required this.isSelected,
    required this.isLight,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.onSelect,
    required this.onClose,
  });

  @override
  State<_NoteTabItem> createState() => _NoteTabItemState();
}

class _NoteTabItemState extends State<_NoteTabItem> {
  bool _isHovered = false;
  bool _isCloseHovered = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (event.buttons == kMiddleMouseButton) {
          widget.onClose(widget.noteId);
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: () => widget.onSelect(widget.noteId),
          child: AnimatedScale(
            scale: _isHovered ? 1.025 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutQuad,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: 6),
              width: NoteTabBar.tabItemWidth,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? (widget.isLight
                        ? widget.accent.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.14))
                    : (_isHovered
                        ? (widget.isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.06))
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(MoscaroTokens.radiusButton),
                border: Border.all(
                  color: widget.isSelected
                      ? (widget.isLight ? widget.accent.withValues(alpha: 0.6) : MoscaroTokens.borderGlow)
                      : (_isHovered
                          ? (widget.isLight ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.12))
                          : Colors.transparent),
                  width: 1.0,
                ),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: widget.accent.withValues(alpha: 0.25),
                          blurRadius: 10,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: widget.isSelected
                            ? (widget.isLight ? widget.accent : widget.textPrimary)
                            : widget.textSecondary,
                        fontSize: 12,
                        fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 5),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _isCloseHovered = true),
                    onExit: (_) => setState(() => _isCloseHovered = false),
                    child: GestureDetector(
                      onTap: () => widget.onClose(widget.noteId),
                      child: AnimatedScale(
                        scale: _isCloseHovered ? 1.2 : 1.0,
                        duration: const Duration(milliseconds: 100),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isCloseHovered
                                ? Colors.redAccent.withValues(alpha: 0.25)
                                : Colors.transparent,
                          ),
                          child: SvgIcon(
                            name: 'close',
                            size: 11,
                            color: _isCloseHovered
                                ? Colors.redAccent
                                : (widget.isSelected
                                    ? widget.textSecondary
                                    : widget.textSecondary.withValues(alpha: 0.5)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
