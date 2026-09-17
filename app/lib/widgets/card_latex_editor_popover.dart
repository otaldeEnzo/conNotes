import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import '../theme/moscaro_theme_controller.dart';
import '../models/canvas_card_model.dart';
import '../models/latex_symbols_catalog.dart';
import 'card_format_floating_pill.dart';
import 'latex_symbols_drawer.dart';
import 'svg_icon.dart';

/// Popover de Edição e Inserção de Fórmulas LaTeX com Preview em Tempo Real.
/// Segue estritamente as diretrizes do Design System Moscaro v2:
/// Glassmorphism líquido, blur suave, bordas glow ciano e ícones vetoriais SVG (zero emojis).
class CardLatexEditorPopover extends StatefulWidget {
  final String initialLatex;
  final ValueChanged<String> onApply;
  final VoidCallback onClose;
  final double maxWidth;
  final bool defaultBlockMode;

  const CardLatexEditorPopover({
    super.key,
    this.initialLatex = '',
    required this.onApply,
    required this.onClose,
    this.maxWidth = 460.0,
    this.defaultBlockMode = false,
  });

  static String stripDelimiters(String raw) {
    var s = raw.trim();
    if (s.startsWith(r'$$') && s.endsWith(r'$$') && s.length >= 4) {
      s = s.substring(2, s.length - 2).trim();
    } else if (s.startsWith(r'$') && s.endsWith(r'$') && s.length >= 2) {
      s = s.substring(1, s.length - 1).trim();
    }
    return s;
  }

  @override
  State<CardLatexEditorPopover> createState() => _CardLatexEditorPopoverState();
}

class _CardLatexEditorPopoverState extends State<CardLatexEditorPopover> {
  late final TextEditingController _textController;
  late final TextEditingController _searchController;
  late final FocusNode _focusNode;
  late bool _isBlockMode;
  String _currentText = '';
  String _searchQuery = '';
  bool _isDrawerOpen = false;

