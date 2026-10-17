import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/pdf_internal_object_models.dart';
import '../theme/moscaro_theme_controller.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../services/diagnostics_override_controller.dart';
import 'svg_icon.dart';

/// Floating Moscaro action menu displayed over an inspected or selected PDF object
/// (image, formula, table, or text block).
/// Zero emojis, pure SVG vector icons, glassmorphism backdrop.
class PdfObjectActionMenu extends StatelessWidget {
  final PdfInternalObject? selectedObject;
  final String? selectedText;
  final VoidCallback onSpawnCard;
  final VoidCallback onCopy;
  final VoidCallback onAskAi;
  final VoidCallback? onHighlight;
  final VoidCallback onDismiss;

  const PdfObjectActionMenu({
    super.key,
    this.selectedObject,
    this.selectedText,
    required this.onSpawnCard,
    required this.onCopy,
    required this.onAskAi,
    this.onHighlight,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = MoscaroThemeController.instance.currentTheme;
    final themeAccent = theme.accentPrimary;

    final String spawnTitle;
    final String spawnIcon;
    final String copyTitle;

    if (selectedObject != null) {
      switch (selectedObject!.type) {
        case PdfInternalObjectType.image:
          spawnTitle = 'Criar Card de Imagem';
          spawnIcon = 'image';
          copyTitle = 'Copiar Imagem HD';
          break;
        case PdfInternalObjectType.table:
          spawnTitle = 'Criar Card Tabela';
          spawnIcon = 'table';
          copyTitle = 'Copiar Markdown / TSV';
          break;
        case PdfInternalObjectType.formula:
          spawnTitle = 'Criar Card LaTeX';
          spawnIcon = 'code';
          copyTitle = 'Copiar LaTeX';
          break;
        case PdfInternalObjectType.textBlock:
          spawnTitle = 'Criar Card STEM';
          spawnIcon = 'layout';
          copyTitle = 'Copiar Texto';
          break;
      }
    } else {
      spawnTitle = 'Criar Card STEM';
      spawnIcon = 'layout';
      copyTitle = 'Copiar Texto';
    }

    final bool bypass = DiagnosticsOverrideController.instance.bypassBackdropFilter;
    final double blurSigma = (!bypass && MoscaroTokens.enableCardsBlur && MoscaroTokens.blurSigma > 0)
        ? MoscaroTokens.blurSigma
        : 0.0;

    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            height: 32.0,
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
            decoration: BoxDecoration(
              color: MoscaroTokens.glassTint,
              borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
              border: Border.all(
                color: MoscaroTokens.isLight ? MoscaroTokens.borderSubtle : MoscaroTokens.borderGlow,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: MoscaroTokens.isLight ? 0.20 : 0.40),
                  blurRadius: 14.0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Criar Card no Canvas
                _MenuActionButton(
                  iconName: spawnIcon,
                  title: spawnTitle,
                  themeAccent: themeAccent,
                  onTap: onSpawnCard,
                ),
                const SizedBox(width: 4.0),

                // 2. Grifar (apenas para texto)
                if (onHighlight != null) ...[
                  _MenuActionButton(
                    iconName: 'highlighter',
                    title: 'Grifar',
                    themeAccent: themeAccent,
                    onTap: onHighlight!,
                  ),
                  const SizedBox(width: 4.0),
                ],

                // 3. Copiar
                _MenuActionButton(
                  iconName: 'copy',
                  title: copyTitle,
                  themeAccent: themeAccent,
                  onTap: onCopy,
                ),
                const SizedBox(width: 4.0),

                // 4. Enviar para IA
                _MenuActionButton(
                  iconName: 'sparkles',
                  title: 'Enviar para IA',
                  themeAccent: themeAccent,
                  onTap: onAskAi,
                ),
                const SizedBox(width: 4.0),

                // 5. Fechar / Dispensar
                InkWell(
                  onTap: onDismiss,
                  borderRadius: BorderRadius.circular(12.0),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: SvgIcon(
                      name: 'x',
                      size: 13.0,
                      color: MoscaroTokens.iconInactive,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuActionButton extends StatefulWidget {
  final String iconName;
  final String title;
  final Color themeAccent;
  final VoidCallback onTap;

  const _MenuActionButton({
    required this.iconName,
    required this.title,
    required this.themeAccent,
    required this.onTap,
  });

  @override
  State<_MenuActionButton> createState() => _MenuActionButtonState();
}

class _MenuActionButtonState extends State<_MenuActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.title,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
            decoration: BoxDecoration(
              color: _isHovered
                  ? widget.themeAccent.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgIcon(
                  name: widget.iconName,
                  size: 13.0,
                  color: _isHovered ? widget.themeAccent : MoscaroTokens.textSecondary,
                ),
                const SizedBox(width: 5.0),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: _isHovered ? widget.themeAccent : MoscaroTokens.textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
