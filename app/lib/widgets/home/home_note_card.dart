import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/moscaro_theme_controller.dart';
import '../../theme/moscaro_v2_extension.dart';
import '../../theme/moscaro_v2_tokens.dart';
import '../../services/note_ai_summary_service.dart';
import '../note_models.dart';
import '../svg_icon.dart';
import '../moscaro_glass_popup_menu.dart';
import 'home_note_hover_preview.dart';

/// Card Individual de cada Nota da Biblioteca (Moscaro v2 Pro Max).
/// Apresenta:
/// - Fundo de Vidro Líquido com desfoque e borda iluminada reativa ao hover.
/// - Tag da disciplina com cor temática.
/// - Resumo inteligente (IA, OCR Local ou Heurístico com badges).
/// - Popover flutuante expandido suave sob hover com preview vetorial dos traços.
/// - Menu de contexto completo (Fixar, Renomear, Duplicar, Deletar).
class HomeNoteCard extends StatefulWidget {
  final NoteDocument note;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onRename;
  final bool isListMode;

  const HomeNoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.onDelete,
    required this.onDuplicate,
    required this.onRename,
    this.isListMode = false,
  });

  @override
  State<HomeNoteCard> createState() => _HomeNoteCardState();
}

class _HomeNoteCardState extends State<HomeNoteCard> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _hoverTimer;
  final ValueNotifier<bool> _isHoveredNotifier = ValueNotifier(false);
  bool get _isHovered => _isHoveredNotifier.value;

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _scheduleOverlay() {
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 280), () {
      if (mounted && _isHovered && _overlayEntry == null) {
        _showOverlay();
      }
    });
  }

  void _cancelOverlay() {
    _hoverTimer?.cancel();
    _removeOverlay();
  }

  void _showOverlay() {
    final overlayState = Overlay.of(context, rootOverlay: true);
    final theme = MoscaroThemeController.instance.currentTheme;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: 320,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(16, -230),
            child: IgnorePointer(
              child: Material(
                color: Colors.transparent,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, child) {
                    return Opacity(
                      opacity: val,
                      child: Transform.scale(
                        scale: 0.94 + (0.06 * val),
                        alignment: Alignment.bottomLeft,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.backgroundSurface.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.accentPrimary.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 28,
                          spreadRadius: 4,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: theme.accentPrimary.withValues(alpha: 0.25),
                          blurRadius: 16,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: theme.accentPrimary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: theme.accentPrimary.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'PREVIEW VETORIAL',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: theme.accentPrimary,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${widget.note.strokes.length} traços',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        HomeNoteHoverPreview(
                          note: widget.note,
                          width: 296,
                          height: 160,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlayState.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) {
      return 'Agora mesmo';
    } else if (diff.inMinutes < 60) {
      return 'Há ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Há ${diff.inHours} h';
    } else if (diff.inDays < 7) {
      return 'Há ${diff.inDays} d';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } else if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  String _buildSmartSummary() {
    // 1. Priorizar resumo já salvo (IA ou OCR), ignorando mensagens de erro do servidor e formatos legados que listavam traços
    final savedSummary = widget.note.aiSummary?.trim();
    if (savedSummary != null && savedSummary.isNotEmpty) {
      final lower = savedSummary.toLowerCase();
      final isErrorMessage = lower.startsWith('erro:') ||
          lower.contains('temporariamente sobrecarregado') ||
          lower.contains('limite de requisições') ||
          lower.contains('não foi possível obter resposta') ||
          lower.contains('chave de api do gemini inválida') ||
          lower.contains('está temporariamente indisponível');

      final isLegacyStrokeSummary = lower.contains('apresenta apenas um traço') ||
          lower.contains('traços vetoriais de tinta') ||
          lower.contains('esquemas desenhados com') ||
          lower.contains('reúne 32 traços') ||
          lower.contains('reúne 35 traços') ||
          lower.contains('conteúdo reúne') ||
          (lower.contains('traços') && lower.contains('aguardando'));

      if (!isErrorMessage && !isLegacyStrokeSummary) {
        return savedSummary;
      }
    }

    // 2. Extrair texto de cartões STEM se existirem
    if (widget.note.cards.isNotEmpty) {
      final cardSnippets = <String>[];
      for (final card in widget.note.cards) {
        final cleanContent = card.content.replaceAll('\n', ' ').trim();
        if (cleanContent.isNotEmpty) {
          cardSnippets.add(cleanContent);
        }
      }
      if (cardSnippets.isNotEmpty) {
        return cardSnippets.join(' • ');
      }
    }

    // 3. Heurística conceitual baseada no título e disciplina (sem contagem de traços)
    final tagText = widget.note.tags.isNotEmpty ? widget.note.tags.first : 'Estudos Gerais';
    if (widget.note.strokes.isNotEmpty) {
      return 'Registro visual e esquemas conceituais em $tagText, estruturados para cálculos e anotações técnicas.';
    }

    return 'Caderno de estudos em $tagText preparado para anotações, deduções e resolução de problemas.';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MoscaroThemeController.instance,
      builder: (context, _) {
        final theme = MoscaroThemeController.instance.currentTheme;
        final accent = theme.accentPrimary;
        final isLight = MoscaroTokens.isLight;

        final tagText = widget.note.tags.isNotEmpty ? widget.note.tags.first : 'Geral';
        final totalStrokes = widget.note.strokes.length;
        final totalCards = widget.note.cards.length;

        final estimatedSize = 4096 + (totalStrokes * 240) + (totalCards * 512);
        final summary = _buildSmartSummary();

        final cardInner = CompositedTransformTarget(
          link: _layerLink,
          child: MouseRegion(
            onEnter: (_) {
              _isHoveredNotifier.value = true;
              if (totalStrokes > 0 || totalCards > 0) {
                _scheduleOverlay();
              }
            },
            onExit: (_) {
              _isHoveredNotifier.value = false;
              _cancelOverlay();
            },
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: widget.isListMode
                    ? const EdgeInsets.symmetric(horizontal: 18, vertical: 12)
                    : const EdgeInsets.all(18),
                child: widget.isListMode
                    // Visualização em Lista Horizontal Elegante e Compacta (Sem Overflow)
                    ? Row(
                        children: [
                          // Tag Temática da Disciplina
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: isLight ? 0.12 : 0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.45),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              tagText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isLight ? const Color(0xFF0284C7) : accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Título e Resumo Rápido
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.note.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: isLight ? const Color(0xFF0F172A) : Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Badges Discretas STEM
                                    if (totalCards > 0)
                                      _buildBadge(
                                        icon: 'card',
                                        text: '$totalCards blocos',
                                        color: theme.accentSecondary,
                                        isLight: isLight,
                                      ),
                                    if (totalCards > 0 && totalStrokes > 0)
                                      const SizedBox(width: 6),
                                    if (totalStrokes > 0)
                                      _buildBadge(
                                        icon: 'brush',
                                        text: '$totalStrokes traços',
                                        color: theme.accentPrimary,
                                        isLight: isLight,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  summary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w400,
                                    color: isLight ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Timestamp e Tamanho
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgIcon(
                                    name: 'activity',
                                    size: 11,
                                    color: isLight ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatRelativeTime(widget.note.updatedAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: isLight ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatFileSize(estimatedSize),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isLight ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),

                          // Ações: Favorito e Menu
                          IconButton(
                            icon: SvgIcon(
                              name: widget.note.isFavorite ? 'star_filled' : 'star',
                              size: 16,
                              color: widget.note.isFavorite ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                            ),
                            onPressed: widget.onFavoriteToggle,
                            tooltip: widget.note.isFavorite ? 'Remover dos favoritos' : 'Favoritar nota',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          ),
                          const SizedBox(width: 4),
                          // Menu de Contexto Moscaro Glass com Blur
                          MoscaroGlassPopupMenu<String>(
                            tooltip: 'Opções da nota',
                            items: [
                              MoscaroGlassMenuItem<String>(
                                value: 'pin',
                                label: widget.note.isFavorite ? 'Desafixar' : 'Fixar no topo',
                                svgIconName: widget.note.isFavorite ? 'star_filled' : 'star',
                                color: accent,
                              ),
                              MoscaroGlassMenuItem<String>(
                                value: 'summarize_ai',
                                label: 'Gerar Resumo por IA',
                                svgIconName: 'ai',
                                color: MoscaroTokens.auroraBlue,
                              ),
                              MoscaroGlassMenuItem<String>(
                                value: 'rename',
                                label: 'Renomear',
                                svgIconName: 'edit',
                                color: accent,
                              ),
                              MoscaroGlassMenuItem<String>(
                                value: 'duplicate',
                                label: 'Duplicar',
                                svgIconName: 'copy',
                                color: accent,
                              ),
                              const MoscaroGlassMenuItem<String>.divider(value: 'div'),
                              const MoscaroGlassMenuItem<String>(
                                value: 'delete',
                                label: 'Mover para Lixeira',
                                svgIconName: 'trash',
                                isDestructive: true,
                              ),
                            ],
                            onSelected: (val) {
                              if (val == 'pin') widget.onFavoriteToggle();
                              if (val == 'summarize_ai') {
                                NoteAiSummaryService.instance.forceSummarize(widget.note);
                              }
                              if (val == 'rename') widget.onRename();
                              if (val == 'duplicate') widget.onDuplicate();
                              if (val == 'delete') widget.onDelete();
                            },
                          ),
                        ],
                      )
                    // Visualização em Card de Grade (Padrão Grid)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Linha Superior: Tag Temática + Ações Rápidas (Favorito e Menu)
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: isLight ? 0.12 : 0.18),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.45),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  tagText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isLight ? const Color(0xFF0284C7) : accent,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // Botão Favorito
                              IconButton(
                                icon: SvgIcon(
                                  name: widget.note.isFavorite ? 'star_filled' : 'star',
                                  size: 15,
                                  color: widget.note.isFavorite ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                                ),
                                onPressed: widget.onFavoriteToggle,
                                tooltip: widget.note.isFavorite ? 'Remover dos favoritos' : 'Favoritar nota',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              ),
                              const SizedBox(width: 4),
                              // Menu de Contexto Moscaro Glass com Blur
                              MoscaroGlassPopupMenu<String>(
                                tooltip: 'Opções da nota',
                                items: [
                                  MoscaroGlassMenuItem<String>(
                                    value: 'pin',
                                    label: widget.note.isFavorite ? 'Desafixar' : 'Fixar no topo',
                                    svgIconName: widget.note.isFavorite ? 'star_filled' : 'star',
                                    color: accent,
                                  ),
                                  MoscaroGlassMenuItem<String>(
                                    value: 'summarize_ai',
                                    label: 'Gerar Resumo por IA',
                                    svgIconName: 'ai',
                                    color: MoscaroTokens.auroraBlue,
                                  ),
                                  MoscaroGlassMenuItem<String>(
                                    value: 'rename',
                                    label: 'Renomear',
                                    svgIconName: 'edit',
                                    color: accent,
                                  ),
                                  MoscaroGlassMenuItem<String>(
                                    value: 'duplicate',
                                    label: 'Duplicar',
                                    svgIconName: 'copy',
                                    color: accent,
                                  ),
                                  const MoscaroGlassMenuItem<String>.divider(value: 'div'),
                                  const MoscaroGlassMenuItem<String>(
                                    value: 'delete',
                                    label: 'Mover para Lixeira',
                                    svgIconName: 'trash',
                                    isDestructive: true,
                                  ),
                                ],
                                onSelected: (val) {
                                  if (val == 'pin') widget.onFavoriteToggle();
                                  if (val == 'summarize_ai') {
                                    NoteAiSummaryService.instance.forceSummarize(widget.note);
                                  }
                                  if (val == 'rename') widget.onRename();
                                  if (val == 'duplicate') widget.onDuplicate();
                                  if (val == 'delete') widget.onDelete();
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // 2. Título da Nota
                          Text(
                            widget.note.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isLight ? const Color(0xFF0F172A) : Colors.white,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // 3. Resumo Inteligente Estruturado da Nota (Aproveitamento total do espaço)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    summary,
                                    maxLines: 5,
                                    overflow: TextOverflow.fade,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.45,
                                      fontWeight: FontWeight.w400,
                                      color: isLight ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Badges de Conteúdo STEM
                                Row(
                                  children: [
                                    if (totalCards > 0)
                                      _buildBadge(
                                        icon: 'card',
                                        text: '$totalCards blocos',
                                        color: theme.accentSecondary,
                                        isLight: isLight,
                                      ),
                                    if (totalCards > 0 && totalStrokes > 0)
                                      const SizedBox(width: 6),
                                    if (totalStrokes > 0)
                                      _buildBadge(
                                        icon: 'brush',
                                        text: '$totalStrokes traços',
                                        color: theme.accentPrimary,
                                        isLight: isLight,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // 4. Rodapé: Tempo Relativo e Tamanho do Arquivo
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  SvgIcon(
                                    name: 'activity',
                                    size: 12,
                                    color: isLight ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _formatRelativeTime(widget.note.updatedAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: isLight ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isLight ? const Color(0x150F172A) : const Color(0x20FFFFFF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _formatFileSize(estimatedSize),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isLight ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
              ),
            ),
          ),
        );

        return RepaintBoundary(
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () {
                _cancelOverlay();
                widget.onTap();
              },
              borderRadius: BorderRadius.circular(16.0),
              splashColor: accent.withValues(alpha: 0.12),
              highlightColor: accent.withValues(alpha: 0.06),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: const SizedBox.shrink().moscaroV2(
                      borderRadius: 16.0,
                      blurSigma: 35.0,
                      enableBlur: true,
                      backgroundColor: theme.glassColor.withValues(alpha: 0.1),
                      borderColor: const Color(0x2E3B5278),
                      borderWidth: 1.0,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  Positioned.fill(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _isHoveredNotifier,
                      builder: (context, isHovered, _) {
                        return AnimatedOpacity(
                          opacity: isHovered ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.glassColor,
                              borderRadius: BorderRadius.circular(16.0),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.6),
                                width: 1.0,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  cardInner,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge({
    required String icon,
    required String text,
    required Color color,
    required bool isLight,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isLight ? 0.1 : 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgIcon(name: icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
