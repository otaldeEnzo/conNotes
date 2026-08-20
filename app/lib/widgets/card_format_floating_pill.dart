import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_theme_controller.dart';
import '../models/canvas_card_model.dart';
import '../services/custom_font_manager.dart';
import 'latex_stem_symbols_palette.dart';

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
  final Color? textColor;
  final Color? highlightColor;
  final double? fontSize;

  const CardActiveTextStyles({
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
    this.isSubscript = false,
    this.isSuperscript = false,
    this.isCode = false,
    this.isLatex = false,
    this.textColor,
    this.highlightColor,
    this.fontSize,
  });
}

/// Pílula Flutuante de Formatação Rica de Texto, LaTeX, Diagramas e Estilo do Card (100% Moscaro Glass).
class CardFormatFloatingPill extends StatefulWidget {
  final CanvasCardModel card;
  final double cardWidth;
  final CardActiveTextStyles activeStyles;
  final ValueChanged<CanvasCardModel> onUpdateCard;
  final Function(String snippet) onInsertSnippet;
  final Function(String prefix, String suffix) onWrapSelection;
  final Function(Color color) onApplyTextColor;
  final Function(double size) onApplyFontSize;
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
    required this.onApplyFontSize,
    required this.onDeleteCard,
    required this.onDuplicateCard,
  });

  @override
  State<CardFormatFloatingPill> createState() => _CardFormatFloatingPillState();
}

class _CardFormatFloatingPillState extends State<CardFormatFloatingPill> {
  bool _isLatexPaletteOpen = false;
  bool _isMermaidMenuOpen = false;
  bool _isCalloutMenuOpen = false;
  bool _isFontMenuOpen = false;
  bool _isColorPaletteOpen = false;
  bool _isHighlightMenuOpen = false;
  bool _isEditingFontSize = false;
  final ScrollController _pillScrollController = ScrollController();
  late TextEditingController _fontSizeController;
  final FocusNode _fontSizeFocusNode = FocusNode();

  double get _currentEffectiveFontSize => widget.activeStyles.fontSize ?? widget.card.fontSize;

