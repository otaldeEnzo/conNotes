import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../theme/moscaro_v2_tokens.dart';

class LatexSymbolItem {
  final String label;
  final String latexSnippet;
  final String displayMath;

  const LatexSymbolItem({
    required this.label,
    required this.latexSnippet,
    String? displayMath,
  }) : displayMath = displayMath ?? latexSnippet;
}

/// Paleta Categorizada Completa de Símbolos STEM em LaTeX (100% Moscaro Glass).
class LatexStemSymbolsPalette extends StatefulWidget {
  final ValueChanged<String> onSelectSymbol;
  final VoidCallback onClose;

  const LatexStemSymbolsPalette({
    super.key,
    required this.onSelectSymbol,
    required this.onClose,
  });

  @override
  State<LatexStemSymbolsPalette> createState() => _LatexStemSymbolsPaletteState();
}

class _LatexStemSymbolsPaletteState extends State<LatexStemSymbolsPalette> {
  int _activeCategoryIndex = 0;

  static const List<String> _categoryNames = [
    'Álgebra',
    'Cálculo',
    'Matrizes & Vetores',
    'Letras Gregas',
    'Física & Eng.',
    'Química',
    'Lógica & Conjuntos',
  ];

  static const List<List<LatexSymbolItem>> _categories = [
    // 1. Álgebra & Aritmética
    [
      LatexSymbolItem(label: 'Fração', latexSnippet: r'\frac{a}{b}', displayMath: r'\frac{a}{b}'),
      LatexSymbolItem(label: 'Raiz Quadrada', latexSnippet: r'\sqrt{x}', displayMath: r'\sqrt{x}'),
      LatexSymbolItem(label: 'Raiz N-ésima', latexSnippet: r'\sqrt[n]{x}', displayMath: r'\sqrt[n]{x}'),
      LatexSymbolItem(label: 'Expoente', latexSnippet: r'x^{a}', displayMath: r'x^{a}'),
      LatexSymbolItem(label: 'Subscrito', latexSnippet: r'x_{b}', displayMath: r'x_{b}'),
      LatexSymbolItem(label: 'Logaritmo', latexSnippet: r'\log_b(x)', displayMath: r'\log_b(x)'),
      LatexSymbolItem(label: 'Log Natural', latexSnippet: r'\ln(x)', displayMath: r'\ln(x)'),
      LatexSymbolItem(label: 'Binômio', latexSnippet: r'\binom{n}{k}', displayMath: r'\binom{n}{k}'),
      LatexSymbolItem(label: 'Mais ou Menos', latexSnippet: r'\pm', displayMath: r'\pm'),
      LatexSymbolItem(label: 'Menos ou Mais', latexSnippet: r'\mp', displayMath: r'\mp'),
      LatexSymbolItem(label: 'Multiplicação', latexSnippet: r'\times', displayMath: r'\times'),
      LatexSymbolItem(label: 'Divisão', latexSnippet: r'\div', displayMath: r'\div'),
      LatexSymbolItem(label: 'Aproximado', latexSnippet: r'\approx', displayMath: r'\approx'),
      LatexSymbolItem(label: 'Diferente', latexSnippet: r'\neq', displayMath: r'\neq'),
      LatexSymbolItem(label: 'Proporcional', latexSnippet: r'\propto', displayMath: r'\propto'),
      LatexSymbolItem(label: 'Módulo', latexSnippet: r'|x|', displayMath: r'|x|'),
    ],
    // 2. Cálculo & Análise
    [
      LatexSymbolItem(label: 'Derivada', latexSnippet: r'\frac{df}{dx}', displayMath: r'\frac{df}{dx}'),
      LatexSymbolItem(label: 'Derivada Parcial', latexSnippet: r'\frac{\partial f}{\partial x}', displayMath: r'\frac{\partial f}{\partial x}'),
      LatexSymbolItem(label: 'Integral Definida', latexSnippet: r'\int_{a}^{b} f(x) \, dx', displayMath: r'\int_{a}^{b} f(x) dx'),
      LatexSymbolItem(label: 'Integral Dupla', latexSnippet: r'\iint_D f(x,y) \, dA', displayMath: r'\iint_D dA'),
      LatexSymbolItem(label: 'Integral Tripla', latexSnippet: r'\iiint_V f(x,y,z) \, dV', displayMath: r'\iiint_V dV'),
      LatexSymbolItem(label: 'Integral Fechada', latexSnippet: r'\oint_C \vec{F} \cdot d\vec{r}', displayMath: r'\oint_C'),
      LatexSymbolItem(label: 'Somatório', latexSnippet: r'\sum_{i=1}^{n} a_i', displayMath: r'\sum_{i=1}^{n} a_i'),
      LatexSymbolItem(label: 'Produtório', latexSnippet: r'\prod_{i=1}^{n} a_i', displayMath: r'\prod_{i=1}^{n} a_i'),
      LatexSymbolItem(label: 'Limite', latexSnippet: r'\lim_{x \to a} f(x)', displayMath: r'\lim_{x \to a}'),
      LatexSymbolItem(label: 'Gradiente', latexSnippet: r'\nabla f', displayMath: r'\nabla f'),
      LatexSymbolItem(label: 'Laplaciano', latexSnippet: r'\nabla^2 f', displayMath: r'\nabla^2 f'),
      LatexSymbolItem(label: 'Rotacional', latexSnippet: r'\nabla \times \vec{F}', displayMath: r'\nabla \times \vec{F}'),
      LatexSymbolItem(label: 'Divergente', latexSnippet: r'\nabla \cdot \vec{F}', displayMath: r'\nabla \cdot \vec{F}'),
    ],
    // 3. Matrizes & Vetores
    [
      LatexSymbolItem(label: 'Vetor', latexSnippet: r'\vec{v}', displayMath: r'\vec{v}'),
      LatexSymbolItem(label: 'Versor', latexSnippet: r'\hat{u}', displayMath: r'\hat{u}'),
      LatexSymbolItem(label: 'Matriz 2x2', latexSnippet: r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}', displayMath: r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}'),
      LatexSymbolItem(label: 'Matriz Colchetes', latexSnippet: r'\begin{bmatrix} a & b \\ c & d \end{bmatrix}', displayMath: r'\begin{bmatrix} a & b \\ c & d \end{bmatrix}'),
      LatexSymbolItem(label: 'Determinante', latexSnippet: r'\begin{vmatrix} a & b \\ c & d \end{vmatrix}', displayMath: r'\begin{vmatrix} a & b \\ c & d \end{vmatrix}'),
      LatexSymbolItem(label: 'Transposta', latexSnippet: r'A^T', displayMath: r'A^T'),
      LatexSymbolItem(label: 'Inversa', latexSnippet: r'A^{-1}', displayMath: r'A^{-1}'),
      LatexSymbolItem(label: 'Norma', latexSnippet: r'\|\vec{v}\|', displayMath: r'\|\vec{v}\|'),
      LatexSymbolItem(label: 'Produto Escalar', latexSnippet: r'\vec{u} \cdot \vec{v}', displayMath: r'\vec{u} \cdot \vec{v}'),
      LatexSymbolItem(label: 'Produto Vetorial', latexSnippet: r'\vec{u} \times \vec{v}', displayMath: r'\vec{u} \times \vec{v}'),
    ],
    // 4. Letras Gregas
    [
      LatexSymbolItem(label: 'alpha', latexSnippet: r'\alpha', displayMath: r'\alpha'),
      LatexSymbolItem(label: 'beta', latexSnippet: r'\beta', displayMath: r'\beta'),
      LatexSymbolItem(label: 'gamma', latexSnippet: r'\gamma', displayMath: r'\gamma'),
      LatexSymbolItem(label: 'delta', latexSnippet: r'\delta', displayMath: r'\delta'),
      LatexSymbolItem(label: 'epsilon', latexSnippet: r'\epsilon', displayMath: r'\epsilon'),
      LatexSymbolItem(label: 'theta', latexSnippet: r'\theta', displayMath: r'\theta'),
      LatexSymbolItem(label: 'lambda', latexSnippet: r'\lambda', displayMath: r'\lambda'),
      LatexSymbolItem(label: 'mu', latexSnippet: r'\mu', displayMath: r'\mu'),
      LatexSymbolItem(label: 'pi', latexSnippet: r'\pi', displayMath: r'\pi'),
      LatexSymbolItem(label: 'rho', latexSnippet: r'\rho', displayMath: r'\rho'),
      LatexSymbolItem(label: 'sigma', latexSnippet: r'\sigma', displayMath: r'\sigma'),
      LatexSymbolItem(label: 'tau', latexSnippet: r'\tau', displayMath: r'\tau'),
      LatexSymbolItem(label: 'phi', latexSnippet: r'\phi', displayMath: r'\phi'),
      LatexSymbolItem(label: 'omega', latexSnippet: r'\omega', displayMath: r'\omega'),
      LatexSymbolItem(label: 'Delta', latexSnippet: r'\Delta', displayMath: r'\Delta'),
      LatexSymbolItem(label: 'Gamma', latexSnippet: r'\Gamma', displayMath: r'\Gamma'),
      LatexSymbolItem(label: 'Theta', latexSnippet: r'\Theta', displayMath: r'\Theta'),
      LatexSymbolItem(label: 'Lambda', latexSnippet: r'\Lambda', displayMath: r'\Lambda'),
      LatexSymbolItem(label: 'Sigma', latexSnippet: r'\Sigma', displayMath: r'\Sigma'),
      LatexSymbolItem(label: 'Phi', latexSnippet: r'\Phi', displayMath: r'\Phi'),
      LatexSymbolItem(label: 'Omega', latexSnippet: r'\Omega', displayMath: r'\Omega'),
    ],
    // 5. Física & Engenharia
    [
      LatexSymbolItem(label: 'Constante Planck', latexSnippet: r'\hbar', displayMath: r'\hbar'),
      LatexSymbolItem(label: 'Permissividade', latexSnippet: r'\varepsilon_0', displayMath: r'\varepsilon_0'),
      LatexSymbolItem(label: 'Permeabilidade', latexSnippet: r'\mu_0', displayMath: r'\mu_0'),
      LatexSymbolItem(label: 'Velocidade Luz', latexSnippet: r'c', displayMath: r'c'),
      LatexSymbolItem(label: 'Gravitação', latexSnippet: r'G', displayMath: r'G'),
      LatexSymbolItem(label: 'Bra-Ket', latexSnippet: r'\langle \psi | \phi \rangle', displayMath: r'\langle \psi | \phi \rangle'),
      LatexSymbolItem(label: 'Ângulo', latexSnippet: r'\angle \theta', displayMath: r'\angle \theta'),
      LatexSymbolItem(label: 'Campo Elétrico', latexSnippet: r'\vec{E}', displayMath: r'\vec{E}'),
      LatexSymbolItem(label: 'Campo Magnético', latexSnippet: r'\vec{B}', displayMath: r'\vec{B}'),
      LatexSymbolItem(label: 'Ohm', latexSnippet: r'\Omega', displayMath: r'\Omega'),
      LatexSymbolItem(label: 'Unidade m/s²', latexSnippet: r'\mathrm{m/s^2}', displayMath: r'\mathrm{m/s^2}'),
    ],
    // 6. Química & Reações
    [
      LatexSymbolItem(label: 'Reação Direta', latexSnippet: r'\rightarrow', displayMath: r'\rightarrow'),
      LatexSymbolItem(label: 'Equilíbrio Químico', latexSnippet: r'\rightleftharpoons', displayMath: r'\rightleftharpoons'),
      LatexSymbolItem(label: 'Aquecimento', latexSnippet: r'\xrightarrow{\Delta}', displayMath: r'\xrightarrow{\Delta}'),
      LatexSymbolItem(label: 'Água H2O', latexSnippet: r'\mathrm{H_2O}', displayMath: r'\mathrm{H_2O}'),
      LatexSymbolItem(label: 'Gás Carbônico', latexSnippet: r'\mathrm{CO_2}', displayMath: r'\mathrm{CO_2}'),
      LatexSymbolItem(label: 'Cátion Sódio', latexSnippet: r'\mathrm{Na^+}', displayMath: r'\mathrm{Na^+}'),
      LatexSymbolItem(label: 'Ânion Cloreto', latexSnippet: r'\mathrm{Cl^-}', displayMath: r'\mathrm{Cl^-}'),
      LatexSymbolItem(label: 'Entalpia', latexSnippet: r'\Delta H', displayMath: r'\Delta H'),
      LatexSymbolItem(label: 'pH', latexSnippet: r'\mathrm{pH}', displayMath: r'\mathrm{pH}'),
    ],
    // 7. Lógica & Teoria dos Conjuntos
    [
      LatexSymbolItem(label: 'Pertence', latexSnippet: r'\in', displayMath: r'\in'),
      LatexSymbolItem(label: 'Não Pertence', latexSnippet: r'\notin', displayMath: r'\notin'),
      LatexSymbolItem(label: 'Subconjunto', latexSnippet: r'\subset', displayMath: r'\subset'),
      LatexSymbolItem(label: 'Contido ou Igual', latexSnippet: r'\subseteq', displayMath: r'\subseteq'),
      LatexSymbolItem(label: 'União', latexSnippet: r'\cup', displayMath: r'\cup'),
      LatexSymbolItem(label: 'Interseção', latexSnippet: r'\cap', displayMath: r'\cap'),
      LatexSymbolItem(label: 'Para Todo', latexSnippet: r'\forall', displayMath: r'\forall'),
      LatexSymbolItem(label: 'Existe', latexSnippet: r'\exists', displayMath: r'\exists'),
      LatexSymbolItem(label: 'Implica', latexSnippet: r'\implies', displayMath: r'\implies'),
      LatexSymbolItem(label: 'Se e Somente Se', latexSnippet: r'\iff', displayMath: r'\iff'),
      LatexSymbolItem(label: 'Conjunto Vazio', latexSnippet: r'\emptyset', displayMath: r'\emptyset'),
      LatexSymbolItem(label: 'Infinito', latexSnippet: r'\infty', displayMath: r'\infty'),
      LatexSymbolItem(label: 'Reais', latexSnippet: r'\mathbb{R}', displayMath: r'\mathbb{R}'),
      LatexSymbolItem(label: 'Naturais', latexSnippet: r'\mathbb{N}', displayMath: r'\mathbb{N}'),
      LatexSymbolItem(label: 'Complexos', latexSnippet: r'\mathbb{C}', displayMath: r'\mathbb{C}'),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final isLight = MoscaroTokens.isLight;
    final themeAccent = MoscaroTokens.auroraBlue;
    final textPrimary = MoscaroTokens.textPrimary;
    final textSecondary = MoscaroTokens.textSecondary;
    final glassTint = MoscaroTokens.glassTint;
    final blur = (MoscaroTokens.enableSubBarsBlur && MoscaroTokens.blurSigma > 0)
        ? MoscaroTokens.blurSigma
        : 0.0;

    final currentItems = _categories[_activeCategoryIndex];

    Widget content = Container(
      width: 360,
      height: 280,
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
          // Cabeçalho da Paleta
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.functions_rounded, size: 16, color: themeAccent),
                    const SizedBox(width: 6),
                    Text(
                      'Símbolos STEM LaTeX',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isLight ? Colors.black12 : Colors.white12),

          // Abas de Categorias
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: List.generate(_categoryNames.length, (idx) {
                final isSelected = _activeCategoryIndex == idx;
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InkWell(
                    onTap: () => setState(() => _activeCategoryIndex = idx),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? themeAccent.withValues(alpha: 0.2)
                            : (isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? themeAccent : Colors.transparent,
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        _categoryNames[idx],
                        style: TextStyle(
                          color: isSelected ? (isLight ? Colors.black : Colors.white) : textSecondary,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Divider(height: 1, color: isLight ? Colors.black12 : Colors.white12),

          // Grid de Símbolos Renderizados via KaTeX
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.35,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: currentItems.length,
              itemBuilder: (ctx, index) {
                final item = currentItems[index];
                return Tooltip(
                  message: '${item.label}\n${item.latexSnippet}',
                  child: InkWell(
                    onTap: () {
                      widget.onSelectSymbol(item.latexSnippet);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isLight ? Colors.black12 : Colors.white12),
                      ),
                      child: Math.tex(
                        item.displayMath,
                        textStyle: TextStyle(
                          color: textPrimary,
                          fontSize: 13,
                        ),
                        onErrorFallback: (err) => Text(
                          item.label,
                          style: TextStyle(color: textPrimary, fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ),
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
}
