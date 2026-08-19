import 'dart:convert';
import 'dart:io';
import '../widgets/note_models.dart';
import '../widgets/ink_models.dart';

/// Motor Especializado no Formato Autônomo e Híbrido .cncanvas (conNotes Infinite Canvas)
class CncanvasFileService {
  CncanvasFileService._();

  /// Salva um NoteDocument no disco no formato híbrido .cncanvas com visualizador Web Reader embutido
  static Future<void> saveToCnCanvasFile(NoteDocument doc, String targetPath) async {
    final file = File(targetPath);
    final parentDir = file.parent;
    if (!parentDir.existsSync()) {
      parentDir.createSync(recursive: true);
    }

    final jsonMap = doc.toCnCanvasMap();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(jsonMap);
    final htmlContent = _generateStandaloneHtmlContent(doc, jsonStr);

    await file.writeAsString(htmlContent, flush: true);
    doc.filePath = targetPath;
  }

  /// Carrega um NoteDocument a partir de um arquivo .cncanvas do disco
  static Future<NoteDocument?> loadFromCnCanvasFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    final content = await file.readAsString();
    Map<String, dynamic>? jsonMap;

    // 1. Extração robusta do bloco <script id="connotes-data" type="application/json">
    const startTag = '<script id="connotes-data" type="application/json">';
    const endTag = '</script>';
    final startIndex = content.indexOf(startTag);
    if (startIndex != -1) {
      final jsonStart = startIndex + startTag.length;
      final endIndex = content.indexOf(endTag, jsonStart);
      if (endIndex != -1) {
        try {
          final jsonString = content.substring(jsonStart, endIndex).trim();
          jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
        } catch (_) {}
      }
    }

    // 2. Fallback caso o arquivo seja JSON puro
    if (jsonMap == null) {
      try {
        jsonMap = jsonDecode(content.trim()) as Map<String, dynamic>;
      } catch (_) {}
    }

    if (jsonMap == null) return null;

