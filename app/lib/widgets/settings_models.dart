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

/// Ações configuráveis para o botão lateral (Barrel Button) da Caneta / Stylus
enum StylusBarrelAction {
  strokeEraser,
  pixelEraser,
  selectionLasso,
  selectionRect,
  colorPicker,
  pan,
  disabled;

  String get label {
    switch (this) {
      case StylusBarrelAction.strokeEraser:
        return 'Borracha de Traço';
      case StylusBarrelAction.pixelEraser:
        return 'Borracha de Pixel';
      case StylusBarrelAction.selectionLasso:
        return 'Seleção (Laço)';
      case StylusBarrelAction.selectionRect:
        return 'Seleção (Área)';
      case StylusBarrelAction.colorPicker:
        return 'Conta-gotas';
      case StylusBarrelAction.pan:
        return 'Mover / Pan';
      case StylusBarrelAction.disabled:
        return 'Desativado';
    }
  }

  String get iconName {
    switch (this) {
      case StylusBarrelAction.strokeEraser:
        return 'eraser';
      case StylusBarrelAction.pixelEraser:
        return 'eraser';
      case StylusBarrelAction.selectionLasso:
        return 'lasso';
      case StylusBarrelAction.selectionRect:
        return 'select';
      case StylusBarrelAction.colorPicker:
        return 'eyedropper';
      case StylusBarrelAction.pan:
        return 'hand';
      case StylusBarrelAction.disabled:
        return 'lock';
    }
  }

  String get description {
    switch (this) {
      case StylusBarrelAction.strokeEraser:
        return 'Apaga o traço vetorial inteiro ao tocar.';
      case StylusBarrelAction.pixelEraser:
        return 'Apaga precisamente as partes tocadas do traço.';
      case StylusBarrelAction.selectionLasso:
        return 'Desenha um laço livre para selecionar elementos.';
      case StylusBarrelAction.selectionRect:
        return 'Arrasta um retângulo para selecionar elementos na área.';
      case StylusBarrelAction.colorPicker:
        return 'Captura a cor de qualquer elemento no canvas.';
      case StylusBarrelAction.pan:
        return 'Move a visualização do canvas sem desenhar.';
      case StylusBarrelAction.disabled:
        return 'Ignora o botão lateral da caneta.';
    }
  }
}

/// Modo de acionamento do botão do Stylus (Hold vs Toggle)
enum StylusTriggerMode {
  hold,
  toggle;

  String get label {
    switch (this) {
      case StylusTriggerMode.hold:
        return 'Segurar (Hold)';
      case StylusTriggerMode.toggle:
        return 'Alternar (Toggle)';
    }
  }

  String get description {
    switch (this) {
      case StylusTriggerMode.hold:
        return 'A ação fica ativa somente enquanto o botão lateral estiver pressionado.';
      case StylusTriggerMode.toggle:
        return 'Pressione uma vez para ativar e pressione novamente para desativar.';
    }
  }
}

