import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_theme_controller.dart';

/// Moscaro Modern Standard Sleek Scrollbar.
///
/// Encapsulates Flutter's [RawScrollbar] with a thin, non-intrusive track and
/// a translucent active theme accent thumb that smoothly reacts to light and dark modes.
class MoscaroSleekScrollbar extends StatelessWidget {
  /// The scrollable child widget (e.g. ListView, GridView, SingleChildScrollView).
  final Widget child;

  /// Optional ScrollController attached to the scrollable child.
  final ScrollController? controller;

  /// Whether the scrollbar thumb should always be visible or auto-hide.
  final bool thumbVisibility;

  /// Whether the scrollbar track should be visible.
  final bool trackVisibility;

  /// Custom thickness of the scrollbar thumb. Defaults to 4.0px.
  final double thickness;

  /// Padding around the scrollbar.
  final EdgeInsetsGeometry? padding;

  /// Optional custom thumb color override. If null, automatically binds to active theme accent.
  final Color? thumbColor;

  const MoscaroSleekScrollbar({
    super.key,
    required this.child,
    this.controller,
    this.thumbVisibility = true,
    this.trackVisibility = false,
    this.thickness = 4.0,
    this.padding,
    this.thumbColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MoscaroThemeController.instance,
      builder: (context, _) {
        final activeTheme = MoscaroThemeController.instance.currentTheme;
        final themeAccent = activeTheme.accentPrimary;
        final isLight = MoscaroTokens.isLight;

        final effectiveThumbColor = thumbColor ??
            (isLight
                ? themeAccent.withValues(alpha: 0.55)
                : themeAccent.withValues(alpha: 0.38));

        final trackColor = isLight
            ? Colors.black.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.03);

        return RawScrollbar(
          controller: controller,
          thumbVisibility: thumbVisibility,
          trackVisibility: trackVisibility,
          thickness: thickness,
          radius: const Radius.circular(8.0),
          thumbColor: effectiveThumbColor,
          trackColor: trackColor,
          padding: padding,
          interactive: true,
          child: child,
        );
      },
    );
  }
}
