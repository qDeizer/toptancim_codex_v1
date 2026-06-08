import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/notification_model.dart';
import '../utils/logger.dart';

class NotificationService {
  Future<Map<String, dynamic>> getNotifications(String token, {int page = 1, int limit = 20}) async {
    final url = Uri.parse('${Constants.baseUrl}/notifications?page=$page&limit=$limit');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final notifications = (data['notifications'] as List)
            .map((item) => NotificationModel.fromJson(item))
            .toList();
        
        return {
          'notifications': notifications,
          'total': data['total'],
          'unreadCount': data['unreadCount'],
          'page': data['page'],
          'totalPages': data['totalPages'],
        };
      } else {
        AppLogger.error('Failed to load notifications: ${response.statusCode} ${response.body}');
        throw Exception('Failed to load notifications');
      }
    } catch (e) {
      AppLogger.error('NotificationService error', e);
      rethrow;
    }
  }

  Future<void> markAsRead(String token, String notificationId) async {
    final url = Uri.parse('${Constants.baseUrl}/notifications/mark-read/$notificationId');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        AppLogger.error('Failed to mark read: ${response.statusCode}');
        throw Exception('Failed to mark as read');
      }
    } catch (e) {
      AppLogger.error('NotificationService markRead error', e);
      rethrow;
    }
  }

  Future<int> getUnreadCount(String token) async {
    final url = Uri.parse('${Constants.baseUrl}/notifications/unread-count');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['count'];
      } else {
         return 0;
      }
    } catch (e) {
       return 0;
    }
  }
}
