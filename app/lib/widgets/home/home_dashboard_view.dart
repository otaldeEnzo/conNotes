import 'package:flutter/material.dart';
import '../../widgets/note_models.dart';
import '../svg_icon.dart';
import '../../theme/moscaro_v2_tokens.dart';
import '../../theme/moscaro_theme_controller.dart';
import 'home_storage_card.dart';
import 'home_devices_card.dart';
import 'home_notes_grid.dart';

/// Visao de Dashboard Bento Grid do Home Hub conNotes (Notas & Dispositivos).
/// Hierarquia Otimizada (Área Nobre):
/// 1. Biblioteca de Notas e Cadernos no topo imediato para acesso sem atrito.
/// 2. Barra / Painel de Telemetria e Rede Mesh retrátil no rodapé, liberando 100% da visualização inicial.
class HomeDashboardView extends StatefulWidget {
  final ValueChanged<NoteDocument> onOpenNote;
  final VoidCallback onCreateNote;
  final VoidCallback onOptimizeCache;
  final String searchQuery;

  const HomeDashboardView({
    super.key,
    required this.onOpenNote,
    required this.onCreateNote,
    required this.onOptimizeCache,
    this.searchQuery = '',
  });

  @override
  State<HomeDashboardView> createState() => _HomeDashboardViewState();
}

class _HomeDashboardViewState extends State<HomeDashboardView> {
  bool _isTelemetryExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isLight = MoscaroTokens.isLight;
    final theme = MoscaroThemeController.instance.currentTheme;
    final accent = theme.accentPrimary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1360),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. ÁREA NOBRE PRINCIPAL: Biblioteca de Notas e Cadernos
                  RepaintBoundary(
                    child: HomeNotesGrid(
                      onNoteSelected: widget.onOpenNote,
                      onCreateNotePressed: widget.onCreateNote,
                      searchQuery: widget.searchQuery,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // 2. STATUS & TELEMETRIA RETRÁTIL (Rodapé Compacto de Sistema)
                  Container(
                    decoration: BoxDecoration(
                      color: theme.glassColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isTelemetryExpanded
                            ? accent.withValues(alpha: 0.4)
                            : (isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.08)),
                        width: 1.0,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Barra de Status Compacta (Sempre Visível)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isTelemetryExpanded = !_isTelemetryExpanded;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            child: Row(
                              children: [
                                SvgIcon(
                                  name: 'database',
                                  size: 16,
                                  color: MoscaroTokens.auroraBlue,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Armazenamento: ',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isLight ? const Color(0xFF0F172A) : Colors.white,
                                  ),
                                ),
                                Text(
                                  '1.4 GB / 8.0 GB em cache',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isLight ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Container(
                                  width: 1,
                                  height: 14,
                                  color: isLight ? Colors.black12 : Colors.white12,
                                ),
                                const SizedBox(width: 18),
                                SvgIcon(
                                  name: 'share',
                                  size: 16,
                                  color: theme.accentSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Rede Mesh: ',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isLight ? const Color(0xFF0F172A) : Colors.white,
                                  ),
                                ),
                                Text(
                                  '3 dispositivos ativos',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isLight ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: isLight ? 0.12 : 0.18),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.35),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _isTelemetryExpanded ? 'Ocultar Detalhes' : 'Detalhes do Sistema',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: isLight ? const Color(0xFF0284C7) : accent,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      SvgIcon(
                                        name: _isTelemetryExpanded ? 'chevron_up' : 'chevron_down',
                                        size: 13,
                                        color: isLight ? const Color(0xFF0284C7) : accent,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Painel Detalhado Expansível
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 250),
                          crossFadeState: _isTelemetryExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          firstChild: const SizedBox(width: double.infinity, height: 0),
                          secondChild: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: isWide
                                ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 6,
                                        child: RepaintBoundary(
                                          child: HomeStorageCard(
                                            onOptimizeCache: widget.onOptimizeCache,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Expanded(
                                        flex: 4,
                                        child: RepaintBoundary(
                                          child: HomeDevicesCard(),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      RepaintBoundary(
                                        child: HomeStorageCard(
                                          onOptimizeCache: widget.onOptimizeCache,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const RepaintBoundary(
                                        child: HomeDevicesCard(),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
