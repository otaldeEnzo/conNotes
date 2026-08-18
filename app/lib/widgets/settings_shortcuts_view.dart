import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';

/// Visualizador Moderno da Tabela de Atalhos de Teclado e Gestos do conNotes (UI/UX Pro Max).
class SettingsShortcutsView extends StatelessWidget {
  const SettingsShortcutsView({super.key});

  static const List<Map<String, String>> _shortcuts = [
    {'keys': 'Ctrl + Z', 'desc': 'Desfazer último traço ou alteração'},
    {'keys': 'Ctrl + Y', 'desc': 'Refazer última ação desfeita'},
    {'keys': 'Ctrl + ,', 'desc': 'Abrir / Fechar tela de Configurações'},
    {'keys': 'Esc', 'desc': 'Fechar sub-barras, menus ou desmarcar seleção'},
    {'keys': 'Shift + Arrastar', 'desc': 'Desenhar linha reta perfeitamente alinhada'},
    {'keys': 'Ctrl + Arrastar', 'desc': 'Desenhar vetor / seta direcionada'},
    {'keys': 'Draw & Hold', 'desc': 'Reconhecer e converter traço em forma perfeita'},
    {'keys': 'Clique Meio', 'desc': 'Pan / Navegação rápida pelo Canvas infinito'},
    {'keys': 'Ctrl + Scroll', 'desc': 'Zoom in / Zoom out focado no cursor'},
    {'keys': 'Duplo Clique', 'desc': 'Digitar inclinação numérica exata da Régua'},
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 580;

        return GridView.builder(
          itemCount: _shortcuts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 2 : 1,
            mainAxisExtent: 68,
            crossAxisSpacing: 12,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final item = _shortcuts[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1422).withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: MoscaroTokens.auroraBlue.withValues(alpha: 0.4),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: MoscaroTokens.auroraBlue.withValues(alpha: 0.15),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(
                      item['keys']!,
                      style: TextStyle(
                        color: MoscaroTokens.auroraBlue,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item['desc']!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
