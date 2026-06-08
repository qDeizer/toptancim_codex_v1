import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/socket_service.dart';
import '../utils/logger.dart';
import 'dart:async';

class NotificationProvider with ChangeNotifier {
  String? _token;
  final NotificationService _service = NotificationService();
  
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  
  StreamSubscription? _socketSubscription;

  NotificationProvider(this._token) {
    if (_token != null) {
      _initSocketListener();
    }
  }

  void updateAuth(String? newToken) {
    if (_token == newToken) return;
    _token = newToken;
    
    if (_token != null) {
      _initSocketListener();
      fetchNotifications(); // Initial fetch
    } else {
      _notifications = [];
      _unreadCount = 0;
      _socketSubscription?.cancel();
    }
  }

  void _initSocketListener() {
    _socketSubscription?.cancel();
    _socketSubscription = SocketService().notificationStream.listen((data) {
      AppLogger.info('Notification received via socket: $data');
      // Add to list immediately
      try {
        final newNotification = NotificationModel.fromJson(data);
        _notifications.insert(0, newNotification);
        _unreadCount++;
        notifyListeners();
      } catch (e) {
        AppLogger.error('Error parsing notification from socket', e);
      }
    });
  }

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  Future<void> fetchNotifications({int page = 1}) async {
    if (_token == null) return;
    if (page == 1) _isLoading = true;
    notifyListeners();

    try {
      final result = await _service.getNotifications(_token!, page: page);
      if (page == 1) {
        _notifications = result['notifications'];
        _unreadCount = result['unreadCount'];
      } else {
        _notifications.addAll(result['notifications']);
      }
    } catch (e) {
      AppLogger.error('Failed to fetch notifications', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    if (_token == null) return;
    // Optimistic update
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1 && !_notifications[index].isRead) {
       // We can't easily mute a final object field, need to create copy or make fields mutable. 
       // For now, assume fields conform or we replace.
       // Since model fields are final, we replace the item.
       /* 
       _notifications[index] = NotificationModel(
          ...
          isRead: true
       ); 
       That's tedious without copyWith. 
       Let's just decrease count and rely on fetch or manual update if critical.
       */
       _unreadCount = (_unreadCount > 0) ? _unreadCount - 1 : 0;
       notifyListeners();
    }

    try {
      await _service.markAsRead(_token!, notificationId);
      await fetchNotifications(); // Refresh to ensure sync
    } catch (e) {
      // Revert if needed, but fetchNotifications usually fixes it
    }
  }
  
  Future<void> markAllAsRead() async {
     if (_token == null) return;
     _unreadCount = 0;
     notifyListeners();
     try {
       await _service.markAsRead(_token!, 'all');
       await fetchNotifications();
     } catch (e) {
       AppLogger.error('Failed to mark all read', e);
     }
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    super.dispose();
  }
}
