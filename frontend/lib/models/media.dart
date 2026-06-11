class MediaItem {
  final String mediaId;
  final String userId;
  final String filename;
  final String url;
  final String type;
  bool isFavorite;
  final String? prompt;
  final String status; // ready | generating | failed
  final String source; // upload | ai
  final String? errorMessage;
  final List<Map<String, dynamic>>? usedIn; // [{product_id, name}]
  final DateTime? createdAt;

  MediaItem({
    required this.mediaId,
    required this.userId,
    required this.filename,
    required this.url,
    this.type = 'image',
    this.isFavorite = false,
    this.prompt,
    this.status = 'ready',
    this.source = 'upload',
    this.errorMessage,
    this.usedIn,
    this.createdAt,
  });

  bool get isGenerating => status == 'generating';
  bool get isFailed => status == 'failed';
  bool get isReady => status == 'ready';
  bool get isAi => source == 'ai';
  bool get isUsed => usedIn != null && usedIn!.isNotEmpty;

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      mediaId: json['media_id'] ?? '',
      userId: json['user_id'] ?? '',
      filename: json['filename'] ?? '',
      url: json['url'] ?? '',
      type: json['type'] ?? 'image',
      isFavorite: json['is_favorite'] ?? false,
      prompt: json['prompt'],
      status: json['status'] ?? 'ready',
      source: json['source'] ?? 'upload',
      errorMessage: json['error_message'],
      usedIn: json['used_in'] is List ? List<Map<String, dynamic>>.from(json['used_in'].map((e) => Map<String, dynamic>.from(e))) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }
}
