import 'package:flutter/material.dart';
import '../theme/moscaro_theme_controller.dart';
import '../theme/moscaro_v2_tokens.dart';
import 'svg_icon.dart';

/// Interactive Moscaro-styled provenance footer badge for cards generated from PDF text.
/// Clicking it redirects the PDF to the source page and focuses the selected text.
/// Adheres strictly to the Moscaro design system: zero emojis, SVG icons only, liquid glass.
class CardSourceProvenanceBadge extends StatefulWidget {
  final int pageNumber;
  final String? documentTitle;
  final VoidCallback? onTap;

  const CardSourceProvenanceBadge({
    super.key,
    required this.pageNumber,
    this.documentTitle,
    this.onTap,
  });

  @override
  State<CardSourceProvenanceBadge> createState() => _CardSourceProvenanceBadgeState();
}

class _CardSourceProvenanceBadgeState extends State<CardSourceProvenanceBadge> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = MoscaroThemeController.instance.currentTheme;
    final themeAccent = theme.accentPrimary;
    final isLight = MoscaroTokens.isLight;

    final docTitle = widget.documentTitle?.trim();
    final docPart = (docTitle != null && docTitle.isNotEmpty) ? ' • $docTitle' : '';
    final label = 'Origem: Pág. ${widget.pageNumber}$docPart';

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTap: widget.onTap,
        child: Tooltip(
          message: 'Ir para a Página ${widget.pageNumber} do PDF e destacar trecho',
          waitDuration: const Duration(milliseconds: 400),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(top: 8.0),
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: _isHovered
                  ? themeAccent.withValues(alpha: isLight ? 0.12 : 0.16)
                  : (isLight
                      ? Colors.black.withValues(alpha: 0.03)
                      : Colors.white.withValues(alpha: 0.04)),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: _isHovered
                    ? themeAccent.withValues(alpha: 0.6)
                    : (isLight
                        ? Colors.black.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.08)),
                width: 0.8,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: themeAccent.withValues(alpha: 0.20),
                        blurRadius: 8.0,
                        spreadRadius: -1.0,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SvgIcon(
                  name: 'link',
                  size: 11.0,
                  color: _isHovered
                      ? themeAccent
                      : (isLight ? MoscaroTokens.textSecondary : Colors.white54),
                ),
                const SizedBox(width: 5.0),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.0,
                      fontWeight: _isHovered ? FontWeight.w500 : FontWeight.w400,
                      fontStyle: FontStyle.italic,
                      color: _isHovered
                          ? themeAccent
                          : (isLight ? MoscaroTokens.textSecondary : Colors.white60),
                      letterSpacing: 0.1,
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
