class MediaItem {
  final String mediaId;
  final String userId;
  final String filename;
  final String url;
  final String type;
  bool isFavorite;
  final String? prompt;
  final DateTime? createdAt;

  MediaItem({
    required this.mediaId,
    required this.userId,
    required this.filename,
    required this.url,
    this.type = 'image',
    this.isFavorite = false,
    this.prompt,
    this.createdAt,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      mediaId: json['media_id'] ?? '',
      userId: json['user_id'] ?? '',
      filename: json['filename'] ?? '',
      url: json['url'] ?? '',
      type: json['type'] ?? 'image',
      isFavorite: json['is_favorite'] ?? false,
      prompt: json['prompt'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }
}
