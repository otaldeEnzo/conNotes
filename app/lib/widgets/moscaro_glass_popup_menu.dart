import 'package:flutter/material.dart';
import '../theme/moscaro_v2_extension.dart';
import '../theme/moscaro_v2_tokens.dart';
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

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'MoscaroGlassMenu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, anim1, anim2) {
        return ListenableBuilder(
          listenable: MoscaroThemeController.instance,
          builder: (context, _) {
            final activeTheme = MoscaroThemeController.instance.currentTheme;
            final activeAccent = activeTheme.accentPrimary;
            final isBlurEnabled = activeTheme.enableModalsBlur;
            final effectiveBlur = isBlurEnabled ? activeTheme.blurSigma : 0.0;

            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(ctx).pop(),
                  ),
                ),
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
                            accentColor: activeAccent,
                            onTap: () {
                              Navigator.of(ctx).pop();
                              onSelected(item.value);
                            },
                          );
                        }).toList(),
                      ),
                    ).moscaroV2(
                      borderRadius: 16,
                      blurSigma: effectiveBlur,
                      enableBlur: isBlurEnabled && effectiveBlur > 0,
                      backgroundColor: MoscaroTokens.isLight
                          ? Colors.white.withValues(alpha: 0.75)
                          : activeTheme.backgroundSurface.withValues(alpha: 0.35),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      borderColor: activeAccent.withValues(alpha: 0.5),
                      borderWidth: 1.1,
                      customShadows: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 24,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: activeAccent.withValues(alpha: 0.25),
                          blurRadius: 14,
                          spreadRadius: -1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
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
    return ListenableBuilder(
      listenable: MoscaroThemeController.instance,
      builder: (context, _) {
        final theme = MoscaroThemeController.instance.currentTheme;
        final accent = theme.accentPrimary;
        final isBlurEnabled = theme.enableCardsBlur || theme.enableModalsBlur;
        final effectiveBlur = isBlurEnabled ? theme.blurSigma : 0.0;

        Widget buttonWidget = GestureDetector(
          onTap: () => _showMenu(context),
          behavior: HitTestBehavior.opaque,
          child: icon ??
              Container(
                padding: const EdgeInsets.all(6),
                child: SvgIcon(name: 'more_vertical', color: accent.withValues(alpha: 0.85), size: 14),
              ).moscaroV2(
                borderRadius: 10,
                blurSigma: effectiveBlur,
                enableBlur: isBlurEnabled && effectiveBlur > 0,
                backgroundColor: MoscaroTokens.isLight
                    ? Colors.white.withValues(alpha: 0.75)
                    : theme.backgroundSurface.withValues(alpha: 0.35),
                borderColor: accent.withValues(alpha: 0.35),
                borderWidth: 0.8,
                padding: const EdgeInsets.all(6),
                customShadows: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.1),
                    blurRadius: 8,
                    spreadRadius: -2,
                  ),
                ],
              ),
        );

        if (tooltip != null && tooltip!.isNotEmpty) {
          return Tooltip(message: tooltip!, child: buttonWidget);
        }
        return buttonWidget;
      },
    );
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
