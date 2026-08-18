import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import '../theme/moscaro_theme_controller.dart';
import 'settings_models.dart';
import 'svg_icon.dart';

/// Barra Superior de Configurações no padrão Moscaro v2 (Refinamento UI/UX Pro Max).
class SettingsTabBar extends StatefulWidget {
  final SettingsCategory activeCategory;
  final ValueChanged<SettingsCategory> onSelectCategory;
  final VoidCallback onBackToNotes;

  const SettingsTabBar({
    super.key,
    required this.activeCategory,
    required this.onSelectCategory,
    required this.onBackToNotes,
  });

  @override
  State<SettingsTabBar> createState() => _SettingsTabBarState();
}

class _SettingsTabBarState extends State<SettingsTabBar> {
  SettingsCategory? _hoveredCategory;
  bool _isBackHovered = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MoscaroThemeController.instance,
      builder: (context, _) {
        final isLight = MoscaroTokens.isLight;
        final textPrimary = MoscaroTokens.textPrimary;
        final textSecondary = MoscaroTokens.textSecondary;
        final dividerColor = isLight ? Colors.black12 : Colors.white12;

        return Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Botão de Voltar para Notas
              MouseRegion(
                onEnter: (_) => setState(() => _isBackHovered = true),
                onExit: (_) => setState(() => _isBackHovered = false),
                child: GestureDetector(
                  onTap: widget.onBackToNotes,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isBackHovered
                          ? (isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.12))
                          : (isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isBackHovered
                            ? MoscaroTokens.auroraBlue.withValues(alpha: 0.5)
                            : (isLight ? Colors.black12 : Colors.white12),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgIcon(
                          assetName: 'arrow_left',
                          size: 13,
                          color: _isBackHovered ? MoscaroTokens.auroraBlue : textPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Voltar',
                          style: TextStyle(
                            color: _isBackHovered ? MoscaroTokens.auroraBlue : textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Divisor Vertical Sutil
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Container(
                  width: 1,
                  color: dividerColor,
                ),
              ),

              // 3. Abas de Configurações
              Row(
                mainAxisSize: MainAxisSize.min,
                children: SettingsCategory.values.map((category) {
                  final isSelected = widget.activeCategory == category;
                  final isHovered = _hoveredCategory == category;

                  return MouseRegion(
                    onEnter: (_) => setState(() => _hoveredCategory = category),
                    onExit: (_) => setState(() => _hoveredCategory = null),
                    child: GestureDetector(
                      onTap: () => widget.onSelectCategory(category),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isLight ? MoscaroTokens.auroraBlue.withValues(alpha: 0.15) : MoscaroTokens.auroraBlue.withValues(alpha: 0.20))
                              : (isHovered
                                  ? (isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08))
                                  : Colors.transparent),
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [
                                    MoscaroTokens.auroraBlue.withValues(alpha: isLight ? 0.18 : 0.25),
                                    MoscaroTokens.auroraPurple.withValues(alpha: isLight ? 0.10 : 0.15),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? MoscaroTokens.auroraBlue.withValues(alpha: isLight ? 0.6 : 0.85)
                                : (isHovered
                                    ? (isLight ? Colors.black12 : Colors.white24)
                                    : Colors.transparent),
                            width: isSelected ? 1.3 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: MoscaroTokens.auroraBlue.withValues(alpha: 0.20),
                                    blurRadius: 8,
                                    spreadRadius: -2,
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgIcon(
                              assetName: category.iconName,
                              size: 13,
                              color: isSelected
                                  ? MoscaroTokens.auroraBlue
                                  : (isHovered ? textPrimary : textSecondary),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              category.label,
                              style: TextStyle(
                                color: isSelected
                                    ? (isLight ? MoscaroTokens.auroraBlue : textPrimary)
                                    : (isHovered ? textPrimary : textSecondary),
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ).moscaroV2(
          borderRadius: MoscaroTokens.radiusPill,
          padding: EdgeInsets.zero,
        );
      },
    );
  }
}