  @override
  void initState() {
    super.initState();
    final size = _currentEffectiveFontSize;
    _fontSizeController = TextEditingController(
      text: size.toStringAsFixed(
        size.truncateToDouble() == size ? 0 : 1,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant CardFormatFloatingPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSize = oldWidget.activeStyles.fontSize ?? oldWidget.card.fontSize;
    final newSize = _currentEffectiveFontSize;
    if (oldSize != newSize && !_isEditingFontSize) {
      _fontSizeController.text = newSize.toStringAsFixed(
        newSize.truncateToDouble() == newSize ? 0 : 1,
      );
    }
  }

  @override
  void dispose() {
    _pillScrollController.dispose();
    _fontSizeController.dispose();
    _fontSizeFocusNode.dispose();
    super.dispose();
  }

  void _updateFontSize(double newSize) {
    final clamped = newSize.clamp(6.0, 160.0);
    widget.onApplyFontSize(clamped);
  }

  Widget _buildPillContainer({
    required Widget child,
    required bool isLight,
    required Color glassTint,
    required double blur,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
      child: blur > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blur,
                sigmaY: blur,
              ),
              child: Container(
                height: 38,
                constraints: BoxConstraints(maxWidth: math.max(widget.cardWidth, 480.0)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: child,
              ),
            )
          : Container(
              height: 38,
              constraints: BoxConstraints(maxWidth: math.max(widget.cardWidth, 480.0)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: child,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      canRequestFocus: false,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          MoscaroThemeController.instance,
          CustomFontManager.instance,
        ]),
        builder: (context, _) {
          final isLight = MoscaroTokens.isLight;
          final themeAccent = MoscaroTokens.auroraBlue;
          final textPrimary = MoscaroTokens.textPrimary;
          final textSecondary = MoscaroTokens.textSecondary;
          final glassTint = MoscaroTokens.glassTint;
          final blur = (MoscaroTokens.enableToolbarBlur && MoscaroTokens.blurSigma > 0) ? MoscaroTokens.blurSigma : 0.0;
          final popoverBlur = (MoscaroTokens.enableSubBarsBlur && MoscaroTokens.blurSigma > 0) ? MoscaroTokens.blurSigma : 0.0;
          final fonts = CustomFontManager.instance.availableFonts;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Popover do Menu de Fontes Moscaro
              if (_isFontMenuOpen) ...[
                _buildMoscaroFontPopover(fonts, isLight, glassTint, themeAccent, textPrimary, textSecondary, popoverBlur),
                const SizedBox(height: 6),
              ],

              // 2. Popover da Paleta de Cores de Texto
              if (_isColorPaletteOpen) ...[
                _buildTextColorPalettePopover(isLight, glassTint, themeAccent, textPrimary, popoverBlur),
                const SizedBox(height: 6),
              ],

              // 2.1 Popover da Paleta de Marca-Texto
              if (_isHighlightMenuOpen) ...[
                _buildHighlightPalettePopover(isLight, glassTint, themeAccent, textPrimary, popoverBlur),
                const SizedBox(height: 6),
              ],

              // 3. Menu Suspenso de Símbolos LaTeX
              if (_isLatexPaletteOpen) ...[
                LatexStemSymbolsPalette(
                  onSelectSymbol: (snippet) {
                    final formatted = snippet.startsWith(r'$') ? snippet : '\$$snippet\$';
                    widget.onInsertSnippet(formatted);
                    setState(() => _isLatexPaletteOpen = false);
                  },
                  onClose: () => setState(() => _isLatexPaletteOpen = false),
                ),
                const SizedBox(height: 6),
              ],

              // 4. Menu Suspenso de Templates Mermaid
              if (_isMermaidMenuOpen) ...[
                _buildMermaidMenu(isLight, glassTint, themeAccent, textPrimary, popoverBlur),
                const SizedBox(height: 6),
              ],

              // 5. Menu Suspenso de Callouts STEM
              if (_isCalloutMenuOpen) ...[
                _buildCalloutMenu(isLight, glassTint, themeAccent, textPrimary, popoverBlur),
                const SizedBox(height: 6),
              ],

              // Pílula Única e Confortável de Ações e Formatação do Card
              _buildPillContainer(
                isLight: isLight,
                glassTint: glassTint,
                blur: blur,
                child: Listener(
                  onPointerSignal: (pointerSignal) {
                    if (pointerSignal is PointerScrollEvent && _pillScrollController.hasClients) {
                      final target = (_pillScrollController.offset + pointerSignal.scrollDelta.dy * 1.3).clamp(
                        0.0,
                        _pillScrollController.position.maxScrollExtent,
                      );
                      _pillScrollController.animateTo(
                        target,
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                  child: SingleChildScrollView(
                    controller: _pillScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMoscaroFontSelectorButton(isLight, textPrimary, textSecondary, themeAccent),
                        const SizedBox(width: 5),
                        _buildDivider(isLight),
                        const SizedBox(width: 5),
                        _buildFontSizeControls(textPrimary, themeAccent, isLight),
                        const SizedBox(width: 5),
                        _buildDivider(isLight),
                        const SizedBox(width: 5),
                        _buildRichFormattingControls(),
                        const SizedBox(width: 5),
                        _buildDivider(isLight),
                        const SizedBox(width: 5),
                        _buildAlignmentControls(),
                        const SizedBox(width: 5),
                        _buildDivider(isLight),
                        const SizedBox(width: 5),
                        _buildListControls(),
                        const SizedBox(width: 5),
                        _buildDivider(isLight),
                        const SizedBox(width: 5),
                        _buildLatexMermaidButtons(),
                        const SizedBox(width: 5),
                        _buildDivider(isLight),
                        const SizedBox(width: 5),
                        _buildActionControls(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // Botão e Popover de Fontes Moscaro v2
  // ==========================================

  Widget _buildMoscaroFontSelectorButton(bool isLight, Color textPrimary, Color textSecondary, Color themeAccent) {
    final currentFont = widget.card.fontFamily;
    return Tooltip(
      message: 'Selecionar Tipografia / Fonte',
      child: InkWell(
        onTap: () {
          setState(() {
            _isFontMenuOpen = !_isFontMenuOpen;
            _isColorPaletteOpen = false;
            _isLatexPaletteOpen = false;
            _isMermaidMenuOpen = false;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: _isFontMenuOpen
                ? themeAccent.withValues(alpha: 0.2)
                : (isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.06)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isFontMenuOpen ? themeAccent : (isLight ? Colors.black12 : Colors.white12),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentFont.length > 10 ? '${currentFont.substring(0, 9)}…' : currentFont,
                style: TextStyle(
                  color: _isFontMenuOpen ? themeAccent : textPrimary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  fontFamily: currentFont,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                _isFontMenuOpen ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                size: 14,
                color: _isFontMenuOpen ? themeAccent : textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoscaroFontPopover(
    List<String> fonts,
    bool isLight,
    Color glassTint,
    Color themeAccent,
    Color textPrimary,
    Color textSecondary,
    double blur,
  ) {
    Widget content = Container(
      width: 220,
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withValues(alpha: 0.94) : glassTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: themeAccent.withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tipografias STEM',
                  style: TextStyle(color: textPrimary, fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 14, color: textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  onPressed: () => setState(() => _isFontMenuOpen = false),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isLight ? Colors.black12 : Colors.white12),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: fonts.length,
              itemBuilder: (ctx, idx) {
                final font = fonts[idx];
                final isSelected = widget.card.fontFamily == font;
                return InkWell(
                  onTap: () {
                    widget.onUpdateCard(widget.card.copyWith(fontFamily: font));
                    setState(() => _isFontMenuOpen = false);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: isSelected ? themeAccent.withValues(alpha: 0.15) : Colors.transparent,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          font,
                          style: TextStyle(
                            fontFamily: font,
                            color: isSelected ? themeAccent : textPrimary,
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_rounded, size: 14, color: themeAccent),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: blur > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: content,
            )
          : content,
    );
  }

  // ==========================================
  // Formatação Rica (Negrito, Itálico, Sublinhado, Marca-texto, Cor)
  // ==========================================

  Widget _buildRichFormattingControls() {
    final active = widget.activeStyles;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPillIconButton(
          icon: Icons.format_bold_rounded,
          isActive: active.isBold,
          tooltip: 'Negrito (**texto**)',
          onTap: () => widget.onWrapSelection('**', '**'),
        ),
        _buildPillIconButton(
          icon: Icons.format_italic_rounded,
          isActive: active.isItalic,
          tooltip: 'Itálico (*texto*)',
          onTap: () => widget.onWrapSelection('*', '*'),
        ),
        _buildPillIconButton(
          icon: Icons.format_underlined_rounded,
          isActive: active.isUnderline,
          tooltip: 'Sublinhado (<u>texto</u>)',
          onTap: () => widget.onWrapSelection('<u>', '</u>'),
        ),
        _buildPillIconButton(
          icon: Icons.format_strikethrough_rounded,
          isActive: active.isStrikethrough,
          tooltip: 'Tachado (~~texto~~)',
          onTap: () => widget.onWrapSelection('~~', '~~'),
        ),
        const SizedBox(width: 3),
        _buildPillIconButton(
          icon: Icons.subscript_rounded,
          isActive: active.isSubscript,
          tooltip: 'Subscrito (X₂)',
          onTap: () => widget.onWrapSelection('<sub>', '</sub>'),
        ),
        _buildPillIconButton(
          icon: Icons.superscript_rounded,
          isActive: active.isSuperscript,
          tooltip: 'Sobrescrito (X²)',
          onTap: () => widget.onWrapSelection('<sup>', '</sup>'),
        ),
        _buildPillIconButton(
          icon: Icons.code_rounded,
          isActive: active.isCode,
          tooltip: 'Código Inline (`código`)',
          onTap: () => widget.onWrapSelection('`', '`'),
        ),
        _buildPillIconButton(
          icon: Icons.functions_rounded,
          isActive: active.isLatex,
          tooltip: r'Fórmula Inline ($x$)',
          onTap: () => widget.onWrapSelection(r'$', r'$'),
        ),
        const SizedBox(width: 3),
        _buildPillIconButton(
          icon: Icons.highlight_rounded,
          isActive: _isHighlightMenuOpen || active.highlightColor != null,
          tooltip: 'Cor do Marca-Texto / Destaque',
          onTap: () {
            setState(() {
              _isHighlightMenuOpen = !_isHighlightMenuOpen;
              _isColorPaletteOpen = false;
              _isFontMenuOpen = false;
              _isLatexPaletteOpen = false;
              _isMermaidMenuOpen = false;
              _isCalloutMenuOpen = false;
            });
          },
        ),
        _buildPillIconButton(
          icon: Icons.format_color_text_rounded,
          isActive: _isColorPaletteOpen || active.textColor != null,
          tooltip: 'Cor do Texto',
          onTap: () {
            setState(() {
              _isColorPaletteOpen = !_isColorPaletteOpen;
              _isHighlightMenuOpen = false;
              _isFontMenuOpen = false;
              _isLatexPaletteOpen = false;
              _isMermaidMenuOpen = false;
              _isCalloutMenuOpen = false;
            });
          },
        ),
      ],
    );
  }

  Widget _buildHighlightPalettePopover(
    bool isLight,
    Color glassTint,
    Color themeAccent,
    Color textPrimary,
    double blur,
  ) {
    final highlightColors = [
      {'name': 'Amarelo', 'hex': '#FACC15', 'color': const Color(0xFFFACC15)},
      {'name': 'Ciano', 'hex': '#00E1FF', 'color': const Color(0xFF00E1FF)},
      {'name': 'Verde', 'hex': '#10B981', 'color': const Color(0xFF10B981)},
      {'name': 'Rosa', 'hex': '#FF007A', 'color': const Color(0xFFFF007A)},
      {'name': 'Laranja', 'hex': '#FB923C', 'color': const Color(0xFFFB923C)},
      {'name': 'Roxo', 'hex': '#A855F7', 'color': const Color(0xFFA855F7)},
    ];

    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withValues(alpha: 0.96) : glassTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeAccent.withValues(alpha: 0.5), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              widget.onWrapSelection('==', '==');
              setState(() => _isHighlightMenuOpen = false);
            },
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              child: Text(
                'Padrão',
                style: TextStyle(color: themeAccent, fontSize: 10.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 6),
          ...highlightColors.map((hc) {
            final c = hc['color'] as Color;
            final hex = hc['hex'] as String;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: () {
                  widget.onWrapSelection('<mark style="background: $hex">', '</mark>');
                  setState(() => _isHighlightMenuOpen = false);
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: c.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => setState(() => _isHighlightMenuOpen = false),
            borderRadius: BorderRadius.circular(10),
            child: Icon(Icons.close, size: 14, color: textPrimary.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: blur > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: content,
            )
          : content,
    );
  }

  Widget _buildTextColorPalettePopover(
    bool isLight,
    Color glassTint,
    Color themeAccent,
    Color textPrimary,
    double blur,
  ) {
    final colors = [
      const Color(0xFFFFFFFF),
      const Color(0xFF00E1FF),
      const Color(0xFFA855F7),
      const Color(0xFFFF007A),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF60A5FA),
      const Color(0xFFE2E8F0),
    ];

    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withValues(alpha: 0.96) : glassTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeAccent.withValues(alpha: 0.5), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...colors.map((c) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: () {
                  widget.onApplyTextColor(c);
                  setState(() => _isColorPaletteOpen = false);
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: c.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => setState(() => _isColorPaletteOpen = false),
            borderRadius: BorderRadius.circular(10),
            child: Icon(Icons.close, size: 14, color: textPrimary.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: blur > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: content,
            )
          : content,
    );
  }

  // ==========================================
  // Controles de Tamanho de Fonte
  // ==========================================

  Widget _buildFontSizeControls(Color textPrimary, Color themeAccent, bool isLight) {
    final effectiveSize = _currentEffectiveFontSize;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPillIconButton(
          icon: Icons.remove,
          tooltip: 'Diminuir Fonte',
          onTap: () => _updateFontSize(effectiveSize - 1),
        ),
        GestureDetector(
          onDoubleTap: () {
            setState(() => _isEditingFontSize = true);
            _fontSizeFocusNode.requestFocus();
          },
          child: Container(
            width: 32,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: _isEditingFontSize
                  ? themeAccent.withValues(alpha: 0.15)
                  : (isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.05)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _isEditingFontSize ? themeAccent : (isLight ? Colors.black12 : Colors.white12),
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: _isEditingFontSize
                ? FocusScope(
                    canRequestFocus: true,
                    child: TextField(
                      controller: _fontSizeController,
                      focusNode: _fontSizeFocusNode,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: themeAccent, fontSize: 10.5, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                      onSubmitted: (val) {
                        final parsed = double.tryParse(val.trim());
                        if (parsed != null && parsed > 4 && parsed < 200) {
                          _updateFontSize(parsed);
                        }
                        setState(() => _isEditingFontSize = false);
                      },
                      onTapOutside: (_) {
                        final parsed = double.tryParse(_fontSizeController.text.trim());
                        if (parsed != null && parsed > 4 && parsed < 200) {
                          _updateFontSize(parsed);
                        }
                        setState(() => _isEditingFontSize = false);
                      },
                    ),
                  )
                : Tooltip(
                    message: 'Clique duplo para digitar o tamanho',
                    child: Text(
                      effectiveSize.toStringAsFixed(
                        effectiveSize.truncateToDouble() == effectiveSize ? 0 : 1,
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ),
        _buildPillIconButton(
          icon: Icons.add,
          tooltip: 'Aumentar Fonte',
          onTap: () => _updateFontSize(effectiveSize + 1),
        ),
      ],
    );
  }

  // ==========================================
  // Alinhamento & Listas
  // ==========================================

  Widget _buildAlignmentControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPillIconButton(
          icon: Icons.format_align_left_rounded,
          isActive: widget.card.textAlign == TextAlign.left,
          tooltip: 'Alinhar à Esquerda',
          onTap: () => widget.onUpdateCard(widget.card.copyWith(textAlign: TextAlign.left)),
        ),
        _buildPillIconButton(
          icon: Icons.format_align_center_rounded,
          isActive: widget.card.textAlign == TextAlign.center,
          tooltip: 'Centralizar',
          onTap: () => widget.onUpdateCard(widget.card.copyWith(textAlign: TextAlign.center)),
        ),
        _buildPillIconButton(
          icon: Icons.format_align_right_rounded,
          isActive: widget.card.textAlign == TextAlign.right,
          tooltip: 'Alinhar à Direita',
          onTap: () => widget.onUpdateCard(widget.card.copyWith(textAlign: TextAlign.right)),
        ),
        _buildPillIconButton(
          icon: Icons.format_align_justify_rounded,
          isActive: widget.card.textAlign == TextAlign.justify,
          tooltip: 'Justificar',
          onTap: () => widget.onUpdateCard(widget.card.copyWith(textAlign: TextAlign.justify)),
        ),
      ],
    );
  }

  Widget _buildListControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPillIconButton(
          icon: Icons.format_list_bulleted_rounded,
          tooltip: 'Lista com Marcadores',
          onTap: () => widget.onInsertSnippet('\n- '),
        ),
        _buildPillIconButton(
          icon: Icons.format_list_numbered_rounded,
          tooltip: 'Lista Numerada',
          onTap: () => widget.onInsertSnippet('\n1. '),
        ),
        _buildPillIconButton(
          icon: Icons.check_box_outlined,
          tooltip: 'Checklist / Tarefa',
          onTap: () => widget.onInsertSnippet('\n- [ ] '),
        ),
      ],
    );
  }

  Widget _buildLatexMermaidButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPillButton(
          label: r'f(x) LaTeX',
          icon: Icons.functions_rounded,
          isActive: _isLatexPaletteOpen,
          tooltip: 'Paleta Categorizada de Fórmulas LaTeX',
          onTap: () {
            setState(() {
              _isLatexPaletteOpen = !_isLatexPaletteOpen;
              _isMermaidMenuOpen = false;
              _isFontMenuOpen = false;
              _isColorPaletteOpen = false;
            });
          },
        ),
        const SizedBox(width: 4),
        _buildPillButton(
          label: 'Mermaid',
          icon: Icons.account_tree_rounded,
          isActive: _isMermaidMenuOpen,
          tooltip: 'Templates de Diagramas Mermaid',
          onTap: () {
            setState(() {
              _isMermaidMenuOpen = !_isMermaidMenuOpen;
              _isLatexPaletteOpen = false;
              _isCalloutMenuOpen = false;
              _isFontMenuOpen = false;
              _isColorPaletteOpen = false;
              _isHighlightMenuOpen = false;
            });
          },
        ),
        const SizedBox(width: 4),
        _buildPillButton(
          label: 'Callouts',
          icon: Icons.style_outlined,
          isActive: _isCalloutMenuOpen,
          tooltip: 'Caixas de Destaque STEM (Dica, Teorema, Alerta, Conceito)',
          onTap: () {
            setState(() {
              _isCalloutMenuOpen = !_isCalloutMenuOpen;
              _isLatexPaletteOpen = false;
              _isMermaidMenuOpen = false;
              _isFontMenuOpen = false;
              _isColorPaletteOpen = false;
              _isHighlightMenuOpen = false;
            });
          },
        ),
      ],
    );
  }

  Widget _buildActionControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPillIconButton(
          icon: widget.card.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
          isActive: widget.card.isPinned,
          activeColor: const Color(0xFFFF007A),
          tooltip: widget.card.isPinned ? 'Desafixar Posição' : 'Fixar Posição (Travar)',
          onTap: () => widget.onUpdateCard(widget.card.copyWith(isPinned: !widget.card.isPinned)),
        ),
        _buildPillIconButton(
          icon: Icons.copy_rounded,
          tooltip: 'Duplicar Card',
          onTap: widget.onDuplicateCard,
        ),
        _buildPillIconButton(
          icon: Icons.delete_outline_rounded,
          activeColor: const Color(0xFFFF007A),
          tooltip: 'Excluir Card',
          onTap: widget.onDeleteCard,
        ),
      ],
    );
  }

  Widget _buildDivider(bool isLight) {
    return Container(
      width: 1,
      height: 18,
      color: isLight ? Colors.black12 : Colors.white12,
    );
  }

  Widget _buildPillIconButton({
    required IconData icon,
    bool isActive = false,
    Color? activeColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final themeAccent = activeColor ?? MoscaroTokens.auroraBlue;
    final isLight = MoscaroTokens.isLight;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive
                ? themeAccent.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? themeAccent : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: Icon(
            icon,
            size: 14,
            color: isActive ? themeAccent : (isLight ? Colors.black87 : Colors.white70),
          ),
        ),
      ),
    );
  }

  Widget _buildPillButton({
    required String label,
    required IconData icon,
    bool isActive = false,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final themeAccent = MoscaroTokens.auroraBlue;
    final isLight = MoscaroTokens.isLight;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: isActive
                ? themeAccent.withValues(alpha: 0.2)
                : (isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.06)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? themeAccent : (isLight ? Colors.black12 : Colors.white12),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: isActive ? themeAccent : (isLight ? Colors.black87 : Colors.white70)),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? themeAccent : (isLight ? Colors.black87 : Colors.white70),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMermaidMenu(
    bool isLight,
    Color glassTint,
    Color themeAccent,
    Color textPrimary,
    double blur,
  ) {
    final templates = [
      {
        'title': 'Fluxograma (Flowchart)',
        'snippet': "\n```mermaid\ngraph TD\n    A[Início] --> B{Condição}\n    B -->|Sim| C[Ação 1]\n    B -->|Não| D[Ação 2]\n    C --> E[Fim]\n    D --> E\n```\n",
      },
      {
        'title': 'Diagrama de Sequência',
        'snippet': "\n```mermaid\nsequenceDiagram\n    autonumber\n    Alice->>Bob: Olá Bob\n    Bob-->>Alice: Olá Alice\n```\n",
      },
      {
        'title': 'Diagrama de Classes',
        'snippet': "\n```mermaid\nclassDiagram\n    class Animal {\n        +String nome\n        +mover()\n    }\n```\n",
      },
      {
        'title': 'Diagrama de Estados',
        'snippet': "\n```mermaid\nstateDiagram-v2\n    [*] --> Parado\n    Parado --> Movimento: Acelerar\n    Movimento --> Parado: Frear\n```\n",
      },
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: blur > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: Container(
                width: 260,
                decoration: BoxDecoration(
                  color: isLight ? Colors.white.withValues(alpha: 0.94) : glassTint,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: themeAccent.withValues(alpha: 0.5), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Inserir Diagrama Mermaid',
                            style: TextStyle(color: textPrimary, fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 14, color: textPrimary.withValues(alpha: 0.7)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                            onPressed: () => setState(() => _isMermaidMenuOpen = false),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: isLight ? Colors.black12 : Colors.white12),
                    for (final t in templates)
                      InkWell(
                        onTap: () {
                          widget.onInsertSnippet(t['snippet']!);
                          setState(() => _isMermaidMenuOpen = false);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text(
                            t['title']!,
                            style: TextStyle(color: textPrimary, fontSize: 11.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            )
          : Container(
              width: 260,
              decoration: BoxDecoration(
                color: isLight ? Colors.white.withValues(alpha: 0.94) : glassTint,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: themeAccent.withValues(alpha: 0.5), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Inserir Diagrama Mermaid',
                          style: TextStyle(color: textPrimary, fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 14, color: textPrimary.withValues(alpha: 0.7)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                          onPressed: () => setState(() => _isMermaidMenuOpen = false),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: isLight ? Colors.black12 : Colors.white12),
                  for (final t in templates)
                    InkWell(
                      onTap: () {
                        widget.onInsertSnippet(t['snippet']!);
                        setState(() => _isMermaidMenuOpen = false);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(
                          t['title']!,
                          style: TextStyle(color: textPrimary, fontSize: 11.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildCalloutMenu(
    bool isLight,
    Color glassTint,
    Color themeAccent,
    Color textPrimary,
    double blur,
  ) {
    final callouts = [
      {
        'title': 'Dica / Insight STEM',
        'subtitle': 'Caixa ciano com ícone de lâmpada',
        'icon': Icons.lightbulb_outline_rounded,
        'color': MoscaroTokens.calloutTipColor,
        'snippet': "\n> [!TIP]\n> Insira a dica ou insight STEM aqui.\n",
      },
      {
        'title': 'Teorema / Fórmula-Chave',
        'subtitle': 'Caixa púrpura para matemática e física',
        'icon': Icons.functions_rounded,
        'color': MoscaroTokens.calloutTheoremColor,
        'snippet': "\n> [!THEOREM]\n> Para todo triângulo retângulo: \$a^2 + b^2 = c^2\$.\n",
      },
      {
        'title': 'Atenção / Ponto Crítico',
        'subtitle': 'Caixa âmbar de aviso e cuidados',
        'icon': Icons.warning_amber_rounded,
        'color': MoscaroTokens.calloutWarningColor,
        'snippet': "\n> [!WARNING]\n> Cuidado com condições de contorno e singularidades.\n",
      },
      {
        'title': 'Definição / Conceito',
        'subtitle': 'Caixa verde de conceito fundamental',
        'icon': Icons.menu_book_rounded,
        'color': MoscaroTokens.calloutConceptColor,
        'snippet': "\n> [!CONCEPT]\n> Definição formal do conceito científico.\n",
      },
    ];

    Widget content = Container(
      width: 250,
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withValues(alpha: 0.94) : glassTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: themeAccent.withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Callouts & Caixas STEM',
                  style: TextStyle(color: textPrimary, fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 14, color: textPrimary.withValues(alpha: 0.7)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  onPressed: () => setState(() => _isCalloutMenuOpen = false),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isLight ? Colors.black12 : Colors.white12),
          for (final c in callouts)
            InkWell(
              onTap: () {
                widget.onInsertSnippet(c['snippet'] as String);
                setState(() => _isCalloutMenuOpen = false);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(c['icon'] as IconData, size: 16, color: c['color'] as Color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c['title'] as String,
                            style: TextStyle(color: textPrimary, fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            c['subtitle'] as String,
                            style: TextStyle(color: textPrimary.withValues(alpha: 0.6), fontSize: 9.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: blur > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: content,
            )
          : content,
    );
  }
}
