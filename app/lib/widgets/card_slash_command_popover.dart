import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_theme_controller.dart';

class SlashCommandItem {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final String snippet;

  const SlashCommandItem({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.snippet,
  });
}

/// Menu Flutuante de Comandos Rápidos ("Slash Commands" `/`) no padrão Moscaro Glass v2.
class CardSlashCommandPopover extends StatefulWidget {
  final String query;
  final ValueChanged<SlashCommandItem> onSelectCommand;
  final VoidCallback onClose;
  final bool isLight;
  final Color themeAccent;
  final Color textPrimary;
  final double blur;

  const CardSlashCommandPopover({
    super.key,
    required this.query,
    required this.onSelectCommand,
    required this.onClose,
    required this.isLight,
    required this.themeAccent,
    required this.textPrimary,
    required this.blur,
  });

  @override
  State<CardSlashCommandPopover> createState() => _CardSlashCommandPopoverState();
}

class _CardSlashCommandPopoverState extends State<CardSlashCommandPopover> {
  final ScrollController _scrollController = ScrollController();

  static const List<SlashCommandItem> _allCommands = [
    SlashCommandItem(
      key: 'h1',
      title: 'Título 1 (H1)',
      subtitle: 'Cabeçalho principal grande de seção',
      icon: Icons.title_rounded,
      snippet: '# ',
    ),
    SlashCommandItem(
      key: 'h2',
      title: 'Título 2 (H2)',
      subtitle: 'Subtítulo médio de documento',
      icon: Icons.format_size_rounded,
      snippet: '## ',
    ),
    SlashCommandItem(
      key: 'h3',
      title: 'Título 3 (H3)',
      subtitle: 'Subtítulo pequeno e tópicos',
      icon: Icons.text_fields_rounded,
      snippet: '### ',
    ),
    SlashCommandItem(
      key: 'math',
      title: 'Equação LaTeX STEM',
      subtitle: 'Bloco de fórmula matemática centralizada',
      icon: Icons.functions_rounded,
      snippet: '\$\$\n\\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}\n\$\$',
    ),
    SlashCommandItem(
      key: 'dica',
      title: 'Callout Dica / Insight',
      subtitle: 'Caixa de destaque com ícone e borda ciano',
      icon: Icons.lightbulb_outline_rounded,
      snippet: '> [!TIP]\n> Insira a dica ou insight STEM aqui.',
    ),
    SlashCommandItem(
      key: 'teorema',
      title: 'Callout Teorema / Fórmula',
      subtitle: 'Definição matemática com borda púrpura',
      icon: Icons.auto_awesome_rounded,
      snippet: '> [!THEOREM]\n> Para todo triângulo retângulo: \$a^2 + b^2 = c^2\$.',
    ),
    SlashCommandItem(
      key: 'aviso',
      title: 'Callout Atenção / Alerta',
      subtitle: 'Avisos e pontos críticos com borda âmbar',
      icon: Icons.warning_amber_rounded,
      snippet: '> [!WARNING]\n> Cuidado com as condições de contorno e singularidades.',
    ),
    SlashCommandItem(
      key: 'conceito',
      title: 'Callout Definição / Conceito',
      subtitle: 'Conceitos fundamentais com borda verde',
      icon: Icons.menu_book_rounded,
      snippet: '> [!CONCEPT]\n> Definição formal do conceito científico.',
    ),
    SlashCommandItem(
      key: 'tarefas',
      title: 'Lista de Tarefas (Checklist)',
      subtitle: 'Checklist interativa com marcadores',
      icon: Icons.check_box_outlined,
      snippet: '- [ ] Primeira Tarefa\n- [ ] Segunda Tarefa',
    ),
    SlashCommandItem(
      key: 'mermaid',
      title: 'Diagrama Mermaid',
      subtitle: 'Fluxograma ou mapa de processos vetorial',
      icon: Icons.account_tree_rounded,
      snippet: '```mermaid\ngraph TD\n  A[Início] --> B{Condição}\n  B -- Sim --> C[Resultado]\n  B -- Não --> D[Repetir]\n```',
    ),
    SlashCommandItem(
      key: 'codigo',
      title: 'Bloco de Código',
      subtitle: 'Bloco de programação com syntax highlight',
      icon: Icons.code_rounded,
      snippet: '```dart\nvoid main() {\n  print("conNotes STEM");\n}\n```',
    ),
    SlashCommandItem(
      key: 'citacao',
      title: 'Citação / Destaque',
      subtitle: 'Bloco de citação estilizado',
      icon: Icons.format_quote_rounded,
      snippet: '> "A imaginação é mais importante que o conhecimento." - Einstein',
    ),
  ];

  List<SlashCommandItem> get _filteredCommands {
    final q = widget.query.toLowerCase().replaceAll('/', '').trim();
    if (q.isEmpty) return _allCommands;
    return _allCommands.where((cmd) {
      return cmd.key.contains(q) ||
          cmd.title.toLowerCase().contains(q) ||
          cmd.subtitle.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MoscaroThemeController.instance,
      builder: (context, _) {
        final isLight = MoscaroTokens.isLight;
        final themeAccent = widget.themeAccent;
        final textPrimary = widget.textPrimary;
        final textSecondary = MoscaroTokens.textSecondary;
        final glassTint = isLight
            ? const Color(0xFFFFFFFF).withValues(alpha: 0.96)
            : MoscaroTokens.glassTint;
        final blur = (MoscaroTokens.enableSubBarsBlur && MoscaroTokens.blurSigma > 0)
            ? MoscaroTokens.blurSigma
            : 0.0;
        final filtered = _filteredCommands;

        Widget content = Container(
          width: 300,
          decoration: BoxDecoration(
            color: glassTint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isLight
                  ? MoscaroTokens.borderSubtle
                  : themeAccent.withValues(alpha: 0.45),
              width: 1.2,
            ),
                boxShadow: [
                  BoxShadow(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  if (!isLight)
                    BoxShadow(
                      color: themeAccent.withValues(alpha: 0.2),
                      blurRadius: 12,
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabeçalho do Popover
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: themeAccent.withValues(alpha: isLight ? 0.08 : 0.14),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                      border: Border(
                        bottom: BorderSide(
                          color: isLight
                              ? MoscaroTokens.borderSubtle
                              : themeAccent.withValues(alpha: 0.25),
                          width: 1.0,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bolt_rounded, size: 14, color: themeAccent),
                            const SizedBox(width: 6),
                            Text(
                              'Comandos Rápidos (/)',
                              style: TextStyle(
                                color: themeAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: widget.onClose,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Icon(Icons.close_rounded, size: 14, color: textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Lista com Rolagem Fluida e Scrollbar Moscaro
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Nenhum comando encontrado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 210,
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, index) {
                            final item = filtered[index];

                            return InkWell(
                              onTap: () => widget.onSelectCommand(item),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: themeAccent.withValues(alpha: isLight ? 0.08 : 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: themeAccent.withValues(alpha: isLight ? 0.2 : 0.35),
                                        ),
                                      ),
                                      child: Icon(item.icon, size: 15, color: themeAccent),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: TextStyle(
                                              color: textPrimary,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            item.subtitle,
                                            style: TextStyle(
                                              color: textSecondary,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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
                  filter: ImageFilter.blur(
                    sigmaX: blur,
                    sigmaY: blur,
                  ),
                  child: content,
                )
              : content,
        );
      },
    );
  }
}
