import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/theme_models.dart';
import '../theme/moscaro_theme_controller.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import 'theme_preset_card.dart';
import 'create_theme_card.dart';
import 'theme_editor_modal.dart';

/// Visualizador da Aba de Temas & Estilo (Moscaro v2 Pro Max).
class SettingsThemeView extends StatefulWidget {
  final VoidCallback onThemeChanged;

  const SettingsThemeView({
    super.key,
    required this.onThemeChanged,
  });

  @override
  State<SettingsThemeView> createState() => _SettingsThemeViewState();
}

class _SettingsThemeViewState extends State<SettingsThemeView> {
  void _openCreateModal({ThemeDefinition? initialTheme}) {
    showDialog(
      context: context,
      builder: (ctx) {
        return ThemeEditorModal(
          initialTheme: initialTheme,
          onSave: (newTheme) {
            final controller = MoscaroThemeController.instance;
            if (initialTheme != null && initialTheme.isCustom) {
              controller.updateCustomTheme(newTheme);
            } else {
              controller.addCustomTheme(newTheme);
            }
            widget.onThemeChanged();
          },
        );
      },
    );
  }

  void _exportTheme(ThemeDefinition theme) {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(theme.toJson());
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.file_upload_outlined, color: MoscaroTokens.auroraBlue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Exportar: ${theme.name}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Copie o código JSON abaixo para salvar ou compartilhar seu tema:',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 180,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      jsonStr,
                      style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Fechar', style: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MoscaroTokens.auroraBlue.withValues(alpha: 0.2),
                        foregroundColor: MoscaroTokens.auroraBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: MoscaroTokens.auroraBlue),
                        ),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: const Text('Copiar JSON'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: jsonStr));
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Código JSON do tema copiado para a área de transferência!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ).moscaroV2(
            borderRadius: 20,
            enableBlur: MoscaroTokens.enableModalsBlur,
            borderColor: MoscaroTokens.auroraBlue.withValues(alpha: 0.5),
            borderWidth: 1.2,
          ),
        );
      },
    );
  }

  void _openImportDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.file_download_outlined, color: MoscaroTokens.auroraBlue, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Importar Tema Personalizado',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cole o código JSON do tema para importá-lo no conNotes:',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  maxLines: 8,
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 11),
                  decoration: InputDecoration(
                    hintText: '{\n  "name": "Meu Tema",\n  ...\n}',
                    hintStyle: const TextStyle(color: Colors.white30, fontFamily: 'monospace'),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.4),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: MoscaroTokens.auroraBlue),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MoscaroTokens.auroraBlue.withValues(alpha: 0.2),
                        foregroundColor: MoscaroTokens.auroraBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: MoscaroTokens.auroraBlue),
                        ),
                      ),
                      onPressed: () {
                        try {
                          final parsed = jsonDecode(textController.text) as Map<String, dynamic>;
                          final theme = ThemeDefinition.fromJson(parsed);
                          MoscaroThemeController.instance.addCustomTheme(theme);
                          widget.onThemeChanged();
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Tema "${theme.name}" importado com sucesso!'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Erro: Formato JSON inválido para o tema.'),
                              backgroundColor: Colors.redAccent,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      child: const Text('Importar'),
                    ),
                  ],
                ),
              ],
            ),
          ).moscaroV2(
            borderRadius: 20,
            enableBlur: MoscaroTokens.enableModalsBlur,
            borderColor: MoscaroTokens.auroraBlue.withValues(alpha: 0.5),
            borderWidth: 1.2,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = MoscaroThemeController.instance;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          key: const ValueKey('theme_settings_view'),
          children: [
            // 1. Grade de Presets Oficiais STEM
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Presets Oficiais STEM (Paletas de Alta Vivacidade)',
                style: TextStyle(
                  color: MoscaroTokens.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            ),

            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 580;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ThemeDefinition.officialPresets.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isWide ? 3 : 2,
                    mainAxisExtent: 180,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final presetTheme = ThemeDefinition.officialPresets[index];
                    final isSelected = controller.activePreset != AppThemePreset.custom &&
                        controller.activeThemeId == presetTheme.preset.id;

                    return ThemePresetCard(
                      theme: presetTheme,
                      isSelected: isSelected,
                      onSelect: () {
                        controller.selectPreset(presetTheme.preset);
                        widget.onThemeChanged();
                      },
                      onDuplicate: () {
                        final copy = controller.duplicateTheme(presetTheme);
                        widget.onThemeChanged();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Tema duplicado como "${copy.name}"!'), duration: const Duration(seconds: 2)),
                        );
                      },
                      onExport: () => _exportTheme(presetTheme),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            // 2. Seção de Temas Personalizados
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Temas Personalizados',
                        style: TextStyle(
                          color: MoscaroTokens.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: MoscaroTokens.auroraBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: MoscaroTokens.auroraBlue.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '${controller.customThemes.length}',
                          style: TextStyle(color: MoscaroTokens.auroraBlue, fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: MoscaroTokens.auroraBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.file_download_outlined, size: 15),
                    label: const Text('Importar JSON', style: TextStyle(fontSize: 12)),
                    onPressed: _openImportDialog,
                  ),
                ],
              ),
            ),

            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 580;
                final customList = controller.customThemes;
                final totalItems = customList.length + 1; // +1 para o CreateThemeCard

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: totalItems,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isWide ? 3 : 2,
                    mainAxisExtent: 180,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return CreateThemeCard(
                        onTap: () => _openCreateModal(),
                      );
                    }

                    final customTheme = customList[index - 1];
                    final isSelected = controller.activeThemeId == customTheme.id;

                    return ThemePresetCard(
                      theme: customTheme,
                      isSelected: isSelected,
                      onSelect: () {
                        controller.selectCustomTheme(customTheme);
                        widget.onThemeChanged();
                      },
                      onEdit: () => _openCreateModal(initialTheme: customTheme),
                      onDuplicate: () {
                        final copy = controller.duplicateTheme(customTheme);
                        widget.onThemeChanged();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Tema duplicado como "${copy.name}"!'), duration: const Duration(seconds: 2)),
                        );
                      },
                      onExport: () => _exportTheme(customTheme),
                      onDelete: () {
                        controller.deleteCustomTheme(customTheme.id);
                        widget.onThemeChanged();
                      },
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}
