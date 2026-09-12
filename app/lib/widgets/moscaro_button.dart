import 'package:flutter/material.dart';
import '../theme/moscaro_v2_extension.dart';
import '../theme/moscaro_theme_controller.dart';

/// Botão Genérico Universal do Design System `moscaro-v2`
/// Suporta modo normal e expansível garantindo mesmo padrão visual.
class MoscaroButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final bool isExpandable;
  final Widget? expandedChild;

  const MoscaroButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.isExpandable = false,
    this.expandedChild,
  });

  @override
  State<MoscaroButton> createState() => _MoscaroButtonState();
}

class _MoscaroButtonState extends State<MoscaroButton> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MoscaroThemeController.instance,
      builder: (context, _) {
        final theme = MoscaroThemeController.instance.currentTheme;
        final isBlurEnabled = theme.enableModalsBlur;
        final effectiveBlur = isBlurEnabled ? theme.blurSigma : 0.0;

        final content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                widget.onPressed();
                if (widget.isExpandable) {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                }
              },
              child: widget.child,
            ),
            if (widget.isExpandable && _isExpanded && widget.expandedChild != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: widget.expandedChild!,
              ),
          ],
        );

        return content.moscaroV2(
          borderRadius: 16.0,
          blurSigma: effectiveBlur,
          enableBlur: isBlurEnabled && effectiveBlur > 0,
        );
      },
    );
  }
}
