import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Evento de Jank registrado pelo DevHub
class JankRecord {
  final DateTime timestamp;
  final double totalMs;
  final double buildMs;
  final double rasterMs;
  final String primaryBottleneck;
  final String? lastUserAction;
  final int strokeCount;
  final int activeTiles;

  JankRecord({
    required this.timestamp,
    required this.totalMs,
    required this.buildMs,
    required this.rasterMs,
    required this.primaryBottleneck,
    this.lastUserAction,
    required this.strokeCount,
    required this.activeTiles,
  });

  Map<String, dynamic> toJson() => {
    'time': '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}.${(timestamp.millisecond ~/ 100)}',
    'totalMs': totalMs.toStringAsFixed(1),
    'buildMs': buildMs.toStringAsFixed(1),
    'rasterMs': rasterMs.toStringAsFixed(1),
    'bottleneck': primaryBottleneck,
    'action': lastUserAction ?? 'Idle / Canvas Render',
    'strokes': strokeCount,
    'tiles': activeTiles,
  };
}

/// Serviço de Telemetria e Servidor Local do Dev Hub em janela/processo separado
class DevHubServer {
  static final DevHubServer instance = DevHubServer._();
  DevHubServer._();

  HttpServer? _server;
  final List<WebSocket> _clients = [];
  Timer? _telemetryTimer;

  // Métricas em tempo real
  double currentFps = 60.0;
  double frameTimeMs = 16.6;
  double buildTimeMs = 4.0;
  double rasterTimeMs = 6.0;
  int strokeCount = 0;
  int pointCount = 0;
  int activeTilesCount = 0;
  int gpuTexturesCount = 0;
  int memoryRssMb = 0;

  // Histórico e Diagnóstico de Janks
  final List<JankRecord> _jankHistory = [];
  String? lastActionName;
  DateTime? lastActionTime;
  int totalFramesSampled = 0;
  int totalJankFrames = 0;
  double maxFrameTimeRecorded = 0.0;
  DateTime sessionStartTime = DateTime.now();

  // Callbacks para comandos recebidos do Dev Hub
  void Function(int count)? onInjectStrokes;
  void Function()? onForceGc;
  void Function()? onRunBenchmark;

  bool get isRunning => _server != null;

  /// Registra uma ação executada no canvas para correlação com janks
  void logAction(String actionName) {
    lastActionName = actionName;
    lastActionTime = DateTime.now();
  }

  Future<void> start({int port = 9876}) async {
    if (!kDebugMode) return;
    if (_server != null) return;

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      
      _server!.listen((HttpRequest request) {
        if (request.uri.path == '/ws') {
          WebSocketTransformer.upgrade(request).then((WebSocket socket) {
            _clients.add(socket);
            socket.listen(
              (data) => _handleClientMessage(data),
              onDone: () => _clients.remove(socket),
              onError: (_) => _clients.remove(socket),
            );
          });
        } else if (request.uri.path == '/export-report') {
          _serveReportDownload(request);
        } else {
          _serveDashboardHtml(request);
        }
      });

      // Hook no Scheduler do Flutter para calcular FPS e Frame Time com precisão
      SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);

