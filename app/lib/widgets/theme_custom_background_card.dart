import 'package:flutter/material.dart';
import '../models/theme_models.dart';
import '../theme/moscaro_v2_tokens.dart';

/// Card de Customização Avançada de Fundo do Canvas (Cores Sólidas, Gradientes e Texturas STEM).
class ThemeCustomBackgroundCard extends StatefulWidget {
  final CanvasBackgroundMode backgroundMode;
  final Color solidColor;
  final Color gradientStart;
  final Color gradientEnd;
  final CanvasTextureType textureType;
  final ValueChanged<CanvasBackgroundMode> onModeChanged;
  final ValueChanged<Color> onSolidColorChanged;
  final Function(Color, Color) onGradientChanged;
  final ValueChanged<CanvasTextureType> onTextureChanged;

  const ThemeCustomBackgroundCard({
    super.key,
    required this.backgroundMode,
    required this.solidColor,
    required this.gradientStart,
    required this.gradientEnd,
    required this.textureType,
    required this.onModeChanged,
    required this.onSolidColorChanged,
    required this.onGradientChanged,
    required this.onTextureChanged,
  });

  @override
  State<ThemeCustomBackgroundCard> createState() => _ThemeCustomBackgroundCardState();
}

class _ThemeCustomBackgroundCardState extends State<ThemeCustomBackgroundCard> {
  static const List<Color> _presetSolidColors = [
    Color(0xFF070B14),
    Color(0xFF040507),
    Color(0xFF030D08),
    Color(0xFF0C0718),
    Color(0xFF0F0A05),
    Color(0xFF081324),
    Color(0xFF140D1B),
    Color(0xFF0B1B1C),
  ];

  static const List<List<Color>> _presetGradients = [
    [Color(0xFF0C1B2E), Color(0xFF060B12)],
    [Color(0xFF160D2E), Color(0xFF080512)],
    [Color(0xFF0A2218), Color(0xFF030E09)],
    [Color(0xFF261608), Color(0xFF0D0703)],
    [Color(0xFF121824), Color(0xFF080B10)],
    [Color(0xFF210B1C), Color(0xFF0D030B)],
  ];

  @override
  Widget build(BuildContext context) {
    final isLight = MoscaroTokens.isLight;
    final textPrimary = MoscaroTokens.textPrimary;
    final textSecondary = MoscaroTokens.textSecondary;
    final dividerColor = isLight ? Colors.black12 : Colors.white10;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MoscaroTokens.glassTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MoscaroTokens.borderSubtle, width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header do Fundo Customizado
          Row(
            children: [
              Text(
                'Personalização Avançada de Fundo',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Escolha uma cor sólida, gradiente suave ou textura de engenharia para o canvas.',
            style: TextStyle(color: textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // 2. Abas do Modo de Fundo
          Wrap(
            spacing: 8,
            children: [
              _buildModeTab('Presets STEM', CanvasBackgroundMode.preset, isLight, textPrimary, textSecondary),
              _buildModeTab('Cor Sólida', CanvasBackgroundMode.solidColor, isLight, textPrimary, textSecondary),
              _buildModeTab('Gradiente', CanvasBackgroundMode.gradient, isLight, textPrimary, textSecondary),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Conteúdo Específico do Modo
          if (widget.backgroundMode == CanvasBackgroundMode.solidColor)
            _buildSolidColorPicker(textSecondary)
          else if (widget.backgroundMode == CanvasBackgroundMode.gradient)
            _buildGradientPicker(textSecondary),

          const SizedBox(height: 16),
          Divider(color: dividerColor, height: 1),
          const SizedBox(height: 16),

          // 4. Seletor de Texturas Procedurais STEM
          Text(
            'Textura Técnica de Fundo (Sobreposição Procedural)',
            style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Adiciona uma malha técnica ao fundo sem comprometer a performance do canvas.',
            style: TextStyle(color: textSecondary, fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CanvasTextureType.values.map((tex) {
              final isSelected = widget.textureType == tex;
              return GestureDetector(
                onTap: () => widget.onTextureChanged(tex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? MoscaroTokens.auroraBlue.withValues(alpha: isLight ? 0.15 : 0.25)
                        : (isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.04)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? MoscaroTokens.auroraBlue.withValues(alpha: 0.8)
                          : (isLight ? Colors.black12 : Colors.white10),
                      width: isSelected ? 1.2 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: MoscaroTokens.auroraBlue.withValues(alpha: 0.2),
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    tex.label,
                    style: TextStyle(
                      color: isSelected ? MoscaroTokens.auroraBlue : textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab(String title, CanvasBackgroundMode mode, bool isLight, Color textPrimary, Color textSecondary) {
    final isSelected = widget.backgroundMode == mode;
    return GestureDetector(
      onTap: () => widget.onModeChanged(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? MoscaroTokens.auroraBlue.withValues(alpha: isLight ? 0.15 : 0.22)
              : (isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? MoscaroTokens.auroraBlue : (isLight ? Colors.black12 : Colors.white12),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? MoscaroTokens.auroraBlue : textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSolidColorPicker(Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paleta Rápida de Tons STEM:',
          style: TextStyle(color: textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          children: _presetSolidColors.map((c) {
            final isSelected = widget.solidColor == c;
            return GestureDetector(
              onTap: () => widget.onSolidColorChanged(c),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? MoscaroTokens.auroraBlue : (MoscaroTokens.isLight ? Colors.black26 : Colors.white24),
                    width: isSelected ? 2.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: MoscaroTokens.auroraBlue.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ]
                      : [],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGradientPicker(Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Presets de Gradientes Profundos:',
          style: TextStyle(color: textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: _presetGradients.map((grad) {
            final isSelected = widget.gradientStart == grad[0] && widget.gradientEnd == grad[1];
            return GestureDetector(
              onTap: () => widget.onGradientChanged(grad[0], grad[1]),
              child: Container(
                width: 54,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: grad,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? MoscaroTokens.auroraBlue : Colors.white24,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: MoscaroTokens.auroraBlue.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ]
                      : [],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
