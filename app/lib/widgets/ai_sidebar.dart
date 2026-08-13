import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import 'prompt_input_box.dart';

/// Painel Lateral Direito da IA em formato Pílula Vertical moscaro-v2 (Área de Chat)
class AiSidebar extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final ValueChanged<String> onSubmitPrompt;

  const AiSidebar({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.onSubmitPrompt,
  });

  @override
  Widget build(BuildContext context) {
    // Animação de transição lateral a partir da direita
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      right: isOpen ? 24 : -400, // Desliza para fora da tela quando fechado
      top: 24,
      bottom: 24,
      child: child,
    );
  }

  Widget get child {
    return Container(
      width: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header da Sidebar da IA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.psychology, color: MoscaroTokens.auroraBlue, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Assistente STEM IA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 16),
          // Área de Chat vazia (futuras mensagens)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.chat_bubble_outline, color: Colors.white24, size: 40),
                  SizedBox(height: 12),
                  Text(
                    'Nenhuma conversa activa',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Escreva uma dúvida para começar',
                    style: TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Caixa de Entrada de Prompt movida para dentro da Sidebar na parte inferior
          PromptInputBox(
            onSubmit: onSubmitPrompt,
            width: 328, // Largura adaptada para caber no menu lateral
          ),
        ],
      ),
    ).moscaroV2(
      borderRadius: MoscaroTokens.radiusPanel,
      padding: const EdgeInsets.all(18),
    );
  }
}
