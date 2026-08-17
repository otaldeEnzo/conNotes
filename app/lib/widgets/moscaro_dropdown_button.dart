import 'package:flutter/material.dart';
import '../theme/moscaro_v2_extension.dart';

/// Um botão de menu expansível reutilizável que segue perfeitamente o design system Moscaro v2.
/// Pode ser usado em qualquer lugar do app (ex: toolbar, barras laterais, etc.).
class MoscaroDropdownButton<T> extends StatefulWidget {
  final Widget icon;
  final String tooltip;
  final List<MoscaroDropdownItem<T>> items;
  final ValueChanged<T> onSelected;
  final double dropdownWidth;
  final ValueChanged<bool>? onOpenChanged;
  final double? customBottom;
  final double? customLeft;

  const MoscaroDropdownButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.items,
    required this.onSelected,
    this.dropdownWidth = 180.0,
    this.onOpenChanged,
    this.customBottom,
    this.customLeft,
  });

  @override
  State<MoscaroDropdownButton<T>> createState() => _MoscaroDropdownButtonState<T>();
}

class _MoscaroDropdownButtonState<T> extends State<MoscaroDropdownButton<T>> {
  OverlayEntry? _overlayEntry;

  void _showDropdown() {
    if (_overlayEntry != null) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final buttonOffset = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;

    // Centraliza o dropdown horizontalmente com o botão ativador caso customLeft não seja informado
    final double dropdownLeft = widget.customLeft ?? (buttonOffset.dx - (widget.dropdownWidth / 2) + (buttonSize.width / 2));
    final double dropdownBottom = widget.customBottom ?? (MediaQuery.of(context).size.height - buttonOffset.dy + 8);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Captura cliques fora para fechar o menu
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeDropdown,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          // O Dropdown flutuante em Vidro Moscaro
          Positioned(
            left: dropdownLeft,
            bottom: dropdownBottom,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: widget.dropdownWidth,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isLast = index == widget.items.length - 1;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            widget.onSelected(item.value);
                            _closeDropdown();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: item.child,
                          ),
                        ),
                        if (!isLast) const Divider(height: 1, color: Colors.white12),
                      ],
                    );
                  }).toList(),
                ),
              ).moscaroV2(
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(vertical: 4),
                borderWidth: 1.2,
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    widget.onOpenChanged?.call(true);
  }

  void _closeDropdown() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      widget.onOpenChanged?.call(false);
    }
  }

  @override
  void dispose() {
    _closeDropdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: widget.icon,
      onPressed: _showDropdown,
      tooltip: widget.tooltip,
    );
  }
}

/// Item de dado e widget para o MoscaroDropdownButton
class MoscaroDropdownItem<T> {
  final T value;
  final Widget child;

  const MoscaroDropdownItem({
    required this.value,
    required this.child,
  });
}
