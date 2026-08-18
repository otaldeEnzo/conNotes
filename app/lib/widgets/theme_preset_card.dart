import 'package:flutter/material.dart';
import '../models/theme_models.dart';
import 'moscaro_glass_popup_menu.dart';

/// Card Visual de Seleção e Gerenciamento de Tema (Moscaro v2 Pro Max).
class ThemePresetCard extends StatefulWidget {
  final ThemeDefinition theme;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;
  final VoidCallback? onExport;

  const ThemePresetCard({
    super.key,
    required this.theme,
    required this.isSelected,
    required this.onSelect,
    this.onEdit,
    this.onDuplicate,
    this.onDelete,
    this.onExport,
  });

  @override
  State<ThemePresetCard> createState() => _ThemePresetCardState();
}

class _ThemePresetCardState extends State<ThemePresetCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final isCardLight = t.backgroundSurface.computeLuminance() > 0.45;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: t.backgroundDeep,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected
                  ? t.accentPrimary
                  : (_isHovered
                      ? t.accentPrimary.withValues(alpha: 0.5)
                      : (isCardLight ? Colors.black12 : Colors.white.withValues(alpha: 0.1))),
              width: widget.isSelected ? 1.6 : 1.0,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: t.accentPrimary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                  ]
                : (_isHovered
                    ? [
                        BoxShadow(
                          color: t.accentPrimary.withValues(alpha: 0.1),
                          blurRadius: 10,
                        ),
                      ]
                    : []),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Mini Preview do Fundo com Grid e Cores
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: t.bgMode == CanvasBackgroundMode.solidColor ? t.backgroundDeep : null,
                      gradient: t.bgMode == CanvasBackgroundMode.solidColor
                          ? null
                          : LinearGradient(
                              colors: t.effectiveGradientColors,
                              stops: [
                                for (int i = 0; i < t.effectiveGradientColors.length; i++)
                                  i / (t.effectiveGradientColors.length - 1)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                    ),
                    child: Stack(
                      children: [
                        // Padrão de Pontos em miniatura
                        CustomPaint(
                          size: Size.infinite,
                          painter: _MiniDotGridPainter(dotColor: t.dotGridColor),
                        ),

                        // Halo do Mouse e Acentos no Canto
                        Positioned(
                          right: -15,
                          top: -15,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  t.mouseGlowColor.withValues(alpha: 0.45),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Paleta Rápida em Miniatura (Pílula Flutuante)
                        Positioned(
                          bottom: 8,
                          left: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isCardLight ? Colors.white.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.5)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCardLight ? Colors.black12 : Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: t.stemPalette.take(5).map((c) {
                                return Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isCardLight ? Colors.black26 : Colors.white.withValues(alpha: 0.4),
                                      width: 0.5,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),

                        // Badge de Ativo / Custom
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.isSelected)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: t.accentPrimary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'ATIVO',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              if (t.isCustom)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isCardLight ? Colors.black.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isCardLight ? Colors.black12 : Colors.white24,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    'CUSTOM',
                                    style: TextStyle(
                                      color: isCardLight ? const Color(0xFF0F172A) : Colors.white,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Menu de 3 Pontinhos no Canto Superior Direito com Vidro Líquido Real
                        Positioned(
                          top: 6,
                          right: 6,
                          child: MoscaroGlassPopupMenu<String>(
                            onSelected: (action) {
                              switch (action) {
                                case 'edit':
                                  widget.onEdit?.call();
                                  break;
                                case 'duplicate':
                                  widget.onDuplicate?.call();
                                  break;
                                case 'export':
                                  widget.onExport?.call();
                                  break;
                                case 'delete':
                                  widget.onDelete?.call();
                                  break;
                              }
                            },
                            items: [
                              if (t.isCustom)
                                const MoscaroGlassMenuItem(
                                  value: 'edit',
                                  label: 'Editar Tema',
                                  icon: Icons.edit_rounded,
                                ),
                              const MoscaroGlassMenuItem(
                                value: 'duplicate',
                                label: 'Duplicar',
                                icon: Icons.copy_rounded,
                              ),
                              const MoscaroGlassMenuItem(
                                value: 'export',
                                label: 'Exportar JSON',
                                icon: Icons.file_upload_outlined,
                              ),
                              if (t.isCustom)
                                const MoscaroGlassMenuItem(
                                  value: 'delete',
                                  label: 'Excluir',
                                  icon: Icons.delete_outline_rounded,
                                  isDestructive: true,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Título do Tema & Descrição (Fundo e Tipografia Derivados do Próprio Tema)
                Container(
                  color: t.backgroundSurface,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: t.accentPrimary,
                              boxShadow: [
                                BoxShadow(
                                  color: t.accentPrimary.withValues(alpha: 0.7),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              t.name,
                              style: TextStyle(
                                color: isCardLight ? const Color(0xFF0F172A) : Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        t.preset.description,
                        style: TextStyle(
                          color: isCardLight ? const Color(0xFF475569) : Colors.white54,
                          fontSize: 10.5,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniDotGridPainter extends CustomPainter {
  final Color dotColor;
  const _MiniDotGridPainter({required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    const spacing = 12.0;
    for (double x = 8; x < size.width; x += spacing) {
      for (double y = 8; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
