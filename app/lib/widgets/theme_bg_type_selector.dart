import 'package:flutter/material.dart';
import '../models/theme_models.dart';
import '../services/windows_file_dialog_service.dart';
import 'theme_color_field_tile.dart';
import 'theme_gradient_stops_editor.dart';

/// Seletor Multimodal de Tipos de Fundo e Texturas STEM com Diálogo Nativo Real do Windows.
class ThemeBgTypeSelector extends StatelessWidget {
  final CanvasBackgroundMode bgMode;
  final Color backgroundSurface;
  final Color backgroundDeep;
  final List<Color> gradientColors;
  final List<double>? gradientStops;
  final String? bgImagePath;
  final double bgImageOpacity;
  final CanvasTextureType textureType;
  final Color accentColor;
  final ValueChanged<CanvasBackgroundMode> onBgModeChanged;
  final ValueChanged<Color> onSurfaceColorChanged;
  final ValueChanged<Color> onDeepColorChanged;
  final ValueChanged<List<Color>> onGradientColorsChanged;
  final ValueChanged<List<double>>? onGradientStopsChanged;
  final ValueChanged<String?> onImagePathChanged;
  final ValueChanged<double> onImageOpacityChanged;
  final ValueChanged<CanvasTextureType> onTextureTypeChanged;

  const ThemeBgTypeSelector({
    super.key,
    required this.bgMode,
    required this.backgroundSurface,
    required this.backgroundDeep,
    required this.gradientColors,
    this.gradientStops,
    this.bgImagePath,
    required this.bgImageOpacity,
    required this.textureType,
    required this.accentColor,
    required this.onBgModeChanged,
    required this.onSurfaceColorChanged,
    required this.onDeepColorChanged,
    required this.onGradientColorsChanged,
    this.onGradientStopsChanged,
    required this.onImagePathChanged,
    required this.onImageOpacityChanged,
    required this.onTextureTypeChanged,
  });

  Future<void> _pickImageFile() async {
    final filePath = await WindowsFileDialogService.pickImageFile();
    if (filePath != null && filePath.isNotEmpty) {
      onImagePathChanged(filePath);
    }
  }

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
          // 1. Header do Tipo de Fundo
          Row(
            children: [
              Icon(Icons.wallpaper_rounded, color: accentColor, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Tipo de Fundo do Canvas',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2. Abas de Modos de Fundo
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: CanvasBackgroundMode.values.map((mode) {
              final isSelected = bgMode == mode;
              return GestureDetector(
                onTap: () => onBgModeChanged(mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? accentColor : Colors.white12,
                      width: isSelected ? 1.3 : 1.0,
                    ),
                  ),
                  child: Text(
                    mode.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // 3. Conteúdo Específico por Modo
          _buildModeContent(context),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 12),

          // 4. Seletor de Textura Procedural Overlay
          Row(
            children: [
              Icon(Icons.texture_rounded, color: accentColor, size: 16),
              const SizedBox(width: 6),
              const Text(
                'Textura Técnica Procedural (Sobreposição)',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: CanvasTextureType.values.map((tex) {
              final isSelected = textureType == tex;
              return GestureDetector(
                onTap: () => onTextureTypeChanged(tex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? accentColor.withValues(alpha: 0.8) : Colors.white12,
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    tex.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildModeContent(BuildContext context) {
    switch (bgMode) {
      case CanvasBackgroundMode.preset:
        return Row(
          children: [
            Expanded(
              child: ThemeColorFieldTile(
                label: 'Cor Superior (Surface)',
                color: backgroundSurface,
                onColorChanged: onSurfaceColorChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ThemeColorFieldTile(
                label: 'Cor Profunda (Deep)',
                color: backgroundDeep,
                onColorChanged: onDeepColorChanged,
              ),
            ),
          ],
        );

      case CanvasBackgroundMode.gradient:
        return ThemeGradientStopsEditor(
          colors: gradientColors,
          stops: gradientStops,
          accentColor: accentColor,
          onColorsChanged: onGradientColorsChanged,
          onStopsChanged: onGradientStopsChanged,
        );

      case CanvasBackgroundMode.solidColor:
        return ThemeColorFieldTile(
          label: 'Cor Sólida do Fundo',
          color: backgroundSurface,
          onColorChanged: (c) {
            onSurfaceColorChanged(c);
            onDeepColorChanged(c);
          },
        );

      case CanvasBackgroundMode.stemWallpaper:
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: StemWallpaperPreset.builtInWallpapers.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 68,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (ctx, index) {
            final wp = StemWallpaperPreset.builtInWallpapers[index];
            final isSelected = bgImagePath == wp.id;
            return GestureDetector(
              onTap: () {
                onImagePathChanged(wp.id);
                onSurfaceColorChanged(wp.baseColor);
                onDeepColorChanged(wp.baseColor.withValues(alpha: 0.7));
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: wp.baseColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? accentColor : Colors.white12,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: accentColor.withValues(alpha: 0.3), blurRadius: 8)]
                      : [],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      wp.name,
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      wp.description,
                      style: const TextStyle(color: Colors.white54, fontSize: 9.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        );

      case CanvasBackgroundMode.customImage:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      bgImagePath != null && bgImagePath!.isNotEmpty
                          ? bgImagePath!
                          : 'Nenhuma imagem selecionada do disco',
                      style: TextStyle(
                        color: bgImagePath != null ? Colors.white : Colors.white38,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor.withValues(alpha: 0.2),
                    foregroundColor: accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: accentColor.withValues(alpha: 0.4)),
                    ),
                  ),
                  icon: const Icon(Icons.folder_open_rounded, size: 14),
                  label: const Text('Procurar', style: TextStyle(fontSize: 11)),
                  onPressed: _pickImageFile,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Opacidade da Imagem:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: bgImageOpacity,
                    min: 0.05,
                    max: 1.0,
                    activeColor: accentColor,
                    onChanged: onImageOpacityChanged,
                  ),
                ),
                Text('${(bgImageOpacity * 100).round()}%', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
              ],
            ),
          ],
        );
    }
  }
}
