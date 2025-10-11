import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:ruwaq_jawi/core/services/supabase_service.dart';

class AdminNotificationManager {
  /// Fetch all admin notifications from database
  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        debugPrint('❌ No user logged in');
        return [];
      }

      // Call the database function to get admin notifications
      final response = await SupabaseService.client
          .rpc('get_admin_notifications', params: {'admin_user_id': userId});

      if (response == null) return [];

      final notifications = <Map<String, dynamic>>[];

      for (final item in response as List<dynamic>) {
        final data = item as Map<String, dynamic>;
        notifications.add({
          'id': data['id'],
          'title': data['title'] ?? '',
          'subtitle': data['subtitle'] ?? '',
          'fullDescription': data['full_description'] ?? '',
          'time': data['time_ago'] ?? 'Baru sahaja',
          'icon': _getIconData(data['icon'] as String?, data['notification_type'] as String?),
          'iconColor': _getColorFromString(data['icon_color'] as String?),
          'type': data['notification_type'] ?? 'system',
          'isRead': data['is_read'] ?? false,
          'metadata': data['metadata'] ?? {},
        });
      }

      return notifications;
    } catch (e) {
      debugPrint('❌ Error fetching admin notifications: $e');
      return [];
    }
  }

  /// Get unread notification count
  Future<int> getNotificationCount() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return 0;

      final count = await SupabaseService.client
          .rpc('get_unread_notification_count', params: {'p_user_id': userId});

      return count as int? ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting notification count: $e');
      return 0;
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return;

      await SupabaseService.client.rpc('mark_notification_as_read', params: {
        'p_notification_id': notificationId,
        'p_user_id': userId,
      });

      debugPrint('✅ Notification $notificationId marked as read');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return;

      await SupabaseService.client.rpc('mark_all_notifications_as_read', params: {
        'p_user_id': userId,
      });

      debugPrint('✅ All notifications marked as read');
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
    }
  }

  // Helper method to get icon data from string
  IconData _getIconData(String? icon, String? type) {
    // If emoji icon provided, use default based on type
    switch (type) {
      case 'ebook':
        return HugeIcons.strokeRoundedBook02;
      case 'video_kitab':
        return HugeIcons.strokeRoundedVideo01;
      case 'payment':
        return HugeIcons.strokeRoundedDollarCircle;
      case 'user_stats':
        return HugeIcons.strokeRoundedUserMultiple;
      case 'admin_notification':
        return HugeIcons.strokeRoundedNotification03;
      default:
        return HugeIcons.strokeRoundedSystemUpdate02;
    }
  }

  // Helper method to convert color string to Color
  Color _getColorFromString(String? colorString) {
    if (colorString == null) return const Color(0xFF00BF6D);

    switch (colorString.toLowerCase()) {
      case 'orange':
        return Colors.orange;
      case 'blue':
        return Colors.blue;
      case '#00bf6d':
        return const Color(0xFF00BF6D);
      case '#ffd700':
        return const Color(0xFFFFD700);
      default:
        return const Color(0xFF00BF6D);
    }
  }
}
