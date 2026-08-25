import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/moscaro_v2_tokens.dart';
import 'settings_models.dart';
import 'settings_slider_tile.dart';
import 'settings_toggle_tile.dart';
import 'settings_shortcuts_view.dart';
import 'settings_sandbox_card.dart';
import 'settings_theme_view.dart';
import 'ai_provider_help_button.dart';
import '../theme/moscaro_theme_controller.dart';
import '../services/workspace_storage_service.dart';
import '../services/windows_file_dialog_service.dart';
import '../services/custom_font_manager.dart';
import 'svg_icon.dart';

/// Visualizador Principal da Página de Configurações no Canvas (Moscaro v2 Pro Max).
/// Transforma o canvas inteiro em uma superfície limpa de Vidro Líquido Moscaro (sem pautas ou grade).
class SettingsPageView extends StatefulWidget {
  final SettingsCategory activeCategory;
  final AppSettingsState settings;
  final ValueChanged<AppSettingsState> onUpdateSettings;
  final VoidCallback onResetCategory;

  const SettingsPageView({
    super.key,
    required this.activeCategory,
    required this.settings,
    required this.onUpdateSettings,
    required this.onResetCategory,
  });

  @override
  State<SettingsPageView> createState() => _SettingsPageViewState();
}

class _SettingsPageViewState extends State<SettingsPageView> {
  final ScrollController _scrollController = ScrollController();
  bool _isResetHovered = false;
  bool _isApiKeyObscured = true;
  bool _isOpenAiKeyObscured = true;
  bool _isClaudeKeyObscured = true;

  late final TextEditingController _geminiController;
  late final TextEditingController _openAiController;
  late final TextEditingController _claudeController;
  late final TextEditingController _ollamaController;

  @override
  void initState() {
    super.initState();
    _geminiController = TextEditingController(text: widget.settings.geminiApiKey);
    _openAiController = TextEditingController(text: widget.settings.openAiApiKey);
    _claudeController = TextEditingController(text: widget.settings.claudeApiKey);
    _ollamaController = TextEditingController(text: widget.settings.ollamaEndpointUrl);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _geminiController.dispose();
    _openAiController.dispose();
    _claudeController.dispose();
    _ollamaController.dispose();
    super.dispose();
  }

