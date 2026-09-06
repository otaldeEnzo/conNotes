import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/canvas_card_model.dart';
import '../services/media_compression_service.dart';
import '../theme/moscaro_theme_controller.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import 'media_orientation_popover.dart';
import 'svg_icon.dart';

/// Pílula Flutuante de Ações para o Card de Mídia (100% Moscaro Glass v2).
/// Totalmente integrada ao MoscaroThemeController, reativa a temas claros/escuros e livre de emojis.
class MediaCardFloatingPill extends StatefulWidget {
  final CanvasCardModel card;
  final ValueChanged<CanvasCardModel> onUpdateCard;
  final VoidCallback onDuplicateCard;
  final VoidCallback onDeleteCard;
  final VoidCallback? onSolveWithAi;
  final VoidCallback? onExtractLatex;
  final VoidCallback? onOpenLightbox;
  final double zoomScale;
  final Offset Function()? getCardScreenCenter;
  final ValueChanged<double>? onTransientRotationChanged;
  final ValueChanged<double>? onRotationEnd;

  const MediaCardFloatingPill({
    super.key,
    required this.card,
    required this.onUpdateCard,
    required this.onDuplicateCard,
    required this.onDeleteCard,
    this.onSolveWithAi,
    this.onExtractLatex,
    this.onOpenLightbox,
    this.zoomScale = 1.0,
    this.getCardScreenCenter,
    this.onTransientRotationChanged,
    this.onRotationEnd,
  });

  @override
  State<MediaCardFloatingPill> createState() => _MediaCardFloatingPillState();
}

class _MediaCardFloatingPillState extends State<MediaCardFloatingPill> {
  bool _isOrientationPopoverOpen = false;

