import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../widgets/settings_models.dart';

/// Serviço Singleton responsável pela persistência Local-First das configurações do conNotes.
class SettingsService {
  static final SettingsService instance = SettingsService._internal();
  SettingsService._internal();

  static const String _settingsFileName = 'settings.json';
  AppSettingsState _settings = const AppSettingsState();
  AppSettingsState get settings => _settings;

  File _getSettingsFile() {
    return File(_settingsFileName);
  }

  /// Carrega as configurações do disco ou retorna os valores padrão
  Future<AppSettingsState> loadSettings() async {
    try {
      final file = _getSettingsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        debugPrint('[SettingsService] Configurações carregadas do disco.');
        _settings = AppSettingsState.fromJson(json);
        return _settings;
      }
    } catch (e) {
      debugPrint('[SettingsService] Erro ao carregar configurações: $e');
    }
    _settings = AppSettingsState.defaults();
    return _settings;
  }

  /// Salva as configurações de forma assíncrona no disco local
  Future<void> saveSettings(AppSettingsState settings) async {
    _settings = settings;
    try {
      final file = _getSettingsFile();
      final content = const JsonEncoder.withIndent('  ').convert(settings.toJson());
      await file.writeAsString(content);
    } catch (e) {
      debugPrint('[SettingsService] Erro ao salvar configurações: $e');
    }
  }
}
