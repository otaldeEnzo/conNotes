import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import '../theme/moscaro_theme_controller.dart';
import 'svg_icon.dart';

/// Informações do Provedor de IA para exibição no Popover de Ajuda
class AiProviderInfo {
  final String providerName;
  final String pricingType; // '100% Gratuito', 'Gratuito com Limite', 'Pago (Pay-as-you-go)'
  final bool isFree;
  final String capabilities;
  final List<String> steps;
  final String officialUrl;
  final String buttonLabel;

  const AiProviderInfo({
    required this.providerName,
    required this.pricingType,
    required this.isFree,
    required this.capabilities,
    required this.steps,
    required this.officialUrl,
    this.buttonLabel = 'Abrir Site Oficial e Gerar Chave',
  });
}

/// Botão Moscaro v2 com Popover / Modal em Hover para ensinar a obter chaves de API
class AiProviderHelpButton extends StatefulWidget {
  final AiProviderInfo info;

  const AiProviderHelpButton({
    super.key,
    required this.info,
  });

  @override
  State<AiProviderHelpButton> createState() => _AiProviderHelpButtonState();
}

class _AiProviderHelpButtonState extends State<AiProviderHelpButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isHoveringButton = false;
  bool _isHoveringPopup = false;

  void _showOverlay() {
    if (_overlayEntry != null) return;

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) {
        final theme = MoscaroThemeController.instance.currentTheme;
        final accent = theme.accentPrimary;

        return Positioned(
          width: 360,
          child: Material(
            type: MaterialType.transparency,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(-270, 32),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutQuart,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 10),
                      child: child,
                    ),
                  );
                },
                child: MouseRegion(
                  onEnter: (_) {
                    _isHoveringPopup = true;
                  },
                  onExit: (_) {
                    _isHoveringPopup = false;
                    _checkHide();
                  },
                  child: Container(
                    width: 360,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Cabeçalho com Nome e Badge de Custo
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                widget.info.providerName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: widget.info.isFree
                                    ? MoscaroTokens.auroraGreen.withValues(alpha: 0.18)
                                    : Colors.amber.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: widget.info.isFree
                                      ? MoscaroTokens.auroraGreen.withValues(alpha: 0.5)
                                      : Colors.amber.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                widget.info.pricingType,
                                style: TextStyle(
                                  color: widget.info.isFree ? MoscaroTokens.auroraGreen : Colors.amber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 2. Capacidades do Modelo
                        Text(
                          'Capacidades:',
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.info.capabilities,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w400,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 3. Passo a Passo
                        Text(
                          'Como obter a chave:',
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (int i = 0; i < widget.info.steps.length; i++) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${i + 1}. ',
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    widget.info.steps[i],
                                    style: const TextStyle(
                                      color: Color(0xFFE1E4EA),
                                      fontSize: 11.5,
                                      height: 1.35,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),

                        // 4. Botão de Link Direto com Abrir no Navegador
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _openUrl(widget.info.officialUrl),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent.withValues(alpha: 0.25),
                              foregroundColor: Colors.white,
                              side: BorderSide(color: accent.withValues(alpha: 0.7), width: 1.1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SvgIcon(assetName: 'open_url', color: Colors.white, size: 12),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    widget.info.buttonLabel,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white, decoration: TextDecoration.none),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).moscaroV2(
                    borderRadius: 16,
                    borderColor: accent.withValues(alpha: 0.5),
                    borderWidth: 1.2,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  void _checkHide() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!_isHoveringButton && !_isHoveringPopup) {
        _hideOverlay();
      }
    });
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() {});
  }

  void _openUrl(String url) {
    _hideOverlay();
    if (Platform.isWindows) {
      Process.run('cmd', ['/c', 'start', '', url], runInShell: true);
    } else if (Platform.isMacOS) {
      Process.run('open', [url]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [url]);
    }
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = MoscaroThemeController.instance.currentTheme;
    final accent = theme.accentPrimary;

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) {
          _isHoveringButton = true;
          setState(() {});
          _showOverlay();
        },
        onExit: (_) {
          _isHoveringButton = false;
          setState(() {});
          _checkHide();
        },
        child: InkWell(
          onTap: () {
            if (_overlayEntry == null) {
              _isHoveringButton = true;
              _showOverlay();
            } else {
              _isHoveringButton = false;
              _hideOverlay();
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isHoveringButton ? accent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isHoveringButton ? accent.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.15),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  size: 13,
                  color: _isHoveringButton ? accent : Colors.white70,
                ),
                const SizedBox(width: 4),
                Text(
                  'Como Obter?',
                  style: TextStyle(
                    color: _isHoveringButton ? accent : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
