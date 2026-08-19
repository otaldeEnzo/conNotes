import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/theme_models.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import '../theme/moscaro_theme_controller.dart';
import '../theme/theme_harmony_service.dart';
import 'theme_color_field_tile.dart';
import 'theme_palette_slots_editor.dart';
import 'theme_bg_type_selector.dart';
import 'theme_blur_toggles_card.dart';
import 'theme_property_hover_preview.dart';

/// Modal Moscaro de Criação e Edição de Temas Personalizados STEM (Moscaro v2 Pro Max).
class ThemeEditorModal extends StatefulWidget {
  final ThemeDefinition? initialTheme;
  final ValueChanged<ThemeDefinition> onSave;

  const ThemeEditorModal({
    super.key,
    this.initialTheme,
    required this.onSave,
  });

  @override
  State<ThemeEditorModal> createState() => _ThemeEditorModalState();
}

class _ThemeEditorModalState extends State<ThemeEditorModal> {
  int _activeTabIndex = 0;

  late TextEditingController _nameController;
  late String _customId;

  // 1. Fundo & Textura
  late CanvasBackgroundMode _bgMode;
  late Color _backgroundDeep;
  late Color _backgroundSurface;
  late List<Color> _gradientColors;
  late List<double> _gradientStops;
  String? _bgImagePath;
  late double _bgImageOpacity;
  late CanvasTextureType _textureType;

  // 2. Acentos Neon e Vidro Líquido
  late Color _accentPrimary;
  late Color _accentSecondary;
  late Color _dotGridColor;
  late Color _mouseGlowColor;
  late Color _glassColor;
  late Color _borderGlowColor;
  late List<Color> _stemPalette;

  // 3. Blur Individual por Componente
  late bool _enableSidebarBlur;
  late bool _enableToolbarBlur;
  late bool _enableSubBarsBlur;
  late bool _enableModalsBlur;
  late bool _enableInstrumentsBlur;

