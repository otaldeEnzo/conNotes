import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../widgets/settings_models.dart';

/// Serviço Singleton responsável pela persistência Local-First das configurações do conNotes.
class SettingsService extends ChangeNotifier {
  static final SettingsService instance = SettingsService._internal();
  SettingsService._internal();

  static const String _settingsFileName = 'settings.json';
  AppSettingsState _settings = const AppSettingsState();
  AppSettingsState get settings => _settings;
  AppSettingsState get currentSettings => _settings;

  File _getSettingsFile() {
    try {
      final userProfile = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
      if (userProfile != null && userProfile.isNotEmpty) {
        final sep = Platform.isWindows ? '\\' : '/';
        final dirPath = '$userProfile${sep}Documents${sep}conNotes';
        final dir = Directory(dirPath);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return File('$dirPath$sep$_settingsFileName');
      }
    } catch (_) {}
    return File(_settingsFileName);
  }

  /// Carrega as configurações do disco ou retorna os valores padrão
  Future<AppSettingsState> loadSettings() async {
    try {
      final file = _getSettingsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final json = jsonDecode(content) as Map<String, dynamic>;
          debugPrint('[SettingsService] Configurações carregadas do disco.');
          _settings = AppSettingsState.fromJson(json);
          notifyListeners();
          return _settings;
        }
      }
    } catch (e) {
      debugPrint('[SettingsService] Erro ao carregar configurações: $e');
    }
    _settings = AppSettingsState.defaults();
    notifyListeners();
    return _settings;
  }

  /// Atualiza em memória sem tocar no disco (útil para testes e previews)
  void updateSettingsInMemory(AppSettingsState settings) {
    _settings = settings;
    notifyListeners();
  }

  /// Salva as configurações de forma assíncrona no disco local
  Future<void> saveSettings(AppSettingsState settings) async {
    _settings = settings;
    notifyListeners();
    try {
      final file = _getSettingsFile();
      final content = const JsonEncoder.withIndent('  ').convert(settings.toJson());
      await file.writeAsString(content);
    } catch (e) {
      debugPrint('[SettingsService] Erro ao salvar configurações: $e');
    }
  }
}
