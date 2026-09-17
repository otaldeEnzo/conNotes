import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_theme_controller.dart';
import '../models/canvas_card_model.dart';
import 'svg_icon.dart';
import 'stem_insert_hub_popover.dart';
import 'card_color_picker_popover.dart';
import 'card_typography_popover.dart';
import 'card_latex_editor_popover.dart';

bool globalIsHoveringFloatingPill = false;

/// Estado dos estilos ativos no cursor / seleção para confirmação visual na barra.
class CardActiveTextStyles {
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final bool isStrikethrough;
  final bool isSubscript;
  final bool isSuperscript;
  final bool isCode;
  final bool isLatex;
  final String? selectedText;
  final Color? textColor;
  final Color? highlightColor;
  final double? fontSize;
  final String? fontFamily;

  const CardActiveTextStyles({
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
    this.isSubscript = false,
    this.isSuperscript = false,
    this.isCode = false,
    this.isLatex = false,
    this.selectedText,
    this.textColor,
    this.highlightColor,
    this.fontSize,
    this.fontFamily,
  });
}

/// Enum para controle exclusivo dos popovers abertos da pílula flutuante.
enum ActivePillPopover {
  none,
  typography,
  textColor,
  highlightColor,
  stemHub,
  latexEditor,
}

/// Pílula Flutuante de Formatação Rica e Inserção STEM (100% Moscaro v2 Glass).
/// Totalmente modular, limpa e padronizada com ícones SVG vetoriais.
class CardFormatFloatingPill extends StatefulWidget {
  final CanvasCardModel card;
  final double cardWidth;
  final CardActiveTextStyles activeStyles;
  final ValueChanged<CanvasCardModel> onUpdateCard;
  final Function(String snippet) onInsertSnippet;
  final Function(String prefix, String suffix) onWrapSelection;
  final Function(Color color) onApplyTextColor;
  final Function(Color? color)? onApplyHighlightColor;
  final Function(double size) onApplyFontSize;
  final Function(String family)? onApplyFontFamily;
  final VoidCallback onDeleteCard;
  final VoidCallback onDuplicateCard;

  const CardFormatFloatingPill({
    super.key,
    required this.card,
    this.cardWidth = 340.0,
    this.activeStyles = const CardActiveTextStyles(),
    required this.onUpdateCard,
    required this.onInsertSnippet,
    required this.onWrapSelection,
    required this.onApplyTextColor,
    this.onApplyHighlightColor,
    required this.onApplyFontSize,
    this.onApplyFontFamily,
    required this.onDeleteCard,
    required this.onDuplicateCard,
  });

  static bool hasActivePopover = false;
  static VoidCallback? closeActivePopover;

  @override
  State<CardFormatFloatingPill> createState() => _CardFormatFloatingPillState();
}

class _CardFormatFloatingPillState extends State<CardFormatFloatingPill> {
  ActivePillPopover _activePopover = ActivePillPopover.none;
  final ScrollController _pillScrollController = ScrollController();

  @override
  void dispose() {
    globalIsHoveringFloatingPill = false;
    if (CardFormatFloatingPill.closeActivePopover == _closePopover) {
      CardFormatFloatingPill.hasActivePopover = false;
      CardFormatFloatingPill.closeActivePopover = null;
    }
    _pillScrollController.dispose();
    super.dispose();
  }

  void _togglePopover(ActivePillPopover popover) {
    setState(() {
      if (_activePopover == popover) {
        _activePopover = ActivePillPopover.none;
        CardFormatFloatingPill.hasActivePopover = false;
        CardFormatFloatingPill.closeActivePopover = null;
      } else {
        _activePopover = popover;
        CardFormatFloatingPill.hasActivePopover = true;
        CardFormatFloatingPill.closeActivePopover = _closePopover;
      }
    });
  }

