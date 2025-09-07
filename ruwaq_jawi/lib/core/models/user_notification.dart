import 'app_notification.dart';

class UserNotificationItem {
  final String id; // user_notifications.id
  final String userId;
  final DateTime deliveredAt;
  final DateTime? readAt;
  final AppNotification notification;

  const UserNotificationItem({
    required this.id,
    required this.userId,
    required this.deliveredAt,
    required this.readAt,
    required this.notification,
  });

  factory UserNotificationItem.fromJoinedMap(Map<String, dynamic> map, String userId) {
    final notifMap = map['notifications'] as Map<String, dynamic>;
    return UserNotificationItem(
      id: map['id'] as String,
      userId: userId,
      deliveredAt: DateTime.parse(map['delivered_at'] as String),
      readAt: map['read_at'] == null ? null : DateTime.parse(map['read_at'] as String),
      notification: AppNotification.fromMap(notifMap),
    );
  }
}
