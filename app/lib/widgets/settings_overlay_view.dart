import 'package:flutter/material.dart';
import 'settings_models.dart';
import 'settings_page_view.dart';

/// Overlay animado e com transição suave Moscaro v2 para a visualização de Configurações no Canvas.
/// Substitui o corte seco de visibilidade por um fade & scale sutil e refinado com IgnorePointer reativo.
class SettingsOverlayView extends StatelessWidget {
  final bool isOpen;
  final double leftOffset;
  final SettingsCategory activeCategory;
  final AppSettingsState settings;
  final ValueChanged<AppSettingsState> onUpdateSettings;
  final VoidCallback onResetCategory;

  const SettingsOverlayView({
    super.key,
    required this.isOpen,
    this.leftOffset = 0.0,
    required this.activeCategory,
    required this.settings,
    required this.onUpdateSettings,
    required this.onResetCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: leftOffset,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !isOpen,
        child: AnimatedOpacity(
          opacity: isOpen ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 240),
          curve: isOpen ? Curves.easeOutCubic : Curves.easeInCubic,
          child: AnimatedScale(
            scale: isOpen ? 1.0 : 0.98,
            duration: const Duration(milliseconds: 240),
            curve: isOpen ? Curves.easeOutCubic : Curves.easeInCubic,
            child: SettingsPageView(
              activeCategory: activeCategory,
              settings: settings,
              onUpdateSettings: onUpdateSettings,
              onResetCategory: onResetCategory,
            ),
          ),
        ),
      ),
    );
  }
}
