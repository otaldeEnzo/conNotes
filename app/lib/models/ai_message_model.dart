import 'package:flutter/foundation.dart';

enum AiMessageRole {
  user,
  assistant,
  system,
}

enum InferredCardType {
  stemText,
  mermaidDiagram,
  plotGraph,
  codeBlock,
}

/// Ação contextual sugerida pela IA abaixo da resposta
class AiDynamicAction {
  final String id;
  final String label;
  final String iconName;

  const AiDynamicAction({
    required this.id,
    required this.label,
    required this.iconName,
  });
}

/// Modelo de mensagem no histórico do chat da IA
class AiMessage {
  final String id;
  final AiMessageRole role;
  final String content;
  final DateTime timestamp;
  final bool isStreaming;
  final String? modelName;
  final String? errorMessage;
  final List<AiDynamicAction> dynamicActions;

  const AiMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isStreaming = false,
    this.modelName,
    this.errorMessage,
    this.dynamicActions = const [],
  });

  AiMessage copyWith({
    String? id,
    AiMessageRole? role,
    String? content,
    DateTime? timestamp,
    bool? isStreaming,
    String? modelName,
    String? errorMessage,
    List<AiDynamicAction>? dynamicActions,
  }) {
    return AiMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      modelName: modelName ?? this.modelName,
      errorMessage: errorMessage ?? this.errorMessage,
      dynamicActions: dynamicActions ?? this.dynamicActions,
    );
  }

  /// Identifica automaticamente o melhor tipo de Card para o Drag and Drop no Canvas
  InferredCardType get inferredCardType {
    if (content.contains('```mermaid')) {
      return InferredCardType.mermaidDiagram;
    }
    if (content.contains('```python') ||
        content.contains('```dart') ||
        content.contains('```cpp') ||
        content.contains('```rust')) {
      return InferredCardType.codeBlock;
    }
    if (content.contains('f(x)') && content.contains('plot')) {
      return InferredCardType.plotGraph;
    }
    return InferredCardType.stemText;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'modelName': modelName,
      'errorMessage': errorMessage,
    };
  }

  factory AiMessage.fromJson(Map<String, dynamic> json) {
    return AiMessage(
      id: json['id'] as String? ?? UniqueKey().toString(),
      role: AiMessageRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => AiMessageRole.assistant,
      ),
      content: json['content'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      modelName: json['modelName'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}
