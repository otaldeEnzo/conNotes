import 'package:flutter/material.dart';
import '../../services/diagnostics_override_controller.dart';
import '../../services/performance_telemetry_controller.dart';
import '../svg_icon.dart';
import 'performance_timeline_painter.dart';

/// Modal e Dashboard Completo de Diagnósticos e Telemetria de Desempenho (F12)
class PerformanceDiagnosticsModal extends StatefulWidget {
  const PerformanceDiagnosticsModal({super.key});

  @override
  State<PerformanceDiagnosticsModal> createState() => _PerformanceDiagnosticsModalState();
}

class _PerformanceDiagnosticsModalState extends State<PerformanceDiagnosticsModal> with SingleTickerProviderStateMixin {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        PerformanceTelemetryController.instance,
        DiagnosticsOverrideController.instance,
      ]),
      builder: (context, _) {
        final diag = DiagnosticsOverrideController.instance;
        final telemetry = PerformanceTelemetryController.instance;

        if (diag.hudMode != PerformanceHudDisplayMode.fullDashboard) {
          return const SizedBox.shrink();
        }

        final samples = telemetry.samples;
        final janks = telemetry.janks;
        final fps = telemetry.currentFps;
        final avgFps = telemetry.averageFps;
        final low1 = telemetry.low1PercentFps;
        final low01 = telemetry.low01PercentFps;
        final totalJanks = telemetry.totalJankCount;
        final memMb = telemetry.currentMemoryRssMb;

        final double jankRate = telemetry.totalSampledFrames > 0
            ? (totalJanks / telemetry.totalSampledFrames * 100.0)
            : 0.0;

        return Positioned.fill(
          child: Material(
            color: Colors.black.withValues(alpha: 0.55),
            child: Center(
              child: Container(
                width: 820,
                height: 580,
                decoration: BoxDecoration(
                  color: const Color(0xF70C0E14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0x6600E1FF),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3300E1FF),
                      blurRadius: 28,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 1. Cabeçalho do Dashboard
                    _buildHeader(diag),

                    // 2. Bento Grid de KPIs Rápidos
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      child: Row(
                        children: [
                          _buildKpiCard('FPS ATUAL / MÉDIO', '${fps.toStringAsFixed(0)} / ${avgFps.toStringAsFixed(0)}', const Color(0xFF00E1FF)),
                          const SizedBox(width: 10),
                          _buildKpiCard('1% / 0.1% LOW', '${low1.toStringAsFixed(0)} / ${low01.toStringAsFixed(0)}', low1 < 50 ? const Color(0xFFFF2A6D) : const Color(0xFF00E1FF)),
                          const SizedBox(width: 10),
                          _buildKpiCard('UI / GPU MS', '${telemetry.currentBuildMs.toStringAsFixed(1)} / ${telemetry.currentRasterMs.toStringAsFixed(1)}', const Color(0xFFBD00FF)),
                          const SizedBox(width: 10),
                          _buildKpiCard('JANKS TOTAIS', '$totalJanks (${jankRate.toStringAsFixed(1)}%)', totalJanks > 0 ? const Color(0xFFFF2A6D) : const Color(0xFF00E1FF)),
                          const SizedBox(width: 10),
                          _buildKpiCard('MEMÓRIA RAM (RSS)', '$memMb MB', const Color(0xFFFFB703)),
                        ],
                      ),
                    ),

                    // 3. Barra de Abas
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      child: Row(
                        children: [
                          _buildTabButton(0, 'Linha do Tempo (150 Quadros)'),
                          const SizedBox(width: 8),
                          _buildTabButton(1, 'Caçador de Gargalos (${janks.length})'),
                          const SizedBox(width: 8),
                          _buildTabButton(2, 'Interruptores & Killswitches'),
                        ],
                      ),
                    ),
                    const Divider(color: Color(0x2200E1FF), height: 16),

                    // 4. Conteúdo da Aba Ativa
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        child: _buildActiveTabContent(diag, telemetry, samples, janks),
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

  Widget _buildHeader(DiagnosticsOverrideController diag) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1F00E1FF))),
      ),
      child: Row(
        children: [
          const SvgIcon(
            name: 'sparkle',
            size: 16,
            color: Color(0xFF00E1FF),
          ),
          const SizedBox(width: 8),
          const Text(
            'conNotes Performance & Diagnostics Suite',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          // Botão Minimizar para Mini HUD
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              diag.setHudMode(PerformanceHudDisplayMode.miniHud);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0x1A00E1FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x4400E1FF)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.remove, size: 12, color: Color(0xFF00E1FF)),
                  SizedBox(width: 4),
                  Text(
                    'Mini HUD',
                    style: TextStyle(fontSize: 11, color: Color(0xFF00E1FF), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Botão Fechar
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              diag.setHudMode(PerformanceHudDisplayMode.off);
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF101420),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 9.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                color: accent,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isSelected = _selectedTab == index;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x3300E1FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF00E1FF) : const Color(0x22FFFFFF),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00E1FF) : Colors.white70,
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(
    DiagnosticsOverrideController diag,
    PerformanceTelemetryController telemetry,
    List<PerformanceFrameSample> samples,
    List<JankIncident> janks,
  ) {
    switch (_selectedTab) {
      case 0:
        return _buildTimelineTab(samples);
      case 1:
        return _buildJankHunterTab(janks, telemetry);
      case 2:
        return _buildKillswitchesTab(diag);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTimelineTab(List<PerformanceFrameSample> samples) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Timeline de Latência (Azul = UI/CPU, Roxo = GPU/Raster, Vermelho = Jank)',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
            Row(
              children: [
                _buildLegendItem('120 FPS (8.3ms)', const Color(0xFF00E1FF)),
                const SizedBox(width: 10),
                _buildLegendItem('60 FPS (16.6ms)', const Color(0xFFFFB703)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF07090E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x2200E1FF)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CustomPaint(
                painter: PerformanceTimelinePainter(samples: samples),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildJankHunterTab(List<JankIncident> janks, PerformanceTelemetryController telemetry) {
    if (janks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 36, color: const Color(0xFF00E1FF).withValues(alpha: 0.6)),
            const SizedBox(height: 10),
            const Text(
              'Nenhum engasgo detectado na sessão atual!',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'O app está operando dentro do orçamento seguro de tempo de quadro.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Últimos ${janks.length} engasgos capturados:',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00E1FF),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              icon: const Icon(Icons.delete_outline, size: 14),
              label: const Text('Limpar Registro', style: TextStyle(fontSize: 11)),
              onPressed: () => telemetry.clearJanks(),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.builder(
            itemCount: janks.length,
            itemBuilder: (context, index) {
              final jank = janks[index];
              final timeStr = '${jank.timestamp.hour.toString().padLeft(2, '0')}:${jank.timestamp.minute.toString().padLeft(2, '0')}:${jank.timestamp.second.toString().padLeft(2, '0')}';

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF101420),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x33FF2A6D)),
                ),
                child: Row(
                  children: [
                    Text(
                      timeStr,
                      style: const TextStyle(color: Colors.white54, fontSize: 11, fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x33FF2A6D),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${jank.totalMs.toStringAsFixed(1)} ms',
                        style: const TextStyle(color: Color(0xFFFF2A6D), fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            jank.primaryCulprit,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Contexto: ${jank.activeContext} • UI: ${jank.buildMs.toStringAsFixed(1)}ms | GPU: ${jank.rasterMs.toStringAsFixed(1)}ms • RAM: ${jank.memoryRssMb}MB',
                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKillswitchesTab(DiagnosticsOverrideController diag) {
    return ListView(
      children: [
        _buildToggleTile(
          title: 'Bypass Global de Blur (Killswitch do BackdropFilter)',
          subtitle: 'Zera instantaneamente o blur de todos os componentes .moscaroV2(). Se o FPS subir para 120+, confirma que o shader de blur é o gargalo.',
          value: diag.bypassBackdropFilter,
          onChanged: (_) => diag.toggleBypassBackdropFilter(),
        ),
        const SizedBox(height: 10),
        _buildToggleTile(
          title: 'Pausar Animações em IDLE (HomeDevicesCard Pulse)',
          subtitle: 'Congela os AnimationControllers perpétuos em repouso para verificar se eles são os responsáveis pelo engasgo periódico em idle.',
          value: diag.pauseIdleAnimations,
          onChanged: (_) => diag.togglePauseIdleAnimations(),
        ),
        const SizedBox(height: 10),
        _buildToggleTile(
          title: 'Repaint Rainbow do Flutter (Visualizador de Repinturas)',
          subtitle: 'Contorna com cores aleatórias em tempo real todas as caixas de widgets que estão sendo repintadas.',
          value: diag.debugRepaintRainbow,
          onChanged: (_) => diag.toggleRepaintRainbow(),
        ),
        const SizedBox(height: 10),
        _buildToggleTile(
          title: 'Gráfico Nativo do Flutter (showPerformanceOverlay)',
          subtitle: 'Ativa ou desativa a barra de desempenho nativa do engine no topo da janela.',
          value: diag.showNativeOverlay,
          onChanged: (_) => diag.toggleNativeOverlay(),
        ),
      ],
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101420),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: value ? const Color(0xFF00E1FF) : const Color(0x22FFFFFF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFF00E1FF),
            activeTrackColor: const Color(0x6600E1FF),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