  void _closePopover() {
    if (_activePopover != ActivePillPopover.none) {
      setState(() {
        _activePopover = ActivePillPopover.none;
        CardFormatFloatingPill.hasActivePopover = false;
        CardFormatFloatingPill.closeActivePopover = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MoscaroThemeController.instance,
      builder: (context, _) {
        final isLight = MoscaroTokens.isLight;
        final themeAccent = MoscaroTokens.auroraBlue;
        final textPrimary = MoscaroTokens.textPrimary;
        final glassTint = MoscaroTokens.glassTint;
        final blur = (MoscaroTokens.enableToolbarBlur && MoscaroTokens.blurSigma > 0)
            ? MoscaroTokens.blurSigma
            : 0.0;

        return MouseRegion(
          hitTestBehavior: HitTestBehavior.opaque,
          onEnter: (_) => globalIsHoveringFloatingPill = true,
          onHover: (_) => globalIsHoveringFloatingPill = true,
          onExit: (_) => globalIsHoveringFloatingPill = false,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) {
              globalIsHoveringFloatingPill = true;
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Popover Ativo (Ancorado acima da pílula)
                  if (_activePopover != ActivePillPopover.none) ...[
                    _buildActivePopover(isLight, themeAccent, textPrimary),
                    const SizedBox(height: 6),
                  ],

                  // Barra Horizontal de Ações (Pílula Compacta) - FocusScope(canRequestFocus: false) apenas aqui
                  // para que cliques nos botões de formatação não roubem foco do editor de texto
                  FocusScope(
                    canRequestFocus: false,
                    child: _buildPillBar(isLight, glassTint, themeAccent, textPrimary, blur),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivePopover(bool isLight, Color themeAccent, Color textPrimary) {
    switch (_activePopover) {
      case ActivePillPopover.typography:
        return CardTypographyPopover(
          currentFontFamily: widget.activeStyles.fontFamily ?? widget.card.fontFamily,
          currentFontSize: widget.activeStyles.fontSize ?? widget.card.fontSize,
          onSelectFontFamily: (family) {
            if (widget.onApplyFontFamily != null) {
              widget.onApplyFontFamily!(family);
            } else {
              widget.onUpdateCard(widget.card.copyWith(fontFamily: family));
            }
          },
          onSelectFontSize: widget.onApplyFontSize,
          onClose: _closePopover,
        );

      case ActivePillPopover.textColor:
        return CardColorPickerPopover(
          currentTextColor: widget.activeStyles.textColor ?? widget.card.textColor,
          currentHighlightColor: widget.activeStyles.highlightColor,
          initialMode: ColorPickerMode.textColor,
          onSelectTextColor: widget.onApplyTextColor,
          onSelectHighlightColor: (color) {
            widget.onApplyHighlightColor?.call(color);
          },
          onClose: _closePopover,
        );

      case ActivePillPopover.highlightColor:
        return CardColorPickerPopover(
          currentTextColor: widget.activeStyles.textColor ?? widget.card.textColor,
          currentHighlightColor: widget.activeStyles.highlightColor,
          initialMode: ColorPickerMode.highlightColor,
          onSelectTextColor: widget.onApplyTextColor,
          onSelectHighlightColor: (color) {
            widget.onApplyHighlightColor?.call(color);
          },
          onClose: _closePopover,
        );

      case ActivePillPopover.stemHub:
        return StemInsertHubPopover(
          onInsertSnippet: widget.onInsertSnippet,
          onClose: _closePopover,
        );

      case ActivePillPopover.latexEditor:
        return CardLatexEditorPopover(
          initialLatex: widget.activeStyles.selectedText ?? '',
          onApply: (mathSnippet) {
            widget.onInsertSnippet(mathSnippet);
          },
          onClose: _closePopover,
        );

      case ActivePillPopover.none:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPillBar(
    bool isLight,
    Color glassTint,
    Color themeAccent,
    Color textPrimary,
    double blur,
  ) {
    final effectiveFont = widget.card.fontFamily;
    final effectiveSize = widget.activeStyles.fontSize ?? widget.card.fontSize;

    return ClipRRect(
      borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
      child: blur > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: _buildBarInner(isLight, glassTint, themeAccent, textPrimary, effectiveFont, effectiveSize),
            )
          : _buildBarInner(isLight, glassTint, themeAccent, textPrimary, effectiveFont, effectiveSize),
    );
  }

  Widget _buildBarInner(
    bool isLight,
    Color glassTint,
    Color themeAccent,
    Color textPrimary,
    String effectiveFont,
    double effectiveSize,
  ) {
    return Container(
      height: 38,
      constraints: BoxConstraints(maxWidth: widget.cardWidth),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isLight
            ? const Color(0xFFF8FAFC).withValues(alpha: 0.95)
            : glassTint,
        borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
        border: Border.all(
          color: isLight ? MoscaroTokens.borderSubtle : MoscaroTokens.borderGlow,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: Listener(
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent && _pillScrollController.hasClients) {
              GestureBinding.instance.pointerSignalResolver.register(pointerSignal, (event) {
                if (event is PointerScrollEvent && _pillScrollController.hasClients) {
                  final delta = event.scrollDelta.dx != 0 ? event.scrollDelta.dx : event.scrollDelta.dy;
                  final target = (_pillScrollController.offset + delta * 1.5).clamp(
                    0.0,
                    _pillScrollController.position.maxScrollExtent,
                  );
                  _pillScrollController.animateTo(
                    target,
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.easeOutCubic,
                  );
                }
              });
            }
          },
          child: SingleChildScrollView(
            controller: _pillScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Tipografia (Fonte + Tamanho)
            _buildTypographyButton(effectiveFont, effectiveSize, themeAccent, textPrimary),

            _buildDivider(isLight),

            // 2. Formatação Básica (B, I, U, S, Code, Math $)
            _buildFormatButton(
              label: 'B',
              tooltip: 'Negrito (Ctrl+B)',
              isActive: widget.activeStyles.isBold,
              themeAccent: themeAccent,
              textPrimary: textPrimary,
              onTap: () => widget.onWrapSelection('**', '**'),
              isBoldText: true,
            ),
            const SizedBox(width: 2),
            _buildFormatButton(
              label: 'I',
              tooltip: 'Itálico (Ctrl+I)',
              isActive: widget.activeStyles.isItalic,
              themeAccent: themeAccent,
              textPrimary: textPrimary,
              onTap: () => widget.onWrapSelection('*', '*'),
              isItalicText: true,
            ),
            const SizedBox(width: 2),
            _buildFormatButton(
              label: 'U',
              tooltip: 'Sublinhado (Ctrl+U)',
              isActive: widget.activeStyles.isUnderline,
              themeAccent: themeAccent,
              textPrimary: textPrimary,
              onTap: () => widget.onWrapSelection('<u>', '</u>'),
              isUnderlineText: true,
            ),
            const SizedBox(width: 2),
            _buildFormatButton(
              label: 'S',
              tooltip: 'Tachado',
              isActive: widget.activeStyles.isStrikethrough,
              themeAccent: themeAccent,
              textPrimary: textPrimary,
              onTap: () => widget.onWrapSelection('~~', '~~'),
              isStrikeText: true,
            ),
            const SizedBox(width: 2),
            _buildIconButton(
              iconName: 'code',
              tooltip: 'Código Monospace (`code`)',
              isActive: widget.activeStyles.isCode,
              themeAccent: themeAccent,
              textPrimary: textPrimary,
              onTap: () => widget.onWrapSelection('`', '`'),
            ),
            const SizedBox(width: 2),
            _buildFormatButton(
              label: r'$',
              tooltip: 'LaTeX Inline (\$f(x)\$)',
              isActive: widget.activeStyles.isLatex || _activePopover == ActivePillPopover.latexEditor,
              themeAccent: themeAccent,
              textPrimary: textPrimary,
              onTap: () => _togglePopover(ActivePillPopover.latexEditor),
            ),

            _buildDivider(isLight),

            // 3. Cores (Texto e Marca-texto)
            _buildColorButton(
              iconName: 'palette',
              tooltip: 'Cor do Texto',
              dotColor: widget.activeStyles.textColor ?? widget.card.textColor,
              isActive: _activePopover == ActivePillPopover.textColor,
              themeAccent: themeAccent,
              textPrimary: textPrimary,
              onTap: () => _togglePopover(ActivePillPopover.textColor),
            ),
            const SizedBox(width: 2),
            _buildColorButton(
              iconName: 'brush',
              tooltip: 'Marca-texto (Realce)',
              dotColor: widget.activeStyles.highlightColor,
              isActive: _activePopover == ActivePillPopover.highlightColor,
              themeAccent: themeAccent,
              textPrimary: textPrimary,
              onTap: () => _togglePopover(ActivePillPopover.highlightColor),
            ),

            _buildDivider(isLight),

            // 4. STEM Hub Unificado (+)
            _buildStemHubButton(themeAccent, textPrimary),

            _buildDivider(isLight),

            // 5. Ações do Card (Duplicar, Excluir)
            _buildIconButton(
              iconName: 'copy',
              tooltip: 'Duplicar Card',
              themeAccent: themeAccent,
              textPrimary: textPrimary,
              onTap: widget.onDuplicateCard,
            ),
            const SizedBox(width: 2),
            _buildIconButton(
              iconName: 'trash',
              tooltip: 'Excluir Card',
              themeAccent: Colors.redAccent,
              textPrimary: textPrimary,
              onTap: widget.onDeleteCard,
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }

  Widget _buildDivider(bool isLight) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: isLight
          ? Colors.black.withValues(alpha: 0.1)
          : Colors.white.withValues(alpha: 0.12),
    );
  }

  Widget _buildTypographyButton(
    String font,
    double size,
    Color themeAccent,
    Color textPrimary,
  ) {
    final isOpen = _activePopover == ActivePillPopover.typography;
    return Tooltip(
      message: 'Alterar Tipografia e Tamanho',
      child: InkWell(
        onTap: () => _togglePopover(ActivePillPopover.typography),
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: isOpen ? themeAccent.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isOpen ? themeAccent.withValues(alpha: 0.5) : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${font.split(' ').first} ${size.round()}pt',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: font,
                  color: isOpen ? themeAccent : textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 3),
              SvgIcon(
                name: 'chevron_down',
                size: 10,
                color: isOpen ? themeAccent : textPrimary.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatButton({
    required String label,
    required String tooltip,
    required bool isActive,
    required Color themeAccent,
    required Color textPrimary,
    required VoidCallback onTap,
    bool isBoldText = false,
    bool isItalicText = false,
    bool isUnderlineText = false,
    bool isStrikeText = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? themeAccent.withValues(alpha: 0.22) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? themeAccent.withValues(alpha: 0.6) : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBoldText ? FontWeight.bold : FontWeight.w600,
              fontStyle: isItalicText ? FontStyle.italic : FontStyle.normal,
              decoration: isUnderlineText
                  ? TextDecoration.underline
                  : (isStrikeText ? TextDecoration.lineThrough : null),
              color: isActive ? themeAccent : textPrimary.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required String iconName,
    required String tooltip,
    bool isActive = false,
    required Color themeAccent,
    required Color textPrimary,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? themeAccent.withValues(alpha: 0.22) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? themeAccent.withValues(alpha: 0.6) : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: SvgIcon(
            name: iconName,
            size: 13,
            color: isActive ? themeAccent : textPrimary.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }

  Widget _buildColorButton({
    required String iconName,
    required String tooltip,
    Color? dotColor,
    required bool isActive,
    required Color themeAccent,
    required Color textPrimary,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          height: 26,
          decoration: BoxDecoration(
            color: isActive ? themeAccent.withValues(alpha: 0.22) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? themeAccent.withValues(alpha: 0.6) : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(
                name: iconName,
                size: 13,
                color: isActive ? themeAccent : textPrimary.withValues(alpha: 0.85),
              ),
              if (dotColor != null) ...[
                const SizedBox(width: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 0.6,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStemHubButton(Color themeAccent, Color textPrimary) {
    final isOpen = _activePopover == ActivePillPopover.stemHub;
    return Tooltip(
      message: 'STEM Hub (LaTeX, Mermaid & Callouts)',
      child: InkWell(
        onTap: () => _togglePopover(ActivePillPopover.stemHub),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: isOpen
                ? themeAccent.withValues(alpha: 0.28)
                : themeAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isOpen
                  ? themeAccent
                  : themeAccent.withValues(alpha: 0.45),
              width: 0.9,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(name: 'circuit', size: 13, color: themeAccent),
              const SizedBox(width: 4),
              Text(
                'STEM Hub',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: themeAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
