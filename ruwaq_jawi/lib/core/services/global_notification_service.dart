import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Service for handling smart notifications efficiently
/// Uses optimized queries and duplicate prevention
class SmartNotificationService {
  static final _supabase = Supabase.instance.client;

  /// Get unread notifications for current user (optimized query)
  static Future<List<SmartNotification>> getUnreadNotifications() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      // Get unread notifications with optimized query
      final response = await _supabase
          .from('user_notifications')
          .select('id, message, metadata, status, delivered_at, target_criteria')
          .eq('user_id', user.id)
          .eq('status', 'unread')
          .or('target_criteria->>smart_notifications.eq.true,target_criteria->>source.eq.smart_notifications')
          .order('delivered_at', ascending: false)
          .limit(50); // Limit for performance

      if (response == null) return [];

      final List<SmartNotification> notifications = (response as List)
          .map((json) => SmartNotification.fromJson(json))
          .toList();

      if (kDebugMode) {
        print('✅ Loaded ${notifications.length} unread smart notifications');
      }

      return notifications;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading notifications: $e');
      }
      return [];
    }
  }

  /// Mark notification as read
  static Future<bool> markAsRead(String notificationId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final response = await _supabase
          .from('user_notifications')
          .update({'status': 'read', 'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId)
          .eq('user_id', user.id);

      if (kDebugMode) {
        print('✅ Marked notification as read: $notificationId');
      }

      return response != null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marking notification as read: $e');
      }
      return false;
    }
  }

  /// Mark all notifications as read for current user
  static Future<bool> markAllAsRead() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final response = await _supabase
          .from('user_notifications')
          .update({'status': 'read', 'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', user.id)
          .eq('status', 'unread');

      if (kDebugMode) {
        print('✅ Marked all notifications as read for user');
      }

      return response != null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marking all notifications as read: $e');
      }
      return false;
    }
  }

  /// Get notification count
  static Future<int> getUnreadCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;

      final response = await _supabase
          .from('user_notifications')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('user_id', user.id)
          .eq('status', 'unread');

      return response.count ?? 0;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting unread count: $e');
      }
      return 0;
    }
  }

  /// Listen to new notifications
  static Stream<List<SmartNotification>> watchNotifications() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _supabase
        .from('user_notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('delivered_at', ascending: false)
        .asyncMap((_) async => await getUnreadNotifications());
  }

  /// Delete old notifications (cleanup)
  static Future<bool> cleanupOldNotifications({int daysOld = 30}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

      final response = await _supabase
          .from('user_notifications')
          .delete()
          .eq('user_id', user.id)
          .lt('delivered_at', cutoffDate.toIso8601String());

      if (kDebugMode) {
        print('✅ Cleaned up notifications older than $daysOld days');
      }

      return response != null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error cleaning up old notifications: $e');
      }
      return false;
    }
  }
}

/// Smart notification model
class SmartNotification {
  final String id;
  final String message;
  final Map<String, dynamic> metadata;
  final String status;
  final DateTime deliveredAt;
  final Map<String, dynamic> targetCriteria;

  SmartNotification({
    required this.id,
    required this.message,
    required this.metadata,
    required this.status,
    required this.deliveredAt,
    required this.targetCriteria,
  });

  factory SmartNotification.fromJson(Map<String, dynamic> json) {
    return SmartNotification(
      id: json['id'],
      message: json['message'] ?? '',
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      status: json['status'] ?? 'unread',
      deliveredAt: DateTime.parse(json['delivered_at']),
      targetCriteria: Map<String, dynamic>.from(json['target_criteria'] ?? {}),
    );
  }

  /// Get title from metadata
  String get title => metadata['title'] ?? 'Notification';

  /// Get body from metadata
  String get body => metadata['body'] ?? message;

  /// Get type from metadata
  String get type => metadata['type'] ?? 'info';

  /// Get content type from metadata
  String? get contentType => metadata['content_type'];

  /// Get content ID from metadata
  String? get contentId => metadata['content_id'];

  /// Get icon from metadata or default based on type
  String get icon => metadata['icon'] ?? _getDefaultIcon();

  /// Get action URL from metadata
  String get actionUrl => metadata['action_url'] ?? '/home';

  /// Check if notification is unread
  bool get isUnread => status == 'unread';

  /// Check if it's a content notification
  bool get isContentNotification => type == 'content_published';

  /// Check if it's from smart notifications system
  bool get isSmartNotification =>
    targetCriteria['smart_notifications'] == true ||
    targetCriteria['batch_processed'] == true;

  String _getDefaultIcon() {
    switch (type) {
      case 'content_published':
        final contentType = metadata['content_type'];
        switch (contentType) {
          case 'video_kitab':
            return '📹';
          case 'video_episode':
            return '🎬';
          case 'ebook':
            return '📚';
          default:
            return '📖';
        }
      case 'payment_success':
        return '🎉';
      case 'subscription_expiring':
        return '⏰';
      case 'admin_announcement':
        return '📢';
      case 'maintenance':
        return '🔧';
      default:
        return 'ℹ️';
    }
  }

  /// Get formatted time ago
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(deliveredAt);

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minit yang lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari yang lalu';
    } else {
      return '${(difference.inDays / 7).floor()} minggu yang lalu';
    }
  }
}