  String _getCategorySubtitle() {
    switch (widget.activeCategory) {
      case SettingsCategory.themes:
        return 'Escolha um tema oficial STEM ou personalize as cores e texturas do Canvas.';
      case SettingsCategory.visual:
        return 'Personalize os efeitos de vidro líquido, desfoque e indicadores do conNotes.';
      case SettingsCategory.canvas:
        return 'Configure o comportamento da matriz STEM, espaçamento e glow reativo.';
      case SettingsCategory.pen:
        return 'Ajuste a estabilização de traço, pressão da Stylus e tempo de reconhecimento.';
      case SettingsCategory.measurement:
        return 'Defina a atração magnética e as travas angulares da Régua e Transferidor.';
      case SettingsCategory.shortcuts:
        return 'Consulte os atalhos de teclado e modificadores rápidos de produtividade.';
      case SettingsCategory.ai:
        return 'Conecte sua chave de API para resolução de equações LaTeX e gráficos no canvas.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MoscaroThemeController.instance,
      builder: (context, _) {
        return SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Scrollbar(
            controller: _scrollController,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 86, bottom: 32),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 860),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                    // Barra Superior Discreta de Subtítulo e Reset
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _getCategorySubtitle(),
                            style: TextStyle(
                              color: MoscaroTokens.textSecondary,
                              fontSize: 13,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        MouseRegion(
                          onEnter: (_) => setState(() => _isResetHovered = true),
                          onExit: (_) => setState(() => _isResetHovered = false),
                          child: GestureDetector(
                            onTap: widget.onResetCategory,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _isResetHovered
                                    ? (MoscaroTokens.isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.12))
                                    : (MoscaroTokens.isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.05)),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _isResetHovered
                                      ? MoscaroTokens.auroraBlue.withValues(alpha: 0.5)
                                      : (MoscaroTokens.isLight ? Colors.black12 : Colors.white12),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.refresh_rounded,
                                    size: 13,
                                    color: _isResetHovered ? MoscaroTokens.auroraBlue : MoscaroTokens.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Restaurar Padrões',
                                    style: TextStyle(
                                      color: _isResetHovered ? MoscaroTokens.auroraBlue : MoscaroTokens.textSecondary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Conteúdo Dinâmico da Categoria Ativa
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _buildCategoryContent(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

  Widget _buildCategoryContent() {
    switch (widget.activeCategory) {
      case SettingsCategory.themes:
        return SettingsThemeView(
          onThemeChanged: () {
            final c = MoscaroThemeController.instance;
            widget.onUpdateSettings(widget.settings.copyWith(
              activeThemeId: c.activeThemeId,
              customBgMode: c.backgroundMode.id,
              customBgColorHex: '#${c.customSolidColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
              customGradStartHex: '#${c.customGradientStart.toARGB32().toRadixString(16).padLeft(8, '0')}',
              customGradEndHex: '#${c.customGradientEnd.toARGB32().toRadixString(16).padLeft(8, '0')}',
              customTextureType: c.textureType.id,
              customImagePath: c.customImagePath,
              customImageOpacity: c.customImageOpacity,
              customThemes: c.customThemes,
            ));
          },
        );
      case SettingsCategory.visual:
        return _buildVisualSettings();
      case SettingsCategory.canvas:
        return _buildCanvasSettings();
      case SettingsCategory.pen:
        return _buildPenSettings();
      case SettingsCategory.measurement:
        return _buildMeasurementSettings();
      case SettingsCategory.shortcuts:
        return const SettingsShortcutsView();
      case SettingsCategory.ai:
        return _buildAiSettings();
    }
  }

  Widget _buildVisualSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      key: const ValueKey('visual_settings'),
      children: [
        _buildWorkspaceDirectoryTile(context),
        _buildCustomFontsTile(context),
        SettingsSliderTile(
          title: 'Intensidade do Blur (Vidro Líquido)',
          description: 'Define o desfoque de fundo dos menus, painéis e ferramentas de todo o app.',
          value: widget.settings.blurSigma,
          min: 10.0,
          max: 50.0,
          divisions: 8,
          formatValue: (val) => '${val.round()} px',
          onChanged: (val) => widget.onUpdateSettings(widget.settings.copyWith(blurSigma: val)),
        ),
        SettingsToggleTile(
          title: 'Bordas Aurora Dinâmicas',
          description: 'Habilita o efeito de brilho gradiente animado nas bordas de foco.',
          value: widget.settings.enableAuroraBorders,
          onChanged: (val) => widget.onUpdateSettings(widget.settings.copyWith(enableAuroraBorders: val)),
        ),
        SettingsToggleTile(
          title: 'Exibir Telemetria & FPS no HUD',
          description: 'Mostra indicador de taxa de quadros e taxa de amostragem no topo da tela.',
          value: widget.settings.showTelemetryHud,
          onChanged: (val) => widget.onUpdateSettings(widget.settings.copyWith(showTelemetryHud: val)),
        ),
      ],
    );
  }

  Widget _buildWorkspaceDirectoryTile(BuildContext context) {
    final currentPath = widget.settings.workspaceDirectoryPath ?? WorkspaceStorageService.instance.workspacePath;
    final isLight = MoscaroTokens.isLight;
    final textPrimary = MoscaroTokens.textPrimary;
    final textSecondary = MoscaroTokens.textSecondary;
    final accentCyan = MoscaroTokens.auroraBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF0C1422).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SvgIcon(
                name: 'folder',
                size: 20,
                color: accentCyan,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Diretório dos Cadernos & Workspace',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Pasta padrão onde seus cadernos, disciplinas e notas .cncanvas são salvos automaticamente.',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _handlePickWorkspaceFolder(context),
                icon: const SvgIcon(name: 'folder', size: 14, color: Colors.white),
                label: const Text('Alterar Pasta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentCyan.withValues(alpha: 0.25),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: accentCyan.withValues(alpha: 0.6), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: accentCyan.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              currentPath.isNotEmpty ? currentPath : 'Padrão: Documentos/conNotes',
              style: TextStyle(
                color: accentCyan,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomFontsTile(BuildContext context) {
    final isLight = MoscaroTokens.isLight;
    final textPrimary = MoscaroTokens.textPrimary;
    final textSecondary = MoscaroTokens.textSecondary;
    final accentCyan = MoscaroTokens.auroraBlue;
    final fontManager = CustomFontManager.instance;
    final textCtrl = TextEditingController();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF0C1422).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.font_download_rounded, size: 20, color: accentCyan),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tipografias & Fontes do Sistema',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Cadastre manualmente qualquer família tipográfica instalada em seu computador para usar nos cards.',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Campo de Adição Rápida
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: textCtrl,
                  style: TextStyle(color: textPrimary, fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Digite o nome exato da fonte (ex: Helvetica, Comic Sans, Cascadia Code)...',
                    hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.5), fontSize: 11.5),
                    filled: true,
                    fillColor: isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.04),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isLight ? Colors.black12 : Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: accentCyan, width: 1.2),
                    ),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      fontManager.addFont(val.trim());
                      textCtrl.clear();
                      setState(() {});
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  if (textCtrl.text.trim().isNotEmpty) {
                    fontManager.addFont(textCtrl.text.trim());
                    textCtrl.clear();
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Adicionar Fonte', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentCyan.withValues(alpha: 0.25),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: accentCyan.withValues(alpha: 0.6), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  elevation: 0,
                ),
              ),
            ],
          ),

          if (fontManager.userFonts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: fontManager.userFonts.map((f) {
                return Chip(
                  backgroundColor: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08),
                  label: Text(f, style: TextStyle(color: textPrimary, fontSize: 11.5, fontFamily: f)),
                  deleteIcon: Icon(Icons.close, size: 14, color: textSecondary),
                  onDeleted: () {
                    fontManager.removeFont(f);
                    setState(() {});
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: isLight ? Colors.black12 : Colors.white12),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handlePickWorkspaceFolder(BuildContext context) async {
    final selected = await WindowsFileDialogService.pickDirectory(
      dialogTitle: 'Selecionar Nova Pasta de Cadernos do conNotes',
    );
    if (selected == null || !context.mounted) return;

    final current = WorkspaceStorageService.instance.workspacePath;
    if (selected == current) return;

    final bool hasExistingNotes = WorkspaceStorageService.instance.notebooks.isNotEmpty ||
        WorkspaceStorageService.instance.rootNotes.isNotEmpty;

    if (hasExistingNotes) {
      final migrate = await showDialog<bool>(
        context: context,
        builder: (ctx) => _buildMigrationDialog(ctx, selected),
      );
      if (migrate == null) return;

      await WorkspaceStorageService.instance.changeWorkspaceDirectory(
        selected,
        migrateExistingFiles: migrate,
      );
    } else {
      await WorkspaceStorageService.instance.changeWorkspaceDirectory(
        selected,
        migrateExistingFiles: false,
      );
    }

    widget.onUpdateSettings(widget.settings.copyWith(
      workspaceDirectoryPath: selected,
    ));
  }

  Widget _buildMigrationDialog(BuildContext context, String newPath) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0E121A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MoscaroTokens.auroraBlue.withValues(alpha: 0.4), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
            ),
            BoxShadow(
              color: MoscaroTokens.auroraBlue.withValues(alpha: 0.15),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SvgIcon(name: 'folder', size: 24, color: Color(0xFF00E1FF)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Migração de Cadernos & Notas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Você alterou o diretório padrão de salvamento dos seus cadernos. Como deseja proceder com suas notas e cadernos atuais?',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            // Opção 1: Mover Tudo
            InkWell(
              onTap: () => Navigator.of(context).pop(true),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MoscaroTokens.auroraBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MoscaroTokens.auroraBlue.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  children: [
                    SvgIcon(name: 'layers', size: 20, color: Color(0xFF00E1FF)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mover Cadernos para a Nova Pasta (Recomendado)',
                            style: TextStyle(color: Color(0xFF00E1FF), fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Copia todos os cadernos, disciplinas e notas existentes para o novo local.',
                            style: TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Opção 2: Manter Antigos
            InkWell(
              onTap: () => Navigator.of(context).pop(false),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: const Row(
                  children: [
                    SvgIcon(name: 'save', size: 20, color: Colors.white70),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manter Antigos & Iniciar Nova Pasta',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Deixa as notas antigas onde estão e salva apenas as novas notas no novo diretório.',
                            style: TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvasSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      key: const ValueKey('canvas_settings'),
      children: [
        SettingsSliderTile(
          title: 'Espaçamento do Dot Grid',
          description: 'Distância em pixels entre cada ponto da matriz do canvas.',
          value: widget.settings.gridSpacing,
          min: 16.0,
          max: 48.0,
          divisions: 8,
          formatValue: (val) => '${val.round()} px',
          onChanged: (val) => widget.onUpdateSettings(widget.settings.copyWith(gridSpacing: val)),
        ),
        SettingsToggleTile(
          title: 'Glow Reativo do Mouse no Grid',
          description: 'Ilumina os pontos do grid sob a posição do cursor em tempo real.',
          value: widget.settings.enableMouseGlow,
          onChanged: (val) => widget.onUpdateSettings(widget.settings.copyWith(enableMouseGlow: val)),
        ),
        if (widget.settings.enableMouseGlow)
          SettingsSliderTile(
            title: 'Raio do Halo de Glow',
            description: 'Alcance da iluminação dos pontos sob o ponteiro.',
            value: widget.settings.mouseGlowRadius,
            min: 60.0,
            max: 240.0,
            divisions: 9,
            formatValue: (val) => '${val.round()} px',
            onChanged: (val) => widget.onUpdateSettings(widget.settings.copyWith(mouseGlowRadius: val)),
          ),
      ],
    );
  }

  Widget _buildPenSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      key: const ValueKey('pen_settings'),
      children: [
        SettingsSliderTile(
          title: 'Suavização de Traço (Ramer-Douglas-Peucker)',
          description: 'Nível de estabilização e redução de ruído dos traços à mão livre.',
          value: widget.settings.rdpSmoothingTolerance,
          min: 0.1,
          max: 0.8,
          divisions: 7,
          formatValue: (val) => val.toStringAsFixed(2),
          onChanged: (val) => widget.onUpdateSettings(widget.settings.copyWith(rdpSmoothingTolerance: val)),
        ),
        SettingsSliderTile(
          title: 'Sensibilidade à Pressão da Stylus',
          description: 'Multiplicador de espessura de acordo com a pressão da caneta/Apple Pencil/S-Pen.',
          value: widget.settings.pressureSensitivity,
          min: 0.5,
          max: 2.0,
          divisions: 6,
          formatValue: (val) => '${val.toStringAsFixed(1)}x',
          onChanged: (val) => widget.onUpdateSettings(widget.settings.copyWith(pressureSensitivity: val)),
        ),
        SettingsSliderTile(
          title: 'Tempo de Espera para Formas Inteligentes (Draw & Hold)',
          description: 'Duração necessária mantendo a caneta parada no final para converter o traço em forma perfeita.',
          value: widget.settings.drawAndHoldDurationMs.toDouble(),
          min: 250.0,
          max: 750.0,
          divisions: 10,
          formatValue: (val) => '${val.round()} ms',
          onChanged: (val) => widget.onUpdateSettings(widget.settings.copyWith(drawAndHoldDurationMs: val.round())),
        ),
        SettingsSandboxCard(
          smoothingTolerance: widget.settings.rdpSmoothingTolerance,
          pressureSensitivity: widget.settings.pressureSensitivity,
        ),
      ],
    );
  }

  Widget _buildMeasurementSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      key: const ValueKey('measurement_settings'),
      children: [
        SettingsSliderTile(
          title: 'Tolerância de Atração Magnética (Ink Snapping)',
          description: 'Distância máxima em pixels para a caneta conectar magneticamente à borda da Régua e ao arco do Transferidor.',
          value: widget.settings.inkSnapTolerance,
          min: 12.0,
          max: 40.0,
          divisions: 7,
          formatValue: (val) => '${val.round()} px',
          onChanged: (val) => widget.onUpdateSettings(widget.settings.copyWith(inkSnapTolerance: val)),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1422).withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trava Magnética de Ângulo (Angle Snap)',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.1),
              ),
              const SizedBox(height: 4),
              Text(
                'Define o intervalo de graus onde a rotação trava automaticamente.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                children: [0.0, 5.0, 15.0, 30.0, 45.0].map((step) {
                  final isSelected = widget.settings.angleSnapStepDegrees == step;
                  final label = step == 0.0 ? 'Livre' : '${step.round()}°';
                  return GestureDetector(
                    onTap: () => widget.onUpdateSettings(widget.settings.copyWith(angleSnapStepDegrees: step)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  MoscaroTokens.auroraBlue.withValues(alpha: 0.3),
                                  MoscaroTokens.auroraPurple.withValues(alpha: 0.15),
                                ],
                              )
                            : null,
                        color: isSelected ? null : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? MoscaroTokens.auroraBlue.withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.12),
                          width: isSelected ? 1.2 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: MoscaroTokens.auroraBlue.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                ),
                              ]
                            : [],
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? MoscaroTokens.auroraBlue : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAiSettings() {

    final bool hasGemini = widget.settings.geminiApiKey.isNotEmpty;
    final bool hasOpenAi = widget.settings.openAiApiKey.isNotEmpty;
    final bool hasClaude = widget.settings.claudeApiKey.isNotEmpty;
    final bool hasOllama = widget.settings.ollamaEndpointUrl.isNotEmpty;
    final theme = MoscaroThemeController.instance.currentTheme;
    final accent = theme.accentPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      key: const ValueKey('ai_settings'),
      children: [
        // 1. Banner de Privacidade Local-First
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              SvgIcon(assetName: 'ai', color: accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Privacidade Garantida: Suas chaves de API ficam salvas exclusivamente no seu computador e nenhuma informação passa por servidores intermediários.',
                  style: TextStyle(
                    color: MoscaroTokens.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Provedores de IA & Chaves de API
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'PROVEDORES & CHAVES DE API',
            style: TextStyle(color: accent.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
        ),

        // Google Gemini
        _buildApiKeyCard(
          title: 'Google Gemini API',
          description: 'Gemini 2.5 Flash & 1.5 Pro. Chave gratuita no Google AI Studio (aistudio.google.com).',
          hasKey: hasGemini,
          isEnabled: widget.settings.enableGemini,
          controller: _geminiController,
          obscureText: _isApiKeyObscured,
          hintText: 'AIzaSy...',
          accentColor: accent,
          surfaceColor: theme.backgroundSurface,
          helpInfo: const AiProviderInfo(
            providerName: 'Google Gemini API',
            pricingType: '100% Gratuito (com cota)',
            isFree: true,
            capabilities: 'Especialista em matemática, integrais/derivadas passo a passo, deduções físicas, OCR de manuscritos e diagramas KaTeX no canvas.',
            steps: [
              'Acesse o Google AI Studio (aistudio.google.com).',
              'Faça login com sua conta Google pessoal ou profissional.',
              'Clique no botão azul "Get API key" e depois "Create API key".',
              'Copie a chave gerada (inicia com AIzaSy...) e cole abaixo.',
            ],
            officialUrl: 'https://aistudio.google.com/app/apikey',
            buttonLabel: 'Abrir Google AI Studio (Gratuito)',
          ),
          onToggleObscure: () => setState(() => _isApiKeyObscured = !_isApiKeyObscured),
          onChanged: (val) => widget.onUpdateSettings(widget.settings.copyWith(geminiApiKey: val.trim())),
          onToggleEnable: (val) => widget.onUpdateSettings(widget.settings.copyWith(enableGemini: val)),
        ),

        // OpenAI
        _buildApiKeyCard(
          title: 'OpenAI API',
          description: 'GPT-4o e GPT-4o mini para raciocínio lógico e análise multimodal.',
          hasKey: hasOpenAi,
          isEnabled: widget.settings.enableOpenAi,
          controller: _openAiController,
          obscureText: _isOpenAiKeyObscured,
          hintText: 'sk-proj-...',
          accentColor: accent,
          surfaceColor: theme.backgroundSurface,
          helpInfo: const AiProviderInfo(
            providerName: 'OpenAI API',
            pricingType: 'Pago (Pré-pago a partir de \$5)',
            isFree: false,
            capabilities: 'GPT-4o e GPT-4o mini. Alto nível de precisão algorítmica, raciocínio lógico formal e estruturação de cartões de estudo.',
            steps: [
              'Acesse o portal de desenvolvedores da OpenAI (platform.openai.com).',
              'Faça login e adicione créditos na seção "Billing" (mínimo \$5).',
              'Acesse "API Keys", clique em "Create new secret key" e copie o token.',
              'Cole a chave gerada (inicia com sk-proj-...) no campo abaixo.',
            ],
            officialUrl: 'https://platform.openai.com/api-keys',
            buttonLabel: 'Abrir OpenAI Platform',
          ),
          onToggleObscure: () => setState(() => _isOpenAiKeyObscured = !_isOpenAiKeyObscured),
          onChanged: (val) => widget.onUpdateSettings(widget.settings.copyWith(openAiApiKey: val.trim())),
          onToggleEnable: (val) => widget.onUpdateSettings(widget.settings.copyWith(enableOpenAi: val)),
        ),

        // Anthropic Claude
        _buildApiKeyCard(
          title: 'Anthropic Claude API',
          description: 'Claude 3.5 Sonnet & Haiku para escrita científica e código estruturado.',
          hasKey: hasClaude,
          isEnabled: widget.settings.enableClaude,
          controller: _claudeController,
          obscureText: _isClaudeKeyObscured,
          hintText: 'sk-ant-...',
          accentColor: accent,
          surfaceColor: theme.backgroundSurface,
          helpInfo: const AiProviderInfo(
            providerName: 'Anthropic Claude API',
            pricingType: 'Pago (Pré-pago a partir de \$5)',
            isFree: false,
            capabilities: 'Claude 3.5 Sonnet. Didática refinada para escrita científica, resumos acadêmicos e formatação limpa de LaTeX e teoremas.',
            steps: [
              'Acesse o Console da Anthropic (console.anthropic.com).',
              'Configure sua forma de pagamento em "Plans & Billing".',
              'Vá para "API Keys", gere uma nova chave ("Create Key") e copie.',
              'Cole a chave gerada (inicia com sk-ant-...) no campo abaixo.',
            ],
            officialUrl: 'https://console.anthropic.com/settings/keys',
            buttonLabel: 'Abrir Anthropic Console',
          ),
          onToggleObscure: () => setState(() => _isClaudeKeyObscured = !_isClaudeKeyObscured),
          onChanged: (val) => widget.onUpdateSettings(widget.settings.copyWith(claudeApiKey: val.trim())),
          onToggleEnable: (val) => widget.onUpdateSettings(widget.settings.copyWith(enableClaude: val)),
        ),

        // Ollama Local
        _buildApiKeyCard(
          title: 'Ollama Local (100% Offline)',
          description: 'URL do servidor local do Ollama para executar DeepSeek-R1, Llama 3 ou Qwen sem internet.',
          hasKey: hasOllama,
          isEnabled: widget.settings.enableOllama,
          controller: _ollamaController,
          obscureText: false,
          hintText: 'http://localhost:11434',
          accentColor: accent,
          surfaceColor: theme.backgroundSurface,
          badgeLabel: hasOllama ? 'Ativo' : 'Desativado',
          helpInfo: const AiProviderInfo(
            providerName: 'Ollama Local (Offline)',
            pricingType: '100% Gratuito & Offline',
            isFree: true,
            capabilities: 'Privacidade total: executa LLMs como DeepSeek-R1, Llama 3.3 e Qwen 2.5 diretamente no hardware da sua máquina sem enviar dados para nuvem.',
            steps: [
              'Baixe e instale o aplicativo Ollama em ollama.com.',
              'Abra o PowerShell ou Terminal e digite: ollama run deepseek-r1:8b',
              'Mantenha o Ollama rodando em segundo plano.',
              'Confirme se a URL abaixo é http://localhost:11434.',
            ],
            officialUrl: 'https://ollama.com',
            buttonLabel: 'Baixar Ollama no Site Oficial',
          ),
          onToggleObscure: null,
          onChanged: (val) => widget.onUpdateSettings(widget.settings.copyWith(ollamaEndpointUrl: val.trim())),
          onToggleEnable: (val) => widget.onUpdateSettings(widget.settings.copyWith(enableOllama: val)),
        ),

        const SizedBox(height: 12),

        // 3. Toggles Granulares de Privacidade e Funcionalidades
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'CONTROLE DE RECURSOS & PRIVACIDADE',
            style: TextStyle(color: accent.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
        ),

        SettingsToggleTile(
          title: 'Chat Conversacional na Sidebar',
          description: 'Exibe o painel lateral de chat com suporte a LaTeX, KaTeX e histórico.',
          value: widget.settings.enableAiSidebar,
          onChanged: (val) => widget.onUpdateSettings(widget.settings.copyWith(enableAiSidebar: val)),
        ),

        SettingsToggleTile(
          title: 'Botão de IA na Seleção (Lasso & Cards)',
          description: 'Exibe o botão de ação rápida na pílula flutuante ao selecionar elementos no canvas.',
          value: widget.settings.enableAiSelectionActions,
          onChanged: (val) => widget.onUpdateSettings(widget.settings.copyWith(enableAiSelectionActions: val)),
        ),

        SettingsToggleTile(
          title: 'Comandos Inline (/ai) nos Cards',
          description: 'Permite invocar a IA diretamente dentro dos blocos de texto digitando /ai.',
          value: widget.settings.enableAiInlineCommands,
          onChanged: (val) => widget.onUpdateSettings(widget.settings.copyWith(enableAiInlineCommands: val)),
        ),

        SettingsToggleTile(
          title: 'Geração de Diagramas Mermaid',
          description: 'Permite à IA criar fluxogramas, árvores e diagramas técnicos no canvas.',
          value: widget.settings.enableAiMermaidDiagrams,
          onChanged: (val) => widget.onUpdateSettings(widget.settings.copyWith(enableAiMermaidDiagrams: val)),
        ),

        SettingsToggleTile(
          title: 'Reconhecimento de Tinta (OCR para LaTeX)',
          description: 'Habilita a conversão de equações manuscritas com a caneta em Cards STEM formatados.',
          value: widget.settings.enableAiHandwritingOcr,
          onChanged: (val) => widget.onUpdateSettings(widget.settings.copyWith(enableAiHandwritingOcr: val)),
        ),

        SettingsToggleTile(
          title: 'Modo Tutor Socrático',
          description: 'Quando ativado, a IA prioriza formular perguntas e dicas progressivas (> [!TIP]) em vez de apenas dar a resposta pronta.',
          value: widget.settings.enableAiSocraticMode,
          onChanged: (val) => widget.onUpdateSettings(widget.settings.copyWith(enableAiSocraticMode: val)),
        ),
      ],
    );
  }

  Widget _buildApiKeyCard({
    required String title,
    required String description,
    required bool hasKey,
    required bool isEnabled,
    required TextEditingController controller,
    required bool obscureText,
    required String hintText,
    required Color accentColor,
    required Color surfaceColor,
    required AiProviderInfo helpInfo,
    String? badgeLabel,
    VoidCallback? onToggleObscure,
    required ValueChanged<String> onChanged,
    required ValueChanged<bool> onToggleEnable,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.1),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: isEnabled,
                    onChanged: onToggleEnable,
                    activeColor: accentColor,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                  ),
                  const SizedBox(width: 8),
                  AiProviderHelpButton(info: helpInfo),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: hasKey
                          ? MoscaroTokens.auroraGreen.withValues(alpha: 0.15)
                          : Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasKey
                            ? MoscaroTokens.auroraGreen.withValues(alpha: 0.4)
                            : Colors.amber.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasKey ? MoscaroTokens.auroraGreen : Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          badgeLabel ?? (hasKey ? 'Configurada' : 'Não configurada'),
                          style: TextStyle(
                            color: hasKey ? MoscaroTokens.auroraGreen : Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            obscureText: obscureText,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.35),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              prefixIcon: const Icon(Icons.key_rounded, size: 16, color: Colors.white38),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.content_paste_rounded,
                      size: 16,
                      color: Colors.white54,
                    ),
                    tooltip: 'Colar da área de transferência',
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data != null && data.text != null && data.text!.isNotEmpty) {
                        final val = data.text!.trim();
                        controller.text = val;
                        controller.selection = TextSelection.collapsed(offset: val.length);
                        onChanged(val);
                      }
                    },
                  ),
                  if (onToggleObscure != null)
                    IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 16,
                        color: Colors.white38,
                      ),
                      tooltip: obscureText ? 'Mostrar chave' : 'Ocultar chave',
                      onPressed: onToggleObscure,
                    ),
                ],
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor, width: 1.3),
              ),
            ),
            onSubmitted: onChanged,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
