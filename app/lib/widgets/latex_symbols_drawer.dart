import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../models/latex_symbols_catalog.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_theme_controller.dart';
import 'svg_icon.dart';

/// Gaveta expansível de símbolos e fórmulas STEM LaTeX completas.
/// Apresenta busca em tempo real, abas por categoria e renderização KaTeX de alta precisão.
/// Segue os padrões visuais Moscaro v2 (Glassmorphism, bordas sutis glow do tema ativo, zero emojis).
class LatexSymbolsDrawer extends StatefulWidget {
  final ValueChanged<LatexSymbolItem> onSelectSymbol;
  final VoidCallback? onClose;
  final double maxHeight;
  final String? searchQuery;
  final bool showHeaderSearch;

  const LatexSymbolsDrawer({
    super.key,
    required this.onSelectSymbol,
    this.onClose,
    this.maxHeight = 280.0,
    this.searchQuery,
    this.showHeaderSearch = true,
  });

  @override
  State<LatexSymbolsDrawer> createState() => _LatexSymbolsDrawerState();
}

class _LatexSymbolsDrawerState extends State<LatexSymbolsDrawer> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _categoryScrollController = ScrollController();
  LatexSymbolCategory? _selectedCategory;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.searchQuery != null) {
      _searchQuery = widget.searchQuery!;
      _searchController.text = widget.searchQuery!;
    }
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(LatexSymbolsDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != null && widget.searchQuery != _searchQuery) {
      setState(() {
        _searchQuery = widget.searchQuery!;
        _searchController.text = widget.searchQuery!;
      });
    }
  }

  @override
  void dispose() {
    _categoryScrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchQuery != _searchController.text) {
      setState(() {
        _searchQuery = _searchController.text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MoscaroThemeController.instance,
      builder: (context, _) {
        final isLight = MoscaroTokens.isLight;
        final textPrimary = MoscaroTokens.textPrimary;
        final textSecondary = MoscaroTokens.textSecondary;
        final theme = MoscaroThemeController.instance.currentTheme;
        final themeAccent = theme.accentPrimary;
        final glassTint = isLight ? const Color(0xFFF8FAFC).withValues(alpha: 0.95) : MoscaroTokens.glassTint;

        final results = searchLatexSymbols(
          query: _searchQuery,
          category: _selectedCategory,
        );

        return Container(
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          decoration: BoxDecoration(
            color: isLight
                ? const Color(0xF2F6F8FB)
                : glassTint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isLight
                  ? MoscaroTokens.borderSubtle
                  : themeAccent.withValues(alpha: 0.35),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: themeAccent.withValues(alpha: isLight ? 0.05 : 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Barra de Busca e Fechar (se fornecido)
              if (widget.showHeaderSearch)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: isLight
                                ? Colors.black.withValues(alpha: 0.04)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isLight
                                  ? MoscaroTokens.borderSubtle
                                  : MoscaroTokens.borderGlow.withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 12,
                            ),
                            cursorColor: themeAccent,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 7,
                              ),
                              border: InputBorder.none,
                              hintText: 'Buscar símbolo ou fórmula (ex: integral, matriz, alfa)...',
                              hintStyle: TextStyle(
                                color: textSecondary.withValues(alpha: 0.6),
                                fontSize: 11.5,
                              ),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                child: SvgIcon(
                                  name: 'search',
                                  size: 14,
                                  color: textSecondary,
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 16,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? InkWell(
                                      onTap: () {
                                        _searchController.clear();
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(7),
                                        child: SvgIcon(
                                          name: 'close',
                                          size: 13,
                                          color: textSecondary,
                                        ),
                                      ),
                                    )
                                  : null,
                              suffixIconConstraints: const BoxConstraints(
                                minWidth: 26,
                                minHeight: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.onClose != null) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: widget.onClose,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: SvgIcon(
                              name: 'close',
                              size: 14,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else if (widget.onClose != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: widget.onClose,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: SvgIcon(
                            name: 'close',
                            size: 14,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 8),

              // 2. Abas de Categorias (Pills Horizontais com scroll via roda do mouse)
              SizedBox(
                height: 30,
                child: Listener(
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent && _categoryScrollController.hasClients) {
                      GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
                        if (resolved is PointerScrollEvent && _categoryScrollController.hasClients) {
                          final delta = resolved.scrollDelta.dy != 0 ? resolved.scrollDelta.dy : resolved.scrollDelta.dx;
                          final target = (_categoryScrollController.offset + delta).clamp(
                            0.0,
                            _categoryScrollController.position.maxScrollExtent,
                          );
                          _categoryScrollController.jumpTo(target);
                        }
                      });
                    }
                  },
                  child: ListView(
                    controller: _categoryScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    children: [
                      _buildCategoryPill(
                        label: 'Todos (${kLatexCatalog.length})',
                        isSelected: _selectedCategory == null,
                        isLight: isLight,
                        themeAccent: themeAccent,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        onTap: () => setState(() => _selectedCategory = null),
                      ),
                      const SizedBox(width: 4),
                      ...LatexSymbolCategory.values.map((cat) {
                        final count = kLatexCatalog.where((i) => i.category == cat).length;
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: _buildCategoryPill(
                            label: '${cat.label} ($count)',
                            isSelected: _selectedCategory == cat,
                            isLight: isLight,
                            themeAccent: themeAccent,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            onTap: () => setState(() => _selectedCategory = cat),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // 3. Grid de Símbolos / Fórmulas
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgIcon(
                                name: 'search',
                                size: 22,
                                color: textSecondary.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Nenhum símbolo encontrado para "$_searchQuery"',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Scrollbar(
                        thumbVisibility: true,
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 76,
                            mainAxisExtent: 52,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final item = results[index];
                            return _buildSymbolCard(
                              item: item,
                              isLight: isLight,
                              themeAccent: themeAccent,
                              textPrimary: textPrimary,
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryPill({
    required String label,
    required bool isSelected,
    required bool isLight,
    required Color themeAccent,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? themeAccent.withValues(alpha: isLight ? 0.16 : 0.22)
              : (isLight
                  ? Colors.black.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
          border: Border.all(
            color: isSelected
                ? themeAccent.withValues(alpha: 0.8)
                : (isLight ? MoscaroTokens.borderSubtle : MoscaroTokens.borderGlow.withValues(alpha: 0.2)),
            width: isSelected ? 1.0 : 0.6,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? themeAccent : textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSymbolCard({
    required LatexSymbolItem item,
    required bool isLight,
    required Color themeAccent,
    required Color textPrimary,
  }) {
    return _SymbolCardHover(
      item: item,
      isLight: isLight,
      themeAccent: themeAccent,
      textPrimary: textPrimary,
      onTap: () => widget.onSelectSymbol(item),
    );
  }
}

class _SymbolCardHover extends StatefulWidget {
  final LatexSymbolItem item;
  final bool isLight;
  final Color themeAccent;
  final Color textPrimary;
  final VoidCallback onTap;

  const _SymbolCardHover({
    required this.item,
    required this.isLight,
    required this.themeAccent,
    required this.textPrimary,
    required this.onTap,
  });

  @override
  State<_SymbolCardHover> createState() => _SymbolCardHoverState();
}

class _SymbolCardHoverState extends State<_SymbolCardHover> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${widget.item.label}\n${widget.item.latex}',
      waitDuration: const Duration(milliseconds: 350),
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
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: _isHovered
                  ? widget.themeAccent.withValues(alpha: widget.isLight ? 0.12 : 0.18)
                  : (widget.isLight
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.04)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isHovered
                    ? widget.themeAccent
                    : (widget.isLight
                        ? MoscaroTokens.borderSubtle
                        : MoscaroTokens.borderGlow.withValues(alpha: 0.2)),
                width: _isHovered ? 1.2 : 0.8,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: widget.themeAccent.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Math.tex(
                  widget.item.latex,
                  textStyle: TextStyle(
                    fontSize: 13,
                    color: widget.isLight
                        ? (_isHovered ? Colors.black : widget.textPrimary)
                        : (_isHovered ? Colors.white : widget.textPrimary),
                    fontWeight: _isHovered ? FontWeight.w600 : FontWeight.normal,
                  ),
                  onErrorFallback: (err) => Text(
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
        ),
      ),
    );
  }
}
