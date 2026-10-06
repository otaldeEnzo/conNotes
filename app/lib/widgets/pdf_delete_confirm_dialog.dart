import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_theme_controller.dart';
import 'svg_icon.dart';

/// Opções de resposta do diálogo de confirmação de exclusão do PDF.
enum PdfDeleteChoice {
  deleteAllPages,
  deleteCurrentPageOnly,
  cancel,
}

/// Diálogo modal estilizado no padrão Moscaro v2 para confirmação de exclusão de página PDF.
class PdfDeleteConfirmDialog extends StatelessWidget {
  final int pageNumber;
  final int totalPages;

  const PdfDeleteConfirmDialog({
    super.key,
    required this.pageNumber,
    required this.totalPages,
  });

  /// Exibe o diálogo modal e retorna a escolha do usuário.
  static Future<PdfDeleteChoice?> show(
    BuildContext context, {
    required int pageNumber,
    required int totalPages,
  }) {
    return showDialog<PdfDeleteChoice>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => PdfDeleteConfirmDialog(
        pageNumber: pageNumber,
        totalPages: totalPages,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = MoscaroTokens.isLight;
    final theme = MoscaroThemeController.instance.currentTheme;
    final themeAccent = theme.accentPrimary;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(
              width: 380.0,
              padding: const EdgeInsets.all(22.0),
              decoration: BoxDecoration(
                color: isLight
                    ? const Color(0xFFF8FAFC).withValues(alpha: 0.95)
                    : const Color(0xFF0E1018).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: MoscaroTokens.borderGlowActive.withValues(alpha: 0.35),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.50),
                    blurRadius: 28.0,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: themeAccent.withValues(alpha: 0.15),
                    blurRadius: 16.0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabeçalho com ícone de exclusão
                  Row(
                    children: [
                      Container(
                        width: 34.0,
                        height: 34.0,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                            width: 1.0,
                          ),
                        ),
                        child: const SvgIcon(
                          name: 'trash',
                          size: 16.0,
                          color: Color(0xFFFF5252),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Text(
                          'Excluir Página Master (Pág. $pageNumber)',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: isLight ? Colors.black87 : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14.0),

                  // Descrição explicativa
                  Text(
                    'Esta é a página principal vinculada ao documento PDF ($totalPages páginas). Deseja apagar o documento por completo ou remover apenas esta página do canvas?',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.0,
                      fontWeight: FontWeight.w400,
                      color: MoscaroTokens.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22.0),

                  // Botão 1: Excluir Documento Inteiro
                  _buildActionButton(
                    context: context,
                    icon: 'trash',
                    label: 'Excluir Documento Inteiro ($totalPages páginas)',
                    isDestructive: true,
                    onTap: () => Navigator.of(context).pop(PdfDeleteChoice.deleteAllPages),
                  ),
                  const SizedBox(height: 8.0),

                  // Botão 2: Apenas esta Página
                  _buildActionButton(
                    context: context,
                    icon: 'file',
                    label: 'Apenas esta Página',
                    isDestructive: false,
                    themeAccent: themeAccent,
                    onTap: () => Navigator.of(context).pop(PdfDeleteChoice.deleteCurrentPageOnly),
                  ),
                  const SizedBox(height: 8.0),

                  // Botão 3: Cancelar
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(PdfDeleteChoice.cancel),
                    style: TextButton.styleFrom(
                      foregroundColor: MoscaroTokens.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildActionButton({
    required BuildContext context,
    required String icon,
    required String label,
    required bool isDestructive,
    Color? themeAccent,
    required VoidCallback onTap,
  }) {
    final bgColor = isDestructive
        ? const Color(0xFFFF5252).withValues(alpha: 0.16)
        : (themeAccent ?? MoscaroTokens.auroraBlue).withValues(alpha: 0.12);
    final borderColor = isDestructive
        ? const Color(0xFFFF5252).withValues(alpha: 0.40)
        : (themeAccent ?? MoscaroTokens.auroraBlue).withValues(alpha: 0.35);
    final textColor = isDestructive
        ? const Color(0xFFFF5252)
        : (themeAccent ?? MoscaroTokens.auroraBlue);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgIcon(
                name: icon,
                size: 14.0,
                color: textColor,
              ),
              const SizedBox(width: 8.0),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
