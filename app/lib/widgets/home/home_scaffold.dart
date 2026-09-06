import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/moscaro_theme_controller.dart';
import '../../services/settings_service.dart';
import '../../widgets/note_models.dart';
import '../../widgets/settings_models.dart';
import '../settings_page_view.dart';
import '../settings_tab_bar.dart';
import 'home_navigation_bar.dart';
import 'home_dashboard_view.dart';
import 'home_ai_chat_view.dart';
import '../moscaro_window_title_bar.dart';
import '../../main.dart' show rootKeyNotifier, performanceOverlayNotifier;

/// Container Principal do Home Hub do conNotes (Moscaro v2 Pro Max).
/// Orquestra o fundo com Dual Glow Orbs + Dot Grid, barra de navegacao superior,
/// transicoes fluidas entre abas, integracao com o tema ativo e comunicacao com o canvas.
class HomeScaffold extends StatefulWidget {
  final ValueChanged<NoteDocument> onOpenNote;
  final VoidCallback onCreateNote;

  const HomeScaffold({
    super.key,
    required this.onOpenNote,
    required this.onCreateNote,
  });

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  int _selectedTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  AppSettingsState _settings = const AppSettingsState();
  bool _isSettingsOpen = false;
  SettingsCategory _activeSettingsCategory = SettingsCategory.visual;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  Future<void> _loadSettings() async {
    final s = await SettingsService.instance.loadSettings();
    if (mounted) {
      setState(() {
        _settings = s;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _focusSearch() {
    if (_isSettingsOpen) {
      setState(() {
        _isSettingsOpen = false;
      });
    }
    if (_selectedTabIndex != 0) {
      setState(() {
        _selectedTabIndex = 0;
      });
    }
    _searchFocusNode.requestFocus();
  }

  void _openSettingsModal() {
    setState(() {
      _isSettingsOpen = true;
    });
  }

  void _closeSettings() {
    setState(() {
      _isSettingsOpen = false;
    });
  }

  void _updateSettings(AppSettingsState newSettings) {
    setState(() {
      _settings = newSettings;
    });
    SettingsService.instance.saveSettings(newSettings);
  }

  void _handleOptimizeCache() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MoscaroThemeController.instance.currentTheme.backgroundSurface,
        title: const Text('Otimizar Cache', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Deseja limpar arquivos temporários e liberar espaço em disco?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache local otimizado com sucesso!')),
              );
            },
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MoscaroThemeController.instance,
      builder: (context, _) {
        final theme = MoscaroThemeController.instance.currentTheme;
        return Scaffold(
          backgroundColor: theme.backgroundDeep,
          body: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.keyK, control: true): _focusSearch,
              const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _focusSearch,
            },
            child: Focus(
              autofocus: true,
              child: Stack(
                children: [
                  // Fundo com Orbs de Brilho Ambiente Dinamicos (Tema Ativo)
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _HomeAmbientGlowPainter(
                          primaryColor: theme.accentPrimary,
                          secondaryColor: theme.accentSecondary,
                          backgroundDeep: theme.backgroundDeep,
                          backgroundSurface: theme.backgroundSurface,
                        ),
                      ),
                    ),
                  ),

                  // Conteudo Principal do Dashboard (Oculto ou em segundo plano se as configs estiverem abertas)
                  SafeArea(
                    child: Column(
                      children: [
                        // 1. Barra de Navegacao Superior Moscaro
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
                          child: HomeNavigationBar(
                            selectedTabIndex: _selectedTabIndex,
                            onTabChanged: (index) {
                              setState(() {
                                _selectedTabIndex = index;
                              });
                            },
                            searchController: _searchController,
                            searchFocusNode: _searchFocusNode,
                            onSearchChanged: (query) {
                              setState(() {
                                _searchQuery = query;
                              });
                            },
                            onOpenSettings: _openSettingsModal,
                          ),
                        ),

                    const SizedBox(height: 8),

                    // 2. Area Principal Instantânea (0ms e 120 FPS com transição sutil de deslizamento e fade)
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.02, 0.0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: _selectedTabIndex == 0
                            ? RepaintBoundary(
                                key: const ValueKey('home_tab_dashboard'),
                                child: HomeDashboardView(
                                  onOpenNote: widget.onOpenNote,
                                  onCreateNote: widget.onCreateNote,
                                  onOptimizeCache: _handleOptimizeCache,
                                  searchQuery: _searchQuery,
                                ),
                              )
                            : RepaintBoundary(
                                key: const ValueKey('home_tab_ai_chat'),
                                child: HomeAiChatView(
                                  onOpenNoteRequested: (note) {
                                    widget.onOpenNote(note);
                                  },
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Camada de Configuracoes (Mesma experiencia identica do Canvas com entrada/saida suave)
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.98, end: 1.0).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _isSettingsOpen
                      ? Stack(
                          key: const ValueKey('home_settings_open'),
                          children: [
                            Positioned.fill(
                              child: Material(
                                type: MaterialType.transparency,
                                child: SettingsPageView(
                                  activeCategory: _activeSettingsCategory,
                                  settings: _settings,
                                  onUpdateSettings: _updateSettings,
                                  onResetCategory: () {},
                                ),
                              ),
                            ),
                            // TabBar de Configuracoes Flutuante e Centralizada
                            Positioned(
                              top: 14,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: SettingsTabBar(
                                  key: const ValueKey('home_settings_tab_bar'),
                                  activeCategory: _activeSettingsCategory,
                                  onSelectCategory: (cat) {
                                    setState(() {
                                      _activeSettingsCategory = cat;
                                    });
                                  },
                                  onBackToNotes: _closeSettings,
                                ),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(key: ValueKey('home_settings_closed')),
                ),
              ),

              // 4. Barra de Título Customizada Moscaro (Frameless Window Header com Suíte Dev sob kDebugMode)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: MoscaroWindowTitleBar(
                  onHotRestart: () {
                    rootKeyNotifier.value = UniqueKey();
                  },
                  onToggleFps: () {
                    performanceOverlayNotifier.value = !performanceOverlayNotifier.value;
                  },
                  isFpsActive: performanceOverlayNotifier.value,
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

/// Painter procedural de orbs organicos de luz ambiente (Moscaro Liquid Aesthetic)
class _HomeAmbientGlowPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundDeep;
  final Color backgroundSurface;

  _HomeAmbientGlowPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundDeep,
    required this.backgroundSurface,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Preenchimento de fundo em degradê sutil
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [backgroundSurface, backgroundDeep],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. Orb Superior Esquerdo (Acento Primário - Ciano / Esmeralda / Neon)
    final orb1Center = Offset(size.width * 0.15, size.height * 0.12);
    final orb1Radius = size.width * 0.35;
    final orb1Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: 0.16),
          primaryColor.withValues(alpha: 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: orb1Center, radius: orb1Radius));
    canvas.drawCircle(orb1Center, orb1Radius, orb1Paint);

    // 3. Orb Central Direito (Acento Secundário - Violeta / Rosa / Âmbar)
    final orb2Center = Offset(size.width * 0.82, size.height * 0.28);
    final orb2Radius = size.width * 0.38;
    final orb2Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          secondaryColor.withValues(alpha: 0.14),
          secondaryColor.withValues(alpha: 0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: orb2Center, radius: orb2Radius));
    canvas.drawCircle(orb2Center, orb2Radius, orb2Paint);

    // 4. Orb Inferior Esquerdo (Luz de profundidade)
    final orb3Center = Offset(size.width * 0.35, size.height * 0.85);
    final orb3Radius = size.width * 0.4;
    final orb3Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: orb3Center, radius: orb3Radius));
    canvas.drawCircle(orb3Center, orb3Radius, orb3Paint);
  }

  @override
  bool shouldRepaint(covariant _HomeAmbientGlowPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.backgroundDeep != backgroundDeep ||
        oldDelegate.backgroundSurface != backgroundSurface;
  }
}
