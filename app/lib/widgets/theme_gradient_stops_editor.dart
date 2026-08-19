import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/theme_harmony_service.dart';
import 'theme_color_field_tile.dart';

/// Editor Dinâmico de Gradientes com Suporte a Quantidade Ilimitada de Cores (N Stops),
/// Posicionamento Livre de Paradas (Drag & Drop Contínuo), Harmonizador HSL e Gerador Procedural.
class ThemeGradientStopsEditor extends StatelessWidget {
  final List<Color> colors;
  final List<double>? stops;
  final Color accentColor;
  final ValueChanged<List<Color>> onColorsChanged;
  final ValueChanged<List<double>>? onStopsChanged;

  const ThemeGradientStopsEditor({
    super.key,
    required this.colors,
    this.stops,
    required this.accentColor,
    required this.onColorsChanged,
    this.onStopsChanged,
  });

  List<double> get _effectiveStops {
    final count = colors.length;
    if (stops != null && stops!.length == count) {
      return stops!;
    }
    return [
      for (int i = 0; i < count; i++) i / (count - 1)
    ];
  }

  void _addColorStop() {
    final updatedColors = List<Color>.from(colors);

    if (updatedColors.isEmpty) {
      updatedColors.addAll([const Color(0xFF0C1626), const Color(0xFF070B14)]);
      onColorsChanged(updatedColors);
      onStopsChanged?.call([0.0, 1.0]);
      return;
    }

    final last = updatedColors.last;
    final hsv = HSVColor.fromColor(last);
    final newHue = (hsv.hue + 30.0) % 360.0;
    updatedColors.add(HSVColor.fromAHSV(1.0, newHue, hsv.saturation, hsv.value).toColor());

    final newCount = updatedColors.length;
    final updatedStops = [
      for (int i = 0; i < newCount; i++) i / (newCount - 1)
    ];

    onColorsChanged(updatedColors);
    onStopsChanged?.call(updatedStops);
  }

  void _removeColorStop(int index) {
    if (colors.length <= 2) return; // Mínimo 2 cores
    final updatedColors = List<Color>.from(colors)..removeAt(index);
    final updatedStops = List<double>.from(_effectiveStops)..removeAt(index);

    // Garante que o primeiro pino comece em 0.0 e o último termine em 1.0 se estavam nas pontas
    if (updatedStops.isNotEmpty) {
      if (index == 0) updatedStops[0] = 0.0;
      if (index == colors.length - 1) updatedStops[updatedStops.length - 1] = 1.0;
    }

    onColorsChanged(updatedColors);
    onStopsChanged?.call(updatedStops);
  }

  void _updateColorAt(int index, Color newColor) {
    final updated = List<Color>.from(colors);
    updated[index] = newColor;
    onColorsChanged(updated);
  }

  void _updateStopOffset(int index, double newOffset) {
    final updated = List<double>.from(_effectiveStops);
    updated[index] = newOffset.clamp(0.0, 1.0);
    onStopsChanged?.call(updated);
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

    final newStops = [
      for (int i = 0; i < count; i++) i / (count - 1)
    ];

    onColorsChanged(harmonized);
    onStopsChanged?.call(newStops);
  }

  void _generateRandomGradient() {
    final random = math.Random();
    final randomTheme = ThemeHarmonyService.generateRandomTheme();
    final count = random.nextInt(5) + 2; // Gera entre 2 e 6 paradas
    final baseHsv = HSVColor.fromColor(randomTheme.accentPrimary);
    final bgHsv = HSVColor.fromColor(randomTheme.backgroundDeep);
    final hueShift = (random.nextDouble() * 60.0 + 20.0) * (random.nextBool() ? 1 : -1);

    final List<Color> newColors = [];
    for (int i = 0; i < count; i++) {
      final t = i / (count - 1);
      final hue = (bgHsv.hue + (t * hueShift)) % 360.0;
      final val = (bgHsv.value + t * (baseHsv.value * 0.4 - bgHsv.value)).clamp(0.04, 0.95);
      final sat = (bgHsv.saturation + t * (baseHsv.saturation * 0.6 - bgHsv.saturation)).clamp(0.1, 0.95);
      newColors.add(HSVColor.fromAHSV(1.0, hue < 0 ? hue + 360 : hue, sat, val).toColor());
    }

    final newStops = [
      for (int i = 0; i < count; i++) i / (count - 1)
    ];

    onColorsChanged(newColors);
    onStopsChanged?.call(newStops);
  }

