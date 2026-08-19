import '../models/theme_models.dart';

/// Categorias de Configuração da SettingsTabBar
enum SettingsCategory {
  themes,
  visual,
  canvas,
  pen,
  measurement,
  shortcuts,
  ai;

  String get label {
    switch (this) {
      case SettingsCategory.themes:
        return 'Temas & Estilo';
      case SettingsCategory.visual:
        return 'Geral & Visual';
      case SettingsCategory.canvas:
        return 'Canvas & Grid';
      case SettingsCategory.pen:
        return 'Caneta & Stylus';
      case SettingsCategory.measurement:
        return 'Medição';
      case SettingsCategory.shortcuts:
        return 'Atalhos';
      case SettingsCategory.ai:
        return 'Inteligência Artificial';
    }
  }

  String get iconName {
    switch (this) {
      case SettingsCategory.themes:
        return 'palette';
      case SettingsCategory.visual:
        return 'brush';
      case SettingsCategory.canvas:
        return 'grid';
      case SettingsCategory.pen:
        return 'pen';
      case SettingsCategory.measurement:
        return 'ruler';
      case SettingsCategory.shortcuts:
        return 'keyboard';
      case SettingsCategory.ai:
        return 'ai';
    }
  }
}

/// Estado global e imutável de preferências do conNotes
class AppSettingsState {
  // 0. Temas & Estilo STEM
  final String activeThemeId;
  final String customBgMode;
  final String customBgColorHex;
  final String customGradStartHex;
  final String customGradEndHex;
  final String customTextureType;
  final String? customImagePath;
  final double customImageOpacity;
  final List<ThemeDefinition> customThemes;

  // 1. Geral & Visual Moscaro v2
  final String? workspaceDirectoryPath;
  final double blurSigma;
  final bool enableAuroraBorders;
  final bool showTelemetryHud;

  // 2. Canvas & Grid STEM
  final double gridSpacing;
  final bool enableMouseGlow;
  final double mouseGlowRadius;

  // 3. Caneta & Stylus
  final double rdpSmoothingTolerance;
  final double pressureSensitivity;
  final int drawAndHoldDurationMs;

  // 4. Instrumentos de Medição (Régua & Transferidor)
  final double angleSnapStepDegrees;
  final double inkSnapTolerance;

  // 5. Inteligência Artificial STEM
  final String geminiApiKey;
  final String defaultAiModel;

  const AppSettingsState({
    this.activeThemeId = 'moscaro_cyan',
    this.customBgMode = 'preset',
    this.customBgColorHex = '#070B14',
    this.customGradStartHex = '#0C1B2E',
    this.customGradEndHex = '#060B12',
    this.customTextureType = 'none',
    this.customImagePath,
    this.customImageOpacity = 0.5,
    this.customThemes = const [],
    this.workspaceDirectoryPath,
    this.blurSigma = 35.0,
    this.enableAuroraBorders = true,
    this.showTelemetryHud = true,
    this.gridSpacing = 28.0,
    this.enableMouseGlow = true,
    this.mouseGlowRadius = 120.0,
    this.rdpSmoothingTolerance = 0.35,
    this.pressureSensitivity = 1.0,
    this.drawAndHoldDurationMs = 400,
    this.angleSnapStepDegrees = 15.0,
    this.inkSnapTolerance = 24.0,
    this.geminiApiKey = '',
    this.defaultAiModel = 'gemini-2.5-flash',
  });

  factory AppSettingsState.defaults() => const AppSettingsState();

