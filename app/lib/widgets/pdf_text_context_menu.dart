import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/diagnostics_override_controller.dart';
import '../theme/moscaro_theme_controller.dart';
import '../theme/moscaro_v2_tokens.dart';
import 'svg_icon.dart';

/// Compact Moscaro Contextual Mini-Pill displayed over or under selected PDF text.
/// Actions:
/// 1. "Gerar Card STEM" (instantiates adjacent card with selected content)
/// 2. "Grifar" (applies aligned highlighter stroke)
/// Zero emojis, pure SVG vector icons.
class PdfTextContextMenu extends StatelessWidget {
  final VoidCallback onGenerateStemCard;
  final VoidCallback onHighlight;
  final VoidCallback onDismiss;

  const PdfTextContextMenu({
    super.key,
    required this.onGenerateStemCard,
    required this.onHighlight,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = MoscaroThemeController.instance.currentTheme;
    final themeAccent = theme.accentPrimary;

    final bool bypass = DiagnosticsOverrideController.instance.bypassBackdropFilter;
    final double blurSigma = (!bypass && MoscaroTokens.enableCardsBlur && MoscaroTokens.blurSigma > 0)
        ? MoscaroTokens.blurSigma
        : 0.0;

    return ClipRRect(
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
              // 1. Gerar Card STEM
              _ContextActionButton(
                iconName: 'file',
                title: 'Gerar Card STEM',
                themeAccent: themeAccent,
                onTap: onGenerateStemCard,
              ),
              const SizedBox(width: 4.0),

              // Divider
              Container(
                width: 1.0,
                height: 14.0,
                color: MoscaroTokens.borderSubtle,
              ),
              const SizedBox(width: 4.0),

              // 2. Grifar
              _ContextActionButton(
                iconName: 'highlighter',
                title: 'Grifar',
                themeAccent: themeAccent,
                onTap: onHighlight,
              ),
              const SizedBox(width: 4.0),

              // Divider
              Container(
                width: 1.0,
                height: 14.0,
                color: MoscaroTokens.borderSubtle,
              ),
              const SizedBox(width: 2.0),

              // 3. Close
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onDismiss,
                  child: Container(
                    width: 20.0,
                    height: 20.0,
                    alignment: Alignment.center,
                    child: SvgIcon(
                      name: 'close',
                      size: 11.0,
                      color: MoscaroTokens.iconInactive,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextActionButton extends StatefulWidget {
  final String iconName;
  final String title;
  final Color themeAccent;
  final VoidCallback onTap;

  const _ContextActionButton({
    required this.iconName,
    required this.title,
    required this.themeAccent,
    required this.onTap,
  });

  @override
  State<_ContextActionButton> createState() => _ContextActionButtonState();
}

class _ContextActionButtonState extends State<_ContextActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.themeAccent.withValues(alpha: 0.20)
                : widget.themeAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: _isHovered
                  ? widget.themeAccent.withValues(alpha: 0.50)
                  : widget.themeAccent.withValues(alpha: 0.20),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(
                name: widget.iconName,
                size: 12.0,
                color: widget.themeAccent,
              ),
              const SizedBox(width: 5.0),
              Text(
                widget.title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.0,
                  fontWeight: FontWeight.w500,
                  color: MoscaroTokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
