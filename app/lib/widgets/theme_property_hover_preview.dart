import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_extension.dart';

/// Tipos de Propriedades Temáticas para Pré-visualização Contextual por Hover.
enum ThemePropertyType {
  primaryAccent,
  secondaryAccent,
  dotGrid,
  mouseGlow,
  glassFilm,
  borderGlow,
  gradientBg,
  solidBg,
  stemPalette;

  String get title {
    switch (this) {
      case ThemePropertyType.primaryAccent:
        return 'Acento Primário';
      case ThemePropertyType.secondaryAccent:
        return 'Acento Secundário';
      case ThemePropertyType.dotGrid:
        return 'Matriz de Pontos (Grid)';
      case ThemePropertyType.mouseGlow:
        return 'Brilho do Mouse (Glow)';
      case ThemePropertyType.glassFilm:
        return 'Película de Vidro Líquido';
      case ThemePropertyType.borderGlow:
        return 'Borda com Glow Ativo';
      case ThemePropertyType.gradientBg:
        return 'Gradiente do Canvas';
      case ThemePropertyType.solidBg:
        return 'Fundo Sólido';
      case ThemePropertyType.stemPalette:
        return 'Paleta de Canetas STEM';
    }
  }

  String get description {
    switch (this) {
      case ThemePropertyType.primaryAccent:
        return 'Define o destaque principal dos botões ativos, abas, ícones de foco e elementos de ação.';
      case ThemePropertyType.secondaryAccent:
        return 'Acentua gradientes secundários, badges de status, controles deslizantes e realces.';
      case ThemePropertyType.dotGrid:
        return 'Define a cor e densidade visual dos pontos de grade matemática e isométrica do canvas.';
      case ThemePropertyType.mouseGlow:
        return 'Gera o halo de luz reativo que segue dinamicamente a ponta da caneta stylus ou o cursor.';
      case ThemePropertyType.glassFilm:
        return 'Determina o tom de cor e transparência da película de vidro dos menus, barras e diálogos.';
      case ThemePropertyType.borderGlow:
        return 'Controla o brilho neon das bordas finas dos painéis e pílulas flutuantes.';
      case ThemePropertyType.gradientBg:
        return 'Define as transições de cor do plano de fundo profundo do ambiente de anotações.';
      case ThemePropertyType.solidBg:
        return 'Define a tonalidade uniforme da superfície do canvas.';
      case ThemePropertyType.stemPalette:
        return 'Configura as 6 cores de caneta de acesso rápido na barra de ferramentas superior.';
    }
  }
}

/// Envoltório Interativo que dispara uma Pré-visualização Flutuante após 500ms de Hover.
class ThemePropertyHoverPreview extends StatefulWidget {
  final ThemePropertyType propertyType;
  final Color currentColor;
  final Widget child;

  const ThemePropertyHoverPreview({
    super.key,
    required this.propertyType,
    required this.currentColor,
    required this.child,
  });

  @override
  State<ThemePropertyHoverPreview> createState() => _ThemePropertyHoverPreviewState();
}

class _ThemePropertyHoverPreviewState extends State<ThemePropertyHoverPreview> {
  Timer? _hoverTimer;
  OverlayEntry? _overlayEntry;

  void _onMouseEnter(PointerEvent details) {
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _showHoverPreview(details.position);
      }
    });
  }

  void _onMouseExit(PointerEvent details) {
    _hoverTimer?.cancel();
    _removeHoverPreview();
  }

  void _showHoverPreview(Offset cursorGlobalPos) {
    _removeHoverPreview();
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final overlay = Overlay.of(context);
    final size = MediaQuery.of(context).size;
    final boxOffset = renderBox.localToGlobal(Offset.zero);

    // Posicionar o card flutuante inteligentemente acima ou ao lado
    double left = (boxOffset.dx).clamp(16.0, size.width - 290.0);
    double top = boxOffset.dy - 170.0;
    if (top < 20) {
      top = boxOffset.dy + renderBox.size.height + 10;
    }

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: left,
        top: top,
        child: Material(
          color: Colors.transparent,
          child: _HoverSceneCard(
            propertyType: widget.propertyType,
            color: widget.currentColor,
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeHoverPreview() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _removeHoverPreview();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: _onMouseEnter,
      onExit: _onMouseExit,
      child: widget.child,
    );
  }
}

class _HoverSceneCard extends StatelessWidget {
  final ThemePropertyType propertyType;
  final Color color;

  const _HoverSceneCard({
    required this.propertyType,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Mini-Cena Ilustrada em Tempo Real
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: Container(
              height: 86,
              color: const Color(0xFF070B14),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildMiniScene(),
                  ),
                  Positioned(
                    top: 6,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        'PREVIEW AO VIVO',
                        style: TextStyle(
                          color: color,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Título & Descrição de Impacto
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      propertyType.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  propertyType.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).moscaroV2(
      borderRadius: 16,
      padding: EdgeInsets.zero,
      borderColor: color.withValues(alpha: 0.6),
      borderWidth: 1.3,
    );
  }

  Widget _buildMiniScene() {
    switch (propertyType) {
      case ThemePropertyType.primaryAccent:
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color, width: 1.5),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_rounded, color: color, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Ferramenta Ativa',
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );

      case ThemePropertyType.secondaryAccent:
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.05)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.8)),
            ),
            child: Text(
              'Badge de Destaque',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        );

      case ThemePropertyType.dotGrid:
        return CustomPaint(
          size: Size.infinite,
          painter: _DotGridMiniPainter(dotColor: color),
        );

      case ThemePropertyType.mouseGlow:
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DotGridMiniPainter(dotColor: Colors.white24),
              ),
            ),
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [color.withValues(alpha: 0.7), Colors.transparent],
                  ),
                ),
              ),
            ),
            const Center(
              child: Icon(Icons.touch_app_rounded, color: Colors.white, size: 18),
            ),
          ],
        );

      case ThemePropertyType.glassFilm:
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DotGridMiniPainter(dotColor: Colors.white30),
              ),
            ),
            Center(
              child: Container(
                width: 180,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white30, width: 1),
                ),
                child: const Center(
                  child: Text(
                    'Camada de Vidro Translúcida',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        );

      case ThemePropertyType.borderGlow:
        return Center(
          child: Container(
            width: 190,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: color, width: 2),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 14),
              ],
            ),
            child: Center(
              child: Text(
                'Borda Neon Luminosa',
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );

      default:
        return Container(color: color);
    }
  }
}

class _DotGridMiniPainter extends CustomPainter {
  final Color dotColor;

  _DotGridMiniPainter({required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dotColor;
    const spacing = 14.0;
    for (double x = 8; x < size.width; x += spacing) {
      for (double y = 8; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridMiniPainter oldDelegate) => oldDelegate.dotColor != dotColor;
}
