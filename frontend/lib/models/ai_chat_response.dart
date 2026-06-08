class AiTraceStep {
  final String id;
  final String stage;
  final String status;
  final String title;
  final String summary;
  final String? details;
  final Map<String, dynamic> meta;
  final DateTime? timestamp;

  AiTraceStep({
    required this.id,
    required this.stage,
    required this.status,
    required this.title,
    required this.summary,
    required this.details,
    required this.meta,
    required this.timestamp,
  });

  factory AiTraceStep.fromJson(Map<String, dynamic> json) {
    return AiTraceStep(
      id: json['id']?.toString() ?? '',
      stage: json['stage']?.toString() ?? 'unknown',
      status: json['status']?.toString() ?? 'completed',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      details: json['details']?.toString(),
      meta: (json['meta'] as Map?)?.cast<String, dynamic>() ?? {},
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? ''),
    );
  }
}

class AiChatResponse {
  final String response;
  final List<AiTraceStep> trace;
  final Map<String, dynamic> meta;

  AiChatResponse({
    required this.response,
    required this.trace,
    required this.meta,
  });

  factory AiChatResponse.fromJson(Map<String, dynamic> json) {
    return AiChatResponse(
      response: json['response']?.toString() ?? '',
      trace: (json['trace'] as List? ?? [])
          .map((item) => AiTraceStep.fromJson(
                (item as Map).cast<String, dynamic>(),
              ))
          .toList(),
      meta: (json['meta'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }
}

class AiServiceException implements Exception {
  final String message;
  final List<AiTraceStep> trace;

  AiServiceException(this.message, {this.trace = const []});

  @override
  String toString() => message;
}