    final doc = NoteDocument.fromCnCanvasMap(jsonMap, filePath: filePath);
    return doc;
  }

  /// Exporta uma cópia estrita .html se o usuário desejar enviar para terceiros
  static Future<void> exportToHtml(NoteDocument doc, String targetPath) async {
    await saveToCnCanvasFile(doc, targetPath);
  }

  /// Constrói a casca HTML5 autônoma com visualizador Moscaro v2 e SVG interativo (< 10 KB)
  static String _generateStandaloneHtmlContent(NoteDocument doc, String embeddedJson) {
    final titleEscaped = const HtmlEscape().convert(doc.title);
    final strokesSvg = _generateSvgPaths(doc.strokes);

    return '''<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes"/>
  <meta name="connotes-doc-type" content="canvas"/>
  <meta name="connotes-schema-version" content="1"/>
  <meta name="generator" content="conNotes Desktop v1.0"/>
  <title>conNotes - $titleEscaped</title>
  <style>
    :root {
      --bg-deep: #07090e;
      --bg-surface: #0e121a;
      --accent-cyan: #00e1ff;
      --glass-bg: rgba(14, 18, 26, 0.85);
      --glass-border: rgba(0, 225, 255, 0.25);
    }
    * { box-sizing: border-box; margin: 0; padding: 0; user-select: none; }
    body {
      background: var(--bg-deep);
      color: #ffffff;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      overflow: hidden;
      width: 100vw;
      height: 100vh;
    }
    #canvas-container {
      width: 100vw;
      height: 100vh;
      cursor: grab;
      position: absolute;
      top: 0;
      left: 0;
      background: radial-gradient(circle at center, #0f1726 0%, #06080d 100%);
    }
    #canvas-container:active { cursor: grabbing; }
    #svg-stage {
      width: 100%;
      height: 100%;
      position: absolute;
      top: 0;
      left: 0;
      transform-origin: 0 0;
    }
    .hud-header {
      position: fixed;
      top: 20px;
      left: 50%;
      transform: translateX(-50%);
      background: var(--glass-bg);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      border: 1px solid var(--glass-border);
      border-radius: 30px;
      padding: 8px 20px;
      display: flex;
      align-items: center;
      gap: 16px;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.5), 0 0 15px rgba(0, 225, 255, 0.15);
      z-index: 100;
    }
    .hud-title {
      font-size: 13px;
      font-weight: 600;
      color: #fff;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .badge-mode {
      background: rgba(0, 225, 255, 0.15);
      color: var(--accent-cyan);
      font-size: 10px;
      font-weight: bold;
      padding: 2px 8px;
      border-radius: 12px;
      border: 1px solid rgba(0, 225, 255, 0.3);
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .hud-btn {
      background: rgba(255, 255, 255, 0.08);
      border: 1px solid rgba(255, 255, 255, 0.15);
      color: #fff;
      border-radius: 20px;
      padding: 5px 12px;
      font-size: 11px;
      font-weight: bold;
      cursor: pointer;
      transition: all 0.2s;
    }
    .hud-btn:hover {
      background: rgba(0, 225, 255, 0.25);
      border-color: var(--accent-cyan);
      box-shadow: 0 0 10px rgba(0, 225, 255, 0.3);
    }
    .hud-zoom {
      font-size: 11px;
      font-family: monospace;
      color: var(--accent-cyan);
      min-width: 45px;
      text-align: center;
    }
  </style>
</head>
<body>
  <div class="hud-header">
    <div class="hud-title">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#00e1ff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M12 19l7-7 3 3-7 7-3-3z"></path>
        <path d="M18 13l-1.5-7.5L2 2l3.5 14.5L13 18l5-5z"></path>
      </svg>
      <span>$titleEscaped</span>
      <span class="badge-mode">Web Reader</span>
    </div>
    <button class="hud-btn" onclick="zoomIn()">Zoom +</button>
    <button class="hud-btn" onclick="zoomOut()">Zoom -</button>
    <button class="hud-btn" onclick="resetView()">100%</button>
    <span class="hud-zoom" id="zoom-text">100%</span>
  </div>

  <div id="canvas-container">
    <svg id="svg-stage" xmlns="http://www.w3.org/2000/svg">
      <g id="viewport-group" transform="matrix(1 0 0 1 0 0)">
        $strokesSvg
      </g>
    </svg>
  </div>

  <!-- DADOS ESTRUTURADOS DO CONNOTES -->
  <script id="connotes-data" type="application/json">
$embeddedJson
  </script>

  <!-- MOTOR OFFLINE DE PAN & ZOOM INTERATIVO (< 5 KB) -->
  <script>
    let panX = ${doc.panX};
    let panY = ${doc.panY};
    let scale = ${doc.zoomScale};
    let isDragging = false;
    let startX = 0, startY = 0;

    const group = document.getElementById('viewport-group');
    const zoomText = document.getElementById('zoom-text');
    const container = document.getElementById('canvas-container');

    function updateTransform() {
      group.setAttribute('transform', `matrix(\${scale} 0 0 \${scale} \${panX} \${panY})`);
      zoomText.textContent = Math.round(scale * 100) + '%';
    }

    container.addEventListener('mousedown', (e) => {
      if (e.target.closest('.hud-header')) return;
      isDragging = true;
      startX = e.clientX - panX;
      startY = e.clientY - panY;
    });

    window.addEventListener('mousemove', (e) => {
      if (!isDragging) return;
      panX = e.clientX - startX;
      panY = e.clientY - startY;
      updateTransform();
    });

    window.addEventListener('mouseup', () => { isDragging = false; });

    container.addEventListener('wheel', (e) => {
      e.preventDefault();
      const zoomFactor = e.deltaY < 0 ? 1.12 : 0.89;
      const mouseX = e.clientX;
      const mouseY = e.clientY;

      const newScale = Math.min(Math.max(scale * zoomFactor, 0.1), 8.0);
      panX = mouseX - (mouseX - panX) * (newScale / scale);
      panY = mouseY - (mouseY - panY) * (newScale / scale);
      scale = newScale;
      updateTransform();
    }, { passive: false });

    // Suporte a Touch em Celular / Tablet
    let lastTouchX = 0, lastTouchY = 0, touchDist = 0;
    container.addEventListener('touchstart', (e) => {
      if (e.touches.length === 1) {
        isDragging = true;
        startX = e.touches[0].clientX - panX;
        startY = e.touches[0].clientY - panY;
      } else if (e.touches.length === 2) {
        touchDist = Math.hypot(e.touches[0].clientX - e.touches[1].clientX, e.touches[0].clientY - e.touches[1].clientY);
      }
    });

    window.addEventListener('touchmove', (e) => {
      if (e.touches.length === 1 && isDragging) {
        panX = e.touches[0].clientX - startX;
        panY = e.touches[0].clientY - startY;
        updateTransform();
      } else if (e.touches.length === 2) {
        const newDist = Math.hypot(e.touches[0].clientX - e.touches[1].clientX, e.touches[0].clientY - e.touches[1].clientY);
        const factor = newDist / touchDist;
        scale = Math.min(Math.max(scale * factor, 0.1), 8.0);
        touchDist = newDist;
        updateTransform();
      }
    });

    window.addEventListener('touchend', () => { isDragging = false; });

    function zoomIn() { scale = Math.min(scale * 1.25, 8.0); updateTransform(); }
    function zoomOut() { scale = Math.max(scale * 0.8, 0.1); updateTransform(); }
    function resetView() { panX = 0; panY = 0; scale = 1.0; updateTransform(); }

    updateTransform();
  </script>
</body>
</html>''';
  }

  static String _generateSvgPaths(List<InkStroke> strokes) {
    final buffer = StringBuffer();

    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final colorHex = '#${stroke.color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
      final opacity = stroke.color.a;
      final width = stroke.strokeWidth;

      if (stroke.points.length == 1) {
        final p = stroke.points[0].point;
        buffer.writeln('<circle cx="${p.dx}" cy="${p.dy}" r="${width / 2}" fill="$colorHex" opacity="$opacity"/>');
        continue;
      }

      final d = StringBuffer('M ${stroke.points[0].point.dx} ${stroke.points[0].point.dy}');
      for (int i = 1; i < stroke.points.length; i++) {
        final p = stroke.points[i].point;
        d.write(' L ${p.dx} ${p.dy}');
      }

      buffer.writeln('<path d="$d" stroke="$colorHex" stroke-width="$width" stroke-opacity="$opacity" fill="none" stroke-linecap="round" stroke-linejoin="round"/>');
    }

    return buffer.toString();
  }
}
