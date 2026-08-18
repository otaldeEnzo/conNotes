import 'package:flutter/material.dart';

/// Presets Oficiais de Temas STEM do conNotes (9 Presets para Grade 3x3 Perfeita).
enum AppThemePreset {
  moscaroCyan,
  onyxStealth,
  quantumEmerald,
  nebulaCyberpunk,
  solarFlare,
  blueprintEngineer,
  pureLaboratoryLight,
  amethystSupernova,
  graphiteMonolith,
  custom;

  String get id => name;

  String get displayName {
    switch (this) {
      case AppThemePreset.moscaroCyan:
        return 'Moscaro Cyan';
      case AppThemePreset.onyxStealth:
        return 'Onyx Stealth';
      case AppThemePreset.quantumEmerald:
        return 'Quantum Emerald';
      case AppThemePreset.nebulaCyberpunk:
        return 'Nebula Cyberpunk';
      case AppThemePreset.solarFlare:
        return 'Solar Flare';
      case AppThemePreset.blueprintEngineer:
        return 'Blueprint Engineer';
      case AppThemePreset.pureLaboratoryLight:
        return 'Pure Laboratory Light';
      case AppThemePreset.amethystSupernova:
        return 'Amethyst Supernova';
      case AppThemePreset.graphiteMonolith:
        return 'Graphite Monolith';
      case AppThemePreset.custom:
        return 'Personalizado';
    }
  }

  String get description {
    switch (this) {
      case AppThemePreset.moscaroCyan:
        return 'Laboratório Quântico & Stitch Moderno';
      case AppThemePreset.onyxStealth:
        return 'Minimalista, Preto OLED e Titânio';
      case AppThemePreset.quantumEmerald:
        return 'Computação, Terminal e Fósforo Verde';
      case AppThemePreset.nebulaCyberpunk:
        return 'Cosmologia, Astrofísica e Radiação';
      case AppThemePreset.solarFlare:
        return 'Termodinâmica, Energia e Plasma Solar';
      case AppThemePreset.blueprintEngineer:
        return 'Prancheta Técnica Clássica de Engenharia';
      case AppThemePreset.pureLaboratoryLight:
        return 'Preset Claro Oficial, Branco Gelo e Alto Contraste';
      case AppThemePreset.amethystSupernova:
        return 'Violeta Cósmico Profundo, Ametista e Magenta';
      case AppThemePreset.graphiteMonolith:
        return 'Minimalista Escuro, Grafite e Platina Acetinada';
      case AppThemePreset.custom:
        return 'Tema Criado pelo Usuário';
    }
  }

  static AppThemePreset fromId(String id) {
    if (id == 'custom' || id.startsWith('custom')) {
      return AppThemePreset.custom;
    }
    return AppThemePreset.values.firstWhere(
      (e) => e.id == id,
      orElse: () => AppThemePreset.custom,
    );
  }
}

/// Modos de Fundo do Canvas
enum CanvasBackgroundMode {
  preset,
  solidColor,
  gradient,
  stemWallpaper,
  customImage;

  String get id => name;

  String get label {
    switch (this) {
      case CanvasBackgroundMode.preset:
        return 'Preset Gradiente';
      case CanvasBackgroundMode.solidColor:
        return 'Cor Sólida';
      case CanvasBackgroundMode.gradient:
        return 'Gradiente Personalizado';
      case CanvasBackgroundMode.stemWallpaper:
        return 'Wallpapers STEM';
      case CanvasBackgroundMode.customImage:
        return 'Imagem do Disco';
    }
  }

  static CanvasBackgroundMode fromId(String id) {
    return CanvasBackgroundMode.values.firstWhere(
      (e) => e.id == id,
      orElse: () => CanvasBackgroundMode.preset,
    );
  }
}

/// Texturas Procedurais STEM aplicáveis ao Canvas
enum CanvasTextureType {
  none,
  graphPaper,
  blueprintCloth,
  carbonFiber,
  analogGrain;

  String get id => name;
  String get label => displayName;

