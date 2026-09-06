import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Cliente leve para comunicação com o Dart VM Service via JSON-RPC.
/// Permite acionar o Hot Reload e Hot Restart reais registrados pelo daemon do `flutter_tools`,
/// compilando alterações de código em disco idêntico ao comando de terminal.
class VmServiceClient {
  static final VmServiceClient instance = VmServiceClient._internal();
  VmServiceClient._internal();

  WebSocket? _webSocket;
  int _requestId = 1;
  final Map<int, Completer<Map<String, dynamic>>> _pendingRequests = {};
  bool _isConnecting = false;

  /// Conecta ou reutiliza o WebSocket com a URI informada pelo `developer.Service.getInfo()`.
  Future<WebSocket?> _getConnectedSocket() async {
    if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
      return _webSocket;
    }

    if (!kDebugMode) return null;
    if (_isConnecting) {
      // Aguarda conexão em andamento
      while (_isConnecting) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
        return _webSocket;
      }
    }

    _isConnecting = true;
    try {
      final info = await developer.Service.getInfo();
      final serverUri = info.serverUri;
      if (serverUri == null) {
        _isConnecting = false;
        return null;
      }

      final wsScheme = serverUri.scheme == 'https' ? 'wss' : 'ws';
      final pathWithWs = serverUri.path.endsWith('/') ? '${serverUri.path}ws' : '${serverUri.path}/ws';
      final wsUri = serverUri.replace(scheme: wsScheme, path: pathWithWs);

      final socket = await WebSocket.connect(wsUri.toString())
          .timeout(const Duration(seconds: 2));

      _webSocket = socket;
      socket.listen(
        (data) {
          try {
            if (data is String) {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final id = json['id'] as int?;
              if (id != null && _pendingRequests.containsKey(id)) {
                _pendingRequests.remove(id)!.complete(json);
              }
            }
          } catch (_) {}
        },
        onError: (_) {
          _webSocket = null;
        },
        onDone: () {
          _webSocket = null;
        },
      );
      return _webSocket;
    } catch (e) {
      debugPrint('[VmServiceClient] Não foi possível conectar ao VM Service: $e');
      _webSocket = null;
      return null;
    } finally {
      _isConnecting = false;
    }
  }

  /// Dispara uma chamada JSON-RPC ao VM Service
  Future<Map<String, dynamic>?> _callMethod(String method, [Map<String, dynamic>? params]) async {
    try {
      final socket = await _getConnectedSocket();
      if (socket == null) return null;

      final id = _requestId++;
      final payload = {
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        if (params != null) 'params': params,
      };

      final completer = Completer<Map<String, dynamic>>();
      _pendingRequests[id] = completer;

      socket.add(jsonEncode(payload));

      return await completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
        _pendingRequests.remove(id);
        return {'error': 'Timeout aguardando resposta do VM Service'};
      });
    } catch (e) {
      debugPrint('[VmServiceClient] Erro ao chamar RPC $method: $e');
      return null;
    }
  }

  /// Executa o Hot Reload real, recompilando os arquivos Dart alterados em disco.
  Future<bool> hotReload() async {
    debugPrint('[VmServiceClient] Disparando Hot Reload real via VM Service...');
    final response = await _callMethod('hotReload');
    if (response != null && response['error'] == null) {
      debugPrint('[VmServiceClient] Hot Reload concluído com sucesso!');
      return true;
    }

    // Fallback: se o VM service não responder, faz reassemble local
    debugPrint('[VmServiceClient] Fallback para reassembleApplication local.');
    WidgetsBinding.instance.reassembleApplication();
    return false;
  }

  /// Executa o Hot Restart real, reinicializando todo o runtime e estado da VM Dart.
  Future<bool> hotRestart() async {
    debugPrint('[VmServiceClient] Disparando Hot Restart real via VM Service...');
    final response = await _callMethod('hotRestart');
    if (response != null && response['error'] == null) {
      debugPrint('[VmServiceClient] Hot Restart concluído com sucesso!');
      return true;
    }

    debugPrint('[VmServiceClient] Fallback: reassembleApplication.');
    WidgetsBinding.instance.reassembleApplication();
    return false;
  }
}
