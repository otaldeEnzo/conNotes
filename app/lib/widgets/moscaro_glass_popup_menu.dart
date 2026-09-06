import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_extension.dart';
import '../theme/moscaro_theme_controller.dart';
import 'svg_icon.dart';

class MoscaroGlassMenuItem<T> {
  final T value;
  final String label;
  final String? svgIconName;
  final IconData? icon;
  final Color? color;
  final bool isDestructive;
  final bool isDivider;

  const MoscaroGlassMenuItem({
    required this.value,
    required this.label,
    this.svgIconName,
    this.icon,
    this.color,
    this.isDestructive = false,
    this.isDivider = false,
  });

  const MoscaroGlassMenuItem.divider({
    required this.value,
  })  : label = '',
        svgIconName = null,
        icon = null,
        color = null,
        isDestructive = false,
        isDivider = true;
}

/// Botão e Menu Popover Flutuante no Padrão Moscaro v2 com Vidro Líquido Real e Blur.
class MoscaroGlassPopupMenu<T> extends StatelessWidget {
  final List<MoscaroGlassMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final Widget? icon;
  final String? tooltip;

  const MoscaroGlassPopupMenu({
    super.key,
    required this.items,
    required this.onSelected,
    this.icon,
    this.tooltip,
  });

  void _showMenu(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final theme = MoscaroThemeController.instance.currentTheme;
    final accent = theme.accentPrimary;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'MoscaroGlassMenu',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, anim1, anim2) {
        return Stack(
          children: [
            Positioned(
              left: (offset.dx + size.width - 175).clamp(12.0, MediaQuery.of(context).size.width - 187.0),
              top: offset.dy + size.height + 6,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  width: 175,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: items.map((item) {
                      if (item.isDivider) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        );
                      }
                      return _GlassMenuItemWidget<T>(
                        item: item,
                        accentColor: accent,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          onSelected(item.value);
                        },
                      );
                    }).toList(),
                  ),
                ).moscaroV2(
                  borderRadius: 16,
                  blurSigma: 35.0,
                  enableBlur: true,
                  backgroundColor: theme.backgroundSurface.withValues(alpha: 0.65),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  borderColor: accent.withValues(alpha: 0.5),
                  borderWidth: 1.1,
                  customShadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 28,
                      spreadRadius: 2,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: accent.withValues(alpha: 0.2),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = MoscaroThemeController.instance.currentTheme;
    final accent = theme.accentPrimary;

    Widget buttonWidget = GestureDetector(
      onTap: () => _showMenu(context),
      behavior: HitTestBehavior.opaque,
      child: icon ??
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: 20.0,
                sigmaY: 20.0,
              ),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.backgroundSurface.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.1),
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: SvgIcon(name: 'more_vertical', color: accent.withValues(alpha: 0.85), size: 14),
              ),
            ),
          ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: buttonWidget);
    }
    return buttonWidget;
  }
}

class _GlassMenuItemWidget<T> extends StatefulWidget {
  final MoscaroGlassMenuItem<T> item;
  final Color accentColor;
  final VoidCallback onTap;

  const _GlassMenuItemWidget({
    required this.item,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_GlassMenuItemWidget<T>> createState() => _GlassMenuItemWidgetState<T>();
}

class _GlassMenuItemWidgetState<T> extends State<_GlassMenuItemWidget<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDestructive = item.isDestructive;
    final color = isDestructive
        ? const Color(0xFFEF4444)
        : (item.color ?? (_isHovered ? widget.accentColor : Colors.white));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDestructive
                    ? const Color(0xFFEF4444).withValues(alpha: 0.14)
                    : widget.accentColor.withValues(alpha: 0.14))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isHovered
                  ? (isDestructive
                      ? const Color(0xFFEF4444).withValues(alpha: 0.35)
                      : widget.accentColor.withValues(alpha: 0.35))
                  : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              if (item.svgIconName != null)
                SvgIcon(name: item.svgIconName!, size: 14, color: color)
              else if (item.icon != null)
                Icon(item.icon, size: 14, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: _isHovered ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
