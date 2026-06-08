import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_chat_response.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

class AiService {
  Future<AiChatResponse> sendMessage(
    String token,
    List<Map<String, String>> messages, {
    String? targetUserId,
    int timeoutMs = 95000,
  }) async {
    final stopwatch = Stopwatch()..start();
    final requestTimeout = Duration(milliseconds: timeoutMs);

    try {
      AppLogger.info(
        'AI service request started: messageCount=${messages.length}, targetUserId=${targetUserId ?? "self"}, timeoutMs=$timeoutMs',
      );

      final response = await http
          .post(
            Uri.parse('${Constants.baseUrl}/ai/chat'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'messages': messages,
              'targetUserId': targetUserId,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = AiChatResponse.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)),
        );
        AppLogger.info(
          'AI service request completed: status=${response.statusCode}, responseLength=${data.response.length}, traceCount=${data.trace.length}, durationMs=${stopwatch.elapsedMilliseconds}',
        );
        return data;
      }

      final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
      final errorMsg = errorBody['error'] ?? 'Bilinmeyen hata';
      final trace = (errorBody['trace'] as List? ?? [])
          .map((item) => AiTraceStep.fromJson((item as Map).cast<String, dynamic>()))
          .toList();
      AppLogger.warning(
        'AI service request failed: status=${response.statusCode}, targetUserId=${targetUserId ?? "self"}, durationMs=${stopwatch.elapsedMilliseconds}',
        errorMsg,
      );
      throw AiServiceException(
        'API Hatasi [${response.statusCode}]: $errorMsg',
        trace: trace,
      );
    } on TimeoutException catch (error, stackTrace) {
      AppLogger.warning(
        'AI service request timed out after ${requestTimeout.inMilliseconds}ms: targetUserId=${targetUserId ?? "self"}',
        error,
        stackTrace,
      );
      throw AiServiceException(
        'AI yaniti beklenirken zaman asimi olustu. LM Studio veya secili AI saglayicisini kontrol edin.',
      );
    } catch (error, stackTrace) {
      if (error is AiServiceException) {
        AppLogger.warning(
          'AI service rethrowing API error',
          error,
          stackTrace,
        );
        rethrow;
      }
      AppLogger.error(
        'AI service transport failure',
        error,
        stackTrace,
      );
      throw AiServiceException('Baglanti hatasi: $error');
    }
  }
}
