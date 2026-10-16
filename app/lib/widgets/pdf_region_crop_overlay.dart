import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/moscaro_theme_controller.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../services/diagnostics_override_controller.dart';
import 'svg_icon.dart';

enum _CropHandle {
  none,
  inside,
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

/// Interactive high-resolution crop overlay for PDF pages.
/// Displays a resizable glowing cyan marquee box with 8 handles and
/// an attached Moscaro action pill for generating adjacent Image or STEM cards.
class PdfRegionCropOverlay extends StatefulWidget {
  final double pageWidth;
  final double pageHeight;
  final ValueChanged<Rect> onCropAsImage;
  final ValueChanged<Rect> onCropAsStemCard;
  final ValueChanged<Rect>? onCropExtractLatex;
  final ValueChanged<Rect>? onCropSendToAi;
  final VoidCallback onCancel;

  const PdfRegionCropOverlay({
    super.key,
    required this.pageWidth,
    required this.pageHeight,
    required this.onCropAsImage,
    required this.onCropAsStemCard,
    this.onCropExtractLatex,
    this.onCropSendToAi,
    required this.onCancel,
  });

  @override
  State<PdfRegionCropOverlay> createState() => _PdfRegionCropOverlayState();
}

class _PdfRegionCropOverlayState extends State<PdfRegionCropOverlay> {
  Rect? _cropRect;
  _CropHandle _activeHandle = _CropHandle.none;
  Offset? _dragStartLocal;
  Rect? _initialRectOnDrag;
  bool _isDrawingNew = false;

  @override
  void initState() {
    super.initState();
    _cropRect = null;
  }

  Rect? _getPillRect() {
    if (_cropRect == null || _cropRect!.width < 20 || _cropRect!.height < 20 || _isDrawingNew) {
      return null;
    }
    final r = _cropRect!;
    const double pillHeight = 36.0;
    const double pillWidth = 530.0;
    double top = r.bottom + 10.0;
    if (top + pillHeight > widget.pageHeight - 10.0) {
      top = r.top - pillHeight - 10.0;
    }
    top = top.clamp(10.0, math.max(10.0, widget.pageHeight - pillHeight - 10.0));
    final left = (r.center.dx - pillWidth / 2.0)
        .clamp(6.0, math.max(6.0, widget.pageWidth - pillWidth - 6.0))
        .toDouble();
    return Rect.fromLTWH(left, top, pillWidth, pillHeight);
  }