  String get displayName {
    switch (this) {
      case CanvasTextureType.none:
        return 'Nenhuma';
      case CanvasTextureType.graphPaper:
        return 'Papel Milimetrado Escuro';
      case CanvasTextureType.blueprintCloth:
        return 'Blueprint Têxtil';
      case CanvasTextureType.carbonFiber:
        return 'Fibra de Carbono Matrix';
      case CanvasTextureType.analogGrain:
        return 'Grão Analógico Suave';
    }
  }

  static CanvasTextureType fromId(String id) {
    return CanvasTextureType.values.firstWhere(
      (e) => e.id == id,
      orElse: () => CanvasTextureType.none,
    );
  }
}

/// Wallpapers Prontos STEM para Fundo do Canvas
class StemWallpaperPreset {
  final String id;
  final String name;
  final String description;
  final Color baseColor;

  const StemWallpaperPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.baseColor,
  });

  static const List<StemWallpaperPreset> builtInWallpapers = [
    StemWallpaperPreset(
      id: 'deep_field',
      name: 'Cosmos Deep Field',
      description: 'Astrofotografia do espaço profundo e nebulosas',
      baseColor: Color(0xFF080614),
    ),
    StemWallpaperPreset(
      id: 'quantum_circuits',
      name: 'Circuitos Quânticos',
      description: 'Malha geométrica de microeletrônica neon',
      baseColor: Color(0xFF041218),
    ),
    StemWallpaperPreset(
      id: 'technical_grid',
      name: 'Prancheta Holográfica',
      description: 'Grid milimetrado técnico com halo azul ciano',
      baseColor: Color(0xFF061022),
    ),
    StemWallpaperPreset(
      id: 'solar_plasma',
      name: 'Plasma Solar Termal',
      description: 'Gradiente de alta energia com partículas quentes',
      baseColor: Color(0xFF140A04),
    ),
    StemWallpaperPreset(
      id: 'feynman_diagrams',
      name: 'Diagramas de Feynman',
      description: 'Física de partículas, bósons e colisores quânticos',
      baseColor: Color(0xFF0A0F1E),
    ),
    StemWallpaperPreset(
      id: 'gravity_topography',
      name: 'Topografia Gravitacional',
      description: 'Curvatura relativística do espaço-tempo e geodésicas',
      baseColor: Color(0xFF061418),
    ),
    StemWallpaperPreset(
      id: 'graphene_lattice',
      name: 'Estrutura de Grafeno',
      description: 'Cristalografia hexagonal e ciência dos nanomateriais',
      baseColor: Color(0xFF100D1C),
    ),
    StemWallpaperPreset(
      id: 'aerospace_blueprint',
      name: 'Engenharia Aeroespacial',
      description: 'Esquema técnico vetorial de propulsão e telemetria',
      baseColor: Color(0xFF04101A),
    ),
  ];
}

/// Definição Completa de um Tema Visual STEM (Moscaro v2 Pro Max).
class ThemeDefinition {
  final AppThemePreset preset;
  final String? customId;
  final bool isCustom;
  final String name;

  // 1. Cores e Fundo
  final CanvasBackgroundMode bgMode;
  final Color backgroundDeep;
  final Color backgroundSurface;
  final List<Color>? gradientColors;
  final String? bgImagePath;
  final double bgImageOpacity;
  final CanvasTextureType textureType;

  // 2. Acentos Neon e Vidro Líquido
  final Color accentPrimary;
  final Color accentSecondary;
  final Color dotGridColor;
  final Color mouseGlowColor;
  final Color glassColor;
  final Color borderGlowColor;

  // 3. Paleta de Canetas STEM
  final List<Color> stemPalette;

  // 4. Presença Individual de Blur (BackdropFilter) por Componente
  final bool enableSidebarBlur;
  final bool enableToolbarBlur;
  final bool enableSubBarsBlur;
  final bool enableModalsBlur;
  final bool enableInstrumentsBlur;

