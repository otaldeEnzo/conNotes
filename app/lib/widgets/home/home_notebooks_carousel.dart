import 'package:flutter/material.dart';
import '../../services/workspace_storage_service.dart';
import '../../theme/moscaro_theme_controller.dart';
import '../../theme/moscaro_v2_tokens.dart';
import '../svg_icon.dart';

/// Carrossel Horizontal e Seletor de Cadernos (Notebooks) do Home Hub conNotes.
/// Estilo Moscaro Liquid Glass com contagem de notas, cores temáticas de acento,
/// filtro instantâneo e modal rápido de criação de novo caderno.
class HomeNotebooksCarousel extends StatelessWidget {
  final String? selectedNotebookId;
  final ValueChanged<String?> onNotebookSelected;

  const HomeNotebooksCarousel({
    super.key,
    required this.selectedNotebookId,
    required this.onNotebookSelected,
  });

  static void showCreateNotebookDialog(BuildContext context) {
    final theme = MoscaroThemeController.instance.currentTheme;
    final nameController = TextEditingController();
    Color selectedColor = theme.accentPrimary;

    final presetColors = [
      theme.accentPrimary,
      theme.accentSecondary,
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEC4899), // Pink
      const Color(0xFF8B5CF6), // Violet
    ];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Criar Caderno',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, anim1, anim2) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isLight = MoscaroTokens.isLight;

            return Center(
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  width: 380,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: theme.backgroundSurface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selectedColor.withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: selectedColor.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: selectedColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: SvgIcon(
                              name: 'book',
                              size: 18,
                              color: selectedColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Novo Caderno',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                              color: isLight ? const Color(0xFF0F172A) : Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nome da Matéria ou Coleção',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: isLight ? const Color(0xFF0F172A) : Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ex: Cálculo Diferencial, Física Moderna...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isLight ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          filled: true,
                          fillColor: isLight ? const Color(0x0F0F172A) : const Color(0x15FFFFFF),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isLight ? const Color(0x200F172A) : const Color(0x25FFFFFF),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: selectedColor, width: 1.2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Cor Temática da Capa',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: presetColors.map((col) {
                          final isColSelected = col == selectedColor;
                          return GestureDetector(
                            onTap: () => setDialogState(() => selectedColor = col),
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: col,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isColSelected ? Colors.white : Colors.transparent,
                                  width: 2.2,
                                ),
                                boxShadow: isColSelected
                                    ? [
                                        BoxShadow(
                                          color: col.withValues(alpha: 0.6),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(
                                color: isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedColor,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              final name = nameController.text.trim();
                              if (name.isNotEmpty) {
                                await WorkspaceStorageService.instance.createNotebook(
                                  name,
                                  color: selectedColor,
                                );
                              }
                              if (dialogCtx.mounted) {
                                Navigator.pop(dialogCtx);
                              }
                            },
                            child: const Text(
                              'Criar Caderno',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = MoscaroThemeController.instance.currentTheme;
    final isLight = MoscaroTokens.isLight;

    return AnimatedBuilder(
      animation: WorkspaceStorageService.instance,
      builder: (context, _) {
        final notebooks = WorkspaceStorageService.instance.notebooks;
        final allNotes = WorkspaceStorageService.instance.allNotes;

        return RepaintBoundary(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho da Seção de Cadernos
              Row(
                children: [
                  Text(
                    'Cadernos & Matérias',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: isLight ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.accentPrimary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${notebooks.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.accentPrimary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Botão "+ Novo Caderno"
                  InkWell(
                    onTap: () => showCreateNotebookDialog(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isLight ? const Color(0x0F0F172A) : const Color(0x12FFFFFF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.accentPrimary.withValues(alpha: 0.3),
                          width: 0.9,
                        ),
                      ),
                      child: Row(
                        children: [
                          SvgIcon(
                            name: 'plus',
                            size: 13,
                            color: theme.accentPrimary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Novo Caderno',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: theme.accentPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Carrossel Horizontal de Cards de Cadernos
              SizedBox(
                height: 84,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Card 1: "Todos os Cadernos"
                    _buildNotebookCard(
                      id: null,
                      name: 'Todas as Notas',
                      noteCount: allNotes.length,
                      color: theme.accentPrimary,
                      isSelected: selectedNotebookId == null,
                      onTap: () => onNotebookSelected(null),
                      theme: theme,
                      isLight: isLight,
                      isAll: true,
                    ),

                    // Cards dos Cadernos Reais
                    ...notebooks.map((nb) {
                      final isSelected = selectedNotebookId == nb.id;
                      return _buildNotebookCard(
                        id: nb.id,
                        name: nb.name,
                        noteCount: nb.notes.length,
                        color: nb.color,
                        isSelected: isSelected,
                        onTap: () => onNotebookSelected(nb.id),
                        theme: theme,
                        isLight: isLight,
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotebookCard({
    required String? id,
    required String name,
    required int noteCount,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    required dynamic theme,
    required bool isLight,
    bool isAll = false,
  }) {
    return AnimatedScale(
      scale: isSelected ? 1.03 : 1.0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 172,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: isLight ? 0.20 : 0.24)
                    : (isLight ? const Color(0x0C0F172A) : const Color(0x0AFFFFFF)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? color
                      : (isLight ? const Color(0x180F172A) : const Color(0x22FFFFFF)),
                  width: isSelected ? 1.5 : 0.9,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 16,
                          spreadRadius: -1,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  // Ícone animado com capa do caderno
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    width: 36,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.35) : color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? color : color.withValues(alpha: 0.5),
                        width: isSelected ? 1.4 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.45),
                                blurRadius: 10,
                                spreadRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: SvgIcon(
                        name: isAll ? 'home' : 'book',
                        size: isSelected ? 18 : 16,
                        color: isSelected ? Colors.white : color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Nome e contagem
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected
                                ? (isLight ? const Color(0xFF0F172A) : Colors.white)
                                : (isLight ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$noteCount ${noteCount == 1 ? 'nota' : 'notas'}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected
                                ? (isLight ? color : const Color(0xFF00E1FF))
                                : (isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