/// Apelido para interoperabilidade de modelo
typedef AppSettingsData = AppSettingsState;

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
  final bool enableNativeRendering;

  // 2. Canvas & Grid STEM
  final double gridSpacing;
  final bool enableMouseGlow;
  final double mouseGlowRadius;

  // 3. Caneta & Stylus / Mesa Digitalizadora
  final double rdpSmoothingTolerance;
  final double pressureSensitivity;
  final int drawAndHoldDurationMs;
  final StylusBarrelAction stylusPrimaryBarrelAction;
  final StylusTriggerMode stylusPrimaryTriggerMode;
  final StylusBarrelAction stylusSecondaryBarrelAction;
  final StylusTriggerMode stylusSecondaryTriggerMode;
  final bool enableStylusHoverPreview;
  final bool enablePalmRejection;

  // Getters auxiliares
  StylusBarrelAction get primaryBarrelAction => stylusPrimaryBarrelAction;
  StylusTriggerMode get primaryBarrelTriggerMode => stylusPrimaryTriggerMode;
  StylusTriggerMode get stylusTriggerMode => stylusPrimaryTriggerMode;
  StylusBarrelAction get secondaryBarrelAction => stylusSecondaryBarrelAction;
  StylusTriggerMode get secondaryBarrelTriggerMode => stylusSecondaryTriggerMode;

  // 4. Instrumentos de Medição (Régua & Transferidor)
  final double angleSnapStepDegrees;
  final double inkSnapTolerance;

  // 5. Inteligência Artificial STEM (Multi-Provedor & Privacidade)
  final String geminiApiKey;
  final String openAiApiKey;
  final String claudeApiKey;
  final String ollamaEndpointUrl;
  final String activeAiModelId;
  final bool enableGemini;
  final bool enableOpenAi;
  final bool enableClaude;
  final bool enableOllama;

  final bool enableAiSidebar;
  final bool enableAiSelectionActions;
  final bool enableAiInlineCommands;
  final bool enableAiSocraticMode;
  final bool enableAiMermaidDiagrams;
  final bool enableAiHandwritingOcr;

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
    this.enableNativeRendering = true,
    this.gridSpacing = 28.0,
    this.enableMouseGlow = true,
    this.mouseGlowRadius = 120.0,
    this.rdpSmoothingTolerance = 0.35,
    this.pressureSensitivity = 1.0,
    this.drawAndHoldDurationMs = 400,
    this.stylusPrimaryBarrelAction = StylusBarrelAction.strokeEraser,
    this.stylusPrimaryTriggerMode = StylusTriggerMode.hold,
    this.stylusSecondaryBarrelAction = StylusBarrelAction.selectionLasso,
    this.stylusSecondaryTriggerMode = StylusTriggerMode.hold,
    this.enableStylusHoverPreview = true,
    this.enablePalmRejection = true,
    this.angleSnapStepDegrees = 15.0,
    this.inkSnapTolerance = 24.0,
    this.geminiApiKey = '',
    this.openAiApiKey = '',
    this.claudeApiKey = '',
    this.ollamaEndpointUrl = '',
    this.activeAiModelId = 'gemini-2.5-flash',
    this.enableGemini = false,
    this.enableOpenAi = false,
    this.enableClaude = false,
    this.enableOllama = false,
    this.enableAiSidebar = true,
    this.enableAiSelectionActions = true,
    this.enableAiInlineCommands = true,
    this.enableAiSocraticMode = false,
    this.enableAiMermaidDiagrams = true,
    this.enableAiHandwritingOcr = true,
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
    bool? enableNativeRendering,
    double? gridSpacing,
    bool? enableMouseGlow,
    double? mouseGlowRadius,
    double? rdpSmoothingTolerance,
    double? pressureSensitivity,
    int? drawAndHoldDurationMs,
    StylusBarrelAction? stylusPrimaryBarrelAction,
    StylusTriggerMode? stylusPrimaryTriggerMode,
    StylusBarrelAction? stylusSecondaryBarrelAction,
    StylusTriggerMode? stylusSecondaryTriggerMode,
    bool? enableStylusHoverPreview,
    bool? enablePalmRejection,
    double? angleSnapStepDegrees,
    double? inkSnapTolerance,
    String? geminiApiKey,
    String? openAiApiKey,
    String? claudeApiKey,
    String? ollamaEndpointUrl,
    String? activeAiModelId,
    bool? enableGemini,
    bool? enableOpenAi,
    bool? enableClaude,
    bool? enableOllama,
    bool? enableAiSidebar,
    bool? enableAiSelectionActions,
    bool? enableAiInlineCommands,
    bool? enableAiSocraticMode,
    bool? enableAiMermaidDiagrams,
    bool? enableAiHandwritingOcr,
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
      enableNativeRendering: enableNativeRendering ?? this.enableNativeRendering,
      gridSpacing: (gridSpacing ?? this.gridSpacing).clamp(16.0, 48.0),
      enableMouseGlow: enableMouseGlow ?? this.enableMouseGlow,
      mouseGlowRadius: (mouseGlowRadius ?? this.mouseGlowRadius).clamp(60.0, 240.0),
      rdpSmoothingTolerance: (rdpSmoothingTolerance ?? this.rdpSmoothingTolerance).clamp(0.1, 0.8),
      pressureSensitivity: (pressureSensitivity ?? this.pressureSensitivity).clamp(0.5, 2.0),
      drawAndHoldDurationMs: (drawAndHoldDurationMs ?? this.drawAndHoldDurationMs).clamp(250, 750),
      stylusPrimaryBarrelAction: stylusPrimaryBarrelAction ?? this.stylusPrimaryBarrelAction,
      stylusPrimaryTriggerMode: stylusPrimaryTriggerMode ?? this.stylusPrimaryTriggerMode,
      stylusSecondaryBarrelAction: stylusSecondaryBarrelAction ?? this.stylusSecondaryBarrelAction,
      stylusSecondaryTriggerMode: stylusSecondaryTriggerMode ?? this.stylusSecondaryTriggerMode,
      enableStylusHoverPreview: enableStylusHoverPreview ?? this.enableStylusHoverPreview,
      enablePalmRejection: enablePalmRejection ?? this.enablePalmRejection,
      angleSnapStepDegrees: angleSnapStepDegrees ?? this.angleSnapStepDegrees,
      inkSnapTolerance: (inkSnapTolerance ?? this.inkSnapTolerance).clamp(12.0, 40.0),
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      openAiApiKey: openAiApiKey ?? this.openAiApiKey,
      claudeApiKey: claudeApiKey ?? this.claudeApiKey,
      ollamaEndpointUrl: ollamaEndpointUrl ?? this.ollamaEndpointUrl,
      activeAiModelId: activeAiModelId ?? this.activeAiModelId,
      enableGemini: enableGemini ?? this.enableGemini,
      enableOpenAi: enableOpenAi ?? this.enableOpenAi,
      enableClaude: enableClaude ?? this.enableClaude,
      enableOllama: enableOllama ?? this.enableOllama,
      enableAiSidebar: enableAiSidebar ?? this.enableAiSidebar,
      enableAiSelectionActions: enableAiSelectionActions ?? this.enableAiSelectionActions,
      enableAiInlineCommands: enableAiInlineCommands ?? this.enableAiInlineCommands,
      enableAiSocraticMode: enableAiSocraticMode ?? this.enableAiSocraticMode,
      enableAiMermaidDiagrams: enableAiMermaidDiagrams ?? this.enableAiMermaidDiagrams,
      enableAiHandwritingOcr: enableAiHandwritingOcr ?? this.enableAiHandwritingOcr,
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
      'enableNativeRendering': enableNativeRendering,
      'gridSpacing': gridSpacing,
      'enableMouseGlow': enableMouseGlow,
      'mouseGlowRadius': mouseGlowRadius,
      'rdpSmoothingTolerance': rdpSmoothingTolerance,
      'pressureSensitivity': pressureSensitivity,
      'drawAndHoldDurationMs': drawAndHoldDurationMs,
      'stylusPrimaryBarrelAction': stylusPrimaryBarrelAction.name,
      'stylusPrimaryTriggerMode': stylusPrimaryTriggerMode.name,
      'stylusSecondaryBarrelAction': stylusSecondaryBarrelAction.name,
      'stylusSecondaryTriggerMode': stylusSecondaryTriggerMode.name,
      'enableStylusHoverPreview': enableStylusHoverPreview,
      'enablePalmRejection': enablePalmRejection,
      'angleSnapStepDegrees': angleSnapStepDegrees,
      'inkSnapTolerance': inkSnapTolerance,
      'geminiApiKey': geminiApiKey,
      'openAiApiKey': openAiApiKey,
      'claudeApiKey': claudeApiKey,
      'ollamaEndpointUrl': ollamaEndpointUrl,
      'activeAiModelId': activeAiModelId,
      'enableGemini': enableGemini,
      'enableOpenAi': enableOpenAi,
      'enableClaude': enableClaude,
      'enableOllama': enableOllama,
      'enableAiSidebar': enableAiSidebar,
      'enableAiSelectionActions': enableAiSelectionActions,
      'enableAiInlineCommands': enableAiInlineCommands,
      'enableAiSocraticMode': enableAiSocraticMode,
      'enableAiMermaidDiagrams': enableAiMermaidDiagrams,
      'enableAiHandwritingOcr': enableAiHandwritingOcr,
    };
  }

  factory AppSettingsState.fromJson(Map<String, dynamic> json) {
    final rawThemes = json['customThemes'] as List<dynamic>?;
    final List<ThemeDefinition> parsedThemes = <ThemeDefinition>[];
    if (rawThemes != null) {
      for (final item in rawThemes) {
        if (item is Map) {
          try {
            final map = Map<String, dynamic>.from(item);
            parsedThemes.add(ThemeDefinition.fromJson(map));
          } catch (_) {}
        }
      }
    }

    final primaryActionStr = json['stylusPrimaryBarrelAction'] as String? ?? json['primaryBarrelAction'] as String?;
    final primaryBarrelAction = primaryActionStr == 'selection'
        ? StylusBarrelAction.selectionLasso
        : StylusBarrelAction.values.firstWhere(
            (e) => e.name == primaryActionStr,
            orElse: () => StylusBarrelAction.strokeEraser,
          );

    final primaryTriggerStr = json['stylusPrimaryTriggerMode'] as String? ?? json['stylusTriggerMode'] as String?;
    final primaryTriggerMode = StylusTriggerMode.values.firstWhere(
      (e) => e.name == primaryTriggerStr,
      orElse: () => StylusTriggerMode.hold,
    );

    final secondaryActionStr = json['stylusSecondaryBarrelAction'] as String? ?? json['secondaryBarrelAction'] as String?;
    final secondaryBarrelAction = secondaryActionStr == 'selection'
        ? StylusBarrelAction.selectionLasso
        : StylusBarrelAction.values.firstWhere(
            (e) => e.name == secondaryActionStr,
            orElse: () => StylusBarrelAction.selectionLasso,
          );

    final secondaryTriggerStr = json['stylusSecondaryTriggerMode'] as String? ?? json['secondaryBarrelTriggerMode'] as String?;
    final secondaryTriggerMode = StylusTriggerMode.values.firstWhere(
      (e) => e.name == secondaryTriggerStr,
      orElse: () => StylusTriggerMode.hold,
    );

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
      enableNativeRendering: json['enableNativeRendering'] as bool? ?? true,
      gridSpacing: (json['gridSpacing'] as num?)?.toDouble() ?? 28.0,
      enableMouseGlow: json['enableMouseGlow'] as bool? ?? true,
      mouseGlowRadius: (json['mouseGlowRadius'] as num?)?.toDouble() ?? 120.0,
      rdpSmoothingTolerance: (json['rdpSmoothingTolerance'] as num?)?.toDouble() ?? 0.35,
      pressureSensitivity: (json['pressureSensitivity'] as num?)?.toDouble() ?? 1.0,
      drawAndHoldDurationMs: json['drawAndHoldDurationMs'] as int? ?? 400,
      stylusPrimaryBarrelAction: primaryBarrelAction,
      stylusPrimaryTriggerMode: primaryTriggerMode,
      stylusSecondaryBarrelAction: secondaryBarrelAction,
      stylusSecondaryTriggerMode: secondaryTriggerMode,
      enableStylusHoverPreview: json['enableStylusHoverPreview'] as bool? ?? true,
      enablePalmRejection: json['enablePalmRejection'] as bool? ?? true,
      angleSnapStepDegrees: (json['angleSnapStepDegrees'] as num?)?.toDouble() ?? 15.0,
      inkSnapTolerance: (json['inkSnapTolerance'] as num?)?.toDouble() ?? 24.0,
      geminiApiKey: json['geminiApiKey'] as String? ?? '',
      openAiApiKey: json['openAiApiKey'] as String? ?? '',
      claudeApiKey: json['claudeApiKey'] as String? ?? '',
      ollamaEndpointUrl: json['ollamaEndpointUrl'] as String? ?? '',
      activeAiModelId: json['activeAiModelId'] as String? ?? (json['defaultAiModel'] as String? ?? 'gemini-2.5-flash'),
      enableGemini: json['enableGemini'] as bool? ?? false,
      enableOpenAi: json['enableOpenAi'] as bool? ?? false,
      enableClaude: json['enableClaude'] as bool? ?? false,
      enableOllama: json['enableOllama'] as bool? ?? false,
      enableAiSidebar: json['enableAiSidebar'] as bool? ?? true,
      enableAiSelectionActions: json['enableAiSelectionActions'] as bool? ?? true,
      enableAiInlineCommands: json['enableAiInlineCommands'] as bool? ?? true,
      enableAiSocraticMode: json['enableAiSocraticMode'] as bool? ?? false,
      enableAiMermaidDiagrams: json['enableAiMermaidDiagrams'] as bool? ?? true,
      enableAiHandwritingOcr: json['enableAiHandwritingOcr'] as bool? ?? true,
    );
  }
}
