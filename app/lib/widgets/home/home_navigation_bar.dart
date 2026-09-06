import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/theme_models.dart';
import '../../theme/moscaro_theme_controller.dart';
import '../../theme/moscaro_v2_tokens.dart';
import '../svg_icon.dart';

/// Barra de Navegação Superior do Home Hub do conNotes (Moscaro v2 Pro Max).
/// Apresenta:
/// - Logo Vetorial e Badge de Versão Moscaro v2.
/// - Segmented Pill Tab Bar ('Notas & Dispositivos' | 'Chat IA Global').
/// - Busca rápida com atalho `Ctrl+K`.
/// - Alternância rápida de tema e botão de configurações.
class HomeNavigationBar extends StatelessWidget {
  final int selectedTabIndex;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback onOpenSettings;
  final TextEditingController? searchController;
  final FocusNode? searchFocusNode;

  const HomeNavigationBar({
    super.key,
    required this.selectedTabIndex,
    required this.onTabChanged,
    this.onSearchChanged,
    required this.onOpenSettings,
    this.searchController,
    this.searchFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MoscaroThemeController.instance,
      builder: (context, _) {
        final theme = MoscaroThemeController.instance.currentTheme;
        final accent = theme.accentPrimary;

        return Stack(
          alignment: Alignment.center,
          children: [
            // 1. Barra com Logo a Esquerda e Busca / Configuracoes a Direita
            Row(
              children: [
                _buildBrandSection(theme, accent),
                const Spacer(),
                _buildQuickSearchBox(theme, accent),
                const SizedBox(width: 12),
                _buildSettingsButton(theme, accent),
              ],
            ),

            // 2. Segmented Pill Tab Bar Centralizado (Notas & Dispositivos | Chat IA Global)
            _buildSegmentedTabBar(theme, accent),
          ],
        );
      },
    );
  }

  Widget _buildBrandSection(ThemeDefinition theme, Color accent) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.35),
                theme.accentSecondary.withValues(alpha: 0.15),
              ],
            ),
            border: Border.all(
              color: accent.withValues(alpha: 0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.25),
                blurRadius: 12,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Center(
            child: SvgIcon(
              assetName: 'app_logo',
              color: accent,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'conNotes',
          style: TextStyle(
            color: MoscaroTokens.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedTabBar(ThemeDefinition theme, Color accent) {
    final tabs = [
      (0, 'Notas & Dispositivos', 'card'),
      (1, 'Chat IA Global', 'ai'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.glassColor,
        borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
        border: Border.all(
          color: theme.glassColor,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: tabs.map((tab) {
          final isSelected = selectedTabIndex == tab.$1;
          return GestureDetector(
            onTap: () => onTabChanged(tab.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? accent.withValues(alpha: 0.25) : Colors.transparent,
                borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
                border: Border.all(
                  color: isSelected ? accent.withValues(alpha: 0.8) : Colors.transparent,
                  width: 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.25),
                          blurRadius: 12,
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  SvgIcon(
                    assetName: tab.$3,
                    color: isSelected ? accent : MoscaroTokens.iconInactive,
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tab.$2,
                    style: TextStyle(
                      color: isSelected ? MoscaroTokens.textPrimary : MoscaroTokens.textSecondary,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickSearchBox(ThemeDefinition theme, Color accent) {
    return Container(
      width: 240,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: theme.glassColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.glassColor,
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          SvgIcon(
            assetName: 'search',
            color: MoscaroTokens.textMuted,
            size: 15,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: searchController,
              focusNode: searchFocusNode,
              onChanged: onSearchChanged,
              style: TextStyle(
                color: MoscaroTokens.textPrimary,
                fontSize: 12.5,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar notas, tags...',
                hintStyle: TextStyle(
                  color: MoscaroTokens.textMuted,
                  fontSize: 12.5,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: MoscaroTokens.isLight ? Colors.black12 : Colors.white10,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: MoscaroTokens.isLight ? Colors.black12 : Colors.white12,
                width: 0.8,
              ),
            ),
            child: Text(
              'Ctrl+K',
              style: TextStyle(
                color: MoscaroTokens.textMuted,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsButton(ThemeDefinition theme, Color accent) {
    return Tooltip(
      message: 'Configurações Globais',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onOpenSettings,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: 20.0,
                sigmaY: 20.0,
              ),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: theme.backgroundSurface.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.35),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.12),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Center(
                  child: SvgIcon(
                    assetName: 'settings',
                    color: accent.withValues(alpha: 0.85),
                    size: 17,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
