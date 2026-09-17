import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import '../theme/moscaro_theme_controller.dart';
import 'svg_icon.dart';

enum StemHubTab {
  latex,
  mermaid,
  callouts,
}

/// Popover Unificado de Inserção STEM (LaTeX, Mermaid, Callouts).
/// Segue rigorosamente a estética Moscaro v2 e o tema ativo.
class StemInsertHubPopover extends StatefulWidget {
  final ValueChanged<String> onInsertSnippet;
  final VoidCallback onClose;
  final double maxWidth;

  const StemInsertHubPopover({
    super.key,
    required this.onInsertSnippet,
    required this.onClose,
    this.maxWidth = 420.0,
  });

  @override
  State<StemInsertHubPopover> createState() => _StemInsertHubPopoverState();
}

class _StemInsertHubPopoverState extends State<StemInsertHubPopover> {
  StemHubTab _activeTab = StemHubTab.latex;
  int _latexCategoryIndex = 0;

  // Categorias de LaTeX
  static const List<String> _latexCategories = [
    'Básico',
    'Álgebra',
    'Cálculo',
    'Grego',
    'Matrizes',
  ];

  static const Map<String, List<Map<String, String>>> _latexItems = {
    'Básico': [
      {'label': 'Fração', 'math': r'\frac{a}{b}', 'snippet': r'\frac{a}{b}'},
      {'label': 'Potência', 'math': 'x^n', 'snippet': 'x^{n}'},
      {'label': 'Índice', 'math': 'x_i', 'snippet': 'x_{i}'},
      {'label': 'Raiz Quadrada', 'math': r'\sqrt{x}', 'snippet': r'\sqrt{x}'},
      {'label': 'Raiz n-ésima', 'math': r'\sqrt[n]{x}', 'snippet': r'\sqrt[n]{x}'},
      {'label': 'Mais ou Menos', 'math': r'\pm', 'snippet': r'\pm '},
      {'label': 'Multiplicação', 'math': r'\times', 'snippet': r'\times '},
      {'label': 'Divisão', 'math': r'\div', 'snippet': r'\div '},
      {'label': 'Diferente', 'math': r'\neq', 'snippet': r'\neq '},
      {'label': 'Aproximado', 'math': r'\approx', 'snippet': r'\approx '},
      {'label': 'Menor ou Igual', 'math': r'\le', 'snippet': r'\le '},
      {'label': 'Maior ou Igual', 'math': r'\ge', 'snippet': r'\ge '},
    ],
    'Álgebra': [
      {'label': 'Equação 2º Grau', 'math': r'x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}', 'snippet': r'x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}'},
      {'label': 'Somatório', 'math': r'\sum_{i=1}^{n} x_i', 'snippet': r'\sum_{i=1}^{n} x_i'},
      {'label': 'Produtório', 'math': r'\prod_{i=1}^{n} x_i', 'snippet': r'\prod_{i=1}^{n} x_i'},
      {'label': 'Pertence', 'math': r'\in', 'snippet': r'\in '},
      {'label': 'Não Pertence', 'math': r'\notin', 'snippet': r'\notin '},
      {'label': 'Contido', 'math': r'\subset', 'snippet': r'\subset '},
      {'label': 'Para Todo', 'math': r'\forall', 'snippet': r'\forall '},
      {'label': 'Existe', 'math': r'\exists', 'snippet': r'\exists '},
      {'label': 'Infinito', 'math': r'\infty', 'snippet': r'\infty '},
    ],
    'Cálculo': [
      {'label': 'Derivada', 'math': r'\frac{df}{dx}', 'snippet': r'\frac{df}{dx}'},
      {'label': 'Derivada Parcial', 'math': r'\frac{\partial f}{\partial x}', 'snippet': r'\frac{\partial f}{\partial x}'},
      {'label': 'Integral Indefinida', 'math': r'\int f(x)\,dx', 'snippet': r'\int f(x)\,dx'},
      {'label': 'Integral Definida', 'math': r'\int_{a}^{b} f(x)\,dx', 'snippet': r'\int_{a}^{b} f(x)\,dx'},
      {'label': 'Integral Dupla', 'math': r'\iint_D f(x,y)\,dA', 'snippet': r'\iint_D f(x,y)\,dA'},
      {'label': 'Limite', 'math': r'\lim_{x \to 0} f(x)', 'snippet': r'\lim_{x \to 0} f(x)'},
      {'label': 'Nabla / Gradiente', 'math': r'\nabla f', 'snippet': r'\nabla f'},
    ],
    'Grego': [
      {'label': 'Alpha', 'math': r'\alpha', 'snippet': r'\alpha '},
      {'label': 'Beta', 'math': r'\beta', 'snippet': r'\beta '},
      {'label': 'Gamma', 'math': r'\gamma', 'snippet': r'\gamma '},
      {'label': 'Delta', 'math': r'\delta', 'snippet': r'\delta '},
      {'label': 'Delta Maiúsculo', 'math': r'\Delta', 'snippet': r'\Delta '},
      {'label': 'Theta', 'math': r'\theta', 'snippet': r'\theta '},
      {'label': 'Lambda', 'math': r'\lambda', 'snippet': r'\lambda '},
      {'label': 'Mu', 'math': r'\mu', 'snippet': r'\mu '},
      {'label': 'Pi', 'math': r'\pi', 'snippet': r'\pi '},
      {'label': 'Sigma', 'math': r'\sigma', 'snippet': r'\sigma '},
      {'label': 'Omega', 'math': r'\omega', 'snippet': r'\omega '},
    ],
    'Matrizes': [
      {'label': 'Matriz 2x2', 'math': r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}', 'snippet': "\\begin{pmatrix}\n a & b \\\\\n c & d\n\\end{pmatrix}"},
      {'label': 'Vetor Coluna', 'math': r'\begin{bmatrix} x \\ y \end{bmatrix}', 'snippet': "\\begin{bmatrix}\n x \\\\\n y\n\\end{bmatrix}"},
      {'label': 'Determinante', 'math': r'\begin{vmatrix} a & b \\ c & d \end{vmatrix}', 'snippet': "\\begin{vmatrix}\n a & b \\\\\n c & d\n\\end{vmatrix}"},
      {'label': 'Sistema Linear', 'math': r'\begin{cases} x + y = 1 \\ x - y = 0 \end{cases}', 'snippet': "\\begin{cases}\n x + y = 1 \\\\\n x - y = 0\n\\end{cases}"},
    ],
  };

