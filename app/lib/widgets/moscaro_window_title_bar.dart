import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/diagnostics_override_controller.dart';
import '../services/vm_service_client.dart';
import '../services/window_controls_service.dart';
import '../theme/moscaro_theme_controller.dart';
import '../theme/moscaro_v2_tokens.dart';
import 'svg_icon.dart';

/// Barra de título customizada do conNotes com suporte a arrasto de janela,
/// botões nativos de controle (Minimizar, Maximizar, Fechar) e suíte de desenvolvimento
/// com Hot Reload e Hot Restart automáticos no modo Debug (eliminados em Release).
class MoscaroWindowTitleBar extends StatelessWidget {
  final String title;
  final VoidCallback? onHotReload;
  final VoidCallback? onHotRestart;
  final VoidCallback? onToggleDebugCards;
  final VoidCallback? onOpenDevHub;
  final VoidCallback? onToggleFps;
  final bool isDebugCardsActive;
  final bool isFpsActive;

  const MoscaroWindowTitleBar({
    super.key,
    this.title = 'conNotes STEM Canvas',
    this.onHotReload,
    this.onHotRestart,
    this.onToggleDebugCards,
    this.onOpenDevHub,
    this.onToggleFps,
    this.isDebugCardsActive = false,
    this.isFpsActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = MoscaroThemeController.instance;
    final isLight = MoscaroTokens.isLight;
    final accent = theme.currentTheme.accentPrimary;

    return RepaintBoundary(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: MoscaroTokens.blurSigma.clamp(10.0, 30.0),
            sigmaY: MoscaroTokens.blurSigma.clamp(10.0, 30.0),
          ),
          child: Container(
            height: 38.0,
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.white.withValues(alpha: 0.85)
                  : const Color(0xFF0E1018).withValues(alpha: 0.92),
              border: Border(
                bottom: BorderSide(
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.08)
                      : accent.withValues(alpha: 0.20),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                // 1. Logotipo e Título do Documento
                Padding(
                  padding: const EdgeInsets.only(left: 12.0, right: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgIcon(
                        name: 'app_logo',
                        size: 16.0,
                        color: accent,
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        'conNotes',
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: isLight ? Colors.black87 : Colors.white,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: Text(
                          '•',
                          style: TextStyle(
                            fontSize: 11.0,
                            color: isLight ? Colors.black38 : Colors.white38,
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220.0),
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isLight ? Colors.black54 : Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Área Central de Arrasto da Janela (Window Drag Area)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (_) {
                      WindowControlsService.instance.startDrag();
                    },
                    onDoubleTap: () {
                      WindowControlsService.instance.maximizeOrRestore();
                    },
                    child: const SizedBox.expand(),
                  ),
                ),

                // 3. Suíte de Desenvolvimento (Exclusiva do modo Debug - Eliminada em Release)
                if (kDebugMode) ...[
                  _buildDevSuiteBar(context, isLight, accent),
                  const SizedBox(width: 8.0),
                ],

                // 4. Botões Nativos de Janela (Minimizar, Maximizar, Fechar)
                _buildWindowCaptionButtons(context, isLight),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDevSuiteBar(BuildContext context, bool isLight, Color accent) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.black.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: isLight
              ? Colors.black.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.10),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Telemetria F2
          _DevIconButton(
            icon: 'target',
            tooltip: 'Alternar Telemetria & Hitboxes (F2)',
            color: isDebugCardsActive ? const Color(0xFF00FF9D) : (isLight ? Colors.black45 : Colors.white38),
            isActive: isDebugCardsActive,
            onPressed: onToggleDebugCards,
          ),
          // Dev Hub F12
          _DevIconButton(
            icon: 'server',
            tooltip: 'Abrir Dev Hub no Navegador (F12)',
            color: const Color(0xFFBD00FF),
            onPressed: onOpenDevHub,
          ),
          // MiniHUD de Performance (FPS, 1% Low, Latência)
          ListenableBuilder(
            listenable: DiagnosticsOverrideController.instance,
            builder: (context, _) {
              final isHudActive = DiagnosticsOverrideController.instance.hudMode != PerformanceHudDisplayMode.off;
              return _DevIconButton(
                icon: 'activity',
                tooltip: 'Alternar MiniHUD de Performance (FPS, 1% Low)',
                color: isHudActive ? const Color(0xFF00E1FF) : (isLight ? Colors.black45 : Colors.white38),
                isActive: isHudActive,
                onPressed: () {
                  DiagnosticsOverrideController.instance.cycleHudMode();
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWindowCaptionButtons(BuildContext context, bool isLight) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CaptionButton(
          icon: 'minimize',
          tooltip: 'Minimizar',
          isLight: isLight,
          onPressed: () => WindowControlsService.instance.minimize(),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: WindowControlsService.instance.isMaximizedNotifier,
          builder: (context, isMaximized, _) {
            return _CaptionButton(
              icon: isMaximized ? 'window_restore' : 'maximize',
              tooltip: isMaximized ? 'Restaurar' : 'Maximizar',
              isLight: isLight,
              onPressed: () => WindowControlsService.instance.maximizeOrRestore(),
            );
          },
        ),
        _CaptionButton(
          icon: 'close',
          tooltip: 'Fechar',
          isLight: isLight,
          isClose: true,
          onPressed: () => WindowControlsService.instance.close(),
        ),
      ],
    );
  }
}

class _DevIconButton extends StatefulWidget {
  final String icon;
  final String tooltip;
  final Color color;
  final bool isActive;
  final VoidCallback? onPressed;

  const _DevIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    this.isActive = false,
    this.onPressed,
  });

  @override
  State<_DevIconButton> createState() => _DevIconButtonState();
}

class _DevIconButtonState extends State<_DevIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? widget.color.withValues(alpha: 0.20)
                  : (_isHovered ? widget.color.withValues(alpha: 0.12) : Colors.transparent),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: SvgIcon(
              name: widget.icon,
              size: 13.0,
              color: _isHovered || widget.isActive
                  ? widget.color
                  : widget.color.withValues(alpha: 0.75),
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptionButton extends StatefulWidget {
  final String icon;
  final String tooltip;
  final bool isLight;
  final bool isClose;
  final VoidCallback onPressed;

  const _CaptionButton({
    required this.icon,
    required this.tooltip,
    required this.isLight,
    this.isClose = false,
    required this.onPressed,
  });

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final defaultColor = widget.isLight ? Colors.black54 : Colors.white60;
    Color hoverBg = widget.isLight
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.10);
    Color iconColor = defaultColor;

    if (widget.isClose && _isHovered) {
      hoverBg = const Color(0xFFE81123);
      iconColor = Colors.white;
    } else if (_isHovered) {
      iconColor = widget.isLight ? Colors.black87 : Colors.white;
    }

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            width: 44.0,
            height: 38.0,
            color: _isHovered ? hoverBg : Colors.transparent,
            alignment: Alignment.center,
            child: SvgIcon(
              name: widget.icon,
              size: widget.icon == 'minimize' ? 14.0 : 12.0,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
