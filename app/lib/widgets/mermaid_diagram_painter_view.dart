import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import 'svg_icon.dart';


class _MermaidNote {
  final String targetNode;
  final String text;

  const _MermaidNote({required this.targetNode, required this.text});
}

/// Renderizador Gráfico Vetorial de Diagramas Mermaid (100% Flutter Nativo / Moscaro v2).
/// Suporta Fluxogramas (graph TD / LR com subgraphs, notas, nós redondos/retangulares/losangos),
/// Diagramas de Estado (stateDiagram) e Sequência (sequenceDiagram).
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

enum _DiagramDirection { td, lr }

enum _NodeShape { box, rounded, stadium, cylinder, circle, rhombus, hexagon, flag }

enum _ArrowDirection { up, down, left, right }

class _DiagramNode {
  final String id;
  String label;
  _NodeShape shape;
  String? subgraphId;
  final List<String> notes = [];

  _DiagramNode({
    required this.id,
    required this.label,
    this.shape = _NodeShape.box,
    this.subgraphId,
  });
}

class _DiagramEdge {
  final String from;
  final String to;
  final String label;
  final bool directed;
  final bool dashed;
  final bool thick;

  const _DiagramEdge({
    required this.from,
    required this.to,
    this.label = '',
    this.directed = true,
    this.dashed = false,
    this.thick = false,
  });
}

class _DiagramSubgraph {
  final String id;
  final String title;
  final Set<String> nodeIds = {};

  _DiagramSubgraph({required this.id, required this.title});
}

class _MermaidDiagramPainterViewState extends State<MermaidDiagramPainterView> {
  bool _showRawCode = false;
  final ScrollController _hScrollController = ScrollController();