  void _reorderStops(int oldIndex, int newIndex) {
    if (oldIndex == newIndex || oldIndex < 0 || oldIndex >= colors.length || newIndex < 0 || newIndex >= colors.length) {
      return;
    }
    final updatedColors = List<Color>.from(colors);
    final updatedStops = List<double>.from(_effectiveStops);

    final itemColor = updatedColors.removeAt(oldIndex);
    final itemStop = updatedStops.removeAt(oldIndex);

    updatedColors.insert(newIndex, itemColor);
    updatedStops.insert(newIndex, itemStop);

    onColorsChanged(updatedColors);
    onStopsChanged?.call(updatedStops);
  }

  void _moveStop(int index, int delta) {
    final target = index + delta;
    if (target >= 0 && target < colors.length) {
      _reorderStops(index, target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStops = _effectiveStops;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Barra Interativa de Gradiente com Suporte a Drag Livre de Posição dos Pinos
        LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            const badgeSize = 24.0;
            final availableWidth = math.max(10.0, trackWidth - badgeSize);

            return Container(
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: colors.length >= 2 ? colors : [Colors.black, Colors.white],
                  stops: currentStops,
                ),
                border: Border.all(color: Colors.white24, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: colors.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final color = entry.value;
                  final stopOffset = (idx < currentStops.length ? currentStops[idx] : (idx / (colors.length - 1))).clamp(0.0, 1.0);
                  final leftPos = availableWidth * stopOffset;

                  return Positioned(
                    left: leftPos,
                    top: 6,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        final deltaOffset = details.delta.dx / availableWidth;
                        final newOffset = (stopOffset + deltaOffset).clamp(0.0, 1.0);
                        _updateStopOffset(idx, newOffset);
                      },
                      child: Tooltip(
                        message: 'Parada ${idx + 1}: ${(stopOffset * 100).round()}% (Arraste para mover)',
                        child: _buildDraggableStopBadge(idx, color, stopOffset),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // 2. Ações de Harmonia, Geração Aleatória e Adicionar Parada
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

        // 3. Lista de Cores dos Stops com Ajuste Fino de Posição (%)
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: colors.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (ctx, index) {
            final color = colors[index];
            final stop = (index < currentStops.length ? currentStops[index] : (index / (colors.length - 1))).clamp(0.0, 1.0);
            final percent = (stop * 100).round();
            final canRemove = colors.length > 2;
            final canMoveUp = index > 0;
            final canMoveDown = index < colors.length - 1;

            return Row(
              children: [
                // Indicador de Posição Numérica
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
                    label: 'Parada ${index + 1} ($percent%)',
                    color: color,
                    onColorChanged: (c) => _updateColorAt(index, c),
                  ),
                ),

                const SizedBox(width: 6),

                // Tag Visual da Porcentagem da Faixa
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: MoscaroTokens.auroraBlue,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                // Botão Mover para Cima
                IconButton(
                  icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                  color: canMoveUp ? Colors.white70 : Colors.white24,
                  tooltip: 'Mover Ordem para Cima',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: canMoveUp ? () => _moveStop(index, -1) : null,
                ),

                // Botão Mover para Baixo
                IconButton(
                  icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                  color: canMoveDown ? Colors.white70 : Colors.white24,
                  tooltip: 'Mover Ordem para Baixo',
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

  Widget _buildDraggableStopBadge(int idx, Color c, double stopOffset) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 6,
            spreadRadius: 1,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: MoscaroTokens.auroraBlue.withValues(alpha: 0.35),
            blurRadius: 8,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '${idx + 1}',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}
