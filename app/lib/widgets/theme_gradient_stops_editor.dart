import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/theme_harmony_service.dart';
import 'theme_color_field_tile.dart';

/// Editor Dinâmico de Gradientes com Quantidade Ilimitada de Cores (N Stops),
/// Harmonizador HSL e Gerador Aleatório Procedural.
class ThemeGradientStopsEditor extends StatelessWidget {
  final List<Color> colors;
  final Color accentColor;
  final ValueChanged<List<Color>> onColorsChanged;

  const ThemeGradientStopsEditor({
    super.key,
    required this.colors,
    required this.accentColor,
    required this.onColorsChanged,
  });

  void _addColorStop() {
    final updated = List<Color>.from(colors);
    if (updated.isEmpty) {
      updated.addAll([const Color(0xFF0C1626), const Color(0xFF070B14)]);
    } else {
      // Interpola uma cor intermediária ou varia a última
      final last = updated.last;
      final hsv = HSVColor.fromColor(last);
      final newHue = (hsv.hue + 30.0) % 360.0;
      updated.add(HSVColor.fromAHSV(1.0, newHue, hsv.saturation, hsv.value).toColor());
    }
    onColorsChanged(updated);
  }

  void _removeColorStop(int index) {
    if (colors.length <= 2) return; // Mínimo 2 cores
    final updated = List<Color>.from(colors)..removeAt(index);
    onColorsChanged(updated);
  }

  void _updateColorAt(int index, Color newColor) {
    final updated = List<Color>.from(colors);
    updated[index] = newColor;
    onColorsChanged(updated);
  }

  void _harmonizeGradient() {
    if (colors.isEmpty) return;
    final base = colors.first;
    final baseHsv = HSVColor.fromColor(base);
    final count = colors.length;
    final List<Color> harmonized = [];

    for (int i = 0; i < count; i++) {
      final t = i / (count - 1);
      final hue = (baseHsv.hue + (t * 45.0)) % 360.0;
      final val = (baseHsv.value * (1.0 - t * 0.4)).clamp(0.05, 1.0);
      final sat = (baseHsv.saturation * (1.0 + t * 0.2)).clamp(0.1, 1.0);
      harmonized.add(HSVColor.fromAHSV(1.0, hue, sat, val).toColor());
    }

    onColorsChanged(harmonized);
  }

  void _generateRandomGradient() {
    final random = math.Random();
    final randomTheme = ThemeHarmonyService.generateRandomTheme();
    final count = random.nextInt(5) + 2; // Gera entre 2 e 6 paradas
    final baseHsv = HSVColor.fromColor(randomTheme.accentPrimary);
    final bgHsv = HSVColor.fromColor(randomTheme.backgroundDeep);
    final hueShift = (random.nextDouble() * 60.0 + 20.0) * (random.nextBool() ? 1 : -1);

    final List<Color> stops = [];
    for (int i = 0; i < count; i++) {
      final t = i / (count - 1);
      final hue = (bgHsv.hue + (t * hueShift)) % 360.0;
      final val = (bgHsv.value + t * (baseHsv.value * 0.4 - bgHsv.value)).clamp(0.04, 0.95);
      final sat = (bgHsv.saturation + t * (baseHsv.saturation * 0.6 - bgHsv.saturation)).clamp(0.1, 0.95);
      stops.add(HSVColor.fromAHSV(1.0, hue < 0 ? hue + 360 : hue, sat, val).toColor());
    }
    onColorsChanged(stops);
  }

  void _reorderStops(int oldIndex, int newIndex) {
    if (oldIndex == newIndex || oldIndex < 0 || oldIndex >= colors.length || newIndex < 0 || newIndex >= colors.length) {
      return;
    }
    final updated = List<Color>.from(colors);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    onColorsChanged(updated);
  }

