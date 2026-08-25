import 'package:flutter/material.dart';
import '../models/ai_provider_models.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import '../theme/moscaro_theme_controller.dart';
import 'svg_icon.dart';

/// Pílula de Vidro Líquido Moscaro v2 para alternar o menu do modelo de IA ativo
class AiModelSelectorPill extends StatefulWidget {
  final AiModelDefinition selectedModel;
  final bool isOpen;
  final VoidCallback onToggle;

  const AiModelSelectorPill({
    super.key,
    required this.selectedModel,
    required this.isOpen,
    required this.onToggle,
  });

  @override
  State<AiModelSelectorPill> createState() => _AiModelSelectorPillState();
}

class _AiModelSelectorPillState extends State<AiModelSelectorPill> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = MoscaroThemeController.instance.currentTheme;
    final accent = theme.accentPrimary;
    final isOpen = widget.isOpen;
    final isHighlighted = isOpen || _isHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onToggle,
          borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgIcon(
                  assetName: 'ai',
                  color: isHighlighted ? accent : accent.withValues(alpha: 0.9),
                  size: 14,
                ),
                const SizedBox(width: 7),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    widget.selectedModel.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isHighlighted ? accent : MoscaroTokens.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 15,
                  color: isHighlighted ? accent : MoscaroTokens.iconInactive,
                ),
              ],
            ),
          ),
        ),
      ).moscaroV2(
        borderRadius: MoscaroTokens.radiusPill,
        padding: EdgeInsets.zero,
        backgroundColor: isHighlighted
            ? accent.withValues(alpha: isOpen ? 0.22 : 0.12)
            : MoscaroTokens.glassTint,
        borderColor: isHighlighted
            ? accent.withValues(alpha: isOpen ? 0.85 : 0.5)
            : MoscaroTokens.borderGlow,
        borderWidth: isHighlighted ? 1.3 : MoscaroTokens.borderWidthSubtle,
      ),
    );
  }
}
