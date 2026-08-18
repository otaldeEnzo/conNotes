import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';

/// Card Visual interativo para acionar a criação de um Novo Tema Personalizado.
class CreateThemeCard extends StatefulWidget {
  final VoidCallback onTap;

  const CreateThemeCard({
    super.key,
    required this.onTap,
  });

  @override
  State<CreateThemeCard> createState() => _CreateThemeCardState();
}

class _CreateThemeCardState extends State<CreateThemeCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isLight = MoscaroTokens.isLight;
    final textPrimary = MoscaroTokens.textPrimary;
    final textSecondary = MoscaroTokens.textSecondary;
    final baseBg = isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.03);
    final baseBorder = isLight ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.15);
    final iconCircleBg = isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: _isHovered
                ? MoscaroTokens.auroraBlue.withValues(alpha: isLight ? 0.18 : 0.12)
                : baseBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? MoscaroTokens.auroraBlue.withValues(alpha: 0.7)
                  : baseBorder,
              width: _isHovered ? 1.5 : 1.0,
              strokeAlign: BorderSide.strokeAlignCenter,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: MoscaroTokens.auroraBlue.withValues(alpha: 0.2),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _isHovered
                          ? MoscaroTokens.auroraBlue.withValues(alpha: 0.25)
                          : iconCircleBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isHovered
                            ? MoscaroTokens.auroraBlue
                            : (isLight ? Colors.black26 : Colors.white30),
                        width: 1.2,
                      ),
                      boxShadow: _isHovered
                          ? [
                              BoxShadow(
                                color: MoscaroTokens.auroraBlue.withValues(alpha: 0.5),
                                blurRadius: 12,
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 24,
                      color: _isHovered ? MoscaroTokens.auroraBlue : textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Criar Novo Tema',
                    style: TextStyle(
                      color: _isHovered ? MoscaroTokens.auroraBlue : textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Harmonia e paleta própria',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