  @override
  Widget build(BuildContext context) {
    final activeTheme = MoscaroThemeController.instance.currentTheme;
    final isLight = MoscaroTokens.isLight;
    final textPrimary = MoscaroTokens.textPrimary;
    final themeAccent = MoscaroTokens.auroraBlue;
    final glassTint = MoscaroTokens.glassTint;
    final blur = (MoscaroTokens.enableSubBarsBlur && MoscaroTokens.blurSigma > 0)
        ? MoscaroTokens.blurSigma
        : 0.0;

    return Container(
      width: widget.maxWidth,
      constraints: const BoxConstraints(maxHeight: 380),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho com Abas e Botão Fechar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                SvgIcon(name: 'circuit', size: 16, color: themeAccent),
                const SizedBox(width: 8),
                Text(
                  'STEM Hub',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 14),
                // Tab Selector
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTabButton(
                        tab: StemHubTab.latex,
                        label: 'LaTeX',
                        iconName: 'math',
                        themeAccent: themeAccent,
                        textPrimary: textPrimary,
                      ),
                      const SizedBox(width: 4),
                      _buildTabButton(
                        tab: StemHubTab.mermaid,
                        label: 'Mermaid',
                        iconName: 'code',
                        themeAccent: themeAccent,
                        textPrimary: textPrimary,
                      ),
                      const SizedBox(width: 4),
                      _buildTabButton(
                        tab: StemHubTab.callouts,
                        label: 'Callouts',
                        iconName: 'tag',
                        themeAccent: themeAccent,
                        textPrimary: textPrimary,
                      ),
                    ],
                  ),
                ),
                // Botão Fechar X
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
          ),
          Divider(
            height: 1,
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.08),
          ),
          // Conteúdo da Aba Ativa
          Expanded(
            child: switch (_activeTab) {
              StemHubTab.latex => _buildLatexTab(isLight, themeAccent, textPrimary),
              StemHubTab.mermaid => _buildMermaidTab(isLight, themeAccent, textPrimary),
              StemHubTab.callouts => _buildCalloutsTab(isLight, themeAccent, textPrimary, activeTheme),
            },
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
      borderColor: isLight ? MoscaroTokens.borderSubtle : MoscaroTokens.borderGlow,
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
  }

  Widget _buildTabButton({
    required StemHubTab tab,
    required String label,
    required String iconName,
    required Color themeAccent,
    required Color textPrimary,
  }) {
    final isSelected = _activeTab == tab;
    return InkWell(
      onTap: () => setState(() => _activeTab = tab),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? themeAccent.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? themeAccent.withValues(alpha: 0.45)
                : Colors.transparent,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgIcon(
              name: iconName,
              size: 13,
              color: isSelected ? themeAccent : textPrimary.withValues(alpha: 0.65),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? themeAccent : textPrimary.withValues(alpha: 0.75),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ABA LATEX ---
  Widget _buildLatexTab(bool isLight, Color themeAccent, Color textPrimary) {
    final currentCat = _latexCategories[_latexCategoryIndex];
    final items = _latexItems[currentCat] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sub-categorias LaTeX & Botão de Bloco Rápido
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_latexCategories.length, (idx) {
                      final isCatSelected = _latexCategoryIndex == idx;
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: InkWell(
                          onTap: () => setState(() => _latexCategoryIndex = idx),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isCatSelected
                                  ? themeAccent.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isCatSelected
                                    ? themeAccent.withValues(alpha: 0.4)
                                    : Colors.transparent,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              _latexCategories[idx],
                              style: TextStyle(
                                color: isCatSelected ? themeAccent : textPrimary.withValues(alpha: 0.7),
                                fontSize: 10.5,
                                fontWeight: isCatSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Botão de Bloco LaTeX ($$)
              InkWell(
                onTap: () => widget.onInsertSnippet(r'''
$$
\begin{aligned}
  f(x) &= x^2 + 2x + 1
\end{aligned}
$$
'''),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: themeAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: themeAccent.withValues(alpha: 0.4), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgIcon(name: 'plus', size: 10, color: themeAccent),
                      const SizedBox(width: 3),
                      Text(
                        r'$$ Bloco',
                        style: TextStyle(color: themeAccent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Grade de Símbolos / Fórmulas
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 2.1,
            ),
            itemCount: items.length,
            itemBuilder: (context, idx) {
              final item = items[idx];
              return _LatexItemCard(
                label: item['label']!,
                mathStr: item['math']!,
                themeAccent: themeAccent,
                textPrimary: textPrimary,
                isLight: isLight,
                onTap: () {
                  widget.onInsertSnippet('\$${item['snippet']}\$');
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- ABA MERMAID ---
  Widget _buildMermaidTab(bool isLight, Color themeAccent, Color textPrimary) {
    final templates = [
      {
        'title': 'Fluxograma (Flowchart)',
        'subtitle': 'Decisões e fluxo de processos',
        'snippet': "\n```mermaid\ngraph TD\n    A[Início] --> B{Condição}\n    B -->|Sim| C[Ação 1]\n    B -->|Não| D[Ação 2]\n    C --> E[Fim]\n    D --> E\n```\n",
      },
      {
        'title': 'Diagrama de Sequência',
        'subtitle': 'Mensagens entre participantes ao longo do tempo',
        'snippet': "\n```mermaid\nsequenceDiagram\n    autonumber\n    Alice->>Bob: Solicitação\n    Bob-->>Alice: Resposta de Sucesso\n```\n",
      },
      {
        'title': 'Diagrama de Classes',
        'subtitle': 'Modelagem orientada a objetos com atributos e métodos',
        'snippet': "\n```mermaid\nclassDiagram\n    class Experimento {\n        +String nome\n        +executar()\n    }\n```\n",
      },
      {
        'title': 'Diagrama de Estados',
        'subtitle': 'Transições e estados de uma máquina de estados finitos',
        'snippet': "\n```mermaid\nstateDiagram-v2\n    [*] --> Parado\n    Parado --> Ativo: Ligar\n    Ativo --> Parado: Desligar\n```\n",
      },
      {
        'title': 'Gráfico Git (Branches)',
        'subtitle': 'Histórico de commits, merges e ramificações',
        'snippet': "\n```mermaid\ngitGraph\n    commit\n    branch develop\n    checkout develop\n    commit\n    checkout main\n    merge develop\n```\n",
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: templates.length,
      itemBuilder: (context, idx) {
        final t = templates[idx];
        return _SnippetHoverTile(
          title: t['title']!,
          subtitle: t['subtitle']!,
          svgIcon: 'code',
          iconColor: themeAccent,
          themeAccent: themeAccent,
          textPrimary: textPrimary,
          onTap: () => widget.onInsertSnippet(t['snippet']!),
        );
      },
    );
  }

  // --- ABA CALLOUTS ---
  Widget _buildCalloutsTab(
    bool isLight,
    Color themeAccent,
    Color textPrimary,
    dynamic activeTheme,
  ) {
    final callouts = [
      {
        'title': 'Dica / Insight STEM',
        'subtitle': 'Destaque para insights rápidos e métodos eficientes',
        'svgIcon': 'sparkle',
        'color': activeTheme.calloutTipColor,
        'snippet': "\n> [!TIP]\n> Insira a dica ou insight STEM aqui.\n",
      },
      {
        'title': 'Teorema / Fórmula-Chave',
        'subtitle': 'Caixa de destaque formal para teoremas e postulados',
        'svgIcon': 'math',
        'color': activeTheme.calloutTheoremColor,
        'snippet': "\n> [!THEOREM]\n> Para todo triângulo retângulo: \$a^2 + b^2 = c^2\$.\n",
      },
      {
        'title': 'Atenção / Ponto Crítico',
        'subtitle': 'Aviso sobre singularidades e condições de contorno',
        'svgIcon': 'target',
        'color': activeTheme.calloutWarningColor,
        'snippet': "\n> [!WARNING]\n> Cuidado com condições de contorno e singularidades.\n",
      },
      {
        'title': 'Definição / Conceito',
        'subtitle': 'Definição formal de grandezas e termos científicos',
        'svgIcon': 'book',
        'color': activeTheme.calloutConceptColor,
        'snippet': "\n> [!CONCEPT]\n> Definição formal do conceito científico.\n",
      },
      {
        'title': 'Nota Importante',
        'subtitle': 'Lembrete contextual relevante para a resolução',
        'svgIcon': 'tag',
        'color': activeTheme.calloutNoteColor,
        'snippet': "\n> [!NOTE]\n> Lembre-se de converter as unidades para o S.I.\n",
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: callouts.length,
      itemBuilder: (context, idx) {
        final c = callouts[idx];
        return _SnippetHoverTile(
          title: c['title'] as String,
          subtitle: c['subtitle'] as String,
          svgIcon: c['svgIcon'] as String,
          iconColor: c['color'] as Color,
          themeAccent: themeAccent,
          textPrimary: textPrimary,
          onTap: () => widget.onInsertSnippet(c['snippet'] as String),
        );
      },
    );
  }
}

class _LatexItemCard extends StatefulWidget {
  final String label;
  final String mathStr;
  final Color themeAccent;
  final Color textPrimary;
  final bool isLight;
  final VoidCallback onTap;

  const _LatexItemCard({
    required this.label,
    required this.mathStr,
    required this.themeAccent,
    required this.textPrimary,
    required this.isLight,
    required this.onTap,
  });

  @override
  State<_LatexItemCard> createState() => _LatexItemCardState();
}

class _LatexItemCardState extends State<_LatexItemCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.themeAccent.withValues(alpha: 0.16)
                : (widget.isLight
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isHovered
                  ? widget.themeAccent.withValues(alpha: 0.5)
                  : (widget.isLight
                      ? Colors.black.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.06)),
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Math.tex(
                  widget.mathStr,
                  textStyle: TextStyle(
                    color: _isHovered ? widget.themeAccent : widget.textPrimary,
                    fontSize: 13,
                  ),
                  onErrorFallback: (err) => Text(
                    widget.label,
                    style: TextStyle(fontSize: 10, color: widget.textPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 9,
                  color: widget.textPrimary.withValues(alpha: 0.6),
                  overflow: TextOverflow.ellipsis,
                ),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SnippetHoverTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final String svgIcon;
  final Color iconColor;
  final Color themeAccent;
  final Color textPrimary;
  final VoidCallback onTap;

  const _SnippetHoverTile({
    required this.title,
    required this.subtitle,
    required this.svgIcon,
    required this.iconColor,
    required this.themeAccent,
    required this.textPrimary,
    required this.onTap,
  });

  @override
  State<_SnippetHoverTile> createState() => _SnippetHoverTileState();
}

class _SnippetHoverTileState extends State<_SnippetHoverTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.themeAccent.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isHovered
                  ? widget.themeAccent.withValues(alpha: 0.35)
                  : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SvgIcon(name: widget.svgIcon, size: 14, color: widget.iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: _isHovered ? widget.themeAccent : widget.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: widget.textPrimary.withValues(alpha: 0.6),
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