      // Timer de telemetria (30 atualizações por segundo)
      _telemetryTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
        _broadcastTelemetry();
      });
    } catch (e) {
      // Ignorar se a porta já estiver em uso
    }
  }

  void openInBrowser() {
    if (Platform.isWindows) {
      Process.run('cmd', ['/c', 'start', 'http://localhost:9876']);
    } else if (Platform.isMacOS) {
      Process.run('open', ['http://localhost:9876']);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', ['http://localhost:9876']);
    }
  }

  final List<double> _recentFrameTimes = [];
  final List<double> _recentBuildTimes = [];
  final List<double> _recentRasterTimes = [];
  int _framesInLastSecond = 0;
  DateTime _lastFpsCalculation = DateTime.now();

  void _onFrameTimings(List<FrameTiming> timings) {
    if (timings.isEmpty) return;
    
    for (final t in timings) {
      final totalMs = t.totalSpan.inMicroseconds / 1000.0;
      final bMs = t.buildDuration.inMicroseconds / 1000.0;
      final rMs = t.rasterDuration.inMicroseconds / 1000.0;
      
      totalFramesSampled++;
      if (totalMs > maxFrameTimeRecorded) {
        maxFrameTimeRecorded = totalMs;
      }

      _recentFrameTimes.add(totalMs);
      _recentBuildTimes.add(bMs);
      _recentRasterTimes.add(rMs);
      if (_recentFrameTimes.length > 60) {
        _recentFrameTimes.removeAt(0);
        _recentBuildTimes.removeAt(0);
        _recentRasterTimes.removeAt(0);
      }
      _framesInLastSecond++;

      // Detector de Jank: Frame excedeu 20ms (> 50 FPS) ou causou engasgo perceptível
      if (totalMs > 24.0) {
        totalJankFrames++;
        String bottleneck = "Misto (CPU + GPU)";
        if (bMs > rMs * 1.5) {
          bottleneck = "CPU (Dart UI Thread / Geometria / Objetos)";
        } else if (rMs > bMs * 1.5) {
          bottleneck = "GPU (Skia Raster / Tesselação / toImageSync)";
        }

        // Correlacionar com ação recente se ocorreu nos últimos 1.5s
        String? action;
        if (lastActionTime != null && DateTime.now().difference(lastActionTime!).inMilliseconds < 1500) {
          action = lastActionName;
        }

        final jank = JankRecord(
          timestamp: DateTime.now(),
          totalMs: totalMs,
          buildMs: bMs,
          rasterMs: rMs,
          primaryBottleneck: bottleneck,
          lastUserAction: action,
          strokeCount: strokeCount,
          activeTiles: activeTilesCount,
        );

        _jankHistory.insert(0, jank);
        if (_jankHistory.length > 100) {
          _jankHistory.removeLast();
        }
      }
    }

    final now = DateTime.now();
    final elapsed = now.difference(_lastFpsCalculation).inMilliseconds;
    if (elapsed >= 400) {
      currentFps = (_framesInLastSecond * 1000.0 / elapsed).clamp(0.0, 300.0);
      _framesInLastSecond = 0;
      _lastFpsCalculation = now;
      
      if (_recentFrameTimes.isNotEmpty) {
        double sumTotal = 0;
        for (var i = 0; i < _recentFrameTimes.length; i++) {
          sumTotal += _recentFrameTimes[i];
        }
        frameTimeMs = sumTotal / _recentFrameTimes.length;
      }
      if (_recentBuildTimes.isNotEmpty) {
        double sumBuild = 0;
        for (var i = 0; i < _recentBuildTimes.length; i++) {
          sumBuild += _recentBuildTimes[i];
        }
        buildTimeMs = sumBuild / _recentBuildTimes.length;
      }
      if (_recentRasterTimes.isNotEmpty) {
        double sumRaster = 0;
        for (var i = 0; i < _recentRasterTimes.length; i++) {
          sumRaster += _recentRasterTimes[i];
        }
        rasterTimeMs = sumRaster / _recentRasterTimes.length;
      }
    }
  }

  void _broadcastTelemetry() {
    if (_clients.isEmpty) return;

    try {
      memoryRssMb = ProcessInfo.currentRss ~/ (1024 * 1024);
    } catch (_) {}

    // Estimar VRAM com base em 1024x1024 RGBA = 4MB por textura
    final estimatedVramMb = gpuTexturesCount * 4;

    final payload = jsonEncode({
      'fps': currentFps.toStringAsFixed(0),
      'frameTime': frameTimeMs.toStringAsFixed(1),
      'buildTime': buildTimeMs.toStringAsFixed(1),
      'rasterTime': rasterTimeMs.toStringAsFixed(1),
      'strokes': strokeCount,
      'points': pointCount,
      'tiles': activeTilesCount,
      'gpuTextures': gpuTexturesCount,
      'vramMb': estimatedVramMb,
      'memoryMb': memoryRssMb,
      'totalJanks': totalJankFrames,
      'maxFrameTime': maxFrameTimeRecorded.toStringAsFixed(1),
      'jankList': _jankHistory.take(15).map((j) => j.toJson()).toList(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    for (final client in _clients) {
      if (client.readyState == WebSocket.open) {
        client.add(payload);
      }
    }
  }

  void _handleClientMessage(dynamic message) {
    try {
      final data = jsonDecode(message.toString());
      final action = data['action'];
      if (action == 'inject_strokes') {
        final count = (data['count'] as num?)?.toInt() ?? 1000;
        logAction('Injeção de $count traços via DevHub');
        onInjectStrokes?.call(count);
      } else if (action == 'force_gc') {
        logAction('Limpeza de Cache e Forçar GC');
        onForceGc?.call();
      } else if (action == 'run_benchmark') {
        logAction('Executando Benchmark de Fluidez');
        onRunBenchmark?.call();
      } else if (action == 'clear_janks') {
        _jankHistory.clear();
        totalJankFrames = 0;
        maxFrameTimeRecorded = 0.0;
      }
    } catch (e) {
      // ignore
    }
  }

  String generateDiagnosticReportMarkdown() {
    final uptime = DateTime.now().difference(sessionStartTime);
    final uptimeMinutes = uptime.inMinutes;
    final uptimeSeconds = uptime.inSeconds % 60;
    final jankRate = totalFramesSampled > 0 ? (totalJankFrames / totalFramesSampled * 100).toStringAsFixed(2) : "0.0";
    final estimatedVram = gpuTexturesCount * 4;

    final buffer = StringBuffer();
    buffer.writeln('# 📊 Relatório de Diagnóstico de Desempenho — conNotes Engine');
    buffer.writeln('**Data da Extração:** ${DateTime.now().toIso8601String()}');
    buffer.writeln('**Duração da Sessão:** ${uptimeMinutes}m ${uptimeSeconds}s\n');

    buffer.writeln('## ⚡ 1. Resumo Geral de Telemetria');
    buffer.writeln('| Métrica | Valor Atual / Média |');
    buffer.writeln('|---|---|');
    buffer.writeln('| **Taxa de Quadros (FPS)** | `${currentFps.toStringAsFixed(0)} FPS` |');
    buffer.writeln('| **Frame Time Total** | `${frameTimeMs.toStringAsFixed(1)} ms` |');
    buffer.writeln('| **UI Thread (CPU / Dart)** | `${buildTimeMs.toStringAsFixed(1)} ms` |');
    buffer.writeln('| **Raster Thread (GPU / Skia)** | `${rasterTimeMs.toStringAsFixed(1)} ms` |');
    buffer.writeln('| **Pior Frame Registrado (Max Stutter)** | `${maxFrameTimeRecorded.toStringAsFixed(1)} ms` |');
    buffer.writeln('| **Frames com Queda (Janks)** | `$totalJankFrames / $totalFramesSampled ($jankRate%)` |');
    buffer.writeln('| **Uso de Memória RAM (RSS)** | `$memoryRssMb MB` |');
    buffer.writeln('| **Uso Estimado de VRAM (Texturas)** | `$estimatedVram MB ($gpuTexturesCount texturas 1024x1024)` |');
    buffer.writeln('| **Total de Traços / Pontos** | `${strokeCount.toString()} traços / ${pointCount.toString()} pontos` |');
    buffer.writeln('| **Tiles Ativos na Grade** | `$activeTilesCount tiles` |\n');

    buffer.writeln('## 🔍 2. Histórico dos Últimos Micro-Travamentos (Janks Registrados)');
    if (_jankHistory.isEmpty) {
      buffer.writeln('✅ *Nenhum engasgo crítico detectado recentemente! O motor manteve 60+ FPS constante.*');
    } else {
      buffer.writeln('| Hora | Frame Total | CPU (Dart) | GPU (Skia) | Gargalo Principal | Ação do Usuário no Momento | Traços |');
      buffer.writeln('|---|---|---|---|---|---|---|');
      for (final j in _jankHistory.take(25)) {
        final timeStr = '${j.timestamp.hour.toString().padLeft(2, '0')}:${j.timestamp.minute.toString().padLeft(2, '0')}:${j.timestamp.second.toString().padLeft(2, '0')}';
        buffer.writeln('| $timeStr | `${j.totalMs.toStringAsFixed(1)} ms` | `${j.buildMs.toStringAsFixed(1)} ms` | `${j.rasterMs.toStringAsFixed(1)} ms` | ${j.primaryBottleneck} | `${j.lastUserAction ?? "Interação Livre / Render"}` | ${j.strokeCount} |');
      }
    }
    buffer.writeln('');

    buffer.writeln('## 💡 3. Diagnóstico e Recomendações Automáticas');
    if (totalJankFrames == 0) {
      buffer.writeln('- O pipeline está saudável e operando dentro do orçamento de 16.6ms.');
    } else {
      int cpuJanks = 0;
      int gpuJanks = 0;
      for (final j in _jankHistory) {
        if (j.buildMs > j.rasterMs) cpuJanks++;
        else gpuJanks++;
      }
      if (cpuJanks > gpuJanks) {
        buffer.writeln('- ⚠️ **Predomínio de Gargalo na CPU (Dart UI Thread):** A maior parte dos engasgos ocorreu durante manipulação de listas ou estruturas de dados na Thread Principal. Recomenda-se manter inserções e mutações divididas em lotes assíncronos (`addPostFrameCallback`).');
      } else {
        buffer.writeln('- ⚠️ **Predomínio de Gargalo na GPU/Raster (Skia Engine):** A placa de vídeo demorou para desenhar os caminhos na tela. Recomenda-se verificar o limite de tiles assados por frame (`_maxBakesPerFrame`) ou ativar o bypass com `drawRawPoints` para traços densos.');
      }
    }

    return buffer.toString();
  }

  void _serveReportDownload(HttpRequest request) {
    final report = generateDiagnosticReportMarkdown();
    request.response.headers.contentType = ContentType.text;
    request.response.headers.add('Content-Disposition', 'attachment; filename="conNotes_Performance_Report.md"');
    request.response.write(report);
    request.response.close();
  }

  void _serveDashboardHtml(HttpRequest request) {
    request.response.headers.contentType = ContentType.html;
    request.response.write('''
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <title>conNotes Engine Dev Hub & Profiler</title>
  <style>
    :root {
      --bg: #090B10;
      --card-bg: #121622;
      --card-border: #1E2638;
      --text: #F1F5F9;
      --text-dim: #94A3B8;
      --cyan: #00E1FF;
      --purple: #A855F7;
      --green: #10B981;
      --yellow: #F59E0B;
      --red: #EF4444;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, monospace;
      background: var(--bg);
      color: var(--text);
      padding: 24px;
      line-height: 1.5;
    }
    .header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding-bottom: 20px;
      border-bottom: 1px solid var(--card-border);
      margin-bottom: 24px;
    }
    .logo {
      font-size: 20px;
      font-weight: 700;
      color: var(--cyan);
      letter-spacing: 1px;
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .header-actions {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .badge {
      background: rgba(0, 225, 255, 0.1);
      color: var(--cyan);
      border: 1px solid var(--cyan);
      padding: 4px 12px;
      border-radius: 20px;
      font-size: 12px;
      font-weight: 600;
    }
    .btn-export {
      background: linear-gradient(135deg, #00E1FF, #A855F7);
      color: #000;
      border: none;
      font-weight: 700;
      padding: 8px 16px;
      border-radius: 8px;
      cursor: pointer;
      font-size: 13px;
      transition: all 0.2s;
    }
    .btn-export:hover {
      opacity: 0.9;
      transform: translateY(-1px);
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 16px;
      margin-bottom: 24px;
    }
    .card {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 12px;
      padding: 16px 20px;
    }
    .card-title {
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 1px;
      color: var(--text-dim);
      margin-bottom: 6px;
    }
    .card-value {
      font-size: 28px;
      font-weight: 700;
      color: var(--text);
    }
    .card-sub {
      font-size: 12px;
      color: var(--text-dim);
      margin-top: 4px;
    }
    .card-value.cyan { color: var(--cyan); }
    .card-value.purple { color: var(--purple); }
    .card-value.green { color: var(--green); }
    .card-value.yellow { color: var(--yellow); }
    .card-value.red { color: var(--red); }
    
    .chart-container {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 12px;
      padding: 20px;
      margin-bottom: 24px;
    }
    .chart-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 12px;
    }
    .chart-legend {
      display: flex;
      gap: 16px;
      font-size: 12px;
    }
    .legend-item {
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .legend-dot {
      width: 10px;
      height: 10px;
      border-radius: 50%;
    }
    canvas {
      width: 100%;
      height: 180px;
      display: block;
    }
    .actions {
      display: flex;
      gap: 12px;
      flex-wrap: wrap;
    }
    button {
      background: #1E293B;
      color: #FFF;
      border: 1px solid var(--card-border);
      padding: 10px 16px;
      border-radius: 8px;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s;
    }
    button:hover {
      background: var(--cyan);
      color: #000;
      border-color: var(--cyan);
    }
    button.danger:hover {
      background: var(--red);
      color: #FFF;
      border-color: var(--red);
    }
    .table-container {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 12px;
      padding: 20px;
      margin-bottom: 24px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 12px;
      text-align: left;
      margin-top: 12px;
    }
    th {
      color: var(--text-dim);
      padding: 8px 12px;
      border-bottom: 1px solid var(--card-border);
      text-transform: uppercase;
      font-weight: 600;
    }
    td {
      padding: 10px 12px;
      border-bottom: 1px solid rgba(30, 38, 56, 0.5);
    }
    tr:hover {
      background: rgba(255, 255, 255, 0.02);
    }
    .tag {
      padding: 2px 8px;
      border-radius: 4px;
      font-size: 11px;
      font-weight: 600;
    }
    .tag-cpu { background: rgba(0, 225, 255, 0.15); color: var(--cyan); }
    .tag-gpu { background: rgba(168, 85, 247, 0.15); color: var(--purple); }
    .tag-mixed { background: rgba(245, 158, 11, 0.15); color: var(--yellow); }
  </style>
</head>
<body>
  <div class="header">
    <div class="logo">⚡ conNotes Telemetry & Performance Profiler</div>
    <div class="header-actions">
      <button class="btn-export" onclick="exportReport()">📄 Exportar Relatório de Diagnóstico (.md)</button>
      <button onclick="copyReportToClipboard()">📋 Copiar Relatório</button>
      <div class="badge" id="statusBadge">Conectando...</div>
    </div>
  </div>

  <div class="grid">
    <div class="card">
      <div class="card-title">Taxa de Quadros (FPS)</div>
      <div class="card-value cyan" id="fpsVal">--</div>
      <div class="card-sub" id="fpsSub">Meta: 60 - 144 FPS</div>
    </div>
    <div class="card">
      <div class="card-title">Frame Time Total</div>
      <div class="card-value green" id="frameTimeVal">-- ms</div>
      <div class="card-sub" id="breakdownSub">CPU: -- ms | GPU: -- ms</div>
    </div>
    <div class="card">
      <div class="card-title">Engasgos (Janks Registrados)</div>
      <div class="card-value yellow" id="janksVal">0</div>
      <div class="card-sub" id="maxFrameSub">Pior frame: 0.0 ms</div>
    </div>
    <div class="card">
      <div class="card-title">Memória RAM / VRAM</div>
      <div class="card-value purple" id="memoryVal">-- MB</div>
      <div class="card-sub" id="vramSub">VRAM Estimada: 0 MB</div>
    </div>
    <div class="card">
      <div class="card-title">Total de Traços / Pontos</div>
      <div class="card-value" id="strokesVal">0</div>
      <div class="card-sub" id="pointsVal">0 pontos</div>
    </div>
    <div class="card">
      <div class="card-title">Sistema de Tiles (Skia)</div>
      <div class="card-value cyan" id="tilesVal">0</div>
      <div class="card-sub" id="texturesVal">0 texturas assadas</div>
    </div>
  </div>

  <div class="chart-container">
    <div class="chart-header">
      <div class="card-title">Pipeline em Tempo Real: CPU (Dart UI Thread) vs GPU (Skia Raster Thread)</div>
      <div class="chart-legend">
        <div class="legend-item"><div class="legend-dot" style="background: var(--cyan);"></div> CPU / Dart Build</div>
        <div class="legend-item"><div class="legend-dot" style="background: var(--purple);"></div> GPU / Skia Raster</div>
        <div class="legend-item"><div class="legend-dot" style="background: var(--green);"></div> Frame Total</div>
      </div>
    </div>
    <canvas id="fpsChart"></canvas>
  </div>

  <div class="chart-container">
    <div class="card-title" style="margin-bottom: 16px;">Testes de Carga, Estresse & Diagnóstico</div>
    <div class="actions">
      <button onclick="injectStrokes(1000)">+ Injetar 1.000 Traços</button>
      <button onclick="injectStrokes(5000)">+ Injetar 5.000 Traços</button>
      <button onclick="injectStrokes(10000)">⚡ Injetar 10.000 Traços (Stress)</button>
      <button onclick="injectStrokes(50000)">🔥 Injetar 50.000 Traços (Extremo)</button>
      <button class="danger" onclick="forceGc()">🧹 Limpar Cache & Forçar GC</button>
      <button onclick="clearJanks()">🔄 Limpar Histórico de Janks</button>
    </div>
  </div>

  <div class="table-container">
    <div class="chart-header">
      <div class="card-title">Histórico de Micro-Travamentos e Diagnóstico da Causa Raiz</div>
      <div style="font-size: 11px; color: var(--text-dim);">Gravando frames acima de 24ms</div>
    </div>
    <table>
      <thead>
        <tr>
          <th>Horário</th>
          <th>Duração Total</th>
          <th>CPU (Dart)</th>
          <th>GPU (Skia)</th>
          <th>Gargalo Identificado</th>
          <th>Ação do Usuário no Momento</th>
          <th>Traços na Tela</th>
        </tr>
      </thead>
      <tbody id="jankTableBody">
        <tr>
          <td colspan="7" style="text-align: center; color: var(--text-dim); padding: 20px;">Nenhum engasgo registrado até o momento.</td>
        </tr>
      </tbody>
    </table>
  </div>

  <script>
    let ws;
    const historyTotal = [];
    const historyBuild = [];
    const historyRaster = [];
    const maxHistory = 90;
    const canvas = document.getElementById('fpsChart');
    const ctx = canvas.getContext('2d');

    function resizeCanvas() {
      canvas.width = canvas.parentElement.clientWidth - 40;
      canvas.height = 180;
    }
    window.addEventListener('resize', resizeCanvas);
    resizeCanvas();

    function connect() {
      ws = new WebSocket('ws://' + window.location.host + '/ws');
      ws.onopen = () => {
        document.getElementById('statusBadge').innerText = 'CONECTADO AO VIVO';
        document.getElementById('statusBadge').style.borderColor = 'var(--green)';
        document.getElementById('statusBadge').style.color = 'var(--green)';
      };
      ws.onclose = () => {
        document.getElementById('statusBadge').innerText = 'DESCONECTADO';
        document.getElementById('statusBadge').style.borderColor = 'var(--red)';
        document.getElementById('statusBadge').style.color = 'var(--red)';
        setTimeout(connect, 1000);
      };
      ws.onmessage = (e) => {
        const data = JSON.parse(e.data);
        document.getElementById('fpsVal').innerText = data.fps;
        document.getElementById('frameTimeVal').innerText = data.frameTime + ' ms';
        document.getElementById('breakdownSub').innerText = 'CPU: ' + data.buildTime + ' ms | GPU: ' + data.rasterTime + ' ms';
        document.getElementById('janksVal').innerText = data.totalJanks;
        document.getElementById('maxFrameSub').innerText = 'Pior frame: ' + data.maxFrameTime + ' ms';
        document.getElementById('memoryVal').innerText = data.memoryMb + ' MB';
        document.getElementById('vramSub').innerText = 'VRAM Estimada: ' + data.vramMb + ' MB';
        document.getElementById('strokesVal').innerText = Number(data.strokes).toLocaleString();
        document.getElementById('pointsVal').innerText = Number(data.points).toLocaleString() + ' pontos';
        document.getElementById('tilesVal').innerText = data.tiles + ' tiles';
        document.getElementById('texturesVal').innerText = data.gpuTextures + ' texturas em VRAM';

        historyTotal.push(parseFloat(data.frameTime));
        historyBuild.push(parseFloat(data.buildTime));
        historyRaster.push(parseFloat(data.rasterTime));
        if (historyTotal.length > maxHistory) {
          historyTotal.shift();
          historyBuild.shift();
          historyRaster.shift();
        }
        drawChart();
        updateJankTable(data.jankList || []);
      };
    }

    function updateJankTable(janks) {
      const tbody = document.getElementById('jankTableBody');
      if (!janks || janks.length === 0) {
        tbody.innerHTML = '<tr><td colspan="7" style="text-align: center; color: var(--text-dim); padding: 20px;">Nenhum engasgo registrado até o momento. Fluidez perfeita.</td></tr>';
        return;
      }

      let html = '';
      for (const j of janks) {
        let tagClass = 'tag-mixed';
        if (j.bottleneck.includes('CPU')) tagClass = 'tag-cpu';
        if (j.bottleneck.includes('GPU')) tagClass = 'tag-gpu';

        html += `
          <tr>
            <td>\${j.time}</td>
            <td style="font-weight: 700; color: var(--yellow);">\${j.totalMs} ms</td>
            <td style="color: var(--cyan);">\${j.buildMs} ms</td>
            <td style="color: var(--purple);">\${j.rasterMs} ms</td>
            <td><span class="tag \${tagClass}">\${j.bottleneck}</span></td>
            <td>\${j.action}</td>
            <td>\${Number(j.strokes).toLocaleString()}</td>
          </tr>
        `;
      }
      tbody.innerHTML = html;
    }

    function drawChart() {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      if (historyTotal.length < 2) return;

      const maxVal = 40;
      const h144 = canvas.height - (6.9 / maxVal) * canvas.height;
      const h60 = canvas.height - (16.6 / maxVal) * canvas.height;
      const h30 = canvas.height - (33.3 / maxVal) * canvas.height;

      // Linhas de referência
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.08)';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(0, h144); ctx.lineTo(canvas.width, h144);
      ctx.moveTo(0, h60); ctx.lineTo(canvas.width, h60);
      ctx.moveTo(0, h30); ctx.lineTo(canvas.width, h30);
      ctx.stroke();

      ctx.fillStyle = '#64748B';
      ctx.font = '10px monospace';
      ctx.fillText('144 FPS (6.9ms)', 10, h144 - 4);
      ctx.fillText('60 FPS (16.6ms)', 10, h60 - 4);
      ctx.fillText('30 FPS (33.3ms)', 10, h30 - 4);

      const step = canvas.width / (maxHistory - 1);

      function plotLine(arr, color, width) {
        ctx.strokeStyle = color;
        ctx.lineWidth = width;
        ctx.beginPath();
        for (let i = 0; i < arr.length; i++) {
          const val = Math.min(arr[i], maxVal);
          const y = canvas.height - (val / maxVal) * canvas.height;
          const x = i * step;
          if (i === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        }
        ctx.stroke();
      }

      plotLine(historyBuild, '#00E1FF', 1.5);
      plotLine(historyRaster, '#A855F7', 1.5);
      plotLine(historyTotal, '#10B981', 2.0);
    }

    function injectStrokes(count) {
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ action: 'inject_strokes', count: count }));
      }
    }

    function forceGc() {
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ action: 'force_gc' }));
      }
    }

    function clearJanks() {
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ action: 'clear_janks' }));
      }
    }

    function exportReport() {
      window.open('/export-report', '_blank');
    }

    async function copyReportToClipboard() {
      try {
        const res = await fetch('/export-report');
        const text = await res.text();
        await navigator.clipboard.writeText(text);
        alert('✅ Relatório de Diagnóstico copiado para a Área de Transferência com sucesso!');
      } catch (err) {
        alert('Erro ao copiar relatório: ' + err);
      }
    }

    connect();
  </script>
</body>
</html>
''');
    request.response.close();
  }
}