  const ThemeDefinition({
    required this.preset,
    this.customId,
    this.isCustom = false,
    required this.name,
    this.bgMode = CanvasBackgroundMode.preset,
    required this.backgroundDeep,
    required this.backgroundSurface,
    this.gradientColors,
    this.bgImagePath,
    this.bgImageOpacity = 0.5,
    this.textureType = CanvasTextureType.none,
    required this.accentPrimary,
    required this.accentSecondary,
    required this.dotGridColor,
    required this.mouseGlowColor,
    required this.glassColor,
    required this.borderGlowColor,
    required this.stemPalette,
    this.enableSidebarBlur = true,
    this.enableToolbarBlur = true,
    this.enableSubBarsBlur = true,
    this.enableModalsBlur = true,
    this.enableInstrumentsBlur = true,
  });

  String get id => customId ?? preset.id;

  /// Retorna as cores efetivas do gradiente (seja de 2 ou N paradas)
  List<Color> get effectiveGradientColors {
    if (gradientColors != null && gradientColors!.length >= 2) {
      return gradientColors!;
    }
    return [backgroundSurface, backgroundDeep];
  }

  // Contraste Inteligente para Texto do Canvas e Instrumentos (WCAG AAA)
  Color get canvasTextColor {
    final lum = backgroundSurface.computeLuminance();
    return lum > 0.45 ? Colors.black : Colors.white;
  }

  Color get canvasSubtextColor {
    final lum = backgroundSurface.computeLuminance();
    return lum > 0.45 ? Colors.black87 : Colors.white70;
  }

  // Presets Oficiais do conNotes com Películas Translúcidas Temáticas (9 Presets 3x3)
  static const ThemeDefinition moscaroCyan = ThemeDefinition(
    preset: AppThemePreset.moscaroCyan,
    name: 'Moscaro Cyan',
    backgroundDeep: Color(0xFF070B14),
    backgroundSurface: Color(0xFF0C1626),
    accentPrimary: Color(0xFF00E1FF),
    accentSecondary: Color(0xFFA855F7),
    dotGridColor: Color(0x3300E1FF),
    mouseGlowColor: Color(0xFF00E1FF),
    glassColor: Color(0x260A1424),
    borderGlowColor: Color(0x3300E1FF),
    stemPalette: [
      Colors.white,
      Color(0xFF00E1FF),
      Color(0xFFA855F7),
      Color(0xFFFF007A),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
    ],
  );

  static const ThemeDefinition onyxStealth = ThemeDefinition(
    preset: AppThemePreset.onyxStealth,
    name: 'Onyx Stealth',
    backgroundDeep: Color(0xFF040507),
    backgroundSurface: Color(0xFF0D0F14),
    accentPrimary: Color(0xFF38BDF8),
    accentSecondary: Color(0xFF94A3B8),
    dotGridColor: Color(0x2894A3B8),
    mouseGlowColor: Color(0xFF38BDF8),
    glassColor: Color(0x2606080C),
    borderGlowColor: Color(0x2838BDF8),
    stemPalette: [
      Colors.white,
      Color(0xFF38BDF8),
      Color(0xFF94A3B8),
      Color(0xFFE2E8F0),
      Color(0xFF64748B),
      Color(0xFFCBD5E1),
    ],
  );

  static const ThemeDefinition quantumEmerald = ThemeDefinition(
    preset: AppThemePreset.quantumEmerald,
    name: 'Quantum Emerald',
    backgroundDeep: Color(0xFF030D08),
    backgroundSurface: Color(0xFF081C12),
    accentPrimary: Color(0xFF10B981),
    accentSecondary: Color(0xFF06B6D4),
    dotGridColor: Color(0x3010B981),
    mouseGlowColor: Color(0xFF10B981),
    glassColor: Color(0x2604160E),
    borderGlowColor: Color(0x3310B981),
    stemPalette: [
      Colors.white,
      Color(0xFF10B981),
      Color(0xFF06B6D4),
      Color(0xFF34D399),
      Color(0xFF2DD4BF),
      Color(0xFFFBBF24),
    ],
  );

