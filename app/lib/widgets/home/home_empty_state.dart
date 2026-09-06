import 'package:flutter/material.dart';
import '../../theme/moscaro_v2_extension.dart';
import '../../theme/moscaro_v2_tokens.dart';
import '../svg_icon.dart';

/// Estado vazio ilustrado da Biblioteca de Notas conNotes.
/// Exibido quando nenhuma nota corresponde aos filtros ou busca.
class HomeEmptyState extends StatelessWidget {
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final String iconName;

  const HomeEmptyState({
    super.key,
    this.title = 'Nenhuma nota encontrada',
    this.description = 'Crie sua primeira nota interativa ou tente ajustar os filtros de busca.',
    this.actionLabel = 'Criar Nova Nota',
    this.onActionPressed,
    this.iconName = 'file',
  });

  @override
  Widget build(BuildContext context) {
    final isLight = MoscaroTokens.isLight;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        decoration: BoxDecoration(
          color: isLight ? const Color(0x0C0F172A) : const Color(0x10131B2E),
          borderRadius: BorderRadius.circular(MoscaroTokens.radiusButton),
          border: Border.all(
            color: isLight ? const Color(0x180F172A) : const Color(0x20334155),
            width: 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícone vetorial com glow suave
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MoscaroTokens.auroraBlue.withValues(alpha: isLight ? 0.12 : 0.16),
                border: Border.all(
                  color: MoscaroTokens.auroraBlue.withValues(alpha: 0.4),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: MoscaroTokens.auroraBlue.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: SvgIcon(
                  name: iconName,
                  size: 28,
                  color: MoscaroTokens.auroraBlue,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Título
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isLight ? const Color(0xFF0F172A) : Colors.white,
                letterSpacing: -0.2,
              ),
            ),

            const SizedBox(height: 8),

            // Descrição
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),

            if (actionLabel != null && onActionPressed != null) ...[
              const SizedBox(height: 24),
              InkWell(
                onTap: onActionPressed,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: MoscaroTokens.auroraBlue.withValues(alpha: isLight ? 0.18 : 0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: MoscaroTokens.auroraBlue.withValues(alpha: 0.8),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: MoscaroTokens.auroraBlue.withValues(alpha: 0.25),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgIcon(
                        name: 'plus',
                        size: 15,
                        color: isLight ? const Color(0xFF0284C7) : MoscaroTokens.auroraBlue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        actionLabel!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isLight ? const Color(0xFF0284C7) : MoscaroTokens.auroraBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ).moscaroV2(
        borderRadius: MoscaroTokens.radiusButton,
        blurSigma: 12.0,
        enableBlur: true,
      ),
    );
  }
}