  @override
  void dispose() {
    _hScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cleanCode = widget.mermaidCode
        .replaceAll('```mermaid', '')
        .replaceAll('```', '')
        .trim();

    if (cleanCode.isEmpty) {
      return const SizedBox.shrink();
    }

    final accent = widget.themeAccent;
    final secondaryAccent = MoscaroTokens.auroraPurple;
    final glassColor = MoscaroTokens.glassTint;
    final textPrimary = MoscaroTokens.textPrimary;

    Widget content;
    if (_showRawCode) {
      content = Padding(
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          cleanCode,
          style: TextStyle(
            fontFamily: 'monospace',
            color: textPrimary,
            fontSize: widget.fontSize * 0.88,
            height: 1.4,
          ),
        ),
      );
    } else {
      Widget diagram;
      try {
        diagram = _buildParsedMermaidDiagram(cleanCode, accent, secondaryAccent);
      } catch (e) {
        diagram = _buildFallbackView(cleanCode, accent);
      }

      if (diagram is SizedBox && (diagram.width == 0 || diagram.width == null) && (diagram.height == 0 || diagram.height == null)) {
        return const SizedBox.shrink();
      }

      content = Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minW = (constraints.maxWidth > 0 && constraints.maxWidth != double.infinity)
                ? constraints.maxWidth
                : 0.0;
            return Scrollbar(
              controller: _hScrollController,
              thumbVisibility: false, // Só aparece dinamicamente conforme o uso!
              trackVisibility: false,
              interactive: true,
              child: SingleChildScrollView(
                controller: _hScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: minW),
                  child: Center(
                    child: diagram,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: glassColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accent.withValues(alpha: 0.42),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.isLight ? 0.08 : 0.28),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                border: Border(
                  bottom: BorderSide(
                    color: accent.withValues(alpha: 0.24),
                    width: 1.0,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SvgIcon(name: 'shapes', size: 14, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        'Diagrama Mermaid',
                        style: TextStyle(
                          color: accent,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => setState(() => _showRawCode = !_showRawCode),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _showRawCode
                            ? accent.withValues(alpha: 0.22)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgIcon(
                            name: _showRawCode ? 'shapes' : 'keyboard',
                            size: 11,
                            color: accent,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _showRawCode ? 'Ver Gráfico' : 'Ver Código',
                            style: TextStyle(
                              color: accent,
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
            ),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildParsedMermaidDiagram(String code, Color accent, Color secondaryAccent) {
    final lower = code.toLowerCase();
    if (lower.startsWith('statediagram')) {
      return _buildStateDiagram(code, accent, secondaryAccent);
    } else if (lower.startsWith('sequencediagram')) {
      return _buildSequenceDiagram(code, accent, secondaryAccent);
    }
    return _buildFlowchartDiagram(code, accent, secondaryAccent);
  }

  static String _cleanLabel(String input) {
    var s = input.trim();
    s = s.replaceAll('**', '').replaceAll('*', '');
    s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    bool changed = true;
    while (changed && s.length >= 2) {
      changed = false;
      if ((s.startsWith('[') && s.endsWith(']')) ||
          (s.startsWith('(') && s.endsWith(')')) ||
          (s.startsWith('{') && s.endsWith('}')) ||
          (s.startsWith('"') && s.endsWith('"')) ||
          (s.startsWith("'") && s.endsWith("'"))) {
        s = s.substring(1, s.length - 1).trim();
        changed = true;
      }
    }
    return s;
  }

  static _DiagramNode _parseNodeToken(
    String rawToken,
    Map<String, _DiagramNode> nodes, {
    String? currentSubgraphId,
  }) {
    final s = rawToken.trim();
    if (s.isEmpty) return _DiagramNode(id: '', label: '');

    final idMatch = RegExp(r'^([A-Za-z0-9_\-À-ÿ]+)').firstMatch(s);
    if (idMatch == null) {
      final clean = _cleanLabel(s);
      if (!nodes.containsKey(clean)) {
        nodes[clean] = _DiagramNode(id: clean, label: clean, subgraphId: currentSubgraphId);
      }
      return nodes[clean]!;
    }

    final id = idMatch.group(1)!;
    final rest = s.substring(idMatch.end).trim();

    _NodeShape shape = _NodeShape.box;
    String label = id;

    if (rest.isNotEmpty) {
      if (rest.startsWith('((') && rest.endsWith('))')) {
        shape = _NodeShape.circle;
        label = rest.substring(2, rest.length - 2);
      } else if (rest.startsWith('([') && rest.endsWith('])')) {
        shape = _NodeShape.stadium;
        label = rest.substring(2, rest.length - 2);
      } else if (rest.startsWith('[(') && rest.endsWith(')]')) {
        shape = _NodeShape.cylinder;
        label = rest.substring(2, rest.length - 2);
      } else if (rest.startsWith('{{') && rest.endsWith('}}')) {
        shape = _NodeShape.hexagon;
        label = rest.substring(2, rest.length - 2);
      } else if (rest.startsWith('{') && rest.endsWith('}')) {
        shape = _NodeShape.rhombus;
        label = rest.substring(1, rest.length - 1);
      } else if (rest.startsWith('(') && rest.endsWith(')')) {
        shape = _NodeShape.rounded;
        label = rest.substring(1, rest.length - 1);
      } else if (rest.startsWith('[') && rest.endsWith(']')) {
        shape = _NodeShape.box;
        label = rest.substring(1, rest.length - 1);
      } else if (rest.startsWith('>') && rest.endsWith(']')) {
        shape = _NodeShape.flag;
        label = rest.substring(1, rest.length - 1);
      } else {
        label = rest;
      }
      label = _cleanLabel(label);
    }

    if (nodes.containsKey(id)) {
      final existing = nodes[id]!;
      if (label != id && (existing.label == id || existing.label.isEmpty)) {
        existing.label = label;
        existing.shape = shape;
      }
      if (currentSubgraphId != null && existing.subgraphId == null) {
        existing.subgraphId = currentSubgraphId;
      }
      return existing;
    } else {
      final node = _DiagramNode(
        id: id,
        label: label.isEmpty ? id : label,
        shape: shape,
        subgraphId: currentSubgraphId,
      );
      nodes[id] = node;
      return node;
    }
  }

  Widget _buildFlowchartDiagram(String code, Color accent, Color secondaryAccent) {
    final rawLines = code.split('\n');
    final nodes = <String, _DiagramNode>{};
    final edges = <_DiagramEdge>[];
    final subgraphs = <_DiagramSubgraph>[];
    final notes = <_MermaidNote>[];

    _DiagramDirection direction = _DiagramDirection.td;
    _DiagramSubgraph? currentSubgraph;
    bool inNoteBlock = false;
    String noteTarget = '';
    final noteLines = <String>[];

    final arrowPattern = RegExp(
      r'(?:--\s*"?([^"\-\n]+?)"?\s*(-->|---|->)|'
      r'-\.\s*"?([^"\.\n]+?)"?\s*(\.->|\.-|-\.->)|'
      r'==\s*"?([^"=\n]+?)"?\s*(==>|===)|'
      r'(<-->|<==>|-->|---|-.->|-.-|==>|===|->|--)(?:\s*\|([^|]*)\|)?)',
    );

    for (int i = 0; i < rawLines.length; i++) {
      var trimmed = rawLines[i].trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.endsWith(';')) {
        trimmed = trimmed.substring(0, trimmed.length - 1).trim();
      }

      final lower = trimmed.toLowerCase();

      if (lower.startsWith('graph ') ||
          lower == 'graph' ||
          lower.startsWith('flowchart ') ||
          lower == 'flowchart') {
        if (lower.contains('lr')) {
          direction = _DiagramDirection.lr;
        } else if (lower.contains('td') || lower.contains('tb')) {
          direction = _DiagramDirection.td;
        }
        continue;
      }

      if (lower.startsWith('direction ')) {
        if (lower.contains('lr')) {
          direction = _DiagramDirection.lr;
        } else if (lower.contains('tb') || lower.contains('td')) {
          direction = _DiagramDirection.td;
        }
        continue;
      }

      if (lower.startsWith('style ') ||
          lower.startsWith('linkstyle ') ||
          lower.startsWith('classdef ') ||
          lower.startsWith('class ') ||
          lower.startsWith('click ') ||
          lower.startsWith('%%')) {
        continue;
      }

      if (inNoteBlock) {
        if (lower == 'end') {
          if (noteLines.isNotEmpty) {
            final noteText = noteLines.join('\n');
            if (noteTarget.isNotEmpty && nodes.containsKey(noteTarget)) {
              nodes[noteTarget]!.notes.add(noteText);
            } else {
              notes.add(_MermaidNote(targetNode: noteTarget, text: noteText));
            }
          }
          inNoteBlock = false;
          noteTarget = '';
          noteLines.clear();
        } else {
          noteLines.add(trimmed);
        }
        continue;
      }

      if (lower.startsWith('note ')) {
        final singleLineMatch = RegExp(
          r'^note\s+(?:right of|left of|over)\s+([A-Za-z0-9_\-]+)\s*:\s*(.+)$',
          caseSensitive: false,
        ).firstMatch(trimmed);

        if (singleLineMatch != null) {
          final target = singleLineMatch.group(1)!;
          final text = singleLineMatch.group(2)!.trim();
          if (nodes.containsKey(target)) {
            nodes[target]!.notes.add(text);
          } else {
            notes.add(_MermaidNote(targetNode: target, text: text));
          }
        } else {
          final blockMatch = RegExp(
            r'^note\s+(?:right of|left of|over)\s+([A-Za-z0-9_\-]+)',
            caseSensitive: false,
          ).firstMatch(trimmed);
          noteTarget = blockMatch != null ? blockMatch.group(1)! : '';
          inNoteBlock = true;
          noteLines.clear();
        }
        continue;
      }

      if (lower.startsWith('subgraph ')) {
        var rawTitle = trimmed.substring(9).trim();
        String sgId;
        String sgTitle;
        final bracketStart = rawTitle.indexOf('[');
        if (bracketStart != -1 && rawTitle.endsWith(']')) {
          sgId = rawTitle.substring(0, bracketStart).trim();
          sgTitle = _cleanLabel(rawTitle.substring(bracketStart + 1, rawTitle.length - 1));
        } else {
          sgTitle = _cleanLabel(rawTitle);
          sgId = sgTitle.replaceAll(RegExp(r'\s+'), '_');
        }
        if (sgTitle.isEmpty) sgTitle = 'Subgrupo';
        if (sgId.isEmpty) sgId = 'sg_${subgraphs.length}';
        currentSubgraph = _DiagramSubgraph(id: sgId, title: sgTitle);
        subgraphs.add(currentSubgraph);
        continue;
      }

      if (lower == 'end') {
        currentSubgraph = null;
        continue;
      }

      final matches = arrowPattern.allMatches(trimmed).toList();
      if (matches.isNotEmpty) {
        int segStart = 0;
        String? prevNodeId;

        for (int mIdx = 0; mIdx < matches.length; mIdx++) {
          final m = matches[mIdx];
          final lhsRaw = trimmed.substring(segStart, m.start).trim();
          final nextStart = (mIdx + 1 < matches.length) ? matches[mIdx + 1].start : trimmed.length;
          final rhsRaw = trimmed.substring(m.end, nextStart).trim();

          final fromNode = prevNodeId != null && nodes.containsKey(prevNodeId)
              ? nodes[prevNodeId]!
              : _parseNodeToken(lhsRaw, nodes, currentSubgraphId: currentSubgraph?.id);

          final toNode = _parseNodeToken(rhsRaw, nodes, currentSubgraphId: currentSubgraph?.id);

          final rawLabel = m.group(1) ?? m.group(3) ?? m.group(5) ?? m.group(8) ?? '';
          final arrowOp = m.group(2) ?? m.group(4) ?? m.group(6) ?? m.group(7) ?? '-->';

          final isDirected = arrowOp.contains('>');
          final isDashed = arrowOp.contains('.');
          final isThick = arrowOp.contains('=');

          if (fromNode.id.isNotEmpty && toNode.id.isNotEmpty) {
            edges.add(_DiagramEdge(
              from: fromNode.id,
              to: toNode.id,
              label: _cleanLabel(rawLabel),
              directed: isDirected,
              dashed: isDashed,
              thick: isThick,
            ));

            if (currentSubgraph != null) {
              currentSubgraph.nodeIds.add(fromNode.id);
              currentSubgraph.nodeIds.add(toNode.id);
            }
          }

          prevNodeId = toNode.id;
          segStart = m.end;
        }
        continue;
      }

      if (RegExp(r'^[A-Za-z0-9_\-À-ÿ]+\s*[\[\(\{]').hasMatch(trimmed)) {
        final node = _parseNodeToken(trimmed, nodes, currentSubgraphId: currentSubgraph?.id);
        if (node.id.isNotEmpty && currentSubgraph != null) {
          currentSubgraph.nodeIds.add(node.id);
        }
      }
    }

    final activeSubgraphs = subgraphs.where((sg) => sg.nodeIds.isNotEmpty).toList();

    if (nodes.isEmpty && activeSubgraphs.isEmpty && notes.isEmpty) {
      return _buildFallbackView(code, accent);
    }

    return _renderFlowchartGraph(
      nodes: nodes,
      edges: edges,
      subgraphs: activeSubgraphs,
      notes: notes,
      direction: direction,
      accent: accent,
      secondaryAccent: secondaryAccent,
    );
  }

  Widget _renderFlowchartGraph({
    required Map<String, _DiagramNode> nodes,
    required List<_DiagramEdge> edges,
    required List<_DiagramSubgraph> subgraphs,
    required List<_MermaidNote> notes,
    required _DiagramDirection direction,
    required Color accent,
    required Color secondaryAccent,
  }) {
    if (nodes.isEmpty) {
      return const SizedBox.shrink();
    }

    final ranks = <String, int>{};
    for (final id in nodes.keys) {
      ranks[id] = 0;
    }

    final nodeCount = nodes.length;
    for (int iter = 0; iter < nodeCount; iter++) {
      bool changed = false;
      for (final edge in edges) {
        if (!nodes.containsKey(edge.from) || !nodes.containsKey(edge.to)) continue;
        if (edge.from == edge.to) continue;
        final fromRank = ranks[edge.from]!;
        final toRank = ranks[edge.to]!;
        if (fromRank + 1 > toRank) {
          ranks[edge.to] = fromRank + 1;
          changed = true;
        }
      }
      if (!changed) break;
    }

    int maxRank = 0;
    for (final r in ranks.values) {
      if (r > maxRank) maxRank = r;
    }

    final layers = <int, List<String>>{};
    for (int r = 0; r <= maxRank; r++) {
      layers[r] = [];
    }
    for (final entry in ranks.entries) {
      layers[entry.value]?.add(entry.key);
    }

    for (int r = 1; r <= maxRank; r++) {
      final prevLayer = layers[r - 1] ?? [];
      final prevIndices = <String, int>{};
      for (int i = 0; i < prevLayer.length; i++) {
        prevIndices[prevLayer[i]] = i;
      }

      layers[r]!.sort((a, b) {
        final nodeA = nodes[a]!;
        final nodeB = nodes[b]!;

        final sgA = nodeA.subgraphId ?? '';
        final sgB = nodeB.subgraphId ?? '';
        if (sgA != sgB) {
          return sgA.compareTo(sgB);
        }

        double baryA = 0;
        int countA = 0;
        for (final edge in edges.where((e) => e.to == a)) {
          if (prevIndices.containsKey(edge.from)) {
            baryA += prevIndices[edge.from]!;
            countA++;
          }
        }
        final avgA = countA > 0 ? baryA / countA : 999.0;

        double baryB = 0;
        int countB = 0;
        for (final edge in edges.where((e) => e.to == b)) {
          if (prevIndices.containsKey(edge.from)) {
            baryB += prevIndices[edge.from]!;
            countB++;
          }
        }
        final avgB = countB > 0 ? baryB / countB : 999.0;

        return avgA.compareTo(avgB);
      });
    }

    final nodeSizes = <String, Size>{};
    for (final entry in nodes.entries) {
      final textSpan = TextSpan(
        text: entry.value.label,
        style: TextStyle(
          fontSize: widget.fontSize * 0.85,
          fontWeight: FontWeight.w600,
        ),
      );
      final tp = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: 190);

      final w = (tp.width + 30).clamp(92.0, 220.0);
      final h = (tp.height + 20).clamp(38.0, 56.0);
      nodeSizes[entry.key] = Size(w, h);
    }

    final nodeRects = <String, Rect>{};
    double totalWidth = 0;
    double totalHeight = 0;

    if (direction == _DiagramDirection.td) {
      const baseNodeSpacingX = 28.0;
      const extraSubgraphGapX = 48.0;
      const layerSpacingY = 54.0;
      const marginX = 24.0;
      const marginY = 26.0;

      final layerWidths = <int, double>{};
      for (int r = 0; r <= maxRank; r++) {
        final curNodes = layers[r]!;
        if (curNodes.isEmpty) continue;
        double wSum = 0;
        for (int idx = 0; idx < curNodes.length; idx++) {
          final id = curNodes[idx];
          wSum += nodeSizes[id]!.width;
          if (idx < curNodes.length - 1) {
            final nextId = curNodes[idx + 1];
            final diffSg = nodes[id]?.subgraphId != nodes[nextId]?.subgraphId;
            wSum += diffSg ? (baseNodeSpacingX + extraSubgraphGapX) : baseNodeSpacingX;
          }
        }
        layerWidths[r] = wSum;
      }

      double maxLayerW = 0;
      for (final w in layerWidths.values) {
        if (w > maxLayerW) maxLayerW = w;
      }

      double curY = marginY;
      for (int r = 0; r <= maxRank; r++) {
        final curNodes = layers[r]!;
        if (curNodes.isEmpty) continue;

        final layerW = layerWidths[r] ?? 0;
        final startX = marginX + (maxLayerW - layerW) / 2;

        double maxNodeH = 0;
        for (final id in curNodes) {
          final h = nodeSizes[id]!.height;
          if (h > maxNodeH) maxNodeH = h;
        }

        double curX = startX;
        for (int idx = 0; idx < curNodes.length; idx++) {
          final id = curNodes[idx];
          final size = nodeSizes[id]!;
          final nodeY = curY + (maxNodeH - size.height) / 2;
          nodeRects[id] = Rect.fromLTWH(curX, nodeY, size.width, size.height);

          double spacing = baseNodeSpacingX;
          if (idx < curNodes.length - 1) {
            final nextId = curNodes[idx + 1];
            if (nodes[id]?.subgraphId != nodes[nextId]?.subgraphId) {
              spacing += extraSubgraphGapX;
            }
          }
          curX += size.width + spacing;
        }

        curY += maxNodeH + layerSpacingY;
      }

      totalWidth = maxLayerW + marginX * 2;
      totalHeight = curY - layerSpacingY + marginY;
    } else {
      const baseNodeSpacingY = 24.0;
      const extraSubgraphGapY = 48.0;
      const layerSpacingX = 54.0;
      const marginX = 24.0;
      const marginY = 26.0;

      final layerHeights = <int, double>{};
      for (int r = 0; r <= maxRank; r++) {
        final curNodes = layers[r]!;
        if (curNodes.isEmpty) continue;
        double hSum = 0;
        for (int idx = 0; idx < curNodes.length; idx++) {
          final id = curNodes[idx];
          hSum += nodeSizes[id]!.height;
          if (idx < curNodes.length - 1) {
            final nextId = curNodes[idx + 1];
            final diffSg = nodes[id]?.subgraphId != nodes[nextId]?.subgraphId;
            hSum += diffSg ? (baseNodeSpacingY + extraSubgraphGapY) : baseNodeSpacingY;
          }
        }
        layerHeights[r] = hSum;
      }

      double maxLayerH = 0;
      for (final h in layerHeights.values) {
        if (h > maxLayerH) maxLayerH = h;
      }

      double curX = marginX;
      for (int r = 0; r <= maxRank; r++) {
        final curNodes = layers[r]!;
        if (curNodes.isEmpty) continue;

        final layerH = layerHeights[r] ?? 0;
        final startY = marginY + (maxLayerH - layerH) / 2;

        double maxNodeW = 0;
        for (final id in curNodes) {
          final w = nodeSizes[id]!.width;
          if (w > maxNodeW) maxNodeW = w;
        }

        double curY = startY;
        for (int idx = 0; idx < curNodes.length; idx++) {
          final id = curNodes[idx];
          final size = nodeSizes[id]!;
          final nodeX = curX + (maxNodeW - size.width) / 2;
          nodeRects[id] = Rect.fromLTWH(nodeX, curY, size.width, size.height);

          double spacing = baseNodeSpacingY;
          if (idx < curNodes.length - 1) {
            final nextId = curNodes[idx + 1];
            if (nodes[id]?.subgraphId != nodes[nextId]?.subgraphId) {
              spacing += extraSubgraphGapY;
            }
          }
          curY += size.height + spacing;
        }

        curX += maxNodeW + layerSpacingX;
      }

      totalWidth = curX - layerSpacingX + marginX;
      totalHeight = maxLayerH + marginY * 2;
    }

    final subgraphRects = <_DiagramSubgraph, Rect>{};
    double minAllX = 0;
    double minAllY = 0;
    for (final sg in subgraphs) {
      final memberRects = sg.nodeIds.map((id) => nodeRects[id]).whereType<Rect>().toList();
      if (memberRects.isNotEmpty) {
        var r = memberRects.reduce((a, b) => a.expandToInclude(b));
        final expanded = Rect.fromLTRB(r.left - 14, r.top - 28, r.right + 14, r.bottom + 14);
        subgraphRects[sg] = expanded;
        if (expanded.left < minAllX) minAllX = expanded.left;
        if (expanded.top < minAllY) minAllY = expanded.top;
      }
    }

    final shiftX = minAllX < 0 ? -minAllX + 12.0 : 0.0;
    final shiftY = minAllY < 0 ? -minAllY + 12.0 : 0.0;
    if (shiftX > 0 || shiftY > 0) {
      for (final entry in nodeRects.entries.toList()) {
        nodeRects[entry.key] = entry.value.shift(Offset(shiftX, shiftY));
      }
      for (final entry in subgraphRects.entries.toList()) {
        subgraphRects[entry.key] = entry.value.shift(Offset(shiftX, shiftY));
      }
      totalWidth += shiftX;
      totalHeight += shiftY;
    }

    for (final r in subgraphRects.values) {
      if (r.right + 14 > totalWidth) totalWidth = r.right + 14;
      if (r.bottom + 14 > totalHeight) totalHeight = r.bottom + 14;
    }

    final stackChildren = <Widget>[];

    for (final entry in subgraphRects.entries) {
      final sg = entry.key;
      final r = entry.value;
      stackChildren.add(
        Positioned(
          left: r.left,
          top: r.top,
          width: r.width,
          height: r.height,
          child: Container(
            decoration: BoxDecoration(
              color: accent.withValues(alpha: widget.isLight ? 0.04 : 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accent.withValues(alpha: 0.28),
                width: 1.0,
              ),
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                constraints: BoxConstraints(maxWidth: (r.width - 20).clamp(60.0, 500.0)),
                margin: const EdgeInsets.only(left: 8, top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  sg.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: widget.fontSize * 0.76,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    stackChildren.add(
      Positioned(
        left: 0,
        top: 0,
        width: totalWidth,
        height: totalHeight,
        child: CustomPaint(
          size: Size(totalWidth, totalHeight),
          painter: _DiagramEdgesPainter(
            edges: edges,
            nodeRects: nodeRects,
            direction: direction,
            color: secondaryAccent,
            textColor: MoscaroTokens.textPrimary,
            fontSize: widget.fontSize,
          ),
        ),
      ),
    );

    for (final entry in nodes.entries) {
      final id = entry.key;
      final node = entry.value;
      final rect = nodeRects[id];
      if (rect == null) continue;

      stackChildren.add(
        Positioned(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          child: _buildNodeCard(
            node: node,
            accent: accent,
            secondaryAccent: secondaryAccent,
          ),
        ),
      );
    }

    final noteWidgets = <Widget>[];
    for (final node in nodes.values) {
      for (final noteText in node.notes) {
        noteWidgets.add(_buildNoteBadge(node.label, noteText, secondaryAccent));
      }
    }
    for (final note in notes) {
      final targetLabel = nodes[note.targetNode]?.label ?? note.targetNode;
      noteWidgets.add(_buildNoteBadge(targetLabel, note.text, secondaryAccent));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: totalWidth,
          height: totalHeight,
          child: Stack(
            children: stackChildren,
          ),
        ),
        if (noteWidgets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              width: totalWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: noteWidgets,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNodeCard({
    required _DiagramNode node,
    required Color accent,
    required Color secondaryAccent,
  }) {
    BorderRadius radius;
    switch (node.shape) {
      case _NodeShape.stadium:
      case _NodeShape.circle:
        radius = BorderRadius.circular(20);
        break;
      case _NodeShape.rounded:
        radius = BorderRadius.circular(14);
        break;
      case _NodeShape.rhombus:
      case _NodeShape.hexagon:
        radius = BorderRadius.circular(8);
        break;
      case _NodeShape.cylinder:
        radius = BorderRadius.circular(8);
        break;
      case _NodeShape.box:
      case _NodeShape.flag:
        radius = BorderRadius.circular(10);
        break;
    }

    final isRhombus = node.shape == _NodeShape.rhombus;
    final cardBorderColor = isRhombus
        ? secondaryAccent.withValues(alpha: widget.isLight ? 0.6 : 0.8)
        : accent.withValues(alpha: widget.isLight ? 0.40 : 0.65);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isLight
            ? accent.withValues(alpha: 0.08)
            : MoscaroTokens.glassTint,
        borderRadius: radius,
        border: Border.all(
          color: cardBorderColor,
          width: isRhombus ? 1.4 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          node.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: MoscaroTokens.textPrimary,
            fontSize: widget.fontSize * 0.85,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
      ),
    );
  }

  Widget _buildNoteBadge(String targetLabel, String text, Color secondaryAccent) {
    final clean = text.trim();
    if (clean.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: secondaryAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: secondaryAccent.withValues(alpha: 0.38),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgIcon(assetName: 'pen', color: secondaryAccent, size: 12),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  targetLabel.isNotEmpty ? 'Nota ($targetLabel)' : 'Nota',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondaryAccent,
                    fontSize: widget.fontSize * 0.78,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            clean,
            style: TextStyle(
              color: MoscaroTokens.textPrimary,
              fontSize: widget.fontSize * 0.83,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateDiagram(String code, Color accent, Color secondaryAccent) {
    final lines = code.split('\n');
    final nodes = <String, _DiagramNode>{};
    final edges = <_DiagramEdge>[];

    for (final line in lines) {
      var trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.endsWith(';')) trimmed = trimmed.substring(0, trimmed.length - 1).trim();
      final lower = trimmed.toLowerCase();
      if (lower.startsWith('statediagram')) continue;

      final match = RegExp(
        r'(\[\*\]|[A-Za-z0-9_À-ÿ]+)\s*-->\s*(\[\*\]|[A-Za-z0-9_À-ÿ]+)(?:\s*:\s*(.*))?',
      ).firstMatch(trimmed);

      if (match != null) {
        final rawFrom = match.group(1)!;
        final rawTo = match.group(2)!;
        final action = match.group(3)?.trim() ?? '';

        final fromId = rawFrom == '[*]' ? 'state_start' : rawFrom;
        final fromLabel = rawFrom == '[*]' ? 'Início' : rawFrom;
        final fromShape = rawFrom == '[*]' ? _NodeShape.stadium : _NodeShape.rounded;

        final toId = rawTo == '[*]' ? 'state_end' : rawTo;
        final toLabel = rawTo == '[*]' ? 'Fim' : rawTo;
        final toShape = rawTo == '[*]' ? _NodeShape.stadium : _NodeShape.rounded;

        if (!nodes.containsKey(fromId)) {
          nodes[fromId] = _DiagramNode(id: fromId, label: fromLabel, shape: fromShape);
        }
        if (!nodes.containsKey(toId)) {
          nodes[toId] = _DiagramNode(id: toId, label: toLabel, shape: toShape);
        }

        edges.add(_DiagramEdge(
          from: fromId,
          to: toId,
          label: action,
          directed: true,
        ));
      }
    }

    if (nodes.isEmpty) {
      return _buildFlowchartDiagram(code, accent, secondaryAccent);
    }

    return _renderFlowchartGraph(
      nodes: nodes,
      edges: edges,
      subgraphs: const [],
      notes: const [],
      direction: _DiagramDirection.td,
      accent: accent,
      secondaryAccent: secondaryAccent,
    );
  }

  Widget _buildSequenceDiagram(String code, Color accent, Color secondaryAccent) {
    final lines = code.split('\n');
    final messages = <Map<String, String>>[];
    final actors = <String>{};

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty ||
          trimmed.toLowerCase().startsWith('sequencediagram') ||
          trimmed.toLowerCase().startsWith('autonumber')) {
        continue;
      }

      final match = RegExp(r'([A-Za-z0-9_À-ÿ]+)\s*(->>|-->>|->|-->)\s*([A-Za-z0-9_À-ÿ]+)\s*:\s*(.*)').firstMatch(trimmed);
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
        });
      }
    }

    if (messages.isEmpty && actors.isEmpty) {
      return _buildFlowchartDiagram(code, accent, secondaryAccent);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceAround,
          spacing: 8,
          runSpacing: 8,
          children: actors.map((a) => _buildMermaidNodeBox(a, accent)).toList(),
        ),
        const SizedBox(height: 12),
        for (final m in messages)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: MoscaroTokens.glassTint,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: secondaryAccent.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${m['from']} -> ${m['to']}',
                  style: TextStyle(
                    color: accent,
                    fontSize: widget.fontSize * 0.82,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    m['text']!,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: MoscaroTokens.textPrimary,
                      fontSize: widget.fontSize * 0.86,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFallbackView(String code, Color accent) {
    final rawLines = code.split('\n');
    final items = rawLines
        .map((l) => l.trim())
        .where((l) =>
            l.isNotEmpty &&
            !l.toLowerCase().startsWith('graph') &&
            !l.toLowerCase().startsWith('flowchart') &&
            !l.toLowerCase().startsWith('%%'))
        .toList();

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: _buildMermaidNodeBox(_cleanLabel(item), accent),
              ))
          .toList(),
    );
  }

  Widget _buildMermaidNodeBox(String label, Color accent) {
    return Container(
      constraints: const BoxConstraints(minWidth: 84, maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: widget.isLight
            ? accent.withValues(alpha: 0.10)
            : MoscaroTokens.glassTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.65), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 6,
          ),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: MoscaroTokens.textPrimary,
          fontSize: widget.fontSize * 0.88,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _DiagramEdgesPainter extends CustomPainter {
  final List<_DiagramEdge> edges;
  final Map<String, Rect> nodeRects;
  final _DiagramDirection direction;
  final Color color;
  final Color textColor;
  final double fontSize;

  _DiagramEdgesPainter({
    required this.edges,
    required this.nodeRects,
    required this.direction,
    required this.color,
    required this.textColor,
    required this.fontSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final fromRect = nodeRects[edge.from];
      final toRect = nodeRects[edge.to];
      if (fromRect == null || toRect == null) continue;

      final strokeWidth = edge.thick ? 2.2 : 1.4;
      final linePaint = Paint()
        ..color = color.withValues(alpha: 0.85)
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final arrowHeadPaint = Paint()
        ..color = color.withValues(alpha: 0.95)
        ..style = PaintingStyle.fill;

      Offset src;
      Offset dst;
      final path = Path();

      if (direction == _DiagramDirection.td) {
        if (edge.from == edge.to) {
          src = Offset(fromRect.right, fromRect.top + fromRect.height * 0.3);
          dst = Offset(fromRect.right, fromRect.top + fromRect.height * 0.7);
          const loopW = 20.0;
          path.moveTo(src.dx, src.dy);
          path.cubicTo(
            src.dx + loopW, src.dy - 10,
            dst.dx + loopW, dst.dy + 10,
            dst.dx, dst.dy,
          );
          _drawArrowHead(canvas, arrowHeadPaint, dst, _ArrowDirection.left);
        } else if (toRect.top >= fromRect.bottom - 4) {
          src = Offset(fromRect.center.dx, fromRect.bottom);
          dst = Offset(toRect.center.dx, toRect.top);
          path.moveTo(src.dx, src.dy);
          if ((src.dx - dst.dx).abs() < 2) {
            path.lineTo(dst.dx, dst.dy);
          } else {
            final midY = src.dy + (dst.dy - src.dy) * 0.5;
            path.cubicTo(src.dx, midY, dst.dx, midY, dst.dx, dst.dy);
          }
          if (edge.directed) {
            _drawArrowHead(canvas, arrowHeadPaint, dst, _ArrowDirection.down);
          }
        } else {
          src = Offset(fromRect.right, fromRect.center.dy);
          dst = Offset(toRect.right, toRect.center.dy);
          final rightX = (fromRect.right > toRect.right ? fromRect.right : toRect.right) + 24.0;
          path.moveTo(src.dx, src.dy);
          path.cubicTo(rightX, src.dy, rightX, dst.dy, dst.dx, dst.dy);
          if (edge.directed) {
            _drawArrowHead(canvas, arrowHeadPaint, dst, _ArrowDirection.left);
          }
        }
      } else {
        if (edge.from == edge.to) {
          src = Offset(fromRect.left + fromRect.width * 0.3, fromRect.bottom);
          dst = Offset(fromRect.left + fromRect.width * 0.7, fromRect.bottom);
          const loopH = 20.0;
          path.moveTo(src.dx, src.dy);
          path.cubicTo(
            src.dx - 10, src.dy + loopH,
            dst.dx + 10, dst.dy + loopH,
            dst.dx, dst.dy,
          );
          _drawArrowHead(canvas, arrowHeadPaint, dst, _ArrowDirection.up);
        } else if (toRect.left >= fromRect.right - 4) {
          src = Offset(fromRect.right, fromRect.center.dy);
          dst = Offset(toRect.left, toRect.center.dy);
          path.moveTo(src.dx, src.dy);
          if ((src.dy - dst.dy).abs() < 2) {
            path.lineTo(dst.dx, dst.dy);
          } else {
            final midX = src.dx + (dst.dx - src.dx) * 0.5;
            path.cubicTo(midX, src.dy, midX, dst.dy, dst.dx, dst.dy);
          }
          if (edge.directed) {
            _drawArrowHead(canvas, arrowHeadPaint, dst, _ArrowDirection.right);
          }
        } else {
          src = Offset(fromRect.center.dx, fromRect.bottom);
          dst = Offset(toRect.center.dx, toRect.bottom);
          final bottomY = (fromRect.bottom > toRect.bottom ? fromRect.bottom : toRect.bottom) + 24.0;
          path.moveTo(src.dx, src.dy);
          path.cubicTo(src.dx, bottomY, dst.dx, bottomY, dst.dx, dst.dy);
          if (edge.directed) {
            _drawArrowHead(canvas, arrowHeadPaint, dst, _ArrowDirection.up);
          }
        }
      }

      if (edge.dashed) {
        _drawDashedPath(canvas, path, linePaint);
      } else {
        canvas.drawPath(path, linePaint);
      }

      if (edge.label.isNotEmpty) {
        final mid = Offset((src.dx + dst.dx) / 2, (src.dy + dst.dy) / 2);
        _drawEdgeLabel(canvas, edge.label, mid);
      }
    }
  }

  void _drawArrowHead(Canvas canvas, Paint paint, Offset dst, _ArrowDirection dir) {
    final path = Path();
    switch (dir) {
      case _ArrowDirection.down:
        path.moveTo(dst.dx, dst.dy);
        path.lineTo(dst.dx - 4.5, dst.dy - 7.0);
        path.lineTo(dst.dx + 4.5, dst.dy - 7.0);
        break;
      case _ArrowDirection.up:
        path.moveTo(dst.dx, dst.dy);
        path.lineTo(dst.dx - 4.5, dst.dy + 7.0);
        path.lineTo(dst.dx + 4.5, dst.dy + 7.0);
        break;
      case _ArrowDirection.right:
        path.moveTo(dst.dx, dst.dy);
        path.lineTo(dst.dx - 7.0, dst.dy - 4.5);
        path.lineTo(dst.dx - 7.0, dst.dy + 4.5);
        break;
      case _ArrowDirection.left:
        path.moveTo(dst.dx, dst.dy);
        path.lineTo(dst.dx + 7.0, dst.dy - 4.5);
        path.lineTo(dst.dx + 7.0, dst.dy + 4.5);
        break;
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final len = (distance + 4.0 < metric.length) ? 4.0 : (metric.length - distance);
        canvas.drawPath(metric.extractPath(distance, distance + len), paint);
        distance += 8.0;
      }
    }
  }

  void _drawEdgeLabel(Canvas canvas, String label, Offset center) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize * 0.74,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: tp.width + 12,
        height: tp.height + 6,
      ),
      const Radius.circular(5),
    );

    final bgPaint = Paint()
      ..color = MoscaroTokens.backgroundSurface
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(pillRect, bgPaint);
    canvas.drawRRect(pillRect, borderPaint);
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DiagramEdgesPainter oldDelegate) => true;
}
