import 'package:flutter/material.dart';
import '../models/theme_models.dart';
import '../services/settings_service.dart';
import 'moscaro_v2_tokens.dart';

/// Controlador Central de Temas e Customização Visual do conNotes (Moscaro v2 Pro Max).
class MoscaroThemeController extends ChangeNotifier {
  MoscaroThemeController._internal();
  static final MoscaroThemeController instance = MoscaroThemeController._internal();

  AppThemePreset _activePreset = AppThemePreset.moscaroCyan;
  String _activeThemeId = 'moscaroCyan';
  CanvasBackgroundMode _backgroundMode = CanvasBackgroundMode.preset;
  Color _customSolidColor = const Color(0xFF070B14);
  Color _customGradientStart = const Color(0xFF0C1B2E);
  Color _customGradientEnd = const Color(0xFF060B12);
  CanvasTextureType _textureType = CanvasTextureType.none;
  String? _customImagePath;
  double _customImageOpacity = 0.5;

  List<ThemeDefinition> _customThemes = [];
  ThemeDefinition _currentTheme = ThemeDefinition.moscaroCyan;

  AppThemePreset get activePreset => _activePreset;
  String get activeThemeId => _activeThemeId;
  CanvasBackgroundMode get backgroundMode => _backgroundMode;
  Color get customSolidColor => _customSolidColor;
  Color get customGradientStart => _customGradientStart;
  Color get customGradientEnd => _customGradientEnd;
  CanvasTextureType get textureType => _textureType;
  String? get customImagePath => _customImagePath;
  double get customImageOpacity => _customImageOpacity;
  List<ThemeDefinition> get customThemes => List.unmodifiable(_customThemes);
  ThemeDefinition get currentTheme => _currentTheme;

  void _persistThemesToSettings() {
    try {
      final current = SettingsService.instance.currentSettings;
      final updated = current.copyWith(
        activeThemeId: _activeThemeId,
        customBgMode: _backgroundMode.id,
        customBgColorHex: '#${_customSolidColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
        customGradStartHex: '#${_customGradientStart.toARGB32().toRadixString(16).padLeft(8, '0')}',
        customGradEndHex: '#${_customGradientEnd.toARGB32().toRadixString(16).padLeft(8, '0')}',
        customTextureType: _textureType.id,
        customImagePath: _customImagePath,
        customImageOpacity: _customImageOpacity,
        customThemes: List<ThemeDefinition>.from(_customThemes),
      );
      SettingsService.instance.saveSettings(updated);
    } catch (_) {}
  }

  /// Inicializa o controlador com as configurações salvas
  void initialize({
    required String themeId,
    required String bgModeId,
    String? customSolidHex,
    String? customGradStartHex,
    String? customGradEndHex,
    String? textureId,
    String? imagePath,
    double? imageOpacity,
    List<ThemeDefinition>? customThemes,
  }) {
    if (customThemes != null && customThemes.isNotEmpty) {
      _customThemes = List<ThemeDefinition>.from(customThemes);
    }
    _activeThemeId = themeId;
    if (themeId.startsWith('custom') || _customThemes.any((t) => t.id == themeId)) {
      _activePreset = AppThemePreset.custom;
    } else {
      _activePreset = AppThemePreset.fromId(themeId);
    }
    _backgroundMode = CanvasBackgroundMode.fromId(bgModeId);
    if (customSolidHex != null && customSolidHex.isNotEmpty) {
      _customSolidColor = _hexToColor(customSolidHex) ?? _customSolidColor;
    }
    if (customGradStartHex != null && customGradStartHex.isNotEmpty) {
      _customGradientStart = _hexToColor(customGradStartHex) ?? _customGradientStart;
    }
    if (customGradEndHex != null && customGradEndHex.isNotEmpty) {
      _customGradientEnd = _hexToColor(customGradEndHex) ?? _customGradientEnd;
    }
    if (textureId != null) {
      _textureType = CanvasTextureType.fromId(textureId);
    }
    _customImagePath = imagePath;
    if (imageOpacity != null) {
      _customImageOpacity = imageOpacity.clamp(0.05, 1.0);
    }

    _updateCurrentThemeDefinition();
  }

  /// Seleciona um preset oficial
  void selectPreset(AppThemePreset preset) {
    _activePreset = preset;
    _activeThemeId = preset.id;
    _backgroundMode = CanvasBackgroundMode.preset;
    _updateCurrentThemeDefinition();
    notifyListeners();
    _persistThemesToSettings();
  }

  /// Seleciona um tema personalizado
  void selectCustomTheme(ThemeDefinition theme) {
    _activePreset = AppThemePreset.custom;
    _activeThemeId = theme.id;
    _currentTheme = theme;
    _backgroundMode = theme.bgMode;
    _textureType = theme.textureType;
    _customImagePath = theme.bgImagePath;
    _customImageOpacity = theme.bgImageOpacity;
    if (theme.gradientColors != null && theme.gradientColors!.length >= 2) {
      _customGradientStart = theme.gradientColors!.first;
      _customGradientEnd = theme.gradientColors!.last;
    }
    MoscaroTokens.applyTheme(_currentTheme);
    notifyListeners();
    _persistThemesToSettings();
  }

  /// Adiciona um novo tema personalizado
  void addCustomTheme(ThemeDefinition theme) {
    _customThemes.add(theme);
    selectCustomTheme(theme);
    _persistThemesToSettings();
  }

  /// Atualiza um tema personalizado existente
  void updateCustomTheme(ThemeDefinition updated) {
    final index = _customThemes.indexWhere((t) => t.id == updated.id);
    if (index != -1) {
      _customThemes[index] = updated;
      if (_activeThemeId == updated.id) {
        selectCustomTheme(updated);
      } else {
        notifyListeners();
      }
      _persistThemesToSettings();
    }
  }

