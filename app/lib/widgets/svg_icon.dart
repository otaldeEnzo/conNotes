import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Componente padronizado para exibição estrita de ícones SVG.
/// Regra: Emojis são expressamente proibidos em todo o aplicativo conNotes.
class SvgIcon extends StatelessWidget {
  final String assetName;
  final double size;
  final Color color;

  const SvgIcon({
    super.key,
    required this.assetName,
    this.size = 20.0,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/$assetName.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
