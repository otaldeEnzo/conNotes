import 'package:flutter/material.dart';

/// Painel de Controle de Presença de Desfoque (Blur / BackdropFilter) por Componente Visual.
class ThemeBlurTogglesCard extends StatelessWidget {
  final bool enableSidebarBlur;
  final bool enableToolbarBlur;
  final bool enableSubBarsBlur;
  final bool enableModalsBlur;
  final bool enableInstrumentsBlur;
  final Color accentColor;
  final ValueChanged<bool> onSidebarChanged;
  final ValueChanged<bool> onToolbarChanged;
  final ValueChanged<bool> onSubBarsChanged;
  final ValueChanged<bool> onModalsChanged;
  final ValueChanged<bool> onInstrumentsChanged;

  const ThemeBlurTogglesCard({
    super.key,
    required this.enableSidebarBlur,
    required this.enableToolbarBlur,
    required this.enableSubBarsBlur,
    required this.enableModalsBlur,
    required this.enableInstrumentsBlur,
    required this.accentColor,
    required this.onSidebarChanged,
    required this.onToolbarChanged,
    required this.onSubBarsChanged,
    required this.onModalsChanged,
    required this.onInstrumentsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.blur_on_rounded, color: accentColor, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Desfoque de Fundo (Blur) por Componente',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Ligue ou desligue o efeito de vidro líquido para economizar GPU ou personalizar a clareza visual.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          _buildToggleItem(
            label: 'Barra Lateral de Notas (Sidebar)',
            subtitle: 'Lista de cadernos e miniaturas',
            value: enableSidebarBlur,
            onChanged: onSidebarChanged,
          ),
          const Divider(height: 12, color: Colors.white10),
          _buildToggleItem(
            label: 'Toolbar Principal de Ferramentas',
            subtitle: 'Pílula superior de canetas e ações',
            value: enableToolbarBlur,
            onChanged: onToolbarChanged,
          ),
          const Divider(height: 12, color: Colors.white10),
          _buildToggleItem(
            label: 'Sub-barras e Menus Expansíveis',
            subtitle: 'Sub-barras de canetas, seletores e cards de grade',
            value: enableSubBarsBlur,
            onChanged: onSubBarsChanged,
          ),
          const Divider(height: 12, color: Colors.white10),
          _buildToggleItem(
            label: 'Diálogos e Modais',
            subtitle: 'Janelas de configuração e popups flutuantes',
            value: enableModalsBlur,
            onChanged: onModalsChanged,
          ),
          const Divider(height: 12, color: Colors.white10),
          _buildToggleItem(
            label: 'Instrumentos de Medição STEM',
            subtitle: 'Régua milimetrada e transferidor de ângulos',
            value: enableInstrumentsBlur,
            onChanged: onInstrumentsChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: accentColor,
          activeTrackColor: accentColor.withValues(alpha: 0.35),
          inactiveThumbColor: Colors.white60,
          inactiveTrackColor: Colors.white12,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