  @override
  Widget build(BuildContext context) {
    final theme = MoscaroThemeController.instance.currentTheme;
    final themeAccent = theme.accentPrimary;

    return Focus(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel,
        },
        child: SizedBox(
          width: widget.pageWidth,
          height: widget.pageHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Gesture detector for marquee adjustment
              Positioned.fill(
                child: MouseRegion(
                  cursor: _resolveCursor(),
                  onHover: (event) {
                    final pillRect = _getPillRect();
                    if (pillRect != null && pillRect.inflate(10.0).contains(event.localPosition)) {
                      if (_activeHandle != _CropHandle.none) {
                        setState(() {
                          _activeHandle = _CropHandle.none;
                        });
                      }
                      return;
                    }
                    if (_cropRect != null && !_isDrawingNew) {
                      final handle = _hitTestHandle(event.localPosition);
                      if (handle != _activeHandle) {
                        setState(() {
                          _activeHandle = handle;
                        });
                      }
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: _handlePanStart,
                    onPanUpdate: _handlePanUpdate,
                    onPanEnd: (_) => _handlePanEnd(),
                    onPanCancel: () => _handlePanEnd(),
                    child: CustomPaint(
                      painter: _CropMarqueePainter(
                        cropRect: _cropRect,
                        accentColor: themeAccent,
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Moscaro Floating Action Mini-Pill
              _buildActionsPill(themeAccent),
            ],
          ),
        ),
      ),
    );
  }

  MouseCursor _resolveCursor() {
    switch (_activeHandle) {
      case _CropHandle.inside:
        return SystemMouseCursors.move;
      case _CropHandle.topLeft:
      case _CropHandle.bottomRight:
        return SystemMouseCursors.resizeUpLeftDownRight;
      case _CropHandle.topRight:
      case _CropHandle.bottomLeft:
        return SystemMouseCursors.resizeUpRightDownLeft;
      case _CropHandle.topCenter:
      case _CropHandle.bottomCenter:
        return SystemMouseCursors.resizeUpDown;
      case _CropHandle.centerLeft:
      case _CropHandle.centerRight:
        return SystemMouseCursors.resizeLeftRight;
      default:
        return SystemMouseCursors.basic;
    }
  }

  void _handlePanStart(DragStartDetails details) {
    final pos = details.localPosition;
    final pillRect = _getPillRect();
    if (pillRect != null && pillRect.inflate(10.0).contains(pos)) {
      // User tapped or started dragging inside the pill area!
      // Do NOT start a new crop marquee or move handles.
      return;
    }
    _dragStartLocal = pos;
    _initialRectOnDrag = _cropRect;
    _activeHandle = _cropRect != null ? _hitTestHandle(pos) : _CropHandle.none;

    if (_cropRect == null || _activeHandle == _CropHandle.none) {
      _isDrawingNew = true;
      _cropRect = Rect.fromPoints(pos, pos);
    } else {
      _isDrawingNew = false;
    }
    setState(() {});
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_dragStartLocal == null) return;

    if (_isDrawingNew) {
      final cur = details.localPosition;
      final clampedPos = Offset(
        cur.dx.clamp(0.0, widget.pageWidth),
        cur.dy.clamp(0.0, widget.pageHeight),
      );
      setState(() {
        _cropRect = Rect.fromPoints(_dragStartLocal!, clampedPos);
      });
      return;
    }

    if (_initialRectOnDrag == null) return;
    final delta = details.localPosition - _dragStartLocal!;
    final init = _initialRectOnDrag!;

    const minSize = 40.0;
    double l = init.left;
    double t = init.top;
    double r = init.right;
    double b = init.bottom;

    switch (_activeHandle) {
      case _CropHandle.inside:
        final dx = delta.dx.clamp(-init.left, widget.pageWidth - init.right);
        final dy = delta.dy.clamp(-init.top, widget.pageHeight - init.bottom);
        l = init.left + dx;
        t = init.top + dy;
        r = init.right + dx;
        b = init.bottom + dy;
        break;
      case _CropHandle.topLeft:
        l = math.min(init.left + delta.dx, init.right - minSize);
        t = math.min(init.top + delta.dy, init.bottom - minSize);
        break;
      case _CropHandle.topCenter:
        t = math.min(init.top + delta.dy, init.bottom - minSize);
        break;
      case _CropHandle.topRight:
        r = math.max(init.right + delta.dx, init.left + minSize);
        t = math.min(init.top + delta.dy, init.bottom - minSize);
        break;
      case _CropHandle.centerLeft:
        l = math.min(init.left + delta.dx, init.right - minSize);
        break;
      case _CropHandle.centerRight:
        r = math.max(init.right + delta.dx, init.left + minSize);
        break;
      case _CropHandle.bottomLeft:
        l = math.min(init.left + delta.dx, init.right - minSize);
        b = math.max(init.bottom + delta.dy, init.top + minSize);
        break;
      case _CropHandle.bottomCenter:
        b = math.max(init.bottom + delta.dy, init.top + minSize);
        break;
      case _CropHandle.bottomRight:
        r = math.max(init.right + delta.dx, init.left + minSize);
        b = math.max(init.bottom + delta.dy, init.top + minSize);
        break;
      case _CropHandle.none:
        // New marquee selection
        l = math.min(_dragStartLocal!.dx, details.localPosition.dx);
        t = math.min(_dragStartLocal!.dy, details.localPosition.dy);
        r = math.max(_dragStartLocal!.dx, details.localPosition.dx);
        b = math.max(_dragStartLocal!.dy, details.localPosition.dy);
        break;
    }

    l = l.clamp(0.0, widget.pageWidth - minSize);
    t = t.clamp(0.0, widget.pageHeight - minSize);
    r = r.clamp(l + minSize, widget.pageWidth);
    b = b.clamp(t + minSize, widget.pageHeight);

    setState(() {
      _cropRect = Rect.fromLTRB(l, t, r, b);
    });
  }

  void _handlePanEnd() {
    _isDrawingNew = false;
    if (_cropRect != null && (_cropRect!.width < 20 || _cropRect!.height < 20)) {
      _cropRect = null;
    }
    setState(() {
      _activeHandle = _CropHandle.none;
      _dragStartLocal = null;
      _initialRectOnDrag = null;
    });
  }

  _CropHandle _hitTestHandle(Offset pos) {
    if (_cropRect == null) return _CropHandle.none;
    final r = _cropRect!;
    const handleRadius = 14.0;

    bool near(Offset p) => (pos - p).distance <= handleRadius;

    if (near(r.topLeft)) return _CropHandle.topLeft;
    if (near(r.topRight)) return _CropHandle.topRight;
    if (near(r.bottomLeft)) return _CropHandle.bottomLeft;
    if (near(r.bottomRight)) return _CropHandle.bottomRight;

    if (near(Offset(r.center.dx, r.top))) return _CropHandle.topCenter;
    if (near(Offset(r.center.dx, r.bottom))) return _CropHandle.bottomCenter;
    if (near(Offset(r.left, r.center.dy))) return _CropHandle.centerLeft;
    if (near(Offset(r.right, r.center.dy))) return _CropHandle.centerRight;

    if (r.contains(pos)) return _CropHandle.inside;
    return _CropHandle.none;
  }

  Widget _buildActionsPill(Color themeAccent) {
    final isLight = MoscaroTokens.isLight;
    const double pillHeight = 36.0;

    if (_cropRect == null || _cropRect!.width < 20 || _cropRect!.height < 20 || _isDrawingNew) {
      return const SizedBox.shrink();
    }
    final r = _cropRect!;
    double top = r.bottom + 10.0;
    if (top + pillHeight > widget.pageHeight - 10.0) {
      top = r.top - pillHeight - 10.0;
    }
    top = top.clamp(10.0, math.max(10.0, widget.pageHeight - pillHeight - 10.0));

    final bool bypass = DiagnosticsOverrideController.instance.bypassBackdropFilter;
    final double blurSigma = (!bypass && MoscaroTokens.enableToolbarBlur && MoscaroTokens.blurSigma > 0)
        ? MoscaroTokens.blurSigma
        : 0.0;

    final toolbarBox = Container(
      height: pillHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: MoscaroTokens.glassTint,
        borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
        border: Border.all(
          color: isLight
              ? MoscaroTokens.borderSubtle
              : themeAccent.withValues(alpha: 0.45),
          width: MoscaroTokens.borderWidthSubtle,
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? const Color(0x180F172A)
                : Colors.black.withValues(alpha: 0.40),
            blurRadius: 14.0,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: themeAccent.withValues(alpha: isLight ? 0.08 : 0.20),
            blurRadius: 8.0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildButton(
            icon: 'image',
            label: 'Imagem',
            accent: themeAccent,
            onTap: () => widget.onCropAsImage(r),
          ),
          if (widget.onCropSendToAi != null) ...[
            const SizedBox(width: 4.0),
            _buildButton(
              icon: 'sparkle',
              label: 'Enviar para IA',
              accent: themeAccent,
              onTap: () => widget.onCropSendToAi!(r),
            ),
          ],
          if (widget.onCropExtractLatex != null) ...[
            const SizedBox(width: 4.0),
            _buildButton(
              icon: 'flash',
              label: 'Extrair LaTeX',
              accent: themeAccent,
              onTap: () => widget.onCropExtractLatex!(r),
            ),
          ],
          const SizedBox(width: 4.0),
          _buildButton(
            icon: 'code',
            label: 'Card STEM',
            accent: themeAccent,
            onTap: () => widget.onCropAsStemCard(r),
          ),
          const SizedBox(width: 4.0),
          _buildButton(
            icon: 'close',
            label: 'Cancelar',
            accent: MoscaroTokens.auroraPink,
            onTap: widget.onCancel,
          ),
        ],
      ),
    );

    return Positioned(
      left: 6.0,
      right: 6.0,
      top: top,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
            child: blurSigma > 0
                ? BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: toolbarBox,
                    ),
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: toolbarBox,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String icon,
    required String label,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(
                name: icon,
                size: 13.0,
                color: accent,
              ),
              const SizedBox(width: 5.0),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
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

class _CropMarqueePainter extends CustomPainter {
  final Rect? cropRect;
  final Color accentColor;

  _CropMarqueePainter({
    required this.cropRect,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (this.cropRect == null) return;
    final Rect cropRect = this.cropRect!;
    // 1. Semi-transparent backdrop with cutout over cropRect
    final bgPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cropPath = Path()..addRect(cropRect);
    final cutoutPath = Path.combine(PathOperation.difference, bgPath, cropPath);

    final maskPaint = Paint()..color = Colors.black.withValues(alpha: 0.48);
    canvas.drawPath(cutoutPath, maskPaint);

    // 2. Cyan Glowing Border
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawRect(cropRect, glowPaint);

    final borderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawRect(cropRect, borderPaint);

    // 3. Grid lines (rule of thirds)
    final gridPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final thirdW = cropRect.width / 3.0;
    final thirdH = cropRect.height / 3.0;

    canvas.drawLine(
      Offset(cropRect.left + thirdW, cropRect.top),
      Offset(cropRect.left + thirdW, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + 2 * thirdW, cropRect.top),
      Offset(cropRect.left + 2 * thirdW, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdH),
      Offset(cropRect.right, cropRect.top + thirdH),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + 2 * thirdH),
      Offset(cropRect.right, cropRect.top + 2 * thirdH),
      gridPaint,
    );

    // 4. Corner & edge drag handles
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handleBorder = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final handlePositions = [
      cropRect.topLeft,
      Offset(cropRect.center.dx, cropRect.top),
      cropRect.topRight,
      Offset(cropRect.left, cropRect.center.dy),
      Offset(cropRect.right, cropRect.center.dy),
      cropRect.bottomLeft,
      Offset(cropRect.center.dx, cropRect.bottom),
      cropRect.bottomRight,
    ];

    const double r = 4.5;
    for (final pos in handlePositions) {
      canvas.drawCircle(pos, r, handlePaint);
      canvas.drawCircle(pos, r, handleBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _CropMarqueePainter oldDelegate) {
    return oldDelegate.cropRect != cropRect || oldDelegate.accentColor != accentColor;
  }
}