  @override
  void initState() {
    super.initState();
    final trimmed = widget.initialLatex.trim();
    _isBlockMode = trimmed.startsWith(r'$$') || widget.defaultBlockMode;
    final stripped = CardLatexEditorPopover.stripDelimiters(widget.initialLatex);
    _textController = TextEditingController(text: stripped);
    _currentText = stripped;
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    _focusNode = FocusNode(debugLabel: 'TextField_LatexEditor');
    _focusNode.addListener(() {
      globalIsEditingText = _focusNode.hasFocus;
    });
    globalIsEditingText = true;

    _textController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    globalIsHoveringFloatingPill = false;
    globalIsEditingText = false;
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchQuery != _searchController.text) {
      setState(() {
        _searchQuery = _searchController.text;
      });
    }
  }

  void _onTextChanged() {
    if (_currentText != _textController.text) {
      setState(() {
        _currentText = _textController.text;
      });
    }
  }


  void _insertSymbol(LatexSymbolItem item) {
    final text = _textController.text;
    final sel = _textController.selection;
    final start = (sel.isValid && sel.start >= 0) ? sel.start : text.length;
    final end = (sel.isValid && sel.end >= 0) ? sel.end : text.length;

    final String replacement;
    int newCursorOffset;

    if (sel.isValid && start < end && item.hasSelectionPlaceholder) {
      final selectedText = text.substring(start, end);
      replacement = item.template.replaceAll('#SEL#', selectedText);
      newCursorOffset = start + replacement.length;
    } else {
      replacement = item.template.replaceAll('#SEL#', 'x');
      newCursorOffset = start + item.cursorOffset;
      if (newCursorOffset > start + replacement.length) {
        newCursorOffset = start + replacement.length;
      }
    }

    final newText = text.replaceRange(start, end, replacement);
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorOffset),
    );
    _focusNode.requestFocus();
  }

  void _handleConfirm() {
    final trimmed = _textController.text.trim();
    if (trimmed.isEmpty) {
      widget.onClose();
      return;
    }

    final inner = CardLatexEditorPopover.stripDelimiters(trimmed);
    final String formatted;
    if (_isBlockMode) {
      formatted = '\$\$\n$inner\n\$\$';
    } else {
      formatted = '\$$inner\$';
    }

    widget.onApply(formatted);
    widget.onClose();
  }

  String _cleanMathForPreview(String raw) {
    return raw
        .replaceAll(r'\begin{gathered}', r'\begin{aligned}')
        .replaceAll(r'\end{gathered}', r'\end{aligned}');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MoscaroThemeController.instance,
      builder: (context, _) {
        final isLight = MoscaroTokens.isLight;
        final textPrimary = MoscaroTokens.textPrimary;
        final themeAccent = MoscaroTokens.auroraBlue;
        final glassTint = MoscaroTokens.glassTint;
        final blur = (MoscaroTokens.enableSubBarsBlur && MoscaroTokens.blurSigma > 0)
            ? MoscaroTokens.blurSigma
            : 0.0;

        final trimmed = _currentText.trim();
        final strippedForPreview = CardLatexEditorPopover.stripDelimiters(trimmed);

        final effectiveWidth = _isDrawerOpen
            ? (widget.maxWidth < 480.0 ? 480.0 : widget.maxWidth)
            : widget.maxWidth;

        final popoverBody = Container(
          width: effectiveWidth,
          constraints: BoxConstraints(maxHeight: _isDrawerOpen ? 660 : 520),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Cabeçalho com Título, Toggle Inline/Bloco e Fechar
              Row(
                children: [
                  SvgIcon(name: 'math', size: 16, color: themeAccent),
                  const SizedBox(width: 8),
                  Text(
                    'Editor LaTeX',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  // Toggle Inline vs Bloco
                  Container(
                    height: 26,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
                      border: Border.all(
                        color: isLight ? MoscaroTokens.borderSubtle : MoscaroTokens.borderGlow,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildModeTab(
                          label: 'Inline (\$)',
                          isSelected: !_isBlockMode,
                          themeAccent: themeAccent,
                          textPrimary: textPrimary,
                          isLight: isLight,
                          onTap: () => setState(() => _isBlockMode = false),
                        ),
                        _buildModeTab(
                          label: 'Bloco (\$\$)',
                          isSelected: _isBlockMode,
                          themeAccent: themeAccent,
                          textPrimary: textPrimary,
                          isLight: isLight,
                          onTap: () => setState(() => _isBlockMode = true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: SvgIcon(
                        name: 'close',
                        size: 14,
                        color: textPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. Botão de Catálogo Completo + Barra de Busca com Sugestões Dinâmicas
              Row(
                children: [
                  // Botão Catálogo Completo / Gaveta
                  InkWell(
                    onTap: () => setState(() => _isDrawerOpen = !_isDrawerOpen),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: _isDrawerOpen
                            ? themeAccent.withValues(alpha: isLight ? 0.2 : 0.25)
                            : (isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.06)),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _isDrawerOpen
                              ? themeAccent.withValues(alpha: 0.8)
                              : (isLight ? MoscaroTokens.borderSubtle : MoscaroTokens.borderGlow),
                          width: _isDrawerOpen ? 1.0 : 0.7,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgIcon(
                            name: 'search',
                            size: 13,
                            color: _isDrawerOpen ? themeAccent : textPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Catálogo',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _isDrawerOpen ? themeAccent : textPrimary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          SvgIcon(
                            name: _isDrawerOpen ? 'chevron_up' : 'chevron_down',
                            size: 12,
                            color: _isDrawerOpen ? themeAccent : textPrimary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Barra de Pesquisa Semelhante à do Catálogo (substitui os botões anteriores)
                  Expanded(
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: isLight
                            ? Colors.black.withValues(alpha: 0.04)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _searchQuery.isNotEmpty
                              ? themeAccent.withValues(alpha: 0.8)
                              : (isLight ? MoscaroTokens.borderSubtle : MoscaroTokens.borderGlow.withValues(alpha: 0.3)),
                          width: _searchQuery.isNotEmpty ? 1.0 : 0.8,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 11.5,
                        ),
                        cursorColor: themeAccent,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 7,
                          ),
                          border: InputBorder.none,
                          hintText: 'Buscar símbolo ou fórmula...',
                          hintStyle: TextStyle(
                            color: textPrimary.withValues(alpha: 0.45),
                            fontSize: 11.5,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
                            child: SvgIcon(
                              name: 'search',
                              size: 13,
                              color: _searchQuery.isNotEmpty ? themeAccent : textPrimary.withValues(alpha: 0.5),
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 26,
                            minHeight: 16,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? InkWell(
                                  onTap: () {
                                    _searchController.clear();
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: SvgIcon(
                                      name: 'close',
                                      size: 12,
                                      color: textPrimary.withValues(alpha: 0.6),
                                    ),
                                  ),
                                )
                              : null,
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Animação de Abertura do Catálogo / Sugestões Dinâmicas no padrão do programa
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: _isDrawerOpen
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: LatexSymbolsDrawer(
                          maxHeight: 220,
                          searchQuery: _searchQuery,
                          showHeaderSearch: false,
                          onClose: () => setState(() => _isDrawerOpen = false),
                          onSelectSymbol: (item) {
                            _insertSymbol(item);
                          },
                        ),
                      )
                    : (_searchQuery.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _buildSuggestionsRibbon(
                              searchLatexSymbols(query: _searchQuery),
                              themeAccent,
                              textPrimary,
                              isLight,
                            ),
                          )
                        : const SizedBox.shrink()),
              ),
              const SizedBox(height: 10),

              // 3. Campo de Entrada do Código LaTeX
              Container(
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.white.withValues(alpha: 0.8)
                      : Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _focusNode.hasFocus
                        ? themeAccent.withValues(alpha: 0.8)
                        : (isLight ? MoscaroTokens.borderSubtle : MoscaroTokens.borderGlow),
                    width: _focusNode.hasFocus ? 1.2 : 0.8,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  autofocus: true,
                  canRequestFocus: true,
                  keyboardType: TextInputType.multiline,
                  maxLines: 4,
                  minLines: 2,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: textPrimary,
                    height: 1.35,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    hintText: _isBlockMode
                        ? r'Ex: \int_{0}^{\infty} e^{-x^2} dx = \frac{\sqrt{\pi}}{2}'
                        : r'Ex: f(x) = \sqrt{x^2 + 1}',
                    hintStyle: TextStyle(
                      fontFamily: 'monospace',
                      color: textPrimary.withValues(alpha: 0.35),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 4. Área de Preview em Tempo Real KaTeX
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.03)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: themeAccent.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: themeAccent,
                            boxShadow: [
                              BoxShadow(
                                color: themeAccent.withValues(alpha: 0.6),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'PREVIEW EM TEMPO REAL',
                          style: TextStyle(
                            color: textPrimary.withValues(alpha: 0.5),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(minHeight: 48, maxHeight: 90),
                      alignment: Alignment.center,
                      child: strippedForPreview.isEmpty
                          ? Text(
                              'Digite a fórmula acima para pré-visualizar a renderização...',
                              style: TextStyle(
                                color: textPrimary.withValues(alpha: 0.38),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Math.tex(
                                _cleanMathForPreview(strippedForPreview),
                                mathStyle: _isBlockMode ? MathStyle.display : MathStyle.text,
                                textStyle: TextStyle(
                                  color: textPrimary,
                                  fontSize: _isBlockMode ? 16 : 14.5,
                                ),
                                onErrorFallback: (err) {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SvgIcon(
                                        name: 'code',
                                        size: 13,
                                        color: Color(0xFFFF007A),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Sintaxe KaTeX incompleta ou inválida',
                                        style: TextStyle(
                                          color: const Color(0xFFFF007A).withValues(alpha: 0.9),
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 5. Barra de Ações: Limpar, Cancelar e Inserir / Concluir
              Row(
                children: [
                  if (_currentText.isNotEmpty)
                    InkWell(
                      onTap: () {
                        _textController.clear();
                        _focusNode.requestFocus();
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgIcon(
                              name: 'trash',
                              size: 13,
                              color: textPrimary.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Limpar',
                              style: TextStyle(
                                color: textPrimary.withValues(alpha: 0.6),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Spacer(),
                  // Botão Cancelar
                  InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isLight
                            ? Colors.black.withValues(alpha: 0.05)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isLight ? MoscaroTokens.borderSubtle : MoscaroTokens.borderGlow,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: textPrimary.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botão Inserir / Concluir
                  InkWell(
                    onTap: _handleConfirm,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: themeAccent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: themeAccent.withValues(alpha: 0.45),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgIcon(
                            name: 'check',
                            size: 13,
                            color: Colors.black,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Inserir',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
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
        ).moscaroV2(
          borderRadius: 16,
          blurSigma: blur,
          enableBlur: blur > 0,
          backgroundColor: isLight
              ? const Color(0xFFF8FAFC).withValues(alpha: 0.95)
              : glassTint,
          borderColor: isLight ? MoscaroTokens.borderSubtle : themeAccent.withValues(alpha: 0.4),
          borderWidth: 1.0,
          padding: EdgeInsets.zero,
          customShadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        );

        return MouseRegion(
          onEnter: (_) => globalIsHoveringFloatingPill = true,
          onHover: (_) => globalIsHoveringFloatingPill = true,
          onExit: (_) => globalIsHoveringFloatingPill = false,
          child: popoverBody,
        );
      },
    );
  }

  Widget _buildSuggestionsRibbon(
    List<LatexSymbolItem> items,
    Color themeAccent,
    Color textPrimary,
    bool isLight,
  ) {
    if (items.isEmpty) {
      return Container(
        height: 32,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isLight ? MoscaroTokens.borderSubtle : MoscaroTokens.borderGlow.withValues(alpha: 0.2),
            width: 0.7,
          ),
        ),
        child: Text(
          'Nenhum símbolo encontrado para "$_searchQuery"',
          style: TextStyle(
            fontSize: 11,
            color: textPrimary.withValues(alpha: 0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return SizedBox(
      height: 34,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 5),
              itemBuilder: (context, idx) {
                final item = items[idx];
                return _buildCatalogSymbolChip(
                  item,
                  themeAccent,
                  textPrimary,
                  isLight,
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => setState(() => _isDrawerOpen = true),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: themeAccent.withValues(alpha: isLight ? 0.12 : 0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: themeAccent.withValues(alpha: 0.5),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ver todos (${items.length})',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: themeAccent,
                    ),
                  ),
                  const SizedBox(width: 3),
                  SvgIcon(
                    name: 'chevron_down',
                    size: 11,
                    color: themeAccent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required bool isSelected,
    required Color themeAccent,
    required Color textPrimary,
    required bool isLight,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? themeAccent.withValues(alpha: isLight ? 0.2 : 0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
          border: isSelected
              ? Border.all(color: themeAccent.withValues(alpha: 0.5), width: 0.8)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? themeAccent : textPrimary.withValues(alpha: 0.6),
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogSymbolChip(
    LatexSymbolItem item,
    Color themeAccent,
    Color textPrimary,
    bool isLight,
  ) {
    return _CatalogSymbolChipHover(
      item: item,
      themeAccent: themeAccent,
      textPrimary: textPrimary,
      isLight: isLight,
      onTap: () => _insertSymbol(item),
    );
  }
}

class _CatalogSymbolChipHover extends StatefulWidget {
  final LatexSymbolItem item;
  final Color themeAccent;
  final Color textPrimary;
  final bool isLight;
  final VoidCallback onTap;

  const _CatalogSymbolChipHover({
    required this.item,
    required this.themeAccent,
    required this.textPrimary,
    required this.isLight,
    required this.onTap,
  });

  @override
  State<_CatalogSymbolChipHover> createState() => _CatalogSymbolChipHoverState();
}

class _CatalogSymbolChipHoverState extends State<_CatalogSymbolChipHover> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${widget.item.label}\n${widget.item.latex}',
      waitDuration: const Duration(milliseconds: 300),
      textStyle: const TextStyle(fontSize: 11, color: Colors.white),
      decoration: BoxDecoration(
        color: const Color(0xE6151722),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.themeAccent.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _isHovered
                  ? widget.themeAccent.withValues(alpha: widget.isLight ? 0.14 : 0.20)
                  : (widget.isLight
                      ? Colors.black.withValues(alpha: 0.04)
                      : Colors.white.withValues(alpha: 0.05)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _isHovered
                    ? widget.themeAccent
                    : (widget.isLight ? MoscaroTokens.borderSubtle : MoscaroTokens.borderGlow),
                width: _isHovered ? 1.1 : 0.7,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: widget.themeAccent.withValues(alpha: 0.3),
                        blurRadius: 6,
                        spreadRadius: 0.5,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Math.tex(
              widget.item.latex,
              mathStyle: MathStyle.text,
              textStyle: TextStyle(
                fontSize: 11.5,
                color: widget.isLight
                    ? (_isHovered ? Colors.black : widget.textPrimary)
                    : (_isHovered ? Colors.white : widget.textPrimary),
                fontWeight: _isHovered ? FontWeight.w600 : FontWeight.normal,
              ),
              onErrorFallback: (_) => Text(
                widget.item.label,
                style: TextStyle(
                  fontSize: 10,
                  color: widget.isLight
                      ? (_isHovered ? Colors.black : widget.textPrimary)
                      : (_isHovered ? Colors.white : widget.textPrimary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
