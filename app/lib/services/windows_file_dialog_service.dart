import 'dart:io';
import 'package:file_picker/file_picker.dart';

/// Serviço Especializado em Diálogos Nativos de Arquivos para Windows.
class WindowsFileDialogService {
  WindowsFileDialogService._();

  /// Abre a janela nativa do Windows Explorer para selecionar uma imagem (.png, .jpg, .jpeg, .webp, .bmp)
  static Future<String?> pickImageFile() async {
    // 1. Tentar via FilePickerPlatform primeiro
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp'],
        dialogTitle: 'Selecionar Imagem de Fundo STEM',
      );
      if (result.isNotEmpty && result.first.path != null) {
        return result.first.path!;
      }
    } catch (_) {}

    // 2. Fallback Nativo do Windows via Processo PowerShell Forms
    if (Platform.isWindows) {
      try {
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          "Add-Type -AssemblyName System.Windows.Forms; \$d = New-Object System.Windows.Forms.OpenFileDialog; \$d.Title = 'Selecionar Imagem de Fundo STEM'; \$d.Filter = 'Imagens (*.png;*.jpg;*.jpeg;*.webp;*.bmp)|*.png;*.jpg;*.jpeg;*.webp;*.bmp|Todos (*.*)|*.*'; \$res = \$d.ShowDialog(); if (\$res -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output \$d.FileName }",
        ]);
        final path = (result.stdout as String).trim();
        if (path.isNotEmpty && File(path).existsSync()) {
          return path;
        }
      } catch (_) {}
    }

    return null;
  }
}
