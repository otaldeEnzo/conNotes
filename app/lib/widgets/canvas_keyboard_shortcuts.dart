import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CanvasKeyboardShortcuts extends StatelessWidget {
  final Widget child;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onDelete;
  final VoidCallback? onSelectAll;

  const CanvasKeyboardShortcuts({
    super.key,
    required this.child,
    this.onUndo,
    this.onRedo,
    this.onDelete,
    this.onSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      canRequestFocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          final isCtrl = HardwareKeyboard.instance.isControlPressed;
          final isShift = HardwareKeyboard.instance.isShiftPressed;

          if (event.logicalKey == LogicalKeyboardKey.delete || 
              event.logicalKey == LogicalKeyboardKey.backspace) {
            onDelete?.call();
            return KeyEventResult.handled;
          }

          if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyZ) {
            if (isShift) {
              onRedo?.call();
            } else {
              onUndo?.call();
            }
            return KeyEventResult.handled;
          }

          if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyA) {
            onSelectAll?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
