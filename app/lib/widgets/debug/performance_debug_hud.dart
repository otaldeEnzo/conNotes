import 'package:flutter/material.dart';
import '../../services/diagnostics_override_controller.dart';
import '../../services/performance_telemetry_controller.dart';
import '../svg_icon.dart';

/// Mini HUD Flutuante de Performance no Padrão Moscaro (Zero Emojis, Vidro Escuro & SVG)
class PerformanceDebugHud extends StatelessWidget {
  const PerformanceDebugHud({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        PerformanceTelemetryController.instance,
        DiagnosticsOverrideController.instance,
      ]),
      builder: (context, _) {
        final diag = DiagnosticsOverrideController.instance;
        final mode = diag.hudMode;

        if (mode == PerformanceHudDisplayMode.off) {
          return const SizedBox.shrink();
        }

        final telemetry = PerformanceTelemetryController.instance;
        final fps = telemetry.currentFps;
        final low1 = telemetry.low1PercentFps;
        final uiMs = telemetry.currentBuildMs;
        final rasterMs = telemetry.currentRasterMs;
        final isJanky = fps < 55.0 || telemetry.currentTotalMs > 16.66;

        Color statusColor = const Color(0xFF00E1FF); // Cyan 120Hz
        if (fps < 58.0) {
          statusColor = const Color(0xFFFF2A6D); // Red Jank
        } else if (fps < 90.0) {
          statusColor = const Color(0xFFFFB703); // Amber 60Hz
        }

        return Positioned(
          top: 48,
          right: 140,
          child: RepaintBoundary(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xF20A0E17),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isJanky ? const Color(0xFFFF2A6D) : const Color(0x5500E1FF),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isJanky ? const Color(0x33FF2A6D) : const Color(0x2200E1FF),
                      blurRadius: 10,
                      spreadRadius: -1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ponto pulsante / indicador de saúde
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.8),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // FPS Atual
                    Text(
                      '${fps.toStringAsFixed(0)} FPS',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 1% Low
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0x22FFFFFF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '1%L: ${low1.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: low1 < 50 ? const Color(0xFFFF2A6D) : Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Tempos UI & GPU
                    Text(
                      'UI: ${uiMs.toStringAsFixed(1)}ms | GPU: ${rasterMs.toStringAsFixed(1)}ms',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Botão para Expandir Dashboard Completo
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        diag.setHudMode(PerformanceHudDisplayMode.fullDashboard);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: SvgIcon(
                          name: 'settings',
                          size: 13,
                          color: Color(0xFF00E1FF),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),

                    // Botão Fechar HUD
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        diag.setHudMode(PerformanceHudDisplayMode.off);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.close,
                          size: 13,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