  void _moveStop(int index, int delta) {
    final target = index + delta;
    if (target >= 0 && target < colors.length) {
      _reorderStops(index, target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Barra de Preview Contínuo do Gradiente com Suporte a Drag & Drop de Paradas
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: colors.length >= 2 ? colors : [Colors.black, Colors.white],
                stops: [
                  for (int i = 0; i < (colors.length >= 2 ? colors.length : 2); i++)
                    i / ((colors.length >= 2 ? colors.length : 2) - 1)
                ],
              ),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: colors.asMap().entries.map((entry) {
                final idx = entry.key;
                final c = entry.value;

                return DragTarget<int>(
                  onWillAcceptWithDetails: (details) => details.data != idx,
                  onAcceptWithDetails: (details) {
                    _reorderStops(details.data, idx);
                  },
                  builder: (context, candidateData, rejectedData) {
                    final isHighlighted = candidateData.isNotEmpty;
                    return Draggable<int>(
                      data: idx,
                      feedback: Material(
                        color: Colors.transparent,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(color: MoscaroTokens.auroraBlue, width: 2.0),
                            boxShadow: [
                              BoxShadow(color: MoscaroTokens.auroraBlue.withValues(alpha: 0.6), blurRadius: 10),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '${idx + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: _buildStopBadge(idx, c, false),
                      ),
                      child: _buildStopBadge(idx, c, isHighlighted),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // 2. Ações de Harmonia e Geração Aleatória
        Row(
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor.withValues(alpha: 0.18),
                foregroundColor: accentColor,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: accentColor.withValues(alpha: 0.4)),
                ),
              ),
              icon: const Icon(Icons.auto_awesome, size: 13),
              label: const Text('Harmonizar Gradiente', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              onPressed: _harmonizeGradient,
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Gerar Gradiente Aleatório',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Colors.white12),
                ),
              ),
              icon: const Icon(Icons.casino_outlined, size: 16),
              onPressed: _generateRandomGradient,
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: MoscaroTokens.auroraBlue.withValues(alpha: 0.15),
                foregroundColor: MoscaroTokens.auroraBlue,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: MoscaroTokens.auroraBlue.withValues(alpha: 0.4)),
                ),
              ),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Adicionar Cor', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: _addColorStop,
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 3. Lista de Cores dos Stops com Botões de Reordenação Rápida
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: colors.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (ctx, index) {
            final color = colors[index];
            final canRemove = colors.length > 2;
            final canMoveUp = index > 0;
            final canMoveDown = index < colors.length - 1;

            return Row(
              children: [
                // Indicador de Posição Reordenável
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),

                // Campo de Seleção de Cor
                Expanded(
                  child: ThemeColorFieldTile(
                    label: 'Parada ${index + 1} (${index == 0 ? "Superior" : index == colors.length - 1 ? "Profunda" : "Intermediária"})',
                    color: color,
                    onColorChanged: (c) => _updateColorAt(index, c),
                  ),
                ),

                const SizedBox(width: 4),

                // Botão Mover para Cima
                IconButton(
                  icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                  color: canMoveUp ? Colors.white70 : Colors.white24,
                  tooltip: 'Mover Cor para Cima',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: canMoveUp ? () => _moveStop(index, -1) : null,
                ),

                // Botão Mover para Baixo
                IconButton(
                  icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                  color: canMoveDown ? Colors.white70 : Colors.white24,
                  tooltip: 'Mover Cor para Baixo',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: canMoveDown ? () => _moveStop(index, 1) : null,
                ),

                if (canRemove) ...[
                  const SizedBox(width: 2),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 16, color: MoscaroTokens.auroraPink),
                    tooltip: 'Remover Parada',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => _removeColorStop(index),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStopBadge(int idx, Color c, bool isHighlighted) {
    return Container(
      width: isHighlighted ? 22 : 18,
      height: isHighlighted ? 22 : 18,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(
          color: isHighlighted ? MoscaroTokens.auroraBlue : Colors.white,
          width: isHighlighted ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isHighlighted ? MoscaroTokens.auroraBlue.withValues(alpha: 0.5) : Colors.black45,
            blurRadius: isHighlighted ? 8 : 4,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '${idx + 1}',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}