  static const ThemeDefinition nebulaCyberpunk = ThemeDefinition(
    preset: AppThemePreset.nebulaCyberpunk,
    name: 'Nebula Cyberpunk',
    backgroundDeep: Color(0xFF0C0718),
    backgroundSurface: Color(0xFF190D2E),
    accentPrimary: Color(0xFFFF007A),
    accentSecondary: Color(0xFFA855F7),
    dotGridColor: Color(0x35FF007A),
    mouseGlowColor: Color(0xFFFF007A),
    glassColor: Color(0x26130924),
    borderGlowColor: Color(0x38FF007A),
    stemPalette: [
      Colors.white,
      Color(0xFFFF007A),
      Color(0xFFA855F7),
      Color(0xFF00E1FF),
      Color(0xFFFFE600),
      Color(0xFFB026FF),
    ],
  );

  static const ThemeDefinition solarFlare = ThemeDefinition(
    preset: AppThemePreset.solarFlare,
    name: 'Solar Flare',
    backgroundDeep: Color(0xFF0F0A05),
    backgroundSurface: Color(0xFF211409),
    accentPrimary: Color(0xFFF59E0B),
    accentSecondary: Color(0xFFFF5722),
    dotGridColor: Color(0x30F59E0B),
    mouseGlowColor: Color(0xFFF59E0B),
    glassColor: Color(0x26180E06),
    borderGlowColor: Color(0x38F59E0B),
    stemPalette: [
      Colors.white,
      Color(0xFFF59E0B),
      Color(0xFFFF5722),
      Color(0xFFFFB703),
      Color(0xFFFB8500),
      Color(0xFFEF4444),
    ],
  );

  static const ThemeDefinition blueprintEngineer = ThemeDefinition(
    preset: AppThemePreset.blueprintEngineer,
    name: 'Blueprint Engineer',
    backgroundDeep: Color(0xFF081324),
    backgroundSurface: Color(0xFF0E223D),
    accentPrimary: Color(0xFF38BDF8),
    accentSecondary: Color(0xFFE2E8F0),
    dotGridColor: Color(0x3538BDF8),
    mouseGlowColor: Color(0xFF38BDF8),
    glassColor: Color(0x26091930),
    borderGlowColor: Color(0x3838BDF8),
    stemPalette: [
      Colors.white,
      Color(0xFF38BDF8),
      Color(0xFFE2E8F0),
      Color(0xFF60A5FA),
      Color(0xFF93C5FD),
      Color(0xFFF59E0B),
    ],
  );

  static const ThemeDefinition pureLaboratoryLight = ThemeDefinition(
    preset: AppThemePreset.pureLaboratoryLight,
    name: 'Pure Laboratory Light',
    backgroundDeep: Color(0xFFE2E8F0),
    backgroundSurface: Color(0xFFF8FAFC),
    accentPrimary: Color(0xFF0284C7),
    accentSecondary: Color(0xFF6366F1),
    dotGridColor: Color(0x400284C7),
    mouseGlowColor: Color(0xFF0284C7),
    glassColor: Color(0x26F1F5F9),
    borderGlowColor: Color(0x400284C7),
    stemPalette: [
      Color(0xFF0F172A),
      Color(0xFF0284C7),
      Color(0xFFDC2626),
      Color(0xFF16A34A),
      Color(0xFF9333EA),
      Color(0xFFD97706),
    ],
  );

  static const ThemeDefinition amethystSupernova = ThemeDefinition(
    preset: AppThemePreset.amethystSupernova,
    name: 'Amethyst Supernova',
    backgroundDeep: Color(0xFF0B0418),
    backgroundSurface: Color(0xFF17082E),
    accentPrimary: Color(0xFFC084FC),
    accentSecondary: Color(0xFFFF2E93),
    dotGridColor: Color(0x35C084FC),
    mouseGlowColor: Color(0xFFC084FC),
    glassColor: Color(0x26120624),
    borderGlowColor: Color(0x38C084FC),
    stemPalette: [
      Colors.white,
      Color(0xFFC084FC),
      Color(0xFFFF2E93),
      Color(0xFF38BDF8),
      Color(0xFFA855F7),
      Color(0xFFFACC15),
    ],
  );

