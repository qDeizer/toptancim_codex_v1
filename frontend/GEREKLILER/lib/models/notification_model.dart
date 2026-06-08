class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final String? relatedId;
  final String? actorId;
  final String? actorName;
  final String? actorPhoto;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.relatedId,
    this.actorId,
    this.actorName,
    this.actorPhoto,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['notification_id'],
      userId: json['user_id'],
      title: json['title'],
      message: json['message'],
      type: json['type'],
      relatedId: json['related_id'],
      actorId: json['actor_id'],
      actorName: json['actor_name'],
      actorPhoto: json['actor_photo'],
      data: json['data'] ?? {},
      isRead: json['is_read'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
