import 'package:flutter/material.dart';
import '../../services/workspace_storage_service.dart';
import '../../theme/moscaro_v2_extension.dart';
import '../../theme/moscaro_v2_tokens.dart';
import '../note_models.dart';
import '../svg_icon.dart';

/// Modelo de mensagem do Chat Global de IA da PÃ¡gina Inicial
class HomeAiChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> referencedNoteTitles;

  HomeAiChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.referencedNoteTitles = const [],
  });
}

/// Interface completa do Chat Global de IA com o contexto de todas as notas do Workspace.
class HomeAiChatView extends StatefulWidget {
  final ValueChanged<NoteDocument>? onOpenNoteRequested;

  const HomeAiChatView({
    super.key,
    this.onOpenNoteRequested,
  });

  @override
  State<HomeAiChatView> createState() => _HomeAiChatViewState();
}

class _HomeAiChatViewState extends State<HomeAiChatView> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isProcessing = false;

  final List<HomeAiChatMessage> _messages = [
    HomeAiChatMessage(
      id: 'init_1',
      text: 'OlÃ¡! Sou o assistente de inteligÃªncia conNotes. Tenho acesso completo ao contexto e fÃ³rmulas de todas as notas do seu workspace. Como posso ajudar em seus estudos ou pesquisas hoje?',
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];

  final List<String> _quickSuggestions = [
    'Resuma os conceitos chave das minhas notas de FÃ­sica',
    'Existe alguma contradiÃ§Ã£o nas anotaÃ§Ãµes de CÃ¡lculo?',
    'Gere um mapa mental dos tÃ³picos recentes',
    'Quais fÃ³rmulas foram anotadas esta semana?',
  ];

  void _sendMessage(String text) {
    final query = text.trim();
    if (query.isEmpty || _isProcessing) return;

    final userMsg = HomeAiChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: query,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isProcessing = true;
    });
    _promptController.clear();
    _scrollToBottom();

    // SimulaÃ§Ã£o inteligente de resposta com base no workspace real
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;

      final allNotes = WorkspaceStorageService.instance.allNotes;
      final matchedNotes = allNotes
          .where((n) => query.toLowerCase().contains(n.title.toLowerCase()) ||
              n.tags.any((t) => query.toLowerCase().contains(t.toLowerCase())))
          .toList();

      final responseText = matchedNotes.isNotEmpty
          ? 'Encontrei referÃªncias diretas em ${matchedNotes.length} nota(s): "${matchedNotes.first.title}". Analisando os cartÃµes e diagramas, identifiquei as relaÃ§Ãµes estruturais e os passos de demonstraÃ§Ã£o correspondentes.'
          : 'Com base nas ${allNotes.length} notas indexadas no seu workspace, compilei uma sÃ­ntese abrangente estruturada por tÃ³picos lÃ³gicos e variÃ¡veis fundamentais.';

      final aiMsg = HomeAiChatMessage(
        id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
        text: responseText,
        isUser: false,
        timestamp: DateTime.now(),
        referencedNoteTitles: matchedNotes.map((n) => n.title).toList(),
      );

      setState(() {
        _messages.add(aiMsg);
        _isProcessing = false;
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = MoscaroTokens.isLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header do Chat
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MoscaroTokens.auroraBlue.withValues(alpha: isLight ? 0.15 : 0.2),
                border: Border.all(
                  color: MoscaroTokens.auroraBlue.withValues(alpha: 0.6),
                  width: 1.0,
                ),
              ),
              child: Center(
                child: SvgIcon(
                  name: 'ai',
                  size: 18,
                  color: MoscaroTokens.auroraBlue,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assistente Global conNotes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: isLight ? const Color(0xFF0F172A) : Colors.white,
                  ),
                ),
                AnimatedBuilder(
                  animation: WorkspaceStorageService.instance,
                  builder: (context, _) {
                    final count = WorkspaceStorageService.instance.allNotes.length;
                    return Text(
                      '$count notas indexadas em memÃ³ria local',
                      style: TextStyle(
                        fontSize: 12,
                        color: isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Lista de Mensagens
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _messages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final msg = _messages[index];
              return _buildMessageBubble(msg, isLight);
            },
          ),
        ),

        if (_isProcessing)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    valueColor: AlwaysStoppedAnimation<Color>(MoscaroTokens.auroraBlue),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Analisando notas e gerando resposta...',
                  style: TextStyle(
                    fontSize: 12,
                    color: isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),

        // SugestÃµes RÃ¡pidas (Chips)
        if (_messages.length <= 2) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _quickSuggestions.map((sug) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0, bottom: 10),
                  child: InkWell(
                    onTap: () => _sendMessage(sug),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isLight ? const Color(0x100F172A) : const Color(0x18FFFFFF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isLight ? const Color(0x200F172A) : const Color(0x20334155),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgIcon(
                            name: 'sparkle',
                            size: 11,
                            color: MoscaroTokens.auroraBlue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            sug,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isLight ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        // Campo de entrada de Prompt com Glassmorphism
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isLight ? const Color(0xE8FFFFFF) : const Color(0xEB121622),
            borderRadius: BorderRadius.circular(MoscaroTokens.radiusButton),
            border: Border.all(
              color: MoscaroTokens.auroraBlue.withValues(alpha: isLight ? 0.35 : 0.4),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promptController,
                  onSubmitted: _sendMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: isLight ? const Color(0xFF0F172A) : Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Pergunte sobre qualquer nota, fÃ³rmula ou resumo...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isLight ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _sendMessage(_promptController.text),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: MoscaroTokens.auroraBlue,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: MoscaroTokens.auroraBlue.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: SvgIcon(
                      name: 'send',
                      size: 15,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ).moscaroV2(
          borderRadius: MoscaroTokens.radiusButton,
          blurSigma: 16.0,
          enableBlur: true,
        ),
      ],
    );
  }

  Widget _buildMessageBubble(HomeAiChatMessage msg, bool isLight) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 540),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: MoscaroTokens.auroraBlue.withValues(alpha: isLight ? 0.2 : 0.25),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(
              color: MoscaroTokens.auroraBlue.withValues(alpha: 0.7),
              width: 1.0,
            ),
          ),
          child: Text(
            msg.text,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: isLight ? const Color(0xFF0F172A) : Colors.white,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isLight ? const Color(0xF0FFFFFF) : const Color(0xEE121622),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(14),
          ),
          border: Border.all(
            color: isLight ? const Color(0x200F172A) : const Color(0x28334155),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgIcon(
                  name: 'sparkle',
                  size: 13,
                  color: MoscaroTokens.auroraBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  'conNotes AI',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: MoscaroTokens.auroraBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              msg.text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: isLight ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
            if (msg.referencedNoteTitles.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: msg.referencedNoteTitles.map((title) {
                  return InkWell(
                    onTap: () {
                      final notes = WorkspaceStorageService.instance.allNotes;
                      final target = notes.firstWhere(
                        (n) => n.title == title,
                        orElse: () => notes.first,
                      );
                      widget.onOpenNoteRequested?.call(target);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: MoscaroTokens.auroraBlue.withValues(alpha: isLight ? 0.12 : 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: MoscaroTokens.auroraBlue.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgIcon(
                            name: 'file',
                            size: 11,
                            color: MoscaroTokens.auroraBlue,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: MoscaroTokens.auroraBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