  static const ThemeDefinition graphiteMonolith = ThemeDefinition(
    preset: AppThemePreset.graphiteMonolith,
    name: 'Graphite Monolith',
    backgroundDeep: Color(0xFF0C0D0F),
    backgroundSurface: Color(0xFF191B1F),
    accentPrimary: Color(0xFFE2E8F0),
    accentSecondary: Color(0xFF38BDF8),
    dotGridColor: Color(0x2CE2E8F0),
    mouseGlowColor: Color(0xFFE2E8F0),
    glassColor: Color(0x26111317),
    borderGlowColor: Color(0x30E2E8F0),
    stemPalette: [
      Colors.white,
      Color(0xFFE2E8F0),
      Color(0xFF38BDF8),
      Color(0xFF94A3B8),
      Color(0xFF4ADE80),
      Color(0xFFFB923C),
    ],
  );

  static List<ThemeDefinition> get officialPresets => [
    moscaroCyan,
    onyxStealth,
    quantumEmerald,
    nebulaCyberpunk,
    solarFlare,
    blueprintEngineer,
    pureLaboratoryLight,
    amethystSupernova,
    graphiteMonolith,
  ];

  static ThemeDefinition getByPreset(AppThemePreset preset) {
    switch (preset) {
      case AppThemePreset.moscaroCyan:
        return moscaroCyan;
      case AppThemePreset.onyxStealth:
        return onyxStealth;
      case AppThemePreset.quantumEmerald:
        return quantumEmerald;
      case AppThemePreset.nebulaCyberpunk:
        return nebulaCyberpunk;
      case AppThemePreset.solarFlare:
        return solarFlare;
      case AppThemePreset.blueprintEngineer:
        return blueprintEngineer;
      case AppThemePreset.pureLaboratoryLight:
        return pureLaboratoryLight;
      case AppThemePreset.amethystSupernova:
        return amethystSupernova;
      case AppThemePreset.graphiteMonolith:
        return graphiteMonolith;
      case AppThemePreset.custom:
        return moscaroCyan;
    }
  }

