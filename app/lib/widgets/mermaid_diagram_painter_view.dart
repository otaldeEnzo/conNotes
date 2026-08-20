import 'package:flutter/material.dart';

/// Renderizador Gráfico Vetorial de Diagramas Mermaid (100% Flutter Nativo / Moscaro v2).
/// Suporta Fluxogramas (graph TD / LR), Diagramas de Estado (stateDiagram), Sequência e Classes.
class MermaidDiagramPainterView extends StatefulWidget {
  final String mermaidCode;
  final bool isLight;
  final Color themeAccent;
  final Color textPrimary;
  final double fontSize;
  final VoidCallback? onEditCode;

  const MermaidDiagramPainterView({
    super.key,
    required this.mermaidCode,
    required this.isLight,
    required this.themeAccent,
    required this.textPrimary,
    required this.fontSize,
    this.onEditCode,
  });

  @override
  State<MermaidDiagramPainterView> createState() => _MermaidDiagramPainterViewState();
}

class _MermaidDiagramPainterViewState extends State<MermaidDiagramPainterView> {
  bool _showRawCode = false;

  @override
  Widget build(BuildContext context) {
    final cleanCode = widget.mermaidCode
        .replaceAll('```mermaid', '')
        .replaceAll('```', '')
        .trim();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: widget.isLight
            ? const Color(0xFFF1F5F9).withValues(alpha: 0.9)
            : const Color(0xFF0C101A).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFA855F7).withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA855F7).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho do Bloco Mermaid
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFA855F7).withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFFA855F7).withValues(alpha: 0.25),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_tree_rounded, size: 15, color: Color(0xFFA855F7)),
                    SizedBox(width: 6),
                    Text(
                      'Diagrama Mermaid',
                      style: TextStyle(
                        color: Color(0xFFA855F7),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _showRawCode = !_showRawCode),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _showRawCode
                              ? const Color(0xFFA855F7).withValues(alpha: 0.25)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFA855F7).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showRawCode ? Icons.visibility_rounded : Icons.code_rounded,
                              size: 12,
                              color: const Color(0xFFA855F7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _showRawCode ? 'Ver Gráfico' : 'Ver Código',
                              style: const TextStyle(
                                color: Color(0xFFA855F7),
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Corpo do Diagrama
          if (_showRawCode)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                cleanCode,
                style: TextStyle(
                  fontFamily: 'Fira Code',
                  color: widget.textPrimary,
                  fontSize: widget.fontSize * 0.9,
                  height: 1.4,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(14),
              child: _buildParsedMermaidDiagram(cleanCode),
            ),
        ],
      ),
    );
  }

  Widget _buildParsedMermaidDiagram(String code) {
    final lower = code.toLowerCase();
    if (lower.startsWith('graph') || lower.startsWith('flowchart')) {
      return _buildFlowchartDiagram(code);
    } else if (lower.startsWith('statediagram')) {
      return _buildStateDiagram(code);
    } else if (lower.startsWith('sequencediagram')) {
      return _buildSequenceDiagram(code);
    }

    // Fallback genérico para outros diagramas
    return _buildFlowchartDiagram(code);
  }

  // =========================================================
  // Renderizador de Fluxogramas (graph TD / LR)
  // =========================================================

  Widget _buildFlowchartDiagram(String code) {
    final lines = code.split('\n');
    final nodes = <String, String>{};
    final edges = <Map<String, String>>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('graph') || trimmed.startsWith('flowchart')) {
        continue;
      }

      final edgeMatch = RegExp(r'([A-Za-z0-9_]+)(?:\[(.*?)\]|\{(.*?)\})?\s*(-->|-.->|==>)\s*(?:\|(.*?)\|)?\s*([A-Za-z0-9_]+)(?:\[(.*?)\]|\{(.*?)\})?').firstMatch(trimmed);
      if (edgeMatch != null) {
        final fromId = edgeMatch.group(1)!;
        final fromLabel = edgeMatch.group(2) ?? edgeMatch.group(3) ?? fromId;
        final edgeLabel = edgeMatch.group(5) ?? '';
        final toId = edgeMatch.group(6)!;
        final toLabel = edgeMatch.group(7) ?? edgeMatch.group(8) ?? toId;

        nodes[fromId] = fromLabel;
        nodes[toId] = toLabel;
        edges.add({
          'from': fromId,
          'to': toId,
          'label': edgeLabel,
        });
      }
    }

    if (nodes.isEmpty) {
      return SelectableText(
        code,
        style: TextStyle(fontFamily: 'Fira Code', color: widget.textPrimary, fontSize: 11),
      );
    }

    final children = <Widget>[];
    for (int i = 0; i < edges.length; i++) {
      final edge = edges[i];
      final fromLabel = nodes[edge['from']] ?? edge['from']!;
      final toLabel = nodes[edge['to']] ?? edge['to']!;
      final edgeLabel = edge['label'] ?? '';

      if (i == 0) {
        children.add(_buildMermaidNodeBox(fromLabel, const Color(0xFF00E1FF)));
      }

      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              if (edgeLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA855F7).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    edgeLabel,
                    style: const TextStyle(
                      color: Color(0xFFA855F7),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              CustomPaint(
                size: const Size(20, 24),
                painter: _MermaidArrowPainter(color: const Color(0xFFA855F7)),
              ),
            ],
          ),
        ),
      );

      children.add(_buildMermaidNodeBox(toLabel, const Color(0xFFA855F7)));
    }

    return Column(children: children);
  }

  // =========================================================
  // Renderizador de Diagramas de Estado (stateDiagram)
  // =========================================================

  Widget _buildStateDiagram(String code) {
    final lines = code.split('\n');
    final transitions = <Map<String, String>>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('stateDiagram')) continue;

      final match = RegExp(r'(\[\*\]|[A-Za-z0-9_]+)\s*-->\s*(\[\*\]|[A-Za-z0-9_]+)(?:\s*:\s*(.*))?').firstMatch(trimmed);
      if (match != null) {
        transitions.add({
          'from': match.group(1)!,
          'to': match.group(2)!,
          'action': match.group(3) ?? '',
        });
      }
    }

    if (transitions.isEmpty) {
      return SelectableText(
        code,
        style: TextStyle(fontFamily: 'Fira Code', color: widget.textPrimary, fontSize: 11),
      );
    }

    final children = <Widget>[];
    for (int i = 0; i < transitions.length; i++) {
      final t = transitions[i];
      final from = t['from'] == '[*]' ? 'Início ●' : t['from']!;
      final to = t['to'] == '[*]' ? 'Fim ◉' : t['to']!;
      final action = t['action'] ?? '';

      if (i == 0) {
        children.add(_buildMermaidNodeBox(from, const Color(0xFF10B981)));
      }

      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              if (action.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    action,
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              CustomPaint(
                size: const Size(20, 24),
                painter: _MermaidArrowPainter(color: const Color(0xFF38BDF8)),
              ),
            ],
          ),
        ),
      );

      children.add(
        _buildMermaidNodeBox(to, t['to'] == '[*]' ? const Color(0xFFFF007A) : const Color(0xFFA855F7)),
      );
    }

    return Column(children: children);
  }

  // =========================================================
  // Renderizador de Diagramas de Sequência (sequenceDiagram)
  // =========================================================

  Widget _buildSequenceDiagram(String code) {
    final lines = code.split('\n');
    final messages = <Map<String, String>>[];
    final actors = <String>{};

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('sequenceDiagram') || trimmed.startsWith('autonumber')) continue;

      final match = RegExp(r'([A-Za-z0-9_]+)\s*(->>|-->>|->|-->)\s*([A-Za-z0-9_]+)\s*:\s*(.*)').firstMatch(trimmed);
      if (match != null) {
        final from = match.group(1)!;
        final to = match.group(3)!;
        final text = match.group(4)!;
        actors.add(from);
        actors.add(to);
        messages.add({
          'from': from,
          'to': to,
          'text': text,
          'isAsync': match.group(2)!.contains('--') ? 'true' : 'false',
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabeçalho de Atores
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: actors.map((a) => _buildMermaidNodeBox(a, const Color(0xFF00E1FF))).toList(),
        ),
        const SizedBox(height: 12),
        for (final m in messages)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${m['from']} → ${m['to']}',
                  style: const TextStyle(color: Color(0xFF00E1FF), fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
                Text(
                  m['text']!,
                  style: TextStyle(color: widget.textPrimary, fontSize: 11),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMermaidNodeBox(String label, Color accent) {
    return Container(
      constraints: const BoxConstraints(minWidth: 90, maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: widget.isLight ? 0.12 : 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: widget.textPrimary,
          fontSize: widget.fontSize * 0.92,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MermaidArrowPainter extends CustomPainter {
  final Color color;

  _MermaidArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width / 2, size.height);

    // Ponta da flecha
    path.moveTo(size.width / 2 - 4, size.height - 6);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width / 2 + 4, size.height - 6);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MermaidArrowPainter oldDelegate) => oldDelegate.color != color;
}
