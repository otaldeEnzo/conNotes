import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';

class MoscaroGlassMenuItem<T> {
  final T value;
  final String label;
  final IconData icon;
  final Color? color;
  final bool isDestructive;

  const MoscaroGlassMenuItem({
    required this.value,
    required this.label,
    required this.icon,
    this.color,
    this.isDestructive = false,
  });
}

/// Botão e Menu Popover Flutuante no Padrão Moscaro v2 com Vidro Líquido Real.
class MoscaroGlassPopupMenu<T> extends StatelessWidget {
  final List<MoscaroGlassMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final Widget? icon;

  const MoscaroGlassPopupMenu({
    super.key,
    required this.items,
    required this.onSelected,
    this.icon,
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
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (ctx, anim1, anim2) {
        return Stack(
          children: [
            Positioned(
              left: (offset.dx + size.width - 160).clamp(12.0, MediaQuery.of(context).size.width - 172.0),
              top: offset.dy + size.height + 6,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: items.map((item) {
                      return _GlassMenuItemWidget<T>(
                        item: item,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          onSelected(item.value);
                        },
                      );
                    }).toList(),
                  ),
                ).moscaroV2(
                  borderRadius: 14,
                  enableBlur: MoscaroTokens.enableSubBarsBlur,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  borderColor: MoscaroTokens.auroraBlue.withValues(alpha: 0.35),
                  borderWidth: 1.2,
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
    return GestureDetector(
      onTap: () => _showMenu(context),
      child: icon ??
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 0.8),
            ),
            child: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 14),
          ),
    );
  }
}

class _GlassMenuItemWidget<T> extends StatefulWidget {
  final MoscaroGlassMenuItem<T> item;
  final VoidCallback onTap;

  const _GlassMenuItemWidget({
    required this.item,
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
    final color = item.isDestructive
        ? MoscaroTokens.auroraPink
        : (item.color ?? (item.isDestructive ? MoscaroTokens.auroraPink : Colors.white));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: _isHovered ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 14, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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