  Future<void> _handleReplaceImage(BuildContext context) async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
      );

      if (result.isNotEmpty) {
        final path = result.first.path;
        if (path != null) {
          final bytes = await File(path).readAsBytes();
          final compressed = await MediaCompressionService.compressImageBytes(bytes);
          if (compressed != null) {
            final updated = widget.card.copyWith(
              mediaData: compressed.dataUri,
              originalAspectRatio: compressed.aspectRatio,
              height: widget.card.lockAspectRatio && compressed.aspectRatio > 0
                  ? (widget.card.width / compressed.aspectRatio)
                  : widget.card.height,
            );
            widget.onUpdateCard(updated);
          }
        }
      }
    } catch (e) {
      debugPrint('[MediaCardFloatingPill] Erro ao substituir imagem: $e');
    }
  }

  void _handleRotateCw() {
    debugPrint('[MediaCardFloatingPill] _handleRotateCw executed');
    final updated = widget.card.copyWith();
    updated.rotateQuarterTurns(1);
    widget.onUpdateCard(updated);
  }

  void _handleRotateCcw() {
    debugPrint('[MediaCardFloatingPill] _handleRotateCcw executed');
    final updated = widget.card.copyWith();
    updated.rotateQuarterTurns(-1);
    widget.onUpdateCard(updated);
  }

  void _handleFlipH() {
    debugPrint('[MediaCardFloatingPill] _handleFlipH executed');
    final updated = widget.card.copyWith();
    updated.toggleFlipHorizontal();
    widget.onUpdateCard(updated);
  }

  void _handleFlipV() {
    debugPrint('[MediaCardFloatingPill] _handleFlipV executed');
    final updated = widget.card.copyWith();
    updated.toggleFlipVertical();
    widget.onUpdateCard(updated);
  }

  void _toggleInvertLuminance() {
    widget.onUpdateCard(widget.card.copyWith(
      invertLuminance: !widget.card.invertLuminance,
    ));
  }

  void _toggleDrawOverMode() {
    widget.onUpdateCard(widget.card.copyWith(
      isDrawOverMode: !widget.card.isDrawOverMode,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MoscaroThemeController.instance,
      builder: (context, _) {
        final isLight = MoscaroTokens.isLight;
        final theme = MoscaroThemeController.instance.currentTheme;
        final themeAccent = theme.accentPrimary;
        final dividerColor = isLight ? Colors.black12 : Colors.white12;

        final pillRow = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indicador / Ícone de Mídia
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: SvgIcon(
                  name: 'image',
                  size: 16.0,
                  color: themeAccent,
                ),
              ),
              Container(
                width: 1.0,
                height: 18.0,
                color: dividerColor,
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
              ),

              // Ação IA: Resolver Exercício com IA
              if (widget.onSolveWithAi != null)
                _PillActionButton(
                  iconName: 'sparkle',
                  tooltip: 'Resolver exercício com IA',
                  iconColor: themeAccent,
                  onPressed: widget.onSolveWithAi!,
                ),

              // Ação IA: Extrair LaTeX / OCR
              if (widget.onExtractLatex != null)
                _PillActionButton(
                  iconName: 'ai',
                  tooltip: 'Extrair LaTeX / OCR para novo card',
                  onPressed: widget.onExtractLatex!,
                ),

              // Modo Anotação STEM (Desenhar sobre Imagem)
              _PillActionButton(
                iconName: 'pen',
                tooltip: widget.card.isDrawOverMode
                    ? 'Modo anotação ativo (clique para sair)'
                    : 'Anotar / Desenhar sobre a imagem',
                isActive: widget.card.isDrawOverMode,
                onPressed: _toggleDrawOverMode,
              ),

              // Inverter Luminância (Dark Mode para Gráficos Brancos)
              _PillActionButton(
                iconName: 'contrast',
                tooltip: widget.card.invertLuminance
                    ? 'Luminância invertida (fundo escuro)'
                    : 'Inverter luminância (Dark Mode)',
                isActive: widget.card.invertLuminance,
                onPressed: _toggleInvertLuminance,
              ),

              // Visualizar em Tela Cheia (Lightbox)
              if (widget.onOpenLightbox != null)
                _PillActionButton(
                  iconName: 'maximize',
                  tooltip: 'Ver em tela cheia (duplo clique)',
                  onPressed: widget.onOpenLightbox!,
                ),

              Container(
                width: 1.0,
                height: 18.0,
                color: dividerColor,
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
              ),

              // Botão de Rotação / Orientação (Abre o popover Moscaro v2 ancorado)
              _PillActionButton(
                iconName: 'rotate_cw',
                tooltip: 'Orientação e Espelhamento de Imagem',
                isActive: _isOrientationPopoverOpen,
                onPressed: () {
                  setState(() {
                    _isOrientationPopoverOpen = !_isOrientationPopoverOpen;
                  });
                },
              ),

              // Substituir imagem
              _PillActionButton(
                iconName: 'restore',
                tooltip: 'Substituir imagem...',
                onPressed: () => _handleReplaceImage(context),
              ),

              Container(
                width: 1.0,
                height: 18.0,
                color: dividerColor,
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
              ),

              // Duplicar Card
              _PillActionButton(
                iconName: 'plus',
                tooltip: 'Duplicar card (Ctrl+D)',
                onPressed: widget.onDuplicateCard,
              ),

              // Deletar Card
              _PillActionButton(
                iconName: 'trash',
                tooltip: 'Excluir card',
                iconColor: const Color(0xFFFF5252),
                onPressed: widget.onDeleteCard,
              ),
            ],
          ),
        ).moscaroV2(
          borderRadius: 24.0,
          padding: EdgeInsets.zero,
        );

        final pillWithPopover = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_isOrientationPopoverOpen) ...[
              MediaOrientationPopover(
                onRotateCw: _handleRotateCw,
                onRotateCcw: _handleRotateCcw,
                onFlipH: _handleFlipH,
                onFlipV: _handleFlipV,
              ),
              const SizedBox(height: 6.0),
            ],
            pillRow,
          ],
        );

        // Zoom-Invariante: Mantém a barra exatamente com o mesmo tamanho físico na tela
        final effectiveZoom = (widget.zoomScale > 0 ? widget.zoomScale : 1.0).clamp(0.2, 5.0);
        return Transform.scale(
          scale: 1.0 / effectiveZoom,
          alignment: Alignment.bottomCenter,
          child: pillWithPopover,
        );
      },
    );
  }
}

class _PillActionButton extends StatelessWidget {
  final String iconName;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isActive;
  final Color? iconColor;

  const _PillActionButton({
    required this.iconName,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = MoscaroThemeController.instance.currentTheme;
    final themeAccent = theme.accentPrimary;
    final isLight = MoscaroTokens.isLight;
    final defaultColor = isLight ? MoscaroTokens.textSecondary : Colors.white70;

    final effectiveColor = iconColor ?? (isActive ? themeAccent : defaultColor);

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? themeAccent.withValues(alpha: 0.25) : Colors.transparent,
              border: isActive
                  ? Border.all(color: themeAccent.withValues(alpha: 0.4), width: 1.0)
                  : null,
            ),
            child: SvgIcon(
              name: iconName,
              size: 16,
              color: effectiveColor,
            ),
          ),
        ),
      ),
    );
  }
}