  ThemeDefinition copyWith({
    AppThemePreset? preset,
    String? customId,
    bool? isCustom,
    String? name,
    CanvasBackgroundMode? bgMode,
    Color? backgroundDeep,
    Color? backgroundSurface,
    List<Color>? gradientColors,
    String? bgImagePath,
    double? bgImageOpacity,
    CanvasTextureType? textureType,
    Color? accentPrimary,
    Color? accentSecondary,
    Color? dotGridColor,
    Color? mouseGlowColor,
    Color? glassColor,
    Color? borderGlowColor,
    List<Color>? stemPalette,
    bool? enableSidebarBlur,
    bool? enableToolbarBlur,
    bool? enableSubBarsBlur,
    bool? enableModalsBlur,
    bool? enableInstrumentsBlur,
  }) {
    return ThemeDefinition(
      preset: preset ?? this.preset,
      customId: customId ?? this.customId,
      isCustom: isCustom ?? this.isCustom,
      name: name ?? this.name,
      bgMode: bgMode ?? this.bgMode,
      backgroundDeep: backgroundDeep ?? this.backgroundDeep,
      backgroundSurface: backgroundSurface ?? this.backgroundSurface,
      gradientColors: gradientColors ?? this.gradientColors,
      bgImagePath: bgImagePath ?? this.bgImagePath,
      bgImageOpacity: bgImageOpacity ?? this.bgImageOpacity,
      textureType: textureType ?? this.textureType,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      dotGridColor: dotGridColor ?? this.dotGridColor,
      mouseGlowColor: mouseGlowColor ?? this.mouseGlowColor,
      glassColor: glassColor ?? this.glassColor,
      borderGlowColor: borderGlowColor ?? this.borderGlowColor,
      stemPalette: stemPalette ?? this.stemPalette,
      enableSidebarBlur: enableSidebarBlur ?? this.enableSidebarBlur,
      enableToolbarBlur: enableToolbarBlur ?? this.enableToolbarBlur,
      enableSubBarsBlur: enableSubBarsBlur ?? this.enableSubBarsBlur,
      enableModalsBlur: enableModalsBlur ?? this.enableModalsBlur,
      enableInstrumentsBlur: enableInstrumentsBlur ?? this.enableInstrumentsBlur,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customId': id,
      'isCustom': isCustom,
      'name': name,
      'bgMode': bgMode.id,
      'backgroundDeep': '#${backgroundDeep.toARGB32().toRadixString(16).padLeft(8, '0')}',
      'backgroundSurface': '#${backgroundSurface.toARGB32().toRadixString(16).padLeft(8, '0')}',
      'gradientColors': gradientColors?.map((c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}').toList(),
      'bgImagePath': bgImagePath,
      'bgImageOpacity': bgImageOpacity,
      'textureType': textureType.id,
      'accentPrimary': '#${accentPrimary.toARGB32().toRadixString(16).padLeft(8, '0')}',
      'accentSecondary': '#${accentSecondary.toARGB32().toRadixString(16).padLeft(8, '0')}',
      'dotGridColor': '#${dotGridColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
      'mouseGlowColor': '#${mouseGlowColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
      'glassColor': '#${glassColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
      'borderGlowColor': '#${borderGlowColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
      'stemPalette': stemPalette.map((c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}').toList(),
      'enableSidebarBlur': enableSidebarBlur,
      'enableToolbarBlur': enableToolbarBlur,
      'enableSubBarsBlur': enableSubBarsBlur,
      'enableModalsBlur': enableModalsBlur,
      'enableInstrumentsBlur': enableInstrumentsBlur,
    };
  }

  factory ThemeDefinition.fromJson(Map<String, dynamic> json) {
    Color parseHex(String? hex, Color fallback) {
      if (hex == null) return fallback;
      try {
        final clean = hex.replaceAll('#', '').replaceAll('0x', '');
        if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
        if (clean.length == 8) return Color(int.parse(clean, radix: 16));
      } catch (_) {}
      return fallback;
    }

    final rawPalette = json['stemPalette'] as List<dynamic>?;
    final List<Color> palette = rawPalette != null
        ? rawPalette.map((item) => parseHex(item.toString(), Colors.white)).toList()
        : List<Color>.from(moscaroCyan.stemPalette);

    final List<Color>? gradColors = (json['gradientColors'] as List<dynamic>?)
        ?.map((item) => parseHex(item.toString(), Colors.white))
        .toList();

    return ThemeDefinition(
      preset: AppThemePreset.custom,
      customId: json['customId'] as String? ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
      isCustom: json['isCustom'] as bool? ?? true,
      name: json['name'] as String? ?? 'Tema Personalizado',
      bgMode: CanvasBackgroundMode.fromId(json['bgMode'] as String? ?? 'preset'),
      backgroundDeep: parseHex(json['backgroundDeep'] as String?, moscaroCyan.backgroundDeep),
      backgroundSurface: parseHex(json['backgroundSurface'] as String?, moscaroCyan.backgroundSurface),
      gradientColors: gradColors,
      bgImagePath: json['bgImagePath'] as String?,
      bgImageOpacity: (json['bgImageOpacity'] as num?)?.toDouble() ?? 0.5,
      textureType: CanvasTextureType.fromId(json['textureType'] as String? ?? 'none'),
      accentPrimary: parseHex(json['accentPrimary'] as String?, moscaroCyan.accentPrimary),
      accentSecondary: parseHex(json['accentSecondary'] as String?, moscaroCyan.accentSecondary),
      dotGridColor: parseHex(json['dotGridColor'] as String?, moscaroCyan.dotGridColor),
      mouseGlowColor: parseHex(json['mouseGlowColor'] as String?, moscaroCyan.mouseGlowColor),
      glassColor: parseHex(json['glassColor'] as String?, moscaroCyan.glassColor),
      borderGlowColor: parseHex(json['borderGlowColor'] as String?, moscaroCyan.borderGlowColor),
      stemPalette: palette,
      enableSidebarBlur: json['enableSidebarBlur'] as bool? ?? true,
      enableToolbarBlur: json['enableToolbarBlur'] as bool? ?? true,
      enableSubBarsBlur: json['enableSubBarsBlur'] as bool? ?? true,
      enableModalsBlur: json['enableModalsBlur'] as bool? ?? true,
      enableInstrumentsBlur: json['enableInstrumentsBlur'] as bool? ?? true,
    );
  }
}