  /// Exclui um tema personalizado
  void deleteCustomTheme(String customId) {
    _customThemes.removeWhere((t) => t.id == customId);
    if (_activeThemeId == customId) {
      selectPreset(AppThemePreset.moscaroCyan);
    } else {
      notifyListeners();
    }
    _persistThemesToSettings();
  }

  /// Duplica um tema existente (oficial ou customizado)
  ThemeDefinition duplicateTheme(ThemeDefinition source) {
    final duplicated = source.copyWith(
      preset: AppThemePreset.custom,
      customId: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      isCustom: true,
      name: '${source.name} (Cópia)',
    );
    addCustomTheme(duplicated);
    return duplicated;
  }

  /// Define o modo de fundo customizado
  void setBackgroundMode(CanvasBackgroundMode mode) {
    _backgroundMode = mode;
    _updateCurrentThemeDefinition();
    notifyListeners();
    _persistThemesToSettings();
  }

  /// Define a cor sólida customizada
  void setCustomSolidColor(Color color) {
    _customSolidColor = color;
    _backgroundMode = CanvasBackgroundMode.solidColor;
    _updateCurrentThemeDefinition();
    notifyListeners();
    _persistThemesToSettings();
  }

  /// Define o gradiente customizado
  void setCustomGradient(Color start, Color end) {
    _customGradientStart = start;
    _customGradientEnd = end;
    _backgroundMode = CanvasBackgroundMode.gradient;
    _updateCurrentThemeDefinition();
    notifyListeners();
    _persistThemesToSettings();
  }

  /// Define a textura STEM
  void setTextureType(CanvasTextureType type) {
    _textureType = type;
    notifyListeners();
    _persistThemesToSettings();
  }

  /// Define a imagem customizada de fundo
  void setCustomImage(String? path, {double opacity = 0.5}) {
    _customImagePath = path;
    _customImageOpacity = opacity;
    _backgroundMode = path != null ? CanvasBackgroundMode.customImage : CanvasBackgroundMode.preset;
    _updateCurrentThemeDefinition();
    notifyListeners();
    _persistThemesToSettings();
  }

  ThemeDefinition? _themeBeforePreview;

  /// Aplica temporariamente um tema para Live Preview em tempo real
  void previewTheme(ThemeDefinition tempTheme) {
    _themeBeforePreview ??= _currentTheme;
    _currentTheme = tempTheme;
    _backgroundMode = tempTheme.bgMode;
    _textureType = tempTheme.textureType;
    _customImagePath = tempTheme.bgImagePath;
    _customImageOpacity = tempTheme.bgImageOpacity;
    MoscaroTokens.applyTheme(_currentTheme);
    notifyListeners();
  }

  /// Restaura o tema ativo original caso o usuário cancele o modal de edição
  void restoreActiveTheme() {
    if (_themeBeforePreview != null) {
      _currentTheme = _themeBeforePreview!;
      _backgroundMode = _currentTheme.bgMode;
      _textureType = _currentTheme.textureType;
      _customImagePath = _currentTheme.bgImagePath;
      _customImageOpacity = _currentTheme.bgImageOpacity;
      MoscaroTokens.applyTheme(_currentTheme);
      _themeBeforePreview = null;
      notifyListeners();
    }
  }

  /// Confirma e descarta o snapshot de restauração
  void commitPreview() {
    _themeBeforePreview = null;
  }

  void _updateCurrentThemeDefinition() {
    // 1. Se estiver com um tema personalizado ativo
    if (_activePreset == AppThemePreset.custom) {
      final foundCustom = _customThemes.firstWhere(
        (t) => t.id == _activeThemeId,
        orElse: () => _currentTheme.isCustom ? _currentTheme : (_customThemes.isNotEmpty ? _customThemes.last : ThemeDefinition.moscaroCyan),
      );
      _currentTheme = foundCustom;
      _backgroundMode = foundCustom.bgMode;
      _textureType = foundCustom.textureType;
      _customImagePath = foundCustom.bgImagePath;
      _customImageOpacity = foundCustom.bgImageOpacity;
      MoscaroTokens.applyTheme(_currentTheme);
      return;
    }

    // 2. Modos manuais sobre presets oficiais
    if (_backgroundMode == CanvasBackgroundMode.solidColor) {
      final base = ThemeDefinition.getByPreset(_activePreset);
      _currentTheme = base.copyWith(
        preset: AppThemePreset.custom,
        bgMode: CanvasBackgroundMode.solidColor,
        name: 'Personalizado (Sólido)',
        backgroundDeep: _customSolidColor,
        backgroundSurface: _customSolidColor,
        glassColor: _customSolidColor.withValues(alpha: 0.15),
      );
    } else if (_backgroundMode == CanvasBackgroundMode.gradient) {
      final base = ThemeDefinition.getByPreset(_activePreset);
      final blended = Color.lerp(_customGradientStart, _customGradientEnd, 0.5) ?? _customGradientStart;
      _currentTheme = base.copyWith(
        preset: AppThemePreset.custom,
        bgMode: CanvasBackgroundMode.gradient,
        name: 'Personalizado (Gradiente)',
        backgroundDeep: _customGradientStart,
        backgroundSurface: _customGradientEnd,
        gradientColors: [_customGradientStart, _customGradientEnd],
        glassColor: blended.withValues(alpha: 0.15),
      );
    } else {
      _currentTheme = ThemeDefinition.getByPreset(_activePreset);
    }

    MoscaroTokens.applyTheme(_currentTheme);
  }

  static Color? _hexToColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '').replaceAll('0x', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      } else if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return null;
  }
}
