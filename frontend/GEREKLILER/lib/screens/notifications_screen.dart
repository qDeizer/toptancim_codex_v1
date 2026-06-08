import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../models/notification_model.dart';
import 'package:intl/intl.dart';
import '../services/image_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () {
               Provider.of<NotificationProvider>(context, listen: false).markAllAsRead();
            },
            tooltip: 'Tümünü okundu işaretle',
          )
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (ctx, notificationProvider, _) {
          if (notificationProvider.isLoading && notificationProvider.notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (notificationProvider.notifications.isEmpty) {
            return const Center(child: Text('Bildiriminiz yok.'));
          }

          return RefreshIndicator(
            onRefresh: () => notificationProvider.fetchNotifications(page: 1),
            child: ListView.builder(
              itemCount: notificationProvider.notifications.length,
              itemBuilder: (ctx, index) {
                final notification = notificationProvider.notifications[index];
                return NotificationItem(notification: notification);
              },
            ),
          );
        },
      ),
    );
  }
}

class NotificationItem extends StatelessWidget {
  final NotificationModel notification;

  const NotificationItem({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: notification.isRead ? Colors.white : Colors.blue.shade50,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        leading: notification.actorPhoto != null
            ? CircleAvatar(backgroundImage: NetworkImage(ImageService.getFullImageUrl(notification.actorPhoto)))
            : _getIconForType(notification.type),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             if (notification.actorName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  notification.actorName!,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey),
                ),
              ),
            Text(notification.message),
            const SizedBox(height: 5),
            Text(
              DateFormat('dd/MM/yyyy HH:mm').format(notification.createdAt),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        onTap: () {
          if (!notification.isRead) {
            Provider.of<NotificationProvider>(context, listen: false).markAsRead(notification.id);
          }
           // TODO: Navigate to related item if possible
        },
      ),
    );
  }

  Widget _getIconForType(String type) {
    switch (type) {
      case 'order_update':
        return const Icon(Icons.local_shipping, color: Colors.blue);
      case 'transaction':
        return const Icon(Icons.attach_money, color: Colors.green);
      case 'system':
         return const Icon(Icons.info, color: Colors.orange);
      default:
        return const Icon(Icons.notifications);
    }
  }
}
