import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../theme/moscaro_theme_controller.dart';
import '../theme/moscaro_v2_extension.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/stem_ink_theme_adapter.dart';
import '../controllers/pen_slots_controller.dart';
import 'svg_icon.dart';
import 'ink_models.dart';
import 'canvas_layers.dart';
import 'pen_slots_sub_bar.dart';

/// Modal Lightbox Moscaro Fullscreen com zoom/pan livre e camada de anotações bidirecional
class MediaLightboxModal extends StatefulWidget {
  final String? mediaData;
  final String title;
  final List<InkStroke> initialStrokes;
  final double cardX;
  final double cardY;
  final double cardWidth;
  final double cardHeight;
  final String parentCardId;

  const MediaLightboxModal({
    super.key,
    required this.mediaData,
    required this.title,
    required this.initialStrokes,
    required this.cardX,
    required this.cardY,
    required this.cardWidth,
    required this.cardHeight,
    required this.parentCardId,
  });

  /// Abre o modal em tela cheia e retorna a lista final sincronizada de traços
  static Future<List<InkStroke>?> show(
    BuildContext context, {
    required String? mediaData,
    required String title,
    required List<InkStroke> initialStrokes,
    required double cardX,
    required double cardY,
    required double cardWidth,
    required double cardHeight,
    required String parentCardId,
  }) {
    return showDialog<List<InkStroke>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      barrierDismissible: true,
      builder: (ctx) => MediaLightboxModal(
        mediaData: mediaData,
        title: title,
        initialStrokes: initialStrokes,
        cardX: cardX,
        cardY: cardY,
        cardWidth: cardWidth,
        cardHeight: cardHeight,
        parentCardId: parentCardId,
      ),
    );
  }

  @override
  State<MediaLightboxModal> createState() => _MediaLightboxModalState();
}

class _MediaLightboxModalState extends State<MediaLightboxModal> {
  final TransformationController _transformController = TransformationController();
  late double _aspectRatio;
  Uint8List? _decodedBytes;

  // Ferramentas e Estado dos Traços
  String _activeTool = 'nav'; // 'nav', 'pen', 'eraser'
  late PenSlotPreset _activePreset;
  late List<InkStroke> _strokes;
  final List<List<InkStroke>> _undoStack = [];
  final List<List<InkStroke>> _redoStack = [];
  List<StrokePoint> _activePoints = [];

  // Pan com Scroll Button e Cursor da Borracha
  bool _isMiddlePanning = false;
  Offset? _eraserHoverPos;

  @override
  void initState() {
    super.initState();
    _aspectRatio = widget.cardWidth / math.max(1.0, widget.cardHeight);
    _strokes = List<InkStroke>.from(widget.initialStrokes);
    _activePreset = PenSlotsController.instance.activePreset;
    PenSlotsController.instance.addListener(_onPenSlotsChanged);
    _loadAndDetectDimensions();
  }

  void _onPenSlotsChanged() {
    if (mounted) {
      setState(() {
        _activePreset = PenSlotsController.instance.activePreset;
      });
    }
  }

