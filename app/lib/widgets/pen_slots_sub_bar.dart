import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import 'ink_models.dart';
import 'precision_color_picker.dart';

/// Sub-Barra Flutuante de Slots de Canetas Vivas.
/// Agora super compacta e minimalista (sem nomes de texto), com suporte a Drag & Drop para reordenar slots.
class PenSlotsSubBar extends StatefulWidget {
  final bool isVisible;
  final List<PenSlotPreset> presets;
  final String activePresetId;
  final ValueChanged<PenSlotPreset> onSelectPreset;
  final Function(PenSlotPreset updated) onUpdatePreset;
  final Function(int oldIndex, int newIndex) onReorderSlots;
  final VoidCallback onAddNewSlot;
  final ValueChanged<String> onDeleteSlot;

  const PenSlotsSubBar({
    super.key,
    required this.isVisible,
    required this.presets,
    required this.activePresetId,
    required this.onSelectPreset,
    required this.onUpdatePreset,
    required this.onReorderSlots,
    required this.onAddNewSlot,
    required this.onDeleteSlot,
  });

  @override
  State<PenSlotsSubBar> createState() => _PenSlotsSubBarState();
}

class _PenSlotsSubBarState extends State<PenSlotsSubBar> {
  final ScrollController _scrollController = ScrollController();
  OverlayEntry? _editorOverlay;

  @override
  void dispose() {
    _closeEditor();
    _scrollController.dispose();
    super.dispose();
  }

  void _closeEditor() {
    _editorOverlay?.remove();
    _editorOverlay = null;
  }

  void _openSlotEditor(BuildContext context, PenSlotPreset preset, Offset buttonOffset) {
    _closeEditor();

    _editorOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeEditor,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: (buttonOffset.dx - 120).clamp(24.0, MediaQuery.of(context).size.width - 320),
            bottom: MediaQuery.of(context).size.height - buttonOffset.dy + 12,
            child: Material(
              color: Colors.transparent,
              child: PrecisionColorPicker(
                initialPreset: preset,
                canDelete: widget.presets.length > 1,
                onChange: (updated) {
                  // Salvamento automático contínuo em tempo real (Auto-save)
                  widget.onUpdatePreset(updated);
                },
                onDelete: () {
                  widget.onDeleteSlot(preset.id);
                  _closeEditor();
                },
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_editorOverlay!);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && _scrollController.hasClients) {
      final double newOffset = (_scrollController.offset + event.scrollDelta.dy).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        newOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.isVisible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        offset: widget.isVisible ? Offset.zero : const Offset(0, 0.4),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          scale: widget.isVisible ? 1.0 : 0.88,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: widget.isVisible ? 1.0 : 0.0,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              constraints: const BoxConstraints(maxWidth: 520),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Carrossel Reordenável (Drag & Drop) de Slots
                  Flexible(
                    child: Listener(
                      onPointerSignal: _handlePointerSignal,
                      child: ScrollConfiguration(
                        behavior: const ScrollBehavior().copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.trackpad,
                          },
                          scrollbars: false,
                        ),
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(widget.presets.length, (index) {
                              final preset = widget.presets[index];
                              final isSelected = preset.id == widget.activePresetId;

                              return DragTarget<int>(
                                onWillAcceptWithDetails: (details) => details.data != index,
                                onAcceptWithDetails: (details) {
                                  widget.onReorderSlots(details.data, index);
                                },
                                builder: (context, candidateData, rejectedData) {
                                  return LongPressDraggable<int>(
                                    data: index,
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: Opacity(
                                        opacity: 0.8,
                                        child: _buildSlotPill(context, preset, true, isGhost: true),
                                      ),
                                    ),
                                    childWhenDragging: Opacity(
                                      opacity: 0.3,
                                      child: _buildSlotPill(context, preset, isSelected),
                                    ),
                                    child: _buildSlotPill(context, preset, isSelected),
                                  );
                                },
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(width: 1, height: 18, color: Colors.white24),
                  const SizedBox(width: 4),
                  // Botão Adicionar Novo Slot
                  IconButton(
                    icon: const Icon(Icons.add, size: 18, color: MoscaroTokens.auroraBlue),
                    onPressed: widget.onAddNewSlot,
                    tooltip: 'Novo Slot de Caneta',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ).moscaroV2(
              borderRadius: MoscaroTokens.radiusPill,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlotPill(BuildContext context, PenSlotPreset preset, bool isSelected, {bool isGhost = false}) {
    return Builder(
      builder: (slotContext) {
        return GestureDetector(
          onTap: () {
            if (isSelected) {
              final RenderBox box = slotContext.findRenderObject() as RenderBox;
              final offset = box.localToGlobal(Offset.zero);
              _openSlotEditor(context, preset, offset);
            } else {
              widget.onSelectPreset(preset);
            }
          },
          onDoubleTap: () {
            final RenderBox box = slotContext.findRenderObject() as RenderBox;
            final offset = box.localToGlobal(Offset.zero);
            _openSlotEditor(context, preset, offset);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? preset.color : Colors.white12,
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: preset.color.withOpacity(0.4), blurRadius: 8)]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícone da ferramenta pintado exatamente na cor do preset
                Icon(
                  _getToolIcon(preset.toolType),
                  size: 16,
                  color: preset.color,
                ),
                const SizedBox(width: 6),
                // Ponto indicador do diâmetro/espessura
                Container(
                  width: (preset.strokeWidth * 1.5).clamp(3.0, 10.0),
                  height: (preset.strokeWidth * 1.5).clamp(3.0, 10.0),
                  decoration: BoxDecoration(
                    color: preset.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getToolIcon(InkToolType type) {
    switch (type) {
      case InkToolType.technical:
        return Icons.edit;
      case InkToolType.fountain:
        return Icons.brush;
      case InkToolType.pencil:
        return Icons.create;
      case InkToolType.highlighter:
        return Icons.highlight;
    }
  }
}
