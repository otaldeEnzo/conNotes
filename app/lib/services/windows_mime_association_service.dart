import 'dart:io';
import 'package:flutter/foundation.dart';

/// Serviço que registra a extensão .cncanvas no Windows Registry com Content Type "text/html"
/// garantindo que qualquer navegador (Chrome, Edge, Firefox) reconheça o MIME type imediatamente.
class WindowsMimeAssociationService {
  WindowsMimeAssociationService._();

  static Future<void> registerMimeAssociation() async {
    if (!Platform.isWindows) return;

    try {
      // 1. Registrar "Content Type" (com espaço, padrão exigido pelo Chromium/Windows) no HKCU
      await Process.run('reg', [
        'add',
        r'HKCU\Software\Classes\.cncanvas',
        '/v',
        'Content Type',
        '/t',
        'REG_SZ',
        '/d',
        'text/html',
        '/f',
      ]);

      // 2. Registrar PerceivedType
      await Process.run('reg', [
        'add',
        r'HKCU\Software\Classes\.cncanvas',
        '/v',
        'PerceivedType',
        '/t',
        'REG_SZ',
        '/d',
        'text',
        '/f',
      ]);

      // 3. Registrar também com hífen por redundância
      await Process.run('reg', [
        'add',
        r'HKCU\Software\Classes\.cncanvas',
        '/v',
        'Content-Type',
        '/t',
        'REG_SZ',
        '/d',
        'text/html',
        '/f',
      ]);

      debugPrint('[conNotes] Associação MIME .cncanvas -> text/html atualizada no Windows Registry.');
    } catch (e) {
      debugPrint('[conNotes] Erro ao registrar associação MIME no Windows: $e');
    }
  }
}
