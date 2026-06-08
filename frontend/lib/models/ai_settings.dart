class AiProviderConfig {
  final String id;
  final String label;
  final String type;
  final bool enabled;
  final String apiKey;

  AiProviderConfig({
    required this.id,
    required this.label,
    required this.type,
    required this.enabled,
    required this.apiKey,
  });

  AiProviderConfig copyWith({
    String? id,
    String? label,
    String? type,
    bool? enabled,
    String? apiKey,
  }) {
    return AiProviderConfig(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
      apiKey: apiKey ?? this.apiKey,
    );
  }

  factory AiProviderConfig.fromJson(Map<String, dynamic> json) {
    return AiProviderConfig(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      type: json['type']?.toString() ?? 'GEMINI',
      enabled: json['enabled'] ?? true,
      apiKey: json['apiKey']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'type': type,
      'enabled': enabled,
      'apiKey': apiKey,
    };
  }
}

class LocalProviderConfig {
  final bool enabled;
  final String baseUrl;
  final String model;
  final int timeoutMs;
  final String apiToken;
  final bool requiresAuth;

  LocalProviderConfig({
    required this.enabled,
    required this.baseUrl,
    required this.model,
    required this.timeoutMs,
    required this.apiToken,
    required this.requiresAuth,
  });

  LocalProviderConfig copyWith({
    bool? enabled,
    String? baseUrl,
    String? model,
    int? timeoutMs,
    String? apiToken,
    bool? requiresAuth,
  }) {
    return LocalProviderConfig(
      enabled: enabled ?? this.enabled,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      timeoutMs: timeoutMs ?? this.timeoutMs,
      apiToken: apiToken ?? this.apiToken,
      requiresAuth: requiresAuth ?? this.requiresAuth,
    );
  }

  factory LocalProviderConfig.fromJson(Map<String, dynamic> json) {
    return LocalProviderConfig(
      enabled: json['enabled'] ?? true,
      baseUrl: json['baseUrl']?.toString() ?? 'http://localhost:20128/v1',
      model: json['model']?.toString() ?? 'gh/gpt-4o-mini',
      timeoutMs: int.tryParse(json['timeoutMs']?.toString() ?? '') ?? 60000,
      apiToken: json['apiToken']?.toString() ?? '',
      requiresAuth: json['requiresAuth'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'baseUrl': baseUrl,
      'model': model,
      'timeoutMs': timeoutMs,
      'apiToken': apiToken,
      'requiresAuth': requiresAuth,
    };
  }
}

class MlServiceConfig {
  final bool enabled;
  final String baseUrl;
  final int timeoutMs;

  MlServiceConfig({
    required this.enabled,
    required this.baseUrl,
    required this.timeoutMs,
  });

  MlServiceConfig copyWith({
    bool? enabled,
    String? baseUrl,
    int? timeoutMs,
  }) {
    return MlServiceConfig(
      enabled: enabled ?? this.enabled,
      baseUrl: baseUrl ?? this.baseUrl,
      timeoutMs: timeoutMs ?? this.timeoutMs,
    );
  }

  factory MlServiceConfig.fromJson(Map<String, dynamic> json) {
    return MlServiceConfig(
      enabled: json['enabled'] ?? true,
      baseUrl: json['baseUrl']?.toString() ?? 'http://127.0.0.1:8000',
      timeoutMs: int.tryParse(json['timeoutMs']?.toString() ?? '') ?? 120000,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'baseUrl': baseUrl,
      'timeoutMs': timeoutMs,
    };
  }
}

class AiSettings {
  final String strategy;
  final String geminiModel;
  final bool fallbackToLocal;
  final int chatResetSeconds;
  final int chatRequestTimeoutMs;
  final List<AiProviderConfig> providers;
  final MlServiceConfig mlService;
  final LocalProviderConfig localProvider;

  AiSettings({
    required this.strategy,
    required this.geminiModel,
    required this.fallbackToLocal,
    required this.chatResetSeconds,
    required this.chatRequestTimeoutMs,
    required this.providers,
    required this.mlService,
    required this.localProvider,
  });

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    return AiSettings(
      strategy: json['strategy']?.toString() ?? 'AUTO',
      geminiModel:
          json['geminiModel']?.toString() ?? 'gemini-2.5-flash',
      fallbackToLocal: json['fallbackToLocal'] ?? true,
      chatResetSeconds:
          int.tryParse(json['chatResetSeconds']?.toString() ?? '') ?? 15,
      chatRequestTimeoutMs:
          int.tryParse(json['chatRequestTimeoutMs']?.toString() ?? '') ?? 95000,
      providers: (json['providers'] as List? ?? [])
          .map((item) => AiProviderConfig.fromJson(item))
          .toList(),
      mlService: MlServiceConfig.fromJson(
        (json['mlService'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      localProvider: LocalProviderConfig.fromJson(
        (json['localProvider'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'strategy': strategy,
      'geminiModel': geminiModel,
      'fallbackToLocal': fallbackToLocal,
      'chatResetSeconds': chatResetSeconds,
      'chatRequestTimeoutMs': chatRequestTimeoutMs,
      'providers': providers.map((provider) => provider.toJson()).toList(),
      'mlService': mlService.toJson(),
      'localProvider': localProvider.toJson(),
    };
  }

  AiSettings copyWith({
    String? strategy,
    String? geminiModel,
    bool? fallbackToLocal,
    int? chatResetSeconds,
    int? chatRequestTimeoutMs,
    List<AiProviderConfig>? providers,
    MlServiceConfig? mlService,
    LocalProviderConfig? localProvider,
  }) {
    return AiSettings(
      strategy: strategy ?? this.strategy,
      geminiModel: geminiModel ?? this.geminiModel,
      fallbackToLocal: fallbackToLocal ?? this.fallbackToLocal,
      chatResetSeconds: chatResetSeconds ?? this.chatResetSeconds,
      chatRequestTimeoutMs: chatRequestTimeoutMs ?? this.chatRequestTimeoutMs,
      providers: providers ?? this.providers,
      mlService: mlService ?? this.mlService,
      localProvider: localProvider ?? this.localProvider,
    );
  }
}