  @override
  void initState() {
    super.initState();
    final init = widget.initialTheme ?? ThemeDefinition.moscaroCyan;
    _nameController = TextEditingController(
      text: widget.initialTheme != null ? widget.initialTheme!.name : 'Novo Tema STEM',
    );
    _customId = widget.initialTheme?.customId ?? 'custom_${DateTime.now().millisecondsSinceEpoch}';

    _bgMode = init.bgMode;
    _backgroundDeep = init.backgroundDeep;
    _backgroundSurface = init.backgroundSurface;
    _gradientColors = List<Color>.from(init.effectiveGradientColors);
    _gradientStops = List<double>.from(init.effectiveGradientStops);
    _bgImagePath = init.bgImagePath;
    _bgImageOpacity = init.bgImageOpacity;
    _textureType = init.textureType;

    _accentPrimary = init.accentPrimary;
    _accentSecondary = init.accentSecondary;
    _dotGridColor = init.dotGridColor;
    _mouseGlowColor = init.mouseGlowColor;
    _glassColor = init.glassColor;
    _borderGlowColor = init.borderGlowColor;
    _stemPalette = List<Color>.from(init.stemPalette);

    _enableSidebarBlur = init.enableSidebarBlur;
    _enableToolbarBlur = init.enableToolbarBlur;
    _enableSubBarsBlur = init.enableSubBarsBlur;
    _enableModalsBlur = init.enableModalsBlur;
    _enableInstrumentsBlur = init.enableInstrumentsBlur;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerLivePreview();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _triggerLivePreview() {
    MoscaroThemeController.instance.previewTheme(_buildCurrentDefinition());
  }

  void _cancelAndClose() {
    MoscaroThemeController.instance.restoreActiveTheme();
    Navigator.of(context).pop();
  }

  ThemeDefinition _buildCurrentDefinition() {
    return ThemeDefinition(
      preset: AppThemePreset.custom,
      customId: _customId,
      isCustom: true,
      name: _nameController.text.trim().isEmpty ? 'Tema Personalizado' : _nameController.text.trim(),
      bgMode: _bgMode,
      backgroundDeep: _backgroundDeep,
      backgroundSurface: _backgroundSurface,
      gradientColors: _gradientColors,
      gradientStops: _gradientStops,
      bgImagePath: _bgImagePath,
      bgImageOpacity: _bgImageOpacity,
      textureType: _textureType,
      accentPrimary: _accentPrimary,
      accentSecondary: _accentSecondary,
      dotGridColor: _dotGridColor,
      mouseGlowColor: _mouseGlowColor,
      glassColor: _glassColor,
      borderGlowColor: _borderGlowColor,
      stemPalette: _stemPalette,
      enableSidebarBlur: _enableSidebarBlur,
      enableToolbarBlur: _enableToolbarBlur,
      enableSubBarsBlur: _enableSubBarsBlur,
      enableModalsBlur: _enableModalsBlur,
      enableInstrumentsBlur: _enableInstrumentsBlur,
    );
  }

  void _applyHarmonyFromBase() {
    final generated = ThemeHarmonyService.generateHarmoniousTheme(
      baseBg: _backgroundSurface,
      primaryAccent: _accentPrimary,
      name: _nameController.text,
    );
    setState(() {
      _backgroundDeep = generated.backgroundDeep;
      _gradientColors = List<Color>.from(generated.effectiveGradientColors);
      _gradientStops = List<double>.from(generated.effectiveGradientStops);
      _accentSecondary = generated.accentSecondary;
      _dotGridColor = generated.dotGridColor;
      _mouseGlowColor = generated.mouseGlowColor;
      _glassColor = generated.glassColor;
      _borderGlowColor = generated.borderGlowColor;
      _stemPalette = List<Color>.from(generated.stemPalette);
    });
    _triggerLivePreview();
  }

  void _applyRandomTheme() {
    final generated = ThemeHarmonyService.generateRandomTheme();
    setState(() {
      _nameController.text = generated.name;
      _backgroundDeep = generated.backgroundDeep;
      _backgroundSurface = generated.backgroundSurface;
      _gradientColors = List<Color>.from(generated.effectiveGradientColors);
      _gradientStops = List<double>.from(generated.effectiveGradientStops);
      _accentPrimary = generated.accentPrimary;
      _accentSecondary = generated.accentSecondary;
      _dotGridColor = generated.dotGridColor;
      _mouseGlowColor = generated.mouseGlowColor;
      _glassColor = generated.glassColor;
      _borderGlowColor = generated.borderGlowColor;
      _stemPalette = List<Color>.from(generated.stemPalette);
    });
    _triggerLivePreview();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _buildCurrentDefinition();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          MoscaroThemeController.instance.restoreActiveTheme();
        }
      },
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 720,
            height: 660,
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header do Modal com Ícone Moscaro
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _accentPrimary.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                              border: Border.all(color: _accentPrimary.withValues(alpha: 0.4)),
                            ),
                            child: Icon(Icons.palette_rounded, color: _accentPrimary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.initialTheme != null ? 'Editar Tema STEM' : 'Criar Novo Tema STEM',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              Text(
                                'Personalize fundos, acentos, desfoque individual e paletas.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                        onPressed: _cancelAndClose,
                        tooltip: 'Fechar',
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Colors.white12),

                // 2. Mini-Preview Dinâmico do Canvas
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _accentPrimary.withValues(alpha: 0.4), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: _accentPrimary.withValues(alpha: 0.12),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          if (_bgMode == CanvasBackgroundMode.customImage && _bgImagePath != null && File(_bgImagePath!).existsSync())
                            Positioned.fill(
                              child: Image.file(
                                File(_bgImagePath!),
                                fit: BoxFit.cover,
                                opacity: AlwaysStoppedAnimation(_bgImageOpacity),
                              ),
                            )
                          else
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: _bgMode == CanvasBackgroundMode.solidColor
                                      ? null
                                      : LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: _gradientColors.length >= 2
                                              ? _gradientColors
                                              : [_backgroundSurface, _backgroundDeep],
                                          stops: _gradientStops.length == _gradientColors.length
                                              ? _gradientStops
                                              : [
                                                  for (int i = 0; i < (_gradientColors.length >= 2 ? _gradientColors.length : 2); i++)
                                                    i / ((_gradientColors.length >= 2 ? _gradientColors.length : 2) - 1)
                                                ],
                                        ),
                                  color: _bgMode == CanvasBackgroundMode.solidColor ? _backgroundSurface : null,
                                ),
                              ),
                            ),
                          // Pontos do Grid e Glow Simulado
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _PreviewDotGridPainter(
                                dotColor: _dotGridColor,
                                glowColor: _mouseGlowColor,
                              ),
                            ),
                          ),
                          // Mockup de Vidro Líquido Flutuante (Respeitando Blur se ativo)
                          Positioned(
                            top: 14,
                            left: 14,
                            right: 14,
                            bottom: 14,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: _enableToolbarBlur ? 16 : 0,
                                  sigmaY: _enableToolbarBlur ? 16 : 0,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _glassColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _borderGlowColor),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: _accentPrimary,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(color: _accentPrimary, blurRadius: 6),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            theme.name,
                                            style: TextStyle(
                                              color: theme.canvasTextColor,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Prévia das 6 canetas
                                      Row(
                                        children: _stemPalette.take(6).map((c) {
                                          return Container(
                                            width: 14,
                                            height: 14,
                                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                            decoration: BoxDecoration(
                                              color: c,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white70, width: 0.8),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // 3. Abas de Configuração (Cores, Fundo & Textura, Blur)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildTabButton(index: 0, label: 'Cores & Acentos', icon: Icons.palette_outlined),
                      const SizedBox(width: 8),
                      _buildTabButton(index: 1, label: 'Fundo & Textura', icon: Icons.wallpaper_outlined),
                      const SizedBox(width: 8),
                      _buildTabButton(index: 2, label: 'Desfoque (Blur)', icon: Icons.blur_on_rounded),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 4. Corpo Scrollável com Conteúdo da Aba
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    children: [
                      if (_activeTabIndex == 0) ...[
                        // Campo de Nome + Botões de Inspiração Rápida
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  labelText: 'Nome do Tema',
                                  labelStyle: const TextStyle(color: Colors.white70, fontSize: 11.5),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.05),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: _accentPrimary, width: 1.3),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                                onChanged: (_) {
                                  setState(() {});
                                  _triggerLivePreview();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Botão Harmonizar
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accentPrimary.withValues(alpha: 0.15),
                                foregroundColor: _accentPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: _accentPrimary.withValues(alpha: 0.4)),
                                ),
                              ),
                              icon: const Icon(Icons.auto_awesome, size: 15),
                              label: const Text('Harmonizar', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                              onPressed: _applyHarmonyFromBase,
                            ),
                            const SizedBox(width: 8),
                            // Botão Inspiração / Shuffle
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.08),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: Colors.white24),
                                ),
                                padding: const EdgeInsets.all(11),
                              ),
                              icon: const Icon(Icons.casino_rounded, size: 18, color: Colors.white),
                              onPressed: _applyRandomTheme,
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Grade de Configuração de Cores Individuais com Hover Preview de 500ms
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 3.4,
                          children: [
                            ThemeColorFieldTile(
                              label: 'Acento Primário',
                              color: _accentPrimary,
                              propertyType: ThemePropertyType.primaryAccent,
                              onColorChanged: (c) {
                                setState(() {
                                  _accentPrimary = c;
                                  _mouseGlowColor = c;
                                  _dotGridColor = c.withValues(alpha: 0.22);
                                  _borderGlowColor = c.withValues(alpha: 0.35);
                                });
                                _triggerLivePreview();
                              },
                            ),
                            ThemeColorFieldTile(
                              label: 'Acento Secundário',
                              color: _accentSecondary,
                              propertyType: ThemePropertyType.secondaryAccent,
                              onColorChanged: (c) {
                                setState(() => _accentSecondary = c);
                                _triggerLivePreview();
                              },
                            ),
                            ThemeColorFieldTile(
                              label: 'Pontos do Grid (Dot)',
                              color: _dotGridColor,
                              allowAlpha: true,
                              propertyType: ThemePropertyType.dotGrid,
                              onColorChanged: (c) {
                                setState(() => _dotGridColor = c);
                                _triggerLivePreview();
                              },
                            ),
                            ThemeColorFieldTile(
                              label: 'Brilho do Mouse (Glow)',
                              color: _mouseGlowColor,
                              propertyType: ThemePropertyType.mouseGlow,
                              onColorChanged: (c) {
                                setState(() => _mouseGlowColor = c);
                                _triggerLivePreview();
                              },
                            ),
                            ThemeColorFieldTile(
                              label: 'Película de Vidro',
                              color: _glassColor,
                              allowAlpha: true,
                              propertyType: ThemePropertyType.glassFilm,
                              onColorChanged: (c) {
                                setState(() => _glassColor = c);
                                _triggerLivePreview();
                              },
                            ),
                            ThemeColorFieldTile(
                              label: 'Borda com Glow Ativo',
                              color: _borderGlowColor,
                              allowAlpha: true,
                              propertyType: ThemePropertyType.borderGlow,
                              onColorChanged: (c) {
                                setState(() => _borderGlowColor = c);
                                _triggerLivePreview();
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Editor da Paleta de Canetas
                        ThemePaletteSlotsEditor(
                          palette: _stemPalette,
                          primaryAccent: _accentPrimary,
                          onPaletteChanged: (p) {
                            setState(() => _stemPalette = p);
                            _triggerLivePreview();
                          },
                        ),
                      ] else if (_activeTabIndex == 1) ...[
                        ThemeBgTypeSelector(
                          bgMode: _bgMode,
                          backgroundSurface: _backgroundSurface,
                          backgroundDeep: _backgroundDeep,
                          gradientColors: _gradientColors,
                          gradientStops: _gradientStops,
                          bgImagePath: _bgImagePath,
                          bgImageOpacity: _bgImageOpacity,
                          textureType: _textureType,
                          accentColor: _accentPrimary,
                          onBgModeChanged: (m) {
                            setState(() => _bgMode = m);
                            _triggerLivePreview();
                          },
                          onSurfaceColorChanged: (c) {
                            setState(() {
                              _backgroundSurface = c;
                              if (_bgMode != CanvasBackgroundMode.solidColor && _gradientColors.isNotEmpty) {
                                _gradientColors[0] = c;
                              }
                            });
                            _triggerLivePreview();
                          },
                          onDeepColorChanged: (c) {
                            setState(() {
                              _backgroundDeep = c;
                              if (_bgMode != CanvasBackgroundMode.solidColor && _gradientColors.length >= 2) {
                                _gradientColors[_gradientColors.length - 1] = c;
                              }
                            });
                            _triggerLivePreview();
                          },
                          onGradientColorsChanged: (colors) {
                            setState(() {
                              _gradientColors = colors;
                              if (colors.isNotEmpty) _backgroundSurface = colors.first;
                              if (colors.length >= 2) _backgroundDeep = colors.last;
                              if (_gradientStops.length != colors.length) {
                                _gradientStops = [
                                  for (int i = 0; i < colors.length; i++) i / (colors.length - 1)
                                ];
                              }
                            });
                            _triggerLivePreview();
                          },
                          onGradientStopsChanged: (stops) {
                            setState(() {
                              _gradientStops = stops;
                            });
                            _triggerLivePreview();
                          },
                          onImagePathChanged: (p) {
                            setState(() => _bgImagePath = p);
                            _triggerLivePreview();
                          },
                          onImageOpacityChanged: (o) {
                            setState(() => _bgImageOpacity = o);
                            _triggerLivePreview();
                          },
                          onTextureTypeChanged: (t) {
                            setState(() => _textureType = t);
                            _triggerLivePreview();
                          },
                        ),
                      ] else if (_activeTabIndex == 2) ...[
                        ThemeBlurTogglesCard(
                          enableSidebarBlur: _enableSidebarBlur,
                          enableToolbarBlur: _enableToolbarBlur,
                          enableSubBarsBlur: _enableSubBarsBlur,
                          enableModalsBlur: _enableModalsBlur,
                          enableInstrumentsBlur: _enableInstrumentsBlur,
                          accentColor: _accentPrimary,
                          onSidebarChanged: (v) {
                            setState(() => _enableSidebarBlur = v);
                            _triggerLivePreview();
                          },
                          onToolbarChanged: (v) {
                            setState(() => _enableToolbarBlur = v);
                            _triggerLivePreview();
                          },
                          onSubBarsChanged: (v) {
                            setState(() => _enableSubBarsBlur = v);
                            _triggerLivePreview();
                          },
                          onModalsChanged: (v) {
                            setState(() => _enableModalsBlur = v);
                            _triggerLivePreview();
                          },
                          onInstrumentsChanged: (v) {
                            setState(() => _enableInstrumentsBlur = v);
                            _triggerLivePreview();
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                const Divider(height: 1, color: Colors.white12),

                // 5. Footer de Ações
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _cancelAndClose,
                        child: const Text('Cancelar', style: TextStyle(color: Colors.white54, fontSize: 12.5)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentPrimary,
                          foregroundColor: _accentPrimary.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 8,
                          shadowColor: _accentPrimary.withValues(alpha: 0.5),
                        ),
                        onPressed: () {
                          final result = _buildCurrentDefinition();
                          MoscaroThemeController.instance.commitPreview();
                          widget.onSave(result);
                          Navigator.of(context).pop();
                        },
                        child: const Text('Salvar Tema', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).moscaroV2(
            borderRadius: 24,
            enableBlur: MoscaroTokens.enableModalsBlur,
            borderColor: _accentPrimary.withValues(alpha: 0.5),
            borderWidth: 1.3,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _activeTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? _accentPrimary.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _accentPrimary : Colors.white12,
            width: isSelected ? 1.3 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? _accentPrimary : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewDotGridPainter extends CustomPainter {
  final Color dotColor;
  final Color glowColor;

  _PreviewDotGridPainter({
    required this.dotColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 18.0;
    final dotPaint = Paint()
      ..color = dotColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0;

    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.8)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.2;

    final center = Offset(size.width * 0.7, size.height * 0.5);

    for (double x = 6; x < size.width; x += spacing) {
      for (double y = 6; y < size.height; y += spacing) {
        final pt = Offset(x, y);
        if ((pt - center).distanceSquared < 35 * 35) {
          canvas.drawPoints(PointMode.points, [pt], glowPaint);
        } else {
          canvas.drawPoints(PointMode.points, [pt], dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewDotGridPainter oldDelegate) {
    return oldDelegate.dotColor != dotColor || oldDelegate.glowColor != glowColor;
  }
}
