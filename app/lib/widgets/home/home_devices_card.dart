import 'package:flutter/material.dart';
import '../../theme/moscaro_theme_controller.dart';
import '../../theme/moscaro_v2_extension.dart';
import '../../theme/moscaro_v2_tokens.dart';
import '../../services/diagnostics_override_controller.dart';
import '../svg_icon.dart';

/// Bento Card de Status de Dispositivos e Rede Mesh P2P
class HomeDevicesCard extends StatefulWidget {
  const HomeDevicesCard({super.key});

  @override
  State<HomeDevicesCard> createState() => _HomeDevicesCardState();
}

class _HomeDevicesCardState extends State<HomeDevicesCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    if (!DiagnosticsOverrideController.instance.pauseIdleAnimations) {
      _pulseController.repeat(reverse: true);
    }

    DiagnosticsOverrideController.instance.addListener(_onDiagOverrideChanged);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _onDiagOverrideChanged() {
    if (!mounted) return;
    if (DiagnosticsOverrideController.instance.pauseIdleAnimations) {
      _pulseController.stop();
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    DiagnosticsOverrideController.instance.removeListener(_onDiagOverrideChanged);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MoscaroThemeController.instance,
      builder: (context, _) {
        final theme = MoscaroThemeController.instance.currentTheme;
        final accent = theme.accentPrimary;
        final accentConcept = theme.calloutConceptColor;
        final isLight = MoscaroTokens.isLight;

        final cardContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Cabecalho com Status Online / Mesh
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.4),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.2),
                            blurRadius: 12,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: SvgIcon(
                        name: 'activity',
                        color: accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sincronizacao & Rede Mesh',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: isLight ? const Color(0xFF0F172A) : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Local-First P2P com Autosave Continuo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Badge Pulsante de Status Isolado em RepaintBoundary
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, _) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: accentConcept.withValues(alpha: isLight ? 0.14 : 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: accentConcept.withValues(alpha: 0.5 * _pulseAnimation.value),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentConcept.withValues(alpha: 0.35 * _pulseAnimation.value),
                              blurRadius: 10,
                              spreadRadius: -1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: accentConcept,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: accentConcept.withValues(alpha: 0.8),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Online / Local-First',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isLight ? const Color(0xFF065F46) : accentConcept,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // 2. Lista de Dispositivos Conectados
            _buildDeviceItem(
              iconName: 'server',
              name: 'Workstation STEM (Este Dispositivo)',
              detail: '100.64.0.1 (Local) • Sincronizado agora',
              isLocal: true,
              isOnline: true,
              theme: theme,
              isLight: isLight,
            ),
            const SizedBox(height: 8),
            _buildDeviceItem(
              iconName: 'card',
              name: 'iPad Pro M2 (Caneta Stylus)',
              detail: '100.64.0.2 • Ha 2 min',
              isLocal: false,
              isOnline: true,
              theme: theme,
              isLight: isLight,
            ),
            const SizedBox(height: 8),
            _buildDeviceItem(
              iconName: 'rotate',
              name: 'Galaxy Ultra (Mobile Companion)',
              detail: '100.64.0.3 • Ha 45 min',
              isLocal: false,
              isOnline: false,
              theme: theme,
              isLight: isLight,
            ),

            const SizedBox(height: 14),

            // 3. Rodape Informativo
            Row(
              children: [
                SvgIcon(
                  name: 'laser',
                  size: 13,
                  color: isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tailscale Mesh VPN / P2P Local ativo com criptografia ponta a ponta.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

        return cardContent.moscaroV2(
          borderRadius: MoscaroTokens.radiusPanel,
          blurSigma: 35.0,
          enableBlur: true,
          backgroundColor: isLight ? Colors.white.withValues(alpha: 0.8) : theme.glassColor,
          borderColor: isLight ? const Color(0x1F0F172A) : const Color(0x2E3B5278),
          borderWidth: 1.0,
          padding: const EdgeInsets.all(22),
        );
      },
    );
  }

  Widget _buildDeviceItem({
    required String iconName,
    required String name,
    required String detail,
    required bool isLocal,
    required bool isOnline,
    required dynamic theme,
    required bool isLight,
  }) {
    final accent = theme.accentPrimary as Color;
    final concept = theme.calloutConceptColor as Color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isLight ? const Color(0x180F172A) : const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLocal
              ? accent.withValues(alpha: 0.45)
              : (isLight ? const Color(0x200F172A) : const Color(0x18FFFFFF)),
          width: isLocal ? 1.0 : 0.8,
        ),
      ),
      child: Row(
        children: [
          SvgIcon(
            name: iconName,
            size: 16,
            color: isOnline ? accent : const Color(0xFF64748B),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isLight ? const Color(0xFF0F172A) : Colors.white,
                      ),
                    ),
                    if (isLocal) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'Local',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isLight ? const Color(0xFF0284C7) : accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 11,
                    color: isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isOnline
                  ? concept.withValues(alpha: isLight ? 0.12 : 0.16)
                  : (isLight ? const Color(0x150F172A) : const Color(0x18FFFFFF)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isOnline
                    ? concept.withValues(alpha: 0.4)
                    : (isLight ? Colors.black12 : Colors.white12),
                width: 0.8,
              ),
            ),
            child: Text(
              isOnline ? 'Online' : 'Offline',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isOnline
                    ? (isLight ? const Color(0xFF065F46) : concept)
                    : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
