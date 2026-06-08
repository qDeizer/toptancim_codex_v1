import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../models/ai_chat_response.dart';
import '../models/connection.dart';
import '../providers/ai_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/connection_provider.dart';
import '../services/ai_settings_service.dart';
import '../utils/logger.dart';

class AnalysisPlusScreen extends StatefulWidget {
  final String? userId;
  final String? userDisplayName;

  const AnalysisPlusScreen({
    super.key,
    this.userId,
    this.userDisplayName,
  });

  @override
  State<AnalysisPlusScreen> createState() => _AnalysisPlusScreenState();
}

class _AnalysisPlusScreenState extends State<AnalysisPlusScreen> {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiSettingsService _aiSettingsService = AiSettingsService();

  String? _selectedTargetUserId;
  int _chatResetSeconds = 15;
  int _chatRequestTimeoutMs = 95000;
  int _lastKnownMessageCount = 0;

  bool get _isFixedProfileContext => widget.userId != null;
  String? get _effectiveTargetUserId => widget.userId ?? _selectedTargetUserId;
  String get _conversationKey => _effectiveTargetUserId == null
      ? 'analysis:self'
      : 'analysis:pair:${_effectiveTargetUserId!}';

  @override
  void initState() {
    super.initState();
    AppLogger.info(
      'AnalysisPlus screen initialized: fixedProfileContext=$_isFixedProfileContext, targetUserId=${widget.userId ?? "self"}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_isFixedProfileContext) {
        final connectionProvider = context.read<ConnectionProvider>();
        if (!connectionProvider.isLoading &&
            connectionProvider.allConnections.isEmpty) {
          AppLogger.info('AnalysisPlus requesting connection list');
          connectionProvider.fetchConnections();
        }
      }

      _activateConversationScope();
      await _loadChatResetSettings();
    });
  }

  @override
  void dispose() {
    if (mounted) {
      context.read<AiProvider>().scheduleResetForActiveConversation(
            seconds: _chatResetSeconds,
          );
    }
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChatResetSettings() async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      final settings = await _aiSettingsService.fetchSettings(token);
      if (!mounted) {
        return;
      }
      context
          .read<AiProvider>()
          .updateRequestTimeoutMs(settings.chatRequestTimeoutMs);
      setState(() {
        _chatResetSeconds = settings.chatResetSeconds;
        _chatRequestTimeoutMs = settings.chatRequestTimeoutMs;
      });
      AppLogger.info(
        'AnalysisPlus loaded AI chat settings: resetSeconds=$_chatResetSeconds, requestTimeoutMs=$_chatRequestTimeoutMs',
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'AnalysisPlus failed to load chat reset settings',
        error,
        stackTrace,
      );
    }
  }

  void _activateConversationScope() {
    AppLogger.info(
      'AnalysisPlus activating conversation scope: key=$_conversationKey',
    );
    context.read<AiProvider>().activateConversation(_conversationKey);
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) {
      AppLogger.debug('AnalysisPlus ignored empty message');
      return;
    }

    AppLogger.info(
      'AnalysisPlus sending message: targetUserId=${_effectiveTargetUserId ?? "self"}, length=${text.trim().length}',
    );
    _questionController.clear();

    final aiProvider = context.read<AiProvider>();
    await aiProvider.sendMessage(
      text,
      targetUserId: _effectiveTargetUserId,
    );

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        AppLogger.debug('AnalysisPlus scrolling to bottom');
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final aiProvider = context.watch<AiProvider>();
    final connectionProvider = context.watch<ConnectionProvider>();
    final selectableConnections = _deduplicateConnections(
      connectionProvider.allConnections,
    );
    final selectedConnection = _findSelectedConnection(selectableConnections);
    final isPairContext = _effectiveTargetUserId != null;
    final title = _buildTitle(selectedConnection);

    if (aiProvider.messages.length != _lastKnownMessageCount) {
      _lastKnownMessageCount = aiProvider.messages.length;
      _scrollToBottom();
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sohbeti temizle',
            onPressed: () => context.read<AiProvider>().clearConversation(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildScopeCard(selectableConnections, selectedConnection),
          if (aiProvider.messages.isEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bubble_chart,
                      size: 64,
                      color: Colors.blue.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'AI Satis Asistani',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPairContext
                          ? 'Bu oturumda yalnizca siz ve secili kisi arasindaki satis, finans ve iliski verileri kullanilir.'
                          : 'Bu alanda sadece kendi kayitlariniz, siparisleriniz ve finans hareketleriniz analiz edilir.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sayfadan cikarsaniz sohbet $_chatResetSeconds saniye sonra temizlenir.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black45),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bu ekran icin mevcut AI timeout: ${(_chatRequestTimeoutMs / 1000).toStringAsFixed(_chatRequestTimeoutMs % 1000 == 0 ? 0 : 1)} sn',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black45),
                    ),
                    const SizedBox(height: 32),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: isPairContext
                          ? [
                              _buildActionChip(
                                'Bu kisiyle son satis ve odeme ozeti nedir?',
                              ),
                              _buildActionChip(
                                'Bu kisinin odeme aliskanligi nasil?',
                              ),
                              _buildActionChip(
                                'Bu kisiye benzer musteriler ne aliyor?',
                              ),
                            ]
                          : [
                              _buildActionChip(
                                'En cok hangi urunlerde hareket var?',
                              ),
                              _buildActionChip(
                                'Son donemde satis egilimim nasil?',
                              ),
                              _buildActionChip(
                                'Onumuzdeki ay icin hangi urunleri takip etmeliyim?',
                              ),
                            ],
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: aiProvider.messages.length,
                itemBuilder: (ctx, index) {
                  final msg = aiProvider.messages[index];
                  final isUser = msg.role == 'user';

                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.84,
                      ),
                      decoration: BoxDecoration(
                        color: _messageColor(msg, isUser),
                        borderRadius: BorderRadius.circular(12).copyWith(
                          bottomRight:
                              isUser ? Radius.zero : const Radius.circular(12),
                          bottomLeft:
                              !isUser ? Radius.zero : const Radius.circular(12),
                        ),
                        border: msg.isError
                            ? Border.all(color: Colors.red.shade200)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _buildMessageBody(msg, isUser),
                    ),
                  );
                },
              ),
            ),
          if (aiProvider.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                aiProvider.error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _questionController,
                      decoration: InputDecoration(
                        hintText: 'Sorunuzu buraya yazin...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: aiProvider.isLoading ? null : _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor:
                        aiProvider.isLoading ? Colors.grey : Colors.blueAccent,
                    child: IconButton(
                      icon: aiProvider.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                      onPressed: aiProvider.isLoading
                          ? null
                          : () => _sendMessage(_questionController.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _messageColor(AiMessage message, bool isUser) {
    if (isUser) {
      return Colors.blue.shade100;
    }
    if (message.isError) {
      return Colors.red.shade50;
    }
    if (message.isPending) {
      return Colors.grey.shade50;
    }
    return Colors.white;
  }

  Widget _buildMessageBody(AiMessage message, bool isUser) {
    if (isUser) {
      return Text(message.content);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.isPending)
          const Text(
            'Dusunuyor...',
            style: TextStyle(fontWeight: FontWeight.w700),
          )
        else if (message.content.isNotEmpty)
          _buildMarkdownContent(message.content),
        if (message.trace.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildTracePanel(message.trace),
        ],
      ],
    );
  }

  String _buildTitle(Connection? selectedConnection) {
    if (_isFixedProfileContext) {
      return 'AI Analiz: ${widget.userDisplayName ?? "Kisi"}';
    }

    if (selectedConnection != null) {
      return 'Analiz+ (Ben + ${selectedConnection.displayName})';
    }

    return 'Analiz+ (Sadece Ben)';
  }

  Widget _buildScopeCard(
    List<Connection> selectableConnections,
    Connection? selectedConnection,
  ) {
    if (_isFixedProfileContext) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Text(
          'Bu sohbet yalnizca siz ve ${widget.userDisplayName ?? "secili kisi"} arasindaki verilerle sinirlidir. Sayfadan ciktiktan $_chatResetSeconds saniye sonra sifirlanir.',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analiz kapsami',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            selectedConnection == null
                ? 'Varsayilan olarak sadece kendi veriniz analiz edilir. Isterseniz asagidan bir baglanti secip sohbeti kisi bazli daraltabilirsiniz.'
                : 'Su an sadece siz ve ${selectedConnection.displayName} arasindaki veriler kullaniliyor.',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Text(
            'Bu sohbet ekrandan ciktiktan $_chatResetSeconds saniye sonra otomatik temizlenir.',
            style: const TextStyle(color: Colors.black45),
          ),
          const SizedBox(height: 4),
          Text(
            'AI istek timeout: ${(_chatRequestTimeoutMs / 1000).toStringAsFixed(_chatRequestTimeoutMs % 1000 == 0 ? 0 : 1)} sn',
            style: const TextStyle(color: Colors.black45),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedTargetUserId ?? '',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Kisi secimi',
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('Sadece benim verim'),
              ),
              ...selectableConnections.map(
                (connection) => DropdownMenuItem<String>(
                  value: connection.userId,
                  child: Text(connection.displayName),
                ),
              ),
            ],
            onChanged: (value) {
              final nextTargetId =
                  (value == null || value.isEmpty) ? null : value;
              if (nextTargetId == _selectedTargetUserId) {
                AppLogger.debug('AnalysisPlus scope unchanged');
                return;
              }

              AppLogger.info(
                'AnalysisPlus scope changed: targetUserId=${nextTargetId ?? "self"}',
              );
              setState(() {
                _selectedTargetUserId = nextTargetId;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _activateConversationScope();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(String text) {
    return ActionChip(
      label: Text(text),
      backgroundColor: Colors.blue.shade50,
      side: BorderSide(color: Colors.blue.shade200),
      onPressed: () {
        AppLogger.info(
          'AnalysisPlus quick action selected: targetUserId=${_effectiveTargetUserId ?? "self"}',
        );
        _questionController.text = text;
        _sendMessage(text);
      },
    );
  }

  Widget _buildMarkdownContent(String text) {
    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(fontSize: 14),
        h1: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTracePanel(List<AiTraceStep> trace) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hub_outlined, size: 18, color: Colors.blueGrey),
              SizedBox(width: 6),
              Text(
                'Islem adimlari',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.blueGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...trace.map(_buildTraceStepTile),
        ],
      ),
    );
  }

  Widget _buildTraceStepTile(AiTraceStep step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _buildTraceIcon(step),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (step.summary.isNotEmpty)
                  Text(
                    step.summary,
                    style: const TextStyle(fontSize: 13),
                  ),
                if (step.details != null && step.details!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      step.details!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTraceIcon(AiTraceStep step) {
    switch (step.status) {
      case 'running':
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case 'queued':
        return Icon(
          Icons.radio_button_unchecked,
          size: 16,
          color: Colors.grey.shade500,
        );
      case 'failed':
        return Icon(
          Icons.error_outline,
          size: 16,
          color: Colors.red.shade400,
        );
      default:
        return Icon(
          Icons.check_circle_outline,
          size: 16,
          color: Colors.green.shade600,
        );
    }
  }

  List<Connection> _deduplicateConnections(List<Connection> connections) {
    final uniqueByUserId = <String, Connection>{};
    for (final connection in connections) {
      uniqueByUserId.putIfAbsent(connection.userId, () => connection);
    }

    final items = uniqueByUserId.values.toList();
    items.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return items;
  }

  Connection? _findSelectedConnection(List<Connection> selectableConnections) {
    final targetUserId = _effectiveTargetUserId;
    if (targetUserId == null) {
      return null;
    }

    for (final connection in selectableConnections) {
      if (connection.userId == targetUserId) {
        return connection;
      }
    }

    return null;
  }
}
