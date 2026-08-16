import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import 'ink_models.dart';
import 'svg_icon.dart';

/// Sub-Barra Flutuante da Borracha (Vidro Líquido Moscaro v2).
/// Surge centralizada acima da Toolbar principal quando a borracha está ativa.
class EraserSubBar extends StatelessWidget {
  final bool isVisible;
  final EraserMode activeMode;
  final double radius;
  final bool eraseHighlighterOnly;
  final ValueChanged<EraserMode> onSelectMode;
  final ValueChanged<double> onChangeRadius;
  final ValueChanged<bool> onToggleHighlighterOnly;

  static const List<double> sizePresets = [12.0, 24.0, 48.0, 96.0];

  const EraserSubBar({
    super.key,
    required this.isVisible,
    required this.activeMode,
    required this.radius,
    required this.eraseHighlighterOnly,
    required this.onSelectMode,
    required this.onChangeRadius,
    required this.onToggleHighlighterOnly,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !isVisible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        offset: isVisible ? Offset.zero : const Offset(0, 0.4),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          scale: isVisible ? 1.0 : 0.88,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isVisible ? 1.0 : 0.0,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: MoscaroTokens.glassWhite,
                borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
                border: Border.all(color: MoscaroTokens.borderGlow),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Botão: Borracha de Traço Inteiro
                  _buildModeButton(
                    mode: EraserMode.stroke,
                    label: 'Traço Inteiro',
                    assetName: 'eraser',
                    isSelected: activeMode == EraserMode.stroke,
                  ),
                  const SizedBox(width: 4),

                  // 2. Botão: Borracha de Precisão / Segmentos
                  _buildModeButton(
                    mode: EraserMode.precision,
                    label: 'Precisão',
                    assetName: 'eraser',
                    isSelected: activeMode == EraserMode.precision,
                  ),
                  const SizedBox(width: 6),

                  Container(width: 1, height: 18, color: Colors.white12),
                  const SizedBox(width: 6),

                  // 3. Quatro Presets Rápidos de Tamanho
                  for (final preset in sizePresets)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => onChangeRadius(preset),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (radius - preset).abs() < 3.0
                                  ? MoscaroTokens.auroraBlue.withValues(alpha: 0.25)
                                  : Colors.transparent,
                              border: Border.all(
                                color: (radius - preset).abs() < 3.0
                                    ? MoscaroTokens.auroraBlue
                                    : Colors.white24,
                                width: (radius - preset).abs() < 3.0 ? 1.4 : 1.0,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Container(
                              width: (preset / 96.0 * 12.0).clamp(3.5, 12.0),
                              height: (preset / 96.0 * 12.0).clamp(3.5, 12.0),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (radius - preset).abs() < 3.0
                                    ? MoscaroTokens.auroraBlue
                                    : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(width: 4),

                  // 4. Slider Contínuo com Snap Magnético
                  SizedBox(
                    width: 80,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2.0,
                        activeTrackColor: MoscaroTokens.auroraBlue,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: MoscaroTokens.auroraBlue,
                        overlayColor: MoscaroTokens.auroraBlue.withValues(alpha: 0.2),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      ),
                      child: Slider(
                        value: radius.clamp(6.0, 120.0),
                        min: 6.0,
                        max: 120.0,
                        onChanged: (val) {
                          double snapped = val;
                          for (final p in sizePresets) {
                            if ((val - p).abs() <= 4.0) {
                              snapped = p;
                              break;
                            }
                          }
                          onChangeRadius(snapped);
                        },
                      ),
                    ),
                  ),

                  // Label com o tamanho atual em px
                  Text(
                    '${radius.round()}px',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),

                  Container(width: 1, height: 18, color: Colors.white12),
                  const SizedBox(width: 6),

                  // 5. Toggle: Apagar apenas marca-texto
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onToggleHighlighterOnly(!eraseHighlighterOnly),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: eraseHighlighterOnly
                              ? MoscaroTokens.auroraAmber.withValues(alpha: 0.2)
                              : Colors.transparent,
                          border: Border.all(
                            color: eraseHighlighterOnly
                                ? MoscaroTokens.auroraAmber
                                : Colors.transparent,
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: eraseHighlighterOnly
                                    ? MoscaroTokens.auroraAmber
                                    : Colors.white30,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Só Marca-Texto',
                              style: TextStyle(
                                color: eraseHighlighterOnly
                                    ? MoscaroTokens.auroraAmber
                                    : Colors.white60,
                                fontSize: 11,
                                fontWeight: eraseHighlighterOnly
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ).moscaroV2(
              borderRadius: MoscaroTokens.radiusPill,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required EraserMode mode,
    required String label,
    required String assetName,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onSelectMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: isSelected
                ? MoscaroTokens.auroraBlue.withValues(alpha: 0.18)
                : Colors.transparent,
            border: Border.all(
              color: isSelected ? MoscaroTokens.auroraBlue : Colors.transparent,
              width: 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: MoscaroTokens.auroraBlue.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(
                assetName: assetName,
                size: 14,
                color: isSelected ? MoscaroTokens.auroraBlue : Colors.white70,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