  AppSettingsState copyWith({
    String? activeThemeId,
    String? customBgMode,
    String? customBgColorHex,
    String? customGradStartHex,
    String? customGradEndHex,
    String? customTextureType,
    String? customImagePath,
    double? customImageOpacity,
    List<ThemeDefinition>? customThemes,
    String? workspaceDirectoryPath,
    double? blurSigma,
    bool? enableAuroraBorders,
    bool? showTelemetryHud,
    double? gridSpacing,
    bool? enableMouseGlow,
    double? mouseGlowRadius,
    double? rdpSmoothingTolerance,
    double? pressureSensitivity,
    int? drawAndHoldDurationMs,
    double? angleSnapStepDegrees,
    double? inkSnapTolerance,
    String? geminiApiKey,
    String? defaultAiModel,
  }) {
    return AppSettingsState(
      activeThemeId: activeThemeId ?? this.activeThemeId,
      customBgMode: customBgMode ?? this.customBgMode,
      customBgColorHex: customBgColorHex ?? this.customBgColorHex,
      customGradStartHex: customGradStartHex ?? this.customGradStartHex,
      customGradEndHex: customGradEndHex ?? this.customGradEndHex,
      customTextureType: customTextureType ?? this.customTextureType,
      customImagePath: customImagePath ?? this.customImagePath,
      customImageOpacity: customImageOpacity ?? this.customImageOpacity,
      customThemes: customThemes ?? this.customThemes,
      workspaceDirectoryPath: workspaceDirectoryPath ?? this.workspaceDirectoryPath,
      blurSigma: (blurSigma ?? this.blurSigma).clamp(10.0, 50.0),
      enableAuroraBorders: enableAuroraBorders ?? this.enableAuroraBorders,
      showTelemetryHud: showTelemetryHud ?? this.showTelemetryHud,
      gridSpacing: (gridSpacing ?? this.gridSpacing).clamp(16.0, 48.0),
      enableMouseGlow: enableMouseGlow ?? this.enableMouseGlow,
      mouseGlowRadius: (mouseGlowRadius ?? this.mouseGlowRadius).clamp(60.0, 240.0),
      rdpSmoothingTolerance: (rdpSmoothingTolerance ?? this.rdpSmoothingTolerance).clamp(0.1, 0.8),
      pressureSensitivity: (pressureSensitivity ?? this.pressureSensitivity).clamp(0.5, 2.0),
      drawAndHoldDurationMs: (drawAndHoldDurationMs ?? this.drawAndHoldDurationMs).clamp(250, 750),
      angleSnapStepDegrees: angleSnapStepDegrees ?? this.angleSnapStepDegrees,
      inkSnapTolerance: (inkSnapTolerance ?? this.inkSnapTolerance).clamp(12.0, 40.0),
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      defaultAiModel: defaultAiModel ?? this.defaultAiModel,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activeThemeId': activeThemeId,
      'customBgMode': customBgMode,
      'customBgColorHex': customBgColorHex,
      'customGradStartHex': customGradStartHex,
      'customGradEndHex': customGradEndHex,
      'customTextureType': customTextureType,
      'customImagePath': customImagePath,
      'customImageOpacity': customImageOpacity,
      'customThemes': customThemes.map((t) => t.toJson()).toList(),
      'workspaceDirectoryPath': workspaceDirectoryPath,
      'blurSigma': blurSigma,
      'enableAuroraBorders': enableAuroraBorders,
      'showTelemetryHud': showTelemetryHud,
      'gridSpacing': gridSpacing,
      'enableMouseGlow': enableMouseGlow,
      'mouseGlowRadius': mouseGlowRadius,
      'rdpSmoothingTolerance': rdpSmoothingTolerance,
      'pressureSensitivity': pressureSensitivity,
      'drawAndHoldDurationMs': drawAndHoldDurationMs,
      'angleSnapStepDegrees': angleSnapStepDegrees,
      'inkSnapTolerance': inkSnapTolerance,
      'geminiApiKey': geminiApiKey,
      'defaultAiModel': defaultAiModel,
    };
  }

  factory AppSettingsState.fromJson(Map<String, dynamic> json) {
    final rawThemes = json['customThemes'] as List<dynamic>?;
    final List<ThemeDefinition> parsedThemes = rawThemes != null
        ? rawThemes
            .whereType<Map<String, dynamic>>()
            .map((item) => ThemeDefinition.fromJson(item))
            .toList()
        : [];

    return AppSettingsState(
      activeThemeId: json['activeThemeId'] as String? ?? 'moscaro_cyan',
      customBgMode: json['customBgMode'] as String? ?? 'preset',
      customBgColorHex: json['customBgColorHex'] as String? ?? '#070B14',
      customGradStartHex: json['customGradStartHex'] as String? ?? '#0C1B2E',
      customGradEndHex: json['customGradEndHex'] as String? ?? '#060B12',
      customTextureType: json['customTextureType'] as String? ?? 'none',
      customImagePath: json['customImagePath'] as String?,
      customImageOpacity: (json['customImageOpacity'] as num?)?.toDouble() ?? 0.5,
      customThemes: parsedThemes,
      workspaceDirectoryPath: json['workspaceDirectoryPath'] as String?,
      blurSigma: (json['blurSigma'] as num?)?.toDouble() ?? 35.0,
      enableAuroraBorders: json['enableAuroraBorders'] as bool? ?? true,
      showTelemetryHud: json['showTelemetryHud'] as bool? ?? true,
      gridSpacing: (json['gridSpacing'] as num?)?.toDouble() ?? 28.0,
      enableMouseGlow: json['enableMouseGlow'] as bool? ?? true,
      mouseGlowRadius: (json['mouseGlowRadius'] as num?)?.toDouble() ?? 120.0,
      rdpSmoothingTolerance: (json['rdpSmoothingTolerance'] as num?)?.toDouble() ?? 0.35,
      pressureSensitivity: (json['pressureSensitivity'] as num?)?.toDouble() ?? 1.0,
      drawAndHoldDurationMs: json['drawAndHoldDurationMs'] as int? ?? 400,
      angleSnapStepDegrees: (json['angleSnapStepDegrees'] as num?)?.toDouble() ?? 15.0,
      inkSnapTolerance: (json['inkSnapTolerance'] as num?)?.toDouble() ?? 24.0,
      geminiApiKey: json['geminiApiKey'] as String? ?? '',
      defaultAiModel: json['defaultAiModel'] as String? ?? 'gemini-2.5-flash',
    );
  }
}
