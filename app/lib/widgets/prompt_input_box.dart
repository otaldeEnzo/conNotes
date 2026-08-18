import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import 'aurora_border_painter.dart';

/// Caixa de Prompt de IA e inserção de texto com Borda Aurora Animada e efeito de vidro moscaroV2 (igual à Topbar)
class PromptInputBox extends StatefulWidget {
  final ValueChanged<String> onSubmit;
  final double width;

  const PromptInputBox({
    super.key,
    required this.onSubmit,
    this.width = 540,
  });

  @override
  State<PromptInputBox> createState() => _PromptInputBoxState();
}

class _PromptInputBoxState extends State<PromptInputBox> with SingleTickerProviderStateMixin {
  late AnimationController _auroraController;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _auroraController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _auroraController,
      builder: (context, child) {
        return CustomPaint(
          painter: AuroraBorderPainter(
            animationValue: _auroraController.value,
            borderRadius: MoscaroTokens.radiusInput,
            borderWidth: MoscaroTokens.borderWidthAurora,
          ),
          child: SizedBox(
            width: widget.width,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Pergunte à IA de Exatas...',
                      hintStyle: TextStyle(color: Colors.white54, fontSize: 12),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_upward, color: MoscaroTokens.auroraBlue, size: 20),
                  onPressed: () {
                    if (_textController.text.trim().isNotEmpty) {
                      widget.onSubmit(_textController.text);
                      _textController.clear();
                    }
                  },
                ),
              ],
            ),
          ).moscaroV2(
            borderRadius: MoscaroTokens.radiusInput,
            borderWidth: 0,
            padding: EdgeInsets.zero,
          ),
        );
      },
    );
  }
}
