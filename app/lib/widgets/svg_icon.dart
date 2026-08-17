import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Componente padronizado para exibição estrita de ícones SVG.
/// Regra: Emojis são expressamente proibidos em todo o aplicativo conNotes.
class SvgIcon extends StatelessWidget {
  final String assetName;
  final double size;
  final Color color;

  static const Map<String, String> _builtinSvgStrings = {
    'laser': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <circle cx="12" cy="12" r="3"/>
  <path d="M12 3v3"/>
  <path d="M12 18v3"/>
  <path d="M3 12h3"/>
  <path d="M18 12h3"/>
  <path d="m19 19-2-2"/>
  <path d="m5 5 2 2"/>
</svg>''',
    'rotate': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M21 12a9 9 0 1 1-9-9c2.52 0 4.85.83 6.72 2.24L21 8"/>
  <path d="M21 3v5h-5"/>
</svg>''',
    'ruler': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M21.3 8.7 8.7 21.3c-1 1-2.5 1-3.4 0l-2.6-2.6c-1-1-1-2.5 0-3.4L15.3 2.7c1-1 2.5-1 3.4 0l2.6 2.6c1 1 1 2.5 0 3.4Z"/>
  <path d="m14.5 3.5 2 2"/>
  <path d="m11.5 6.5 3 3"/>
  <path d="m8.5 9.5 2 2"/>
  <path d="m5.5 12.5 3 3"/>
</svg>''',
  };

  const SvgIcon({
    super.key,
    required this.assetName,
    this.size = 20.0,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final inlineSvg = _builtinSvgStrings[assetName];
    if (inlineSvg != null) {
      return SvgPicture.string(
        inlineSvg,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }

    return SvgPicture.asset(
      'assets/icons/$assetName.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.lens_blur_rounded,
          size: size,
          color: color,
        );
      },
    );
  }
}
