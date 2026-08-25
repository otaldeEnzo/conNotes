import 'package:flutter/material.dart';
import '../theme/moscaro_theme_controller.dart';

/// Componente de Alternância (Switch / Toggle) estilizado no padrão Moscaro v2 Pro Max.
class SettingsToggleTile extends StatefulWidget {
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsToggleTile({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  State<SettingsToggleTile> createState() => _SettingsToggleTileState();
}

class _SettingsToggleTileState extends State<SettingsToggleTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = MoscaroThemeController.instance.currentTheme;
    final accent = theme.accentPrimary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => widget.onChanged(!widget.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: _isHovered
                ? theme.backgroundSurface.withValues(alpha: 0.65)
                : theme.backgroundSurface.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? accent.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.08),
              width: 1.1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 48,
                height: 26,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: widget.value
                      ? accent.withValues(alpha: 0.32)
                      : Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: widget.value
                        ? accent.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.18),
                    width: 1.2,
                  ),
                  boxShadow: widget.value
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 10,
                            spreadRadius: -1,
                          ),
                        ]
                      : [],
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  alignment: widget.value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.value ? accent : Colors.white70,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
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