  @override
  void dispose() {
    PenSlotsController.instance.removeListener(_onPenSlotsChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _loadAndDetectDimensions() {
    final data = widget.mediaData;
    if (data == null || data.isEmpty) return;

    try {
      if (data.startsWith('data:image/') || (data.length > 500 && !data.startsWith('/'))) {
        final cleanBase64 = data.contains(',') ? data.split(',')[1] : data;
        final bytes = base64Decode(cleanBase64);
        _decodedBytes = bytes;
        ui.decodeImageFromList(bytes, (codec) {
          if (mounted && codec.width > 0 && codec.height > 0) {
            setState(() {
              _aspectRatio = codec.width / codec.height;
            });
          }
        });
      } else if (File(data).existsSync()) {
        final bytes = File(data).readAsBytesSync();
        _decodedBytes = bytes;
        ui.decodeImageFromList(bytes, (codec) {
          if (mounted && codec.width > 0 && codec.height > 0) {
            setState(() {
              _aspectRatio = codec.width / codec.height;
            });
          }
        });
      }
    } catch (_) {}
  }

  void _applyZoomAt(Offset focalPoint, double scaleChange) {
    final currentMatrix = _transformController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final targetScale = (currentScale * scaleChange).clamp(0.5, 10.0);
    final effectiveScaleChange = targetScale / currentScale;
    if ((effectiveScaleChange - 1.0).abs() < 0.001) return;

    final translation = Matrix4.translationValues(focalPoint.dx, focalPoint.dy, 0.0)
      ..multiply(Matrix4.diagonal3Values(effectiveScaleChange, effectiveScaleChange, 1.0))
      ..multiply(Matrix4.translationValues(-focalPoint.dx, -focalPoint.dy, 0.0));

    setState(() {
      _transformController.value = translation * currentMatrix;
    });
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  void _handleClose() {
    Navigator.of(context).pop(_strokes);
  }

  void _saveUndoSnapshot() {
    _undoStack.add(List<InkStroke>.from(_strokes));
    if (_undoStack.length > 30) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _handleUndo() {
    if (_undoStack.isNotEmpty) {
      _redoStack.add(List<InkStroke>.from(_strokes));
      setState(() {
        _strokes = _undoStack.removeLast();
      });
    }
  }

  void _handleRedo() {
    if (_redoStack.isNotEmpty) {
      _undoStack.add(List<InkStroke>.from(_strokes));
      setState(() {
        _strokes = _redoStack.removeLast();
      });
    }
  }

  // --- Desenho e Borracha ---

  void _onDrawingPanStart(DragStartDetails details, Size boxSize) {
    if (_isMiddlePanning || _activeTool == 'nav') return;
    if (boxSize.width <= 0 || boxSize.height <= 0) return;

    if (_activeTool == 'eraser') {
      _eraseAt(details.localPosition, boxSize);
      return;
    }

    final clampedX = details.localPosition.dx.clamp(0.0, boxSize.width);
    final clampedY = details.localPosition.dy.clamp(0.0, boxSize.height);

    setState(() {
      _activePoints = [
        StrokePoint(
          point: Offset(clampedX, clampedY),
          pressure: 1.0,
        ),
      ];
    });
  }

  void _onDrawingPanUpdate(DragUpdateDetails details, Size boxSize) {
    if (_isMiddlePanning || _activeTool == 'nav') return;
    if (boxSize.width <= 0 || boxSize.height <= 0) return;

    if (_activeTool == 'eraser') {
      _eraseAt(details.localPosition, boxSize);
      return;
    }

    final clampedX = details.localPosition.dx.clamp(0.0, boxSize.width);
    final clampedY = details.localPosition.dy.clamp(0.0, boxSize.height);

    setState(() {
      _activePoints.add(
        StrokePoint(
          point: Offset(clampedX, clampedY),
          pressure: 1.0,
        ),
      );
    });
  }

  void _onDrawingPanEnd(DragEndDetails details, Size boxSize) {
    if (_isMiddlePanning || _activeTool == 'nav' || _activeTool == 'eraser') return;
    if (_activePoints.length < 2) {
      setState(() {
        _activePoints = [];
      });
      return;
    }

    // Converte os pontos de coordenadas locais [0..boxSize] para coordenadas do canvas relativas ao card
    final canvasPoints = _activePoints.map((p) {
      final u = boxSize.width > 0 ? (p.point.dx / boxSize.width) : 0.0;
      final v = boxSize.height > 0 ? (p.point.dy / boxSize.height) : 0.0;
      final globalX = widget.cardX + u * widget.cardWidth;
      final globalY = widget.cardY + v * widget.cardHeight;
      return StrokePoint(
        point: Offset(globalX, globalY),
        pressure: p.pressure,
        tilt: p.tilt,
      );
    }).toList();

    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final p in canvasPoints) {
      if (p.point.dx < minX) minX = p.point.dx;
      if (p.point.dx > maxX) maxX = p.point.dx;
      if (p.point.dy < minY) minY = p.point.dy;
      if (p.point.dy > maxY) maxY = p.point.dy;
    }
    final bounds = minX.isFinite ? Rect.fromLTRB(minX, minY, maxX, maxY) : null;

    final newStroke = InkStroke(
      id: 'stroke_lightbox_${DateTime.now().millisecondsSinceEpoch}_${_strokes.length}',
      points: canvasPoints,
      color: _activePreset.color,
      strokeWidth: _activePreset.strokeWidth,
      toolType: _activePreset.toolType,
      enablePressure: _activePreset.enablePressure,
      parentCardId: widget.parentCardId,
      boundingBox: bounds,
    );

    _saveUndoSnapshot();
    setState(() {
      _strokes.add(newStroke);
      _activePoints = [];
    });
  }

  void _eraseAt(Offset localPos, Size boxSize) {
    if (boxSize.width <= 0 || boxSize.height <= 0) return;
    final u = (localPos.dx / boxSize.width).clamp(0.0, 1.0);
    final v = (localPos.dy / boxSize.height).clamp(0.0, 1.0);
    final targetGlobalX = widget.cardX + u * widget.cardWidth;
    final targetGlobalY = widget.cardY + v * widget.cardHeight;
    final targetPos = Offset(targetGlobalX, targetGlobalY);

    final scaleFactor = boxSize.width > 0 ? (widget.cardWidth / boxSize.width) : 1.0;
    final eraserRadius = 24.0 * scaleFactor;
    final eraserRadiusSq = eraserRadius * eraserRadius;

    final toRemove = <String>{};
    for (final s in _strokes) {
      bool hit = false;
      for (int i = 0; i < s.points.length; i++) {
        final p = s.points[i].point;
        if ((p - targetPos).distanceSquared <= eraserRadiusSq) {
          hit = true;
          break;
        }
        if (i > 0) {
          final pPrev = s.points[i - 1].point;
          if (_distToSegmentSquared(targetPos, pPrev, p) <= eraserRadiusSq) {
            hit = true;
            break;
          }
        }
      }
      if (hit) {
        toRemove.add(s.id);
      }
    }

    if (toRemove.isNotEmpty) {
      _saveUndoSnapshot();
      setState(() {
        _strokes.removeWhere((s) => toRemove.contains(s.id));
      });
    }
  }

  static double _distToSegmentSquared(Offset p, Offset v, Offset w) {
    final l2 = (v - w).distanceSquared;
    if (l2 == 0) return (p - v).distanceSquared;
    final t = (((p.dx - v.dx) * (w.dx - v.dx) + (p.dy - v.dy) * (w.dy - v.dy)) / l2).clamp(0.0, 1.0);
    final projection = Offset(v.dx + t * (w.dx - v.dx), v.dy + t * (w.dy - v.dy));
    return (p - projection).distanceSquared;
  }

  Widget _buildImage() {
    if (_decodedBytes != null) {
      return Image.memory(
        _decodedBytes!,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
      );
    }
    return Container(
      color: const Color(0xEB0E1018),
      child: const Center(
        child: SvgIcon(name: 'image', size: 48, color: Colors.white24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNav = _activeTool == 'nav';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_strokes);
      },
      child: FocusScope(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            _handleClose();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
        children: [
          // Área Central Interativa (Pan & Zoom com Listener + InteractiveViewer)
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  final zoomDelta = event.scrollDelta.dy < 0 ? 1.12 : 0.89;
                  _applyZoomAt(event.localPosition, zoomDelta);
                }
              },
              onPointerDown: (event) {
                if ((event.buttons & kMiddleMouseButton) != 0) {
                  setState(() {
                    _isMiddlePanning = true;
                  });
                }
              },
              onPointerMove: (event) {
                if ((event.buttons & kMiddleMouseButton) != 0) {
                  final delta = event.delta;
                  final translation = Matrix4.translationValues(delta.dx, delta.dy, 0.0);
                  setState(() {
                    _transformController.value = translation * _transformController.value;
                  });
                }
              },
              onPointerUp: (event) {
                if (_isMiddlePanning && (event.buttons & kMiddleMouseButton) == 0) {
                  setState(() {
                    _isMiddlePanning = false;
                  });
                }
              },
              onPointerCancel: (_) {
                if (_isMiddlePanning) {
                  setState(() {
                    _isMiddlePanning = false;
                  });
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isNav ? _handleClose : null,
                onDoubleTap: isNav ? _resetZoom : null,
                child: InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 0.5,
                  maxScale: 10.0,
                  panEnabled: isNav,
                  scaleEnabled: isNav,
                  boundaryMargin: const EdgeInsets.all(160),
                  child: Center(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: math.max(320.0, MediaQuery.of(context).size.width * 0.88),
                        maxHeight: math.max(220.0, MediaQuery.of(context).size.height * 0.78),
                      ),
                      child: AspectRatio(
                        aspectRatio: _aspectRatio > 0 ? _aspectRatio : 1.0,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final boxSize = Size(constraints.maxWidth, constraints.maxHeight);

                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                // 1. Imagem
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10.0),
                                  child: _buildImage(),
                                ),

                                // 2. Traços (Sincronizados e Ativos)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: _LightboxStrokesPainter(
                                        strokes: _strokes,
                                        activePoints: _activePoints,
                                        activeColor: _activePreset.color,
                                        activeToolType: _activePreset.toolType,
                                        activeStrokeWidth: _activePreset.strokeWidth,
                                        cardX: widget.cardX,
                                        cardY: widget.cardY,
                                        cardWidth: widget.cardWidth,
                                        cardHeight: widget.cardHeight,
                                      ),
                                    ),
                                  ),
                                ),

                                // 3. Camada de Captura de Desenho / Borracha (Ativa fora do modo nav)
                                if (!isNav)
                                  Positioned.fill(
                                    child: MouseRegion(
                                      cursor: _activeTool == 'eraser'
                                          ? SystemMouseCursors.none
                                          : SystemMouseCursors.precise,
                                      onHover: (event) {
                                        if (_activeTool == 'eraser') {
                                          setState(() {
                                            _eraserHoverPos = event.localPosition;
                                          });
                                        }
                                      },
                                      onExit: (_) {
                                        if (_eraserHoverPos != null) {
                                          setState(() {
                                            _eraserHoverPos = null;
                                          });
                                        }
                                      },
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onPanDown: (d) {
                                          if (_isMiddlePanning) return;
                                          if (_activeTool == 'eraser') {
                                            setState(() {
                                              _eraserHoverPos = d.localPosition;
                                            });
                                            _eraseAt(d.localPosition, boxSize);
                                          }
                                        },
                                        onPanStart: (d) {
                                          if (_isMiddlePanning) return;
                                          if (_activeTool == 'eraser') {
                                            setState(() {
                                              _eraserHoverPos = d.localPosition;
                                            });
                                          }
                                          _onDrawingPanStart(d, boxSize);
                                        },
                                        onPanUpdate: (d) {
                                          if (_isMiddlePanning) return;
                                          if (_activeTool == 'eraser') {
                                            setState(() {
                                              _eraserHoverPos = d.localPosition;
                                            });
                                          }
                                          _onDrawingPanUpdate(d, boxSize);
                                        },
                                        onPanEnd: (d) {
                                          if (_isMiddlePanning) return;
                                          _onDrawingPanEnd(d, boxSize);
                                        },
                                        child: CustomPaint(
                                          painter: _activeTool == 'eraser' && _eraserHoverPos != null
                                              ? _EraserCursorPainter(center: _eraserHoverPos!, radius: 24.0)
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Barra de Ferramentas / Pílula Centralizada Inferior (bottom: 32) Moscaro Glass
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sub-barra de Canetas (só aparece se a caneta estiver selecionada)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.bottomCenter,
                    child: _activeTool == 'pen'
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: PenSlotsSubBar(
                              isVisible: true,
                              presets: PenSlotsController.instance.slots,
                              activePresetId: _activePreset.id,
                              onSelectPreset: (preset) {
                                setState(() {
                                  _activePreset = preset;
                                  PenSlotsController.instance.selectSlot(preset.id);
                                });
                              },
                              onUpdatePreset: (updated) {
                                setState(() {
                                  _activePreset = updated;
                                });
                                PenSlotsController.instance.updateSlot(updated);
                              },
                              onReorderSlots: (oldIndex, newIndex) {
                                setState(() {});
                                PenSlotsController.instance.reorderSlots(oldIndex, newIndex);
                              },
                              onAddNewSlot: () async {
                                await PenSlotsController.instance.addNewSlot();
                                setState(() {
                                  _activePreset = PenSlotsController.instance.activePreset;
                                });
                              },
                              onDeleteSlot: (id) async {
                                await PenSlotsController.instance.deleteSlot(id);
                                setState(() {
                                  _activePreset = PenSlotsController.instance.activePreset;
                                });
                              },
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Pílula Principal Inferior
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. Modo Navegação (Pan / Zoom)
                        _LightboxToolButton(
                          iconName: 'cursor',
                          tooltip: 'Navegação (Mover / Zoom)',
                          isActive: _activeTool == 'nav',
                          onTap: () => setState(() => _activeTool = 'nav'),
                        ),
                        const SizedBox(width: 8),
                        Container(width: 1, height: 20, color: Colors.white24),
                        const SizedBox(width: 8),

                        // 2. Caneta com indicador da cor ativa
                        _LightboxPenButton(
                          isActive: _activeTool == 'pen',
                          activePreset: _activePreset,
                          onTap: () => setState(() => _activeTool = 'pen'),
                        ),
                        const SizedBox(width: 4),

                        // 3. Borracha Inteligente
                        _LightboxToolButton(
                          iconName: 'eraser',
                          tooltip: 'Borracha (Apaga Traços na Imagem)',
                          isActive: _activeTool == 'eraser',
                          onTap: () => setState(() => _activeTool = 'eraser'),
                        ),

                        const SizedBox(width: 8),
                        Container(width: 1, height: 20, color: Colors.white24),
                        const SizedBox(width: 8),

                        // 4. Desfazer (Undo)
                        _LightboxActionButton(
                          iconName: 'undo',
                          tooltip: 'Desfazer',
                          isEnabled: _undoStack.isNotEmpty,
                          onTap: _handleUndo,
                        ),
                        const SizedBox(width: 4),

                        // 5. Refazer (Redo)
                        _LightboxActionButton(
                          iconName: 'redo',
                          tooltip: 'Refazer',
                          isEnabled: _redoStack.isNotEmpty,
                          onTap: _handleRedo,
                        ),

                        const SizedBox(width: 8),
                        Container(width: 1, height: 20, color: Colors.white24),
                        const SizedBox(width: 8),

                        // 6. Resetar Zoom (100%)
                        _LightboxActionButton(
                          iconName: 'maximize',
                          tooltip: 'Redefinir Zoom (100%)',
                          isEnabled: true,
                          onTap: _resetZoom,
                        ),
                        const SizedBox(width: 4),

                        // 7. Fechar e Concluir
                        _LightboxActionButton(
                          iconName: 'close',
                          tooltip: 'Concluir e Salvar',
                          isEnabled: true,
                          onTap: _handleClose,
                          customColor: const Color(0xFFFF5252),
                        ),
                      ],
                    ),
                  ).moscaroV2(
                    borderRadius: MoscaroTokens.radiusPill,
                    enableBlur: true,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}

class _LightboxToolButton extends StatefulWidget {
  final String iconName;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _LightboxToolButton({
    required this.iconName,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_LightboxToolButton> createState() => _LightboxToolButtonState();
}

class _LightboxToolButtonState extends State<_LightboxToolButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = MoscaroThemeController.instance.currentTheme;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: widget.isActive
                  ? theme.accentPrimary.withValues(alpha: 0.22)
                  : (_isHovered ? Colors.white.withValues(alpha: 0.1) : Colors.transparent),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: widget.isActive ? theme.accentPrimary : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: widget.isActive
                  ? [
                      BoxShadow(
                        color: theme.accentPrimary.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Center(
              child: SvgIcon(
                name: widget.iconName,
                size: 18,
                color: widget.isActive
                    ? theme.accentPrimary
                    : (_isHovered ? Colors.white : Colors.white70),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LightboxActionButton extends StatefulWidget {
  final String iconName;
  final String tooltip;
  final bool isEnabled;
  final VoidCallback onTap;
  final Color? customColor;

  const _LightboxActionButton({
    required this.iconName,
    required this.tooltip,
    required this.isEnabled,
    required this.onTap,
    this.customColor,
  });

  @override
  State<_LightboxActionButton> createState() => _LightboxActionButtonState();
}

class _LightboxActionButtonState extends State<_LightboxActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.customColor ?? Colors.white;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: widget.isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) {
          if (widget.isEnabled) setState(() => _isHovered = true);
        },
        onExit: (_) {
          if (widget.isEnabled) setState(() => _isHovered = false);
        },
        child: GestureDetector(
          onTap: widget.isEnabled ? widget.onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _isHovered ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Opacity(
                opacity: widget.isEnabled ? 1.0 : 0.3,
                child: SvgIcon(
                  name: widget.iconName,
                  size: 17,
                  color: _isHovered ? baseColor : baseColor.withValues(alpha: 0.75),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LightboxStrokesPainter extends CustomPainter {
  final List<InkStroke> strokes;
  final List<StrokePoint> activePoints;
  final Color activeColor;
  final InkToolType activeToolType;
  final double activeStrokeWidth;
  final double cardX;
  final double cardY;
  final double cardWidth;
  final double cardHeight;
  final Paint _reusablePaint = Paint();

  _LightboxStrokesPainter({
    required this.strokes,
    required this.activePoints,
    required this.activeColor,
    required this.activeToolType,
    required this.activeStrokeWidth,
    required this.cardX,
    required this.cardY,
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Renderiza traços existentes convertidos de coordenadas globais do card para a proporção local [0..size]
    final scaleX = cardWidth > 0 ? (size.width / cardWidth) : 1.0;
    final scaleY = cardHeight > 0 ? (size.height / cardHeight) : 1.0;

    canvas.save();
    canvas.scale(scaleX, scaleY);
    canvas.translate(-cardX, -cardY);

    for (final s in strokes) {
      if (s.toolType == InkToolType.highlighter) {
        StrokePictureCache.drawSingleStroke(canvas, s, _reusablePaint);
      }
    }
    for (final s in strokes) {
      if (s.toolType != InkToolType.highlighter) {
        StrokePictureCache.drawSingleStroke(canvas, s, _reusablePaint);
      }
    }
    canvas.restore();

    // 2. Traço ativo em tempo real
    if (activePoints.length >= 2) {
      final isHighlighter = activeToolType == InkToolType.highlighter;
      _reusablePaint
        ..color = isHighlighter ? activeColor.withValues(alpha: 0.4) : activeColor
        ..strokeWidth = isHighlighter ? (activeStrokeWidth * 3.5).clamp(12.0, 28.0) : activeStrokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(activePoints.first.point.dx, activePoints.first.point.dy);
      for (int i = 1; i < activePoints.length; i++) {
        path.lineTo(activePoints[i].point.dx, activePoints[i].point.dy);
      }
      canvas.drawPath(path, _reusablePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LightboxStrokesPainter oldDelegate) {
    return true;
  }
}

class _LightboxPenButton extends StatefulWidget {
  final bool isActive;
  final PenSlotPreset activePreset;
  final VoidCallback onTap;

  const _LightboxPenButton({
    required this.isActive,
    required this.activePreset,
    required this.onTap,
  });

  @override
  State<_LightboxPenButton> createState() => _LightboxPenButtonState();
}

class _LightboxPenButtonState extends State<_LightboxPenButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isLight = MoscaroTokens.isLight;
    final theme = MoscaroThemeController.instance.currentTheme;
    final displayColor = StemInkThemeAdapter.adaptStrokeColor(widget.activePreset.color, isLightTheme: isLight);

    return Tooltip(
      message: 'Caneta (${widget.activePreset.name})',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: widget.isActive
                  ? theme.accentPrimary.withValues(alpha: 0.22)
                  : (_isHovered ? Colors.white.withValues(alpha: 0.1) : Colors.transparent),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: widget.isActive ? theme.accentPrimary : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: widget.isActive
                  ? [
                      BoxShadow(
                        color: theme.accentPrimary.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SvgIcon(
                  name: 'pen',
                  size: 18,
                  color: widget.isActive
                      ? theme.accentPrimary
                      : (_isHovered ? Colors.white : Colors.white70),
                ),
                Positioned(
                  bottom: 5,
                  right: 5,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: displayColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black87, width: 1.0),
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

class _EraserCursorPainter extends CustomPainter {
  final Offset center;
  final double radius;

  const _EraserCursorPainter({
    required this.center,
    this.radius = 24.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Preenchimento suave translúcido
    final fillPaint = Paint()
      ..color = const Color(0x2800E1FF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, fillPaint);

    // 2. Anel externo com sombra escura (para imagens claras e fundos brancos)
    final darkRingPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawCircle(center, radius, darkRingPaint);

    // 3. Anel interno ciano vibrante (para imagens escuras e identidade Moscaro)
    final cyanRingPaint = Paint()
      ..color = const Color(0xFF00E1FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(center, radius, cyanRingPaint);

    // 4. Ponto central de precisão
    final dotDarkPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2.5, dotDarkPaint);

    final dotCyanPaint = Paint()
      ..color = const Color(0xFF00E1FF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 1.5, dotCyanPaint);
  }

  @override
  bool shouldRepaint(_EraserCursorPainter oldDelegate) {
    return oldDelegate.center != center || oldDelegate.radius != radius;
  }
}
