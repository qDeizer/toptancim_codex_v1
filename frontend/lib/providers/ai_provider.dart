import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ai_chat_response.dart';
import '../services/ai_service.dart';
import '../utils/logger.dart';

class AiMessage {
  final String role;
  final String content;
  final List<AiTraceStep> trace;
  final bool isPending;
  final bool isError;

  AiMessage({
    required this.role,
    required this.content,
    this.trace = const [],
    this.isPending = false,
    this.isError = false,
  });

  Map<String, String> toMap() {
    return {
      'role': role,
      'content': content,
    };
  }
}

class _AiConversationState {
  final List<AiMessage> messages = [];
  bool isLoading = false;
  String? error;
  Timer? resetTimer;

  void dispose() {
    resetTimer?.cancel();
  }
}

class AiProvider with ChangeNotifier {
  String? _authToken;
  final AiService _aiService = AiService();
  final Map<String, _AiConversationState> _conversations = {};
  int _requestTimeoutMs = 95000;

  String _activeConversationKey = 'analysis:self';

  AiProvider(String? authToken) : _authToken = authToken;

  _AiConversationState get _activeConversation =>
      _conversations.putIfAbsent(_activeConversationKey, _AiConversationState.new);

  List<AiMessage> get messages => List.unmodifiable(_activeConversation.messages);
  bool get isLoading => _activeConversation.isLoading;
  String? get error => _activeConversation.error;
  String get activeConversationKey => _activeConversationKey;
  int get requestTimeoutMs => _requestTimeoutMs;

  void updateAuth(String? token) {
    final didChange = _authToken != token;
    _authToken = token;

    if (didChange) {
      AppLogger.info('AI provider auth updated, all conversations reset');
      _disposeAllConversations();
    }

    notifyListeners();
  }

  void activateConversation(String scopeKey) {
    if (scopeKey.isEmpty) {
      return;
    }

    final didChange = _activeConversationKey != scopeKey;
    _activeConversationKey = scopeKey;
    final conversation = _activeConversation;
    conversation.resetTimer?.cancel();
    conversation.resetTimer = null;

    AppLogger.info(
      'AI provider conversation activated: key=$_activeConversationKey, restoredMessages=${conversation.messages.length}',
    );

    if (didChange) {
      notifyListeners();
    }
  }

  void updateRequestTimeoutMs(int timeoutMs) {
    if (timeoutMs <= 0 || timeoutMs == _requestTimeoutMs) {
      return;
    }

    _requestTimeoutMs = timeoutMs;
    AppLogger.info('AI provider request timeout updated: timeoutMs=$timeoutMs');
    notifyListeners();
  }

  void scheduleResetForActiveConversation({required int seconds}) {
    final key = _activeConversationKey;
    final conversation = _conversations[key];
    if (conversation == null) {
      return;
    }

    conversation.resetTimer?.cancel();
    if (seconds <= 0) {
      _clearConversationKey(key);
      notifyListeners();
      return;
    }

    AppLogger.info(
      'AI provider scheduled conversation reset: key=$key, seconds=$seconds',
    );
    conversation.resetTimer = Timer(Duration(seconds: seconds), () {
      AppLogger.info('AI provider conversation expired: key=$key');
      _clearConversationKey(key);
      notifyListeners();
    });
  }

  void clearConversation({String? scopeKey}) {
    final key = scopeKey ?? _activeConversationKey;
    AppLogger.info('AI provider conversation cleared: key=$key');
    _clearConversationKey(key);
    notifyListeners();
  }

  Future<void> sendMessage(String text, {String? targetUserId}) async {
    final conversation = _activeConversation;

    if (_authToken == null || _authToken!.isEmpty) {
      conversation.error = 'AI istegi icin oturum bilgisi bulunamadi.';
      AppLogger.warning('AI provider blocked message send due to missing auth');
      notifyListeners();
      return;
    }
    if (text.trim().isEmpty) {
      AppLogger.debug('AI provider ignored empty message');
      return;
    }

    conversation.resetTimer?.cancel();
    conversation.resetTimer = null;
    conversation.error = null;
    conversation.isLoading = true;

    conversation.messages.add(AiMessage(role: 'user', content: text));
    conversation.messages.add(
      AiMessage(
        role: 'model',
        content: '',
        isPending: true,
        trace: _buildPendingTrace(targetUserId: targetUserId),
      ),
    );

    AppLogger.info(
      'AI provider send started: key=$_activeConversationKey, messageCount=${conversation.messages.length}, targetUserId=${targetUserId ?? "self"}',
    );
    notifyListeners();

    try {
      final requestMessages = conversation.messages
          .where((m) => !m.isPending && !m.isError)
          .map((m) => m.toMap())
          .toList();
      final response = await _aiService.sendMessage(
        _authToken!,
        requestMessages,
        targetUserId: targetUserId,
        timeoutMs: _requestTimeoutMs,
      );

      _replacePendingAssistantMessage(
        conversation,
        AiMessage(
          role: 'model',
          content: response.response,
          trace: response.trace,
        ),
      );
      AppLogger.info(
        'AI provider send completed: key=$_activeConversationKey, totalMessages=${conversation.messages.length}, traceCount=${response.trace.length}',
      );
    } catch (error, stackTrace) {
      final trace = error is AiServiceException ? error.trace : const <AiTraceStep>[];
      final message = error.toString();
      conversation.error = message;
      _replacePendingAssistantMessage(
        conversation,
        AiMessage(
          role: 'model',
          content: message,
          trace: trace,
          isError: true,
        ),
      );
      AppLogger.error(
        'AI provider send failed',
        error,
        stackTrace,
      );
    } finally {
      conversation.isLoading = false;
      notifyListeners();
    }
  }

  List<AiTraceStep> _buildPendingTrace({String? targetUserId}) {
    final now = DateTime.now();
    return [
      AiTraceStep(
        id: 'pending_filter',
        stage: 'filter_llm',
        status: 'running',
        title: 'Sorgu filtreleniyor',
        summary: 'Soru kapsam ve niyet bazli daraltiliyor.',
        details: targetUserId == null
            ? 'Sadece sizin veriniz dikkate alinacak.'
            : 'Secili kisiyle ortak kapsam icin soru daraltiliyor.',
        meta: const {},
        timestamp: now,
      ),
      AiTraceStep(
        id: 'pending_tools',
        stage: 'tool_call',
        status: 'queued',
        title: 'SQL ve ML araclari hazirlaniyor',
        summary: 'Gerekli sorgular ve analiz araclari siraya alinacak.',
        details: null,
        meta: const {},
        timestamp: now,
      ),
      AiTraceStep(
        id: 'pending_final',
        stage: 'final_llm',
        status: 'queued',
        title: 'Son yanit yazilacak',
        summary: 'Arac ciktilari yorumlanip kullaniciya donulecek.',
        details: null,
        meta: const {},
        timestamp: now,
      ),
    ];
  }

  void _replacePendingAssistantMessage(
    _AiConversationState conversation,
    AiMessage replacement,
  ) {
    for (var index = conversation.messages.length - 1; index >= 0; index--) {
      if (conversation.messages[index].isPending) {
        conversation.messages[index] = replacement;
        return;
      }
    }

    conversation.messages.add(replacement);
  }

  void _clearConversationKey(String key) {
    final existing = _conversations.remove(key);
    existing?.dispose();
  }

  void _disposeAllConversations() {
    for (final conversation in _conversations.values) {
      conversation.dispose();
    }
    _conversations.clear();
  }
}
