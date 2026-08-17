import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import 'smart_shapes.dart';
import 'svg_icon.dart';

/// Sub-Barra Flutuante de Formas Geométricas (Design Moscaro v2).
/// Contém seletor de categorias principais e suas respectivas sub-formas.
class ShapesSubBar extends StatefulWidget {
  final bool isVisible;
  final ShapeType activeShape;
  final ValueChanged<ShapeType> onSelectShape;

  const ShapesSubBar({
    super.key,
    required this.isVisible,
    required this.activeShape,
    required this.onSelectShape,
  });

  @override
  State<ShapesSubBar> createState() => _ShapesSubBarState();
}

class _ShapesSubBarState extends State<ShapesSubBar> {
  ShapeCategory _activeCategory = ShapeCategory.lines;

  @override
  void initState() {
    super.initState();
    _activeCategory = _categoryForShape(widget.activeShape);
  }

  @override
  void didUpdateWidget(ShapesSubBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeShape != widget.activeShape) {
      _activeCategory = _categoryForShape(widget.activeShape);
    }
  }

  ShapeCategory _categoryForShape(ShapeType type) {
    switch (type) {
      case ShapeType.line:
      case ShapeType.arrow:
      case ShapeType.doubleArrow:
        return ShapeCategory.lines;
      case ShapeType.circle:
      case ShapeType.ellipse:
        return ShapeCategory.circles;
      case ShapeType.triangle:
      case ShapeType.triangleRight:
        return ShapeCategory.triangles;
      case ShapeType.rectangle:
      case ShapeType.diamond:
      case ShapeType.hexagon:
        return ShapeCategory.polygons;
    }
  }

  ShapeType _defaultShapeForCategory(ShapeCategory category) {
    switch (category) {
      case ShapeCategory.lines:
        return ShapeType.line;
      case ShapeCategory.circles:
        return ShapeType.circle;
      case ShapeCategory.triangles:
        return ShapeType.triangle;
      case ShapeCategory.polygons:
        return ShapeType.rectangle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.isVisible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        offset: widget.isVisible ? Offset.zero : const Offset(0, 0.4),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          scale: widget.isVisible ? 1.0 : 0.88,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: widget.isVisible ? 1.0 : 0.0,
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
                  // 1. Categorias Principais
                  _buildCategoryButton(ShapeCategory.lines, 'Linhas', 'shape_line'),
                  const SizedBox(width: 3),
                  _buildCategoryButton(ShapeCategory.circles, 'Círculos', 'shape_circle'),
                  const SizedBox(width: 3),
                  _buildCategoryButton(ShapeCategory.triangles, 'Triângulos', 'shape_triangle'),
                  const SizedBox(width: 3),
                  _buildCategoryButton(ShapeCategory.polygons, 'Polígonos', 'shape_rect'),

                  const SizedBox(width: 6),
                  Container(width: 1, height: 18, color: Colors.white24),
                  const SizedBox(width: 6),

                  // 2. Sub-formas da categoria ativa
                  ..._buildSubShapesForCategory(_activeCategory),
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

  Widget _buildCategoryButton(ShapeCategory category, String label, String assetName) {
    final isSelected = _activeCategory == category;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _activeCategory = category;
          });
          final defaultShape = _defaultShapeForCategory(category);
          widget.onSelectShape(defaultShape);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isSelected
                ? MoscaroTokens.auroraBlue.withValues(alpha: 0.18)
                : Colors.transparent,
            border: Border.all(
              color: isSelected ? MoscaroTokens.auroraBlue : Colors.transparent,
              width: 1.0,
            ),
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
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSubShapesForCategory(ShapeCategory category) {
    final List<Widget> items = [];

    switch (category) {
      case ShapeCategory.lines:
        items.add(_buildShapeItem(ShapeType.line, 'Reta', 'shape_line'));
        items.add(_buildShapeItem(ShapeType.arrow, 'Vetor', 'shape_arrow'));
        items.add(_buildShapeItem(ShapeType.doubleArrow, 'Duplo', 'shape_double_arrow'));
        break;
      case ShapeCategory.circles:
        items.add(_buildShapeItem(ShapeType.circle, 'Círculo', 'shape_circle'));
        items.add(_buildShapeItem(ShapeType.ellipse, 'Elipse', 'shape_ellipse'));
        break;
      case ShapeCategory.triangles:
        items.add(_buildShapeItem(ShapeType.triangle, 'Equilátero', 'shape_triangle'));
        items.add(_buildShapeItem(ShapeType.triangleRight, 'Retângulo (90°)', 'shape_triangle_right'));
        break;
      case ShapeCategory.polygons:
        items.add(_buildShapeItem(ShapeType.rectangle, 'Retângulo', 'shape_rect'));
        items.add(_buildShapeItem(ShapeType.diamond, 'Losango', 'shape_diamond'));
        items.add(_buildShapeItem(ShapeType.hexagon, 'Hexágono', 'shape_hexagon'));
        break;
    }

    return items;
  }

  Widget _buildShapeItem(ShapeType type, String label, String assetName) {
    final isSelected = widget.activeShape == type;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => widget.onSelectShape(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isSelected
                  ? MoscaroTokens.auroraPurple.withValues(alpha: 0.25)
                  : Colors.transparent,
              border: Border.all(
                color: isSelected ? MoscaroTokens.auroraPurple : Colors.white12,
                width: isSelected ? 1.4 : 0.8,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: MoscaroTokens.auroraPurple.withValues(alpha: 0.3),
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
                  size: 13,
                  color: isSelected ? MoscaroTokens.auroraPurple : Colors.white70,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